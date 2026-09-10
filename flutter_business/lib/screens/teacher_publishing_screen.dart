import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/teacher_publishing_repository.dart';
import '../models/business_account.dart';

class TeacherPublishingScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const TeacherPublishingScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<TeacherPublishingScreen> createState() => _TeacherPublishingScreenState();
}

class _TeacherPublishingScreenState extends State<TeacherPublishingScreen> {
  bool loading = true;
  bool busy = false;
  String? error;
  List<Map<String, dynamic>> requests = [];
  List<Map<String, dynamic>> booklets = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.teacherPublishingRequests(widget.account.id),
        widget.repository.teacherApprovalBooklets(widget.account.id),
      ]);
      if (!mounted) return;
      setState(() {
        requests = values[0];
        booklets = values[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String statusLabel(dynamic value) => switch ('${value ?? ''}'.toLowerCase()) {
        'new' => 'تم الإرسال',
        'pending' => 'بانتظار المراجعة',
        'under_review' || 'review' => 'قيد المراجعة',
        'designing' => 'قيد التجهيز',
        'changes_requested' => 'مطلوب تعديل',
        'resubmitted' => 'أعيد الإرسال',
        'approved' => 'تمت الموافقة',
        'ready' => 'جاهزة للموافقة',
        'published' => 'منشورة',
        'rejected' => 'مرفوضة',
        _ => '${value ?? 'قيد المراجعة'}',
      };

  bool canResubmit(Map<String, dynamic> row) {
    final s = '${row['status'] ?? ''}'.toLowerCase();
    return s == 'changes_requested' || s == 'rejected';
  }

  int versionOf(Map<String, dynamic> row) {
    final history = row['version_history'];
    return history is List ? history.length + 1 : 1;
  }

  Future<PlatformFile?> pickDocx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (!file.name.toLowerCase().endsWith('.docx')) {
      snack('اختر ملف Word بصيغة DOCX فقط');
      return null;
    }
    if (file.bytes == null || file.bytes!.isEmpty) {
      snack('تعذر قراءة ملف Word');
      return null;
    }
    if (file.size > 20 * 1024 * 1024) {
      snack('حجم الملف يجب ألا يتجاوز 20MB');
      return null;
    }
    return file;
  }

  Future<void> createRequest() async {
    if (busy) return;
    final title = TextEditingController();
    final subject = TextEditingController();
    final grade = TextEditingController();
    final note = TextEditingController();
    PlatformFile? selected;

    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('رفع ملزمة جديدة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'اسم الملزمة *')),
              const SizedBox(height: 8),
              TextField(controller: subject, decoration: const InputDecoration(labelText: 'المادة')),
              const SizedBox(height: 8),
              TextField(controller: grade, decoration: const InputDecoration(labelText: 'الصف أو المرحلة')),
              const SizedBox(height: 8),
              TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات للإدارة')),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final file = await pickDocx();
                  if (file != null) setLocal(() => selected = file);
                },
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(selected == null ? 'اختيار ملف DOCX' : selected!.name, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 6),
              const Text('DOCX فقط — الحد الأقصى 20MB', style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final t = title.text.trim();
                if (t.length < 2) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('اكتب اسم الملزمة')));
                  return;
                }
                if (selected == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('اختر ملف DOCX')));
                  return;
                }
                Navigator.pop(dialogContext, {
                  'title': t,
                  'subject': subject.text.trim(),
                  'grade': grade.text.trim(),
                  'note': note.text.trim(),
                  'file': selected,
                });
              },
              child: const Text('إرسال للإدارة'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    subject.dispose();
    grade.dispose();
    note.dispose();
    if (data == null) return;

    setState(() => busy = true);
    try {
      final file = data['file'] as PlatformFile;
      await widget.repository.teacherCreatePublishingRequest(
        teacherId: widget.account.id,
        title: '${data['title']}',
        subject: '${data['subject']}',
        grade: '${data['grade']}',
        note: '${data['note']}',
        fileName: file.name,
        bytes: file.bytes!,
      );
      await load();
      snack('تم إرسال الملزمة للإدارة للمراجعة');
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resubmit(Map<String, dynamic> row) async {
    if (busy) return;
    final file = await pickDocx();
    if (file == null) return;
    if (!mounted) return;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة رفع التعديل'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(file.name, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظة للإدارة (اختياري)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إعادة الإرسال')),
        ],
      ),
    );
    final noteValue = note.text.trim();
    note.dispose();
    if (ok != true) return;

    setState(() => busy = true);
    try {
      await widget.repository.teacherResubmitPublishingRequest(
        teacherId: widget.account.id,
        requestId: '${row['id']}',
        note: noteValue,
        fileName: file.name,
        bytes: file.bytes!,
      );
      await load();
      snack('تم إعادة إرسال النسخة المعدلة');
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> approveBooklet(Map<String, dynamic> row) async {
    if (busy || row['teacher_approved'] == true) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('موافقة النشر'),
        content: Text('هل توافق على نشر «${row['title'] ?? 'الملزمة'}» بالنسخة النهائية التي جهزتها الإدارة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('أوافق على النشر')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => busy = true);
    try {
      await widget.repository.teacherApproveBooklet('${row['id']}');
      await load();
      snack('تم إرسال موافقتك إلى الإدارة');
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool isPublished(Map<String, dynamic> row) {
    return row['published'] == true || row['is_published'] == true || '${row['publish_status']}'.toLowerCase() == 'published';
  }

  bool hasFinalFile(Map<String, dynamic> row) => '${row['file_path'] ?? ''}'.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رفع ومتابعة الملازم'),
        actions: [IconButton(onPressed: loading || busy ? null : load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : createRequest,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('رفع ملزمة'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(children: [
                          Icon(Icons.lock_rounded),
                          SizedBox(width: 10),
                          Expanded(child: Text('المدرس يرفع ملف DOCX للمراجعة فقط. النسخة النهائية PDF ترفعها الإدارة وبعدها تظهر موافقة النشر.')),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      const Text('طلبات الرفع والتعديل', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (requests.isEmpty)
                        const _Empty(text: 'لا توجد طلبات رفع حتى الآن')
                      else
                        ...requests.map(_requestCard),
                      const SizedBox(height: 22),
                      const Text('النسخ النهائية وموافقة النشر', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (booklets.isEmpty)
                        const _Empty(text: 'لا توجد ملازم نهائية مرتبطة بحسابك حالياً')
                      else
                        ...booklets.map(_bookletCard),
                    ],
                  ),
                ),
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final s = '${row['status'] ?? 'new'}'.toLowerCase();
    final adminNote = '${row['admin_note'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${row['title'] ?? 'طلب ملزمة'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            Chip(label: Text(statusLabel(s))),
          ]),
          const SizedBox(height: 5),
          Text([row['subject'], row['grade']].where((v) => '${v ?? ''}'.trim().isNotEmpty).join(' — ')),
          const SizedBox(height: 6),
          Text('الإصدار: ${versionOf(row)} • الملف: ${row['source_file_name'] ?? '—'}', style: const TextStyle(fontSize: 12)),
          if ('${row['note'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ملاحظتك: ${row['note']}'),
          ],
          if (adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Text('ملاحظة الإدارة: $adminNote', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
          if (canResubmit(row)) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: busy ? null : () => resubmit(row),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('إعادة رفع التعديل'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _bookletCard(Map<String, dynamic> row) {
    final published = isPublished(row);
    final approved = row['teacher_approved'] == true;
    final finalFile = hasFinalFile(row);
    final note = '${row['admin_note'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${row['title'] ?? 'ملزمة'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            Chip(label: Text(published ? 'منشورة' : approved ? 'بانتظار الإدارة' : finalFile ? 'تحتاج موافقتك' : 'قيد التجهيز')),
          ]),
          const SizedBox(height: 6),
          Text([row['subject'], row['grade'], row['year']].where((v) => '${v ?? ''}'.trim().isNotEmpty).join(' — ')),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('ملاحظة الإدارة: $note'),
          ],
          if (!published && !approved && finalFile) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: busy ? null : () => approveBooklet(row),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('موافقة النشر'),
            ),
          ],
          if (approved && !published) ...[
            const SizedBox(height: 8),
            const Text('تمت موافقتك على النسخة النهائية، وبانتظار الإدارة للنشر.', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text(text)),
        ),
      );
}
