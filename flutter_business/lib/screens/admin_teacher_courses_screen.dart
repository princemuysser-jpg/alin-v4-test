import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminTeacherCoursesScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminTeacherCoursesScreen({super.key, required this.repository});

  @override
  State<AdminTeacherCoursesScreen> createState() => _AdminTeacherCoursesScreenState();
}

class _AdminTeacherCoursesScreenState extends State<AdminTeacherCoursesScreen> {
  bool loading = true;
  bool savingVisibility = false;
  bool sectionVisible = true;
  String? error;
  String filter = 'all';
  String search = '';
  List<Map<String, dynamic>> courses = [];

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
      final client = widget.repository.client;
      final values = await Future.wait([
        client.from('teacher_courses').select().order('created_at', ascending: false),
        client.from('teacher_courses_settings').select().eq('id', 'main').limit(1),
      ]);
      if (!mounted) return;
      final rows = (values[0] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final settings = (values[1] as List).whereType<Map>().toList();
      setState(() {
        courses = rows;
        sectionVisible = settings.isEmpty || settings.first['section_visible'] != false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String statusLabel(String value) => switch (value) {
        'draft' => 'مسودة',
        'pending' => 'بانتظار المراجعة',
        'published' => 'منشورة',
        'rejected' => 'مرفوضة',
        'hidden' => 'مخفية',
        _ => value.isEmpty ? '—' : value,
      };

  List<Map<String, dynamic>> get visibleRows {
    final q = search.trim().toLowerCase();
    return courses.where((row) {
      final status = '${row['status'] ?? ''}';
      if (filter != 'all' && status != filter) return false;
      if (q.isEmpty) return true;
      final text = '${row['subject'] ?? ''} ${row['title'] ?? ''} ${row['teacher_name'] ?? ''} ${row['grade'] ?? ''}'.toLowerCase();
      return text.contains(q);
    }).toList();
  }

  Future<void> toggleVisibility() async {
    if (savingVisibility) return;
    setState(() => savingVisibility = true);
    try {
      await widget.repository.client.from('teacher_courses_settings').upsert({
        'id': 'main',
        'section_visible': !sectionVisible,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
      if (!mounted) return;
      setState(() => sectionVisible = !sectionVisible);
      _toast(sectionVisible ? 'تم إظهار بطاقات الدورات' : 'تم إخفاء بطاقات الدورات');
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => savingVisibility = false);
    }
  }

  Future<void> updateCourse(Map<String, dynamic> course, Map<String, dynamic> values, String success) async {
    final id = '${course['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await widget.repository.client.from('teacher_courses').update(values).eq('id', id);
      await load();
      if (mounted) _toast(success);
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> publish(Map<String, dynamic> course) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await updateCourse(course, {
      'status': 'published',
      'approved_at': now,
      'published_at': now,
      'admin_note': null,
    }, 'تمت الموافقة ونشر الدورة');
  }

  Future<void> hide(Map<String, dynamic> course) =>
      updateCourse(course, {'status': 'hidden'}, 'تم إخفاء الدورة');

  Future<void> show(Map<String, dynamic> course) => updateCourse(course, {
        'status': 'published',
        'published_at': DateTime.now().toUtc().toIso8601String(),
      }, 'تم إظهار الدورة');

  Future<void> reject(Map<String, dynamic> course) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض الدورة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'سبب الرفض أو الملاحظة للمدرس'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('تأكيد الرفض')),
        ],
      ),
    );
    controller.dispose();
    if (note == null) return;
    await updateCourse(course, {
      'status': 'rejected',
      'admin_note': note.isEmpty ? 'يرجى تعديل بيانات الدورة' : note,
    }, 'تم رفض الدورة وإضافة الملاحظة');
  }

  Future<void> deleteCourse(Map<String, dynamic> course) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف الدورة'),
            content: Text('حذف دورة «${course['title'] ?? course['subject'] ?? ''}» نهائياً؟'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final id = '${course['id'] ?? ''}';
    if (id.isEmpty) return;
    try {
      await widget.repository.client.from('teacher_courses').delete().eq('id', id);
      await load();
      if (mounted) _toast('تم حذف الدورة');
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final pending = courses.where((e) => '${e['status']}' == 'pending').length;
    final published = courses.where((e) => '${e['status']}' == 'published').length;
    final hidden = courses.where((e) => '${e['status']}' == 'hidden').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('دورات المدرسين'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _header(pending),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth >= 950 ? 4 : 2;
                          return GridView.count(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: c.maxWidth >= 950 ? 2.2 : 1.55,
                            children: [
                              _metric('كل الدورات', '${courses.length}', Icons.video_library_rounded),
                              _metric('بانتظار المراجعة', '$pending', Icons.hourglass_top_rounded),
                              _metric('منشورة', '$published', Icons.public_rounded),
                              _metric('مخفية', '$hidden', Icons.visibility_off_rounded),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _filters(),
                      const SizedBox(height: 12),
                      if (visibleRows.isEmpty)
                        const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد دورات ضمن هذا الفلتر'))))
                      else
                        ...visibleRows.map(_courseCard),
                    ],
                  ),
                ),
    );
  }

  Widget _header(int pending) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: BusinessBrand.heroGradient, borderRadius: BorderRadius.circular(24)),
        child: LayoutBuilder(
          builder: (context, c) {
            final content = [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إدارة دورات المدرسين', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('$pending دورة بانتظار المراجعة', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: BusinessBrand.navy),
                onPressed: savingVisibility ? null : toggleVisibility,
                icon: Icon(sectionVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                label: Text(sectionVisible ? 'إخفاء بطاقات الدورات' : 'إظهار بطاقات الدورات'),
              ),
            ];
            if (c.maxWidth >= 650) return Row(children: content);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [content.first, const SizedBox(height: 14), content.last]);
          },
        ),
      );

  Widget _metric(String label, String value, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            CircleAvatar(backgroundColor: BusinessBrand.softBlue, child: Icon(icon, color: BusinessBrand.navy)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
      );

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, c) {
              final dropdown = DropdownButtonFormField<String>(
                value: filter,
                decoration: const InputDecoration(labelText: 'الحالة'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'pending', child: Text('بانتظار المراجعة')),
                  DropdownMenuItem(value: 'published', child: Text('منشورة')),
                  DropdownMenuItem(value: 'hidden', child: Text('مخفية')),
                  DropdownMenuItem(value: 'rejected', child: Text('مرفوضة')),
                  DropdownMenuItem(value: 'draft', child: Text('مسودة')),
                ],
                onChanged: (value) => setState(() => filter = value ?? 'all'),
              );
              final field = TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: const InputDecoration(labelText: 'بحث', hintText: 'المادة أو اسم المدرس أو عنوان الدورة', prefixIcon: Icon(Icons.search_rounded)),
              );
              if (c.maxWidth >= 700) return Row(children: [SizedBox(width: 230, child: dropdown), const SizedBox(width: 10), Expanded(child: field)]);
              return Column(children: [dropdown, const SizedBox(height: 10), field]);
            },
          ),
        ),
      );

  Widget _courseCard(Map<String, dynamic> row) {
    final status = '${row['status'] ?? ''}';
    final cover = '${row['cover_image_path'] ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final info = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 82,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(color: BusinessBrand.softBlue, borderRadius: BorderRadius.circular(14)),
                  child: cover.isEmpty
                      ? const Icon(Icons.school_rounded, color: BusinessBrand.navy, size: 32)
                      : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, color: BusinessBrand.navy)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 7, runSpacing: 5, children: [
                      Chip(label: Text(statusLabel(status))),
                      if ('${row['grade'] ?? ''}'.trim().isNotEmpty) Chip(label: Text('${row['grade']}')),
                    ]),
                    Text('${row['subject'] ?? 'دورة'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text('${row['teacher_name'] ?? '—'} — ${row['title'] ?? '—'}'),
                    if ('${row['start_date'] ?? ''}'.isNotEmpty) Text('البداية: ${row['start_date']}', style: const TextStyle(color: BusinessBrand.muted)),
                    if ('${row['admin_note'] ?? ''}'.trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('ملاحظة الإدارة: ${row['admin_note']}', style: const TextStyle(color: BusinessBrand.orange))),
                  ]),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.end,
              children: [
                if (status != 'published' && status != 'hidden') FilledButton.icon(onPressed: () => publish(row), icon: const Icon(Icons.publish_rounded), label: const Text('موافقة ونشر')),
                if (status == 'published') OutlinedButton.icon(onPressed: () => hide(row), icon: const Icon(Icons.visibility_off_rounded), label: const Text('إخفاء')),
                if (status == 'hidden') FilledButton.icon(onPressed: () => show(row), icon: const Icon(Icons.visibility_rounded), label: const Text('إظهار')),
                OutlinedButton.icon(onPressed: () => reject(row), icon: const Icon(Icons.block_rounded), label: const Text('رفض')),
                IconButton(onPressed: () => deleteCourse(row), tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded)),
              ],
            );
            if (c.maxWidth >= 800) return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: info), const SizedBox(width: 12), Flexible(child: actions)]);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 12), actions]);
          },
        ),
      ),
    );
  }
}
