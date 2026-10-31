import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prepares light public storefront images without touching printable PDF/DOCX.
///
/// A unique pair of immutable objects is uploaded for each new image:
///   <stem>.full.webp (or the original smaller JPG/PNG/WebP)
///   <stem>.thumb.webp
/// The thumbnail is deliberately a different URL: Flutter's local decode-size
/// options alone do NOT save network transfer / Supabase Cached Egress.
class OptimizedStoreMedia {
  const OptimizedStoreMedia({
    required this.fullBytes,
    required this.fullExtension,
    required this.fullContentType,
    required this.thumbnailBytes,
  });

  final Uint8List fullBytes;
  final String fullExtension;
  final String fullContentType;
  final Uint8List thumbnailBytes;

  static String thumbnailPath(String fullPath) {
    return fullPath.replaceFirst(
      RegExp(r'\.full\.(webp|png|jpg|jpeg)$', caseSensitive: false),
      '.thumb.webp',
    );
  }

  /// Limited to public product/cover/banner imagery, never high-res print files.
  static OptimizedStoreMedia fromBytes(
    Uint8List source, {
    required String sourceExtension,
    int maxFullSide = 1600,
    int maxThumbSide = 360,
  }) {
    if (source.isEmpty || source.length > 5 * 1024 * 1024) {
      throw const FormatException('الصورة غير صالحة أو تتجاوز 5MB');
    }
    final original = img.decodeImage(source);
    if (original == null) throw const FormatException('تعذر قراءة الصورة');
    if (original.width < 1 || original.height < 1 ||
        original.width * original.height > 40 * 1000 * 1000) {
      throw const FormatException('أبعاد الصورة كبيرة جداً');
    }

    img.Image resized(img.Image value, int side) {
      if (value.width <= side && value.height <= side) return value;
      return value.width >= value.height
          ? img.copyResize(value, width: side)
          : img.copyResize(value, height: side);
    }

    final large = resized(original, maxFullSide);
    final small = resized(original, maxThumbSide);
    final webp = img.encodeWebP(large, lossless: false, quality: 80, alphaQuality: 95);
    final thumb = img.encodeWebP(small, lossless: false, quality: 72, alphaQuality: 95);

    final extension = sourceExtension.toLowerCase() == 'jpeg'
        ? 'jpg'
        : sourceExtension.toLowerCase();
    final originalMime = switch (extension) {
      'jpg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const FormatException('نوع الصورة غير مدعوم'),
    };
    // Keep an already-smaller original when it does not need dimension changes.
    final preserveOriginal = identical(large, original) && source.length <= webp.length;
    return OptimizedStoreMedia(
      fullBytes: preserveOriginal ? source : webp,
      fullExtension: preserveOriginal ? extension : 'webp',
      fullContentType: preserveOriginal ? originalMime : 'image/webp',
      thumbnailBytes: thumb,
    );
  }
}
