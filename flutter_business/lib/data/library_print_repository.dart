import 'dart:typed_data';

import 'business_repository.dart';

extension LibraryPrintRepository on BusinessRepository {
  Future<void> librarySetOrderNote(String orderId, String note) async {
    final text = note.trim();
    if (text.length < 2) throw Exception('اكتب ملاحظة واضحة');
    final raw = await client.rpc(
      'alin_library_set_order_note',
      params: {'p_order_id': orderId, 'p_note': text},
    );
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر حفظ ملاحظة المكتبة');
  }

  Future<Map<String, dynamic>> libraryBookletPrintContext(String orderId) async {
    final raw = await client.rpc(
      'alin_library_booklet_print_context',
      params: {'p_order_id': orderId},
    );
    if (raw is! Map) throw Exception('تعذر تجهيز ملف الملزمة');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) {
      throw Exception('${map['error'] ?? 'تعذر تجهيز ملف الملزمة'}');
    }
    return map;
  }

  Future<Uint8List> libraryDownloadProtectedBooklet({
    required String bucket,
    required String objectPath,
  }) async {
    final bytes = await client.storage.from(bucket).download(objectPath);
    if (bytes.isEmpty) throw Exception('ملف الملزمة فارغ');
    return bytes;
  }

  Future<void> libraryUsePrintPermit(String permitId) async {
    final raw = await client.rpc(
      'alin_use_print_permit',
      params: {'p_permit_id': permitId},
    );
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر تثبيت استخدام إذن الطباعة');
  }
}
