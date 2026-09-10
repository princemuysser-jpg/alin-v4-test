import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'business_repository.dart';

extension TeacherPublishingRepository on BusinessRepository {
  Future<List<Map<String, dynamic>>> teacherPublishingRequests(String teacherId) async {
    final raw = await client
        .from('teacher_requests')
        .select('id,teacher_id,title,subject,grade,note,admin_note,source_file_name,status,version_history,reviewed_at,created_at,updated_at')
        .eq('teacher_id', teacherId)
        .order('updated_at', ascending: false)
        .limit(200);
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> teacherApprovalBooklets(String teacherId) async {
    final raw = await client
        .from('booklets')
        .select('id,title,subject,grade,year,price,status,publish_status,published,is_published,teacher_approved,teacher_approved_at,file_path,file_name,admin_note,updated_at')
        .eq('teacher_id', teacherId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .limit(200);
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  String _requestId() {
    final r = Random.secure().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'TR${DateTime.now().microsecondsSinceEpoch}$r';
  }

  String _safeFileName(String name) {
    final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return clean.toLowerCase().endsWith('.docx') ? clean : '$clean.docx';
  }

  Future<Map<String, dynamic>> teacherCreatePublishingRequest({
    required String teacherId,
    required String title,
    required String subject,
    required String grade,
    required String note,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw Exception('ملف Word فارغ');
    if (bytes.length > 20 * 1024 * 1024) throw Exception('حجم ملف Word يجب ألا يتجاوز 20MB');
    if (!fileName.toLowerCase().endsWith('.docx')) throw Exception('الملف يجب أن يكون DOCX');

    final requestId = _requestId();
    final objectPath = 'teacher-requests/$teacherId/$requestId/${_safeFileName(fileName)}';
    await client.storage.from('alin-private').uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ),
        );
    try {
      final raw = await client.rpc('alin_teacher_create_request', params: {
        'p_id': requestId,
        'p_title': title.trim(),
        'p_subject': subject.trim(),
        'p_grade': grade.trim(),
        'p_note': note.trim(),
        'p_source_file_path': objectPath,
        'p_source_file_name': fileName,
        'p_source_mime_type': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      });
      if (raw is! Map) throw Exception('لم يؤكد السيرفر إرسال الطلب');
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر إرسال الطلب'}');
      return map;
    } catch (_) {
      try {
        await client.storage.from('alin-private').remove([objectPath]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<Map<String, dynamic>> teacherResubmitPublishingRequest({
    required String teacherId,
    required String requestId,
    required String note,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) throw Exception('ملف Word فارغ');
    if (bytes.length > 20 * 1024 * 1024) throw Exception('حجم ملف Word يجب ألا يتجاوز 20MB');
    if (!fileName.toLowerCase().endsWith('.docx')) throw Exception('الملف يجب أن يكون DOCX');

    final rev = DateTime.now().microsecondsSinceEpoch;
    final objectPath = 'teacher-requests/$teacherId/$requestId/rev-$rev-${_safeFileName(fileName)}';
    await client.storage.from('alin-private').uploadBinary(
          objectPath,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          ),
        );
    try {
      final raw = await client.rpc('alin_teacher_resubmit_request', params: {
        'p_id': requestId,
        'p_source_file_path': objectPath,
        'p_source_file_name': fileName,
        'p_note': note.trim(),
      });
      if (raw is! Map) throw Exception('لم يؤكد السيرفر إعادة الإرسال');
      final map = Map<String, dynamic>.from(raw);
      if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر إعادة الإرسال'}');
      return map;
    } catch (_) {
      try {
        await client.storage.from('alin-private').remove([objectPath]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> teacherApproveBooklet(String bookletId) async {
    final raw = await client.rpc('alin_teacher_approve_booklet', params: {'p_booklet_id': bookletId});
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر إرسال موافقة النشر');
  }
}
