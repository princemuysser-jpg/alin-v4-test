import 'package:flutter/material.dart';
import '../core/app_scope.dart';

class AlinNetworkImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool thumbnail;
  const AlinNetworkImage({
    super.key,
    required this.path,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.borderRadius,
    this.thumbnail = false,
  });

  @override
  Widget build(BuildContext context) {
    final media = AppScope.of(context);
    final url = media.mediaUrl(path);
    final thumbnailPath = thumbnail
        ? path.replaceFirst(
            RegExp(r'\.full\.(webp|png|jpe?g)(?=$|\?)', caseSensitive: false),
            '.thumb.webp',
          )
        : path;
    final smallUrl = thumbnailPath == path ? url : media.mediaUrl(thumbnailPath);
    Widget picture(String source) => Image.network(
          source,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: thumbnail ? 520 : null,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF0F4F8),
            alignment: Alignment.center,
            child: Image.asset('assets/images/alin_icon.png', width: 72, fit: BoxFit.contain),
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
    final child = url.isEmpty
        ? Container(
            color: const Color(0xFFF0F4F8),
            alignment: Alignment.center,
            child: Image.asset('assets/images/alin_icon.png', width: 72, fit: BoxFit.contain),
          )
        : smallUrl != url
            ? Image.network(
                smallUrl,
                width: width,
                height: height,
                fit: fit,
                cacheWidth: 520,
                errorBuilder: (_, __, ___) => picture(url),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : picture(url);
    return ClipRRect(borderRadius: borderRadius ?? BorderRadius.zero, child: child);
  }
}
