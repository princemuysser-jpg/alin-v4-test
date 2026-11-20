import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

/// Admin-only booklet management, distinct from store books/products.
class AdminBookletsScreen extends StatefulWidget {
  final BusinessRepository repository;
  final bool openCreate;
  const AdminBookletsScreen({super.key, required this.repository, this.openCreate = false});
  @override
  State<AdminBookletsScreen> createState() => _AdminBookletsScreenState();
}

class _AdminBookletsScreenState extends State<AdminBookletsScreen> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> booklets = [], teachers = [];
  String statusFilter = 'all', gradeFilter = 'all', subjectFilter = 'all',
      teacherFilter = 'all', query = '';
  bool loading = true, busy = false;
  String? error;
  SupabaseClient get client => widget.repository.client;
  String text(dynamic value) => '${value ?? ''}'.trim();
  num amount(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${amount(value).round()} د.ع';

  @override
  void initState() {
    super.initState();
    load(openCreate: widget.openCreate);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load({bool openCreate = false}) async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final result = await Future.wait([
        widget.repository.adminBooklets(),
        client.from('accounts').select('id,name,status,deleted_at')
          .eq('role', 'teacher').isFilter('deleted_at', null).order('name'),
      ]);
      if (!mounted) return;
      setState(() {
        booklets = (result[0] as List).whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .where((x) => x['deleted_at'] == null).toList();
        teachers = (result[1] as List).whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x)).toList();
      });
      if (openCreate && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) edit();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String status(Map<String, dynamic> row) {
    final s = text(row['publish_status']);
    return s.isNotEmpty ? s : (text(row['status']).isEmpty ? 'draft' : text(row['status']));
  }

  String label(String v) => switch (v) {
    'published' => 'منشورة', 'hidden' => 'مخفية',
    'draft' => 'مسودة', 'review' || 'pending' => 'قيد المراجعة',
    'archived' => 'مؤرشفة', _ => v,
  };

  Color tint(String s) => switch(s) {
    'published' => BusinessBrand.success,
    'review' || 'pending' => BusinessBrand.warning,
    'hidden' => const Color(0xFF7958A8),
    _ => const Color(0xFF397ACA),
  };

  String teacherName(String id) {
    for (final row in teachers) {
      if (text(row['id']) == id) return text(row['name']);
    }
    return 'مدرس غير محدد';
  }

  List<String> values(String key) =>
    (booklets.map((b) => text(b[key])).where((v) => v.isNotEmpty).toSet().toList()..sort());

  List<Map<String, dynamic>> get visible => booklets.where((b) {
    if (statusFilter != 'all' && status(b) != statusFilter &&
        !(statusFilter == 'review' && status(b) == 'pending')) return false;
    if (gradeFilter != 'all' && text(b['grade']) != gradeFilter) return false;
    if (subjectFilter != 'all' && text(b['subject']) != subjectFilter) return false;
    if (teacherFilter != 'all' && text(b['teacher_id']) != teacherFilter) return false;
    final q = query.trim().toLowerCase();
    return q.isEmpty || [
      b['title'], b['subject'], b['grade'], b['year'],
      teacherName(text(b['teacher_id'])),
    ].map((x) => text(x).toLowerCase()).join(' ').contains(q);
  }).toList();

  Future<PlatformFile?> pick(List<String> types, int maxBytes) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: types,
      withData: true, allowMultiple: false);
    if (selected == null || selected.files.isEmpty) return null;
    final file = selected.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) throw Exception('تعذر قراءة الملف');
    if (file.size > maxBytes) throw Exception('الملف أكبر من الحجم المسموح');
    if (!types.contains((file.extension ?? '').toLowerCase())) throw Exception('صيغة الملف غير مدعومة');
    return file;
  }

  void notice(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
  }

  Future<void> edit([Map<String, dynamic>? existing]) async {
    if (busy || !mounted) return;
    final fields = <String, TextEditingController>{
      for (final key in ['title','subject','grade','term','edition','price','admin_note'])
        key: TextEditingController(text: text(existing?[key])),
      'platform_share_percent': TextEditingController(
        text: existing == null ? '20' : text(existing['platform_share_percent'])),
      'teacher_share_percent': TextEditingController(
        text: existing == null ? '50' : text(existing['teacher_share_percent'])),
      'library_share_percent': TextEditingController(
        text: existing == null ? '30' : text(existing['library_share_percent'])),
    };
    fields['price']!.text = fields['price']!.text.isEmpty ? '0' : fields['price']!.text;
    String teacherId = text(existing?['teacher_id']);
    String selectedStatus = existing == null ? 'draft' : status(existing);
    if (!{'draft','review','published','hidden','archived'}.contains(selectedStatus)) {
      selectedStatus = 'draft';
    }
    PlatformFile? pdf, cover;
    bool picking = false;
    try {
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, local) => AlertDialog(
            title: Text(existing == null ? 'إضافة ملزمة' : 'تعديل الملزمة'),
            content: SizedBox(width: 590, child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final entry in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: TextField(controller: entry.value,
                      keyboardType: const {'price','platform_share_percent',
                        'teacher_share_percent','library_share_percent'}.contains(entry.key)
                        ? const TextInputType.numberWithOptions(decimal: true) : null,
                      maxLines: entry.key == 'admin_note' ? 2 : 1,
                      decoration: InputDecoration(labelText: switch(entry.key) {
                        'title' => 'اسم الملزمة *', 'subject' => 'المادة',
                        'grade' => 'الصف', 'term' => 'الفصل',
                        'edition' => 'الإصدار / السنة', 'price' => 'السعر بالدينار *',
                        'admin_note' => 'ملاحظات الإدارة',
                        'platform_share_percent' => 'حصة المنصة %',
                        'teacher_share_percent' => 'حصة المدرس %',
                        _ => 'حصة المكتبة %',
                      })),
                  ),
                DropdownButtonFormField<String>(
                  key: ValueKey(teacherId),
                  initialValue: teachers.any((t) => text(t['id']) == teacherId)
                    ? teacherId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'المدرس *'),
                  items: teachers.where((t) => text(t['status']) == 'active' ||
                      text(t['id']) == teacherId).map((t) =>
                    DropdownMenuItem(value: text(t['id']),
                      child: Text(text(t['name']), overflow: TextOverflow.ellipsis)))
                        .toList(),
                  onChanged: (v) => local(() => teacherId = v ?? ''),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'حالة النشر'),
                  items: const [
                    DropdownMenuItem(value: 'draft',child: Text('مسودة')),
                    DropdownMenuItem(value: 'review',child: Text('قيد المراجعة')),
                    DropdownMenuItem(value: 'published',child: Text('منشورة')),
                    DropdownMenuItem(value: 'hidden',child: Text('مخفية')),
                    DropdownMenuItem(value: 'archived',child: Text('مؤرشفة')),
                  ],
                  onChanged: (v) => local(() => selectedStatus = v ?? 'draft'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: picking ? null : () async {
                    local(() => picking = true);
                    try {
                      final selected = await pick(['pdf'], 25 * 1024 * 1024);
                      if (selected != null && dialogContext.mounted) local(() => pdf = selected);
                    } catch (e) { if (dialogContext.mounted) notice(e); }
                    finally { if (dialogContext.mounted) local(() => picking = false); }
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(pdf == null
                    ? (existing == null ? 'اختيار PDF * (حتى 25MB)' : 'استبدال PDF (اختياري)')
                    : 'PDF: ${pdf!.name}', overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: picking ? null : () async {
                    local(() => picking = true);
                    try {
                      final selected = await pick(['png','jpg','jpeg','webp'], 5 * 1024 * 1024);
                      if (selected != null && dialogContext.mounted) local(() => cover = selected);
                    } catch(e) { if (dialogContext.mounted) notice(e); }
                    finally { if (dialogContext.mounted) local(() => picking = false); }
                  },
                  icon: const Icon(Icons.image_rounded),
                  label: Text(cover == null ? 'اختيار الغلاف (حتى 5MB)'
                    : 'الغلاف: ${cover!.name}', overflow: TextOverflow.ellipsis),
                ),
                if (existing != null) const Text(
                  'اترك PDF والغلاف فارغين للاحتفاظ بالملفات الحالية.',
                  style: TextStyle(color: BusinessBrand.muted, fontSize: 11)),
              ]),
            )),
            actions: [
              TextButton(onPressed: picking ? null : () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
              FilledButton(
                onPressed: picking ? null : () {
                  final price = num.tryParse(fields['price']!.text.trim());
                  final p = num.tryParse(fields['platform_share_percent']!.text.trim());
                  final t = num.tryParse(fields['teacher_share_percent']!.text.trim());
                  final l = num.tryParse(fields['library_share_percent']!.text.trim());
                  if (fields['title']!.text.trim().isEmpty || teacherId.isEmpty ||
                      price == null || price < 0 || p == null || t == null || l == null ||
                      p < 0 || t < 0 || l < 0 || p > 100 || t > 100 || l > 100 ||
                      (p+t+l-100).abs() > .001 ||
                      (existing == null && pdf == null)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(
                      content: Text('تحقق من الاسم والمدرس وPDF والسعر ومجموع النسب 100%')));
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    for (final key in ['title','subject','grade','term','edition','admin_note'])
                      key: fields[key]!.text.trim(),
                    'year': fields['edition']!.text.trim(), 'teacher_id': teacherId,
                    'price': price, 'platform_share_percent': p,
                    'teacher_share_percent': t, 'library_share_percent': l,
                    'status': selectedStatus, 'publish_status': selectedStatus,
                    'published': selectedStatus == 'published',
                    'is_published': selectedStatus == 'published',
                    '_pdf': pdf, '_cover': cover,
                  });
                },
                child: const Text('حفظ الملزمة'),
              ),
            ],
          )),
      );
      if (data == null || !mounted) return;
      await save(existing, data);
    } finally {
      for (final c in fields.values) { c.dispose(); }
    }
  }

  Future<void> save(Map<String,dynamic>? existing, Map<String,dynamic> data) async {
    if (busy) return;
    setState(() => busy = true);
    final id = existing == null
        ? 'B${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}'
        : text(existing['id']);
    final uploaded = <(String,String)>[];
    try {
      final payload = {...data}..remove('_pdf')..remove('_cover');
      final pdf = data['_pdf'] as PlatformFile?;
      final cover = data['_cover'] as PlatformFile?;
      if (pdf != null) {
        final path = 'booklets/$id/${DateTime.now().microsecondsSinceEpoch}.pdf';
        await client.storage.from('alin-private').uploadBinary(
          path, pdf.bytes!,
          fileOptions: const FileOptions(contentType:'application/pdf',upsert:false));
        uploaded.add(('alin-private',path));
        payload['file_path'] = path;
        payload['file_name'] = pdf.name;
      }
      if (cover != null) {
        final ext = (cover.extension ?? 'png').toLowerCase();
        final mime = ext == 'webp' ? 'image/webp'
          : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/png');
        final path = 'covers/booklets/$id/${DateTime.now().microsecondsSinceEpoch}.$ext';
        await client.storage.from('alin-files').uploadBinary(
          path, cover.bytes!,
          fileOptions: FileOptions(contentType:mime,upsert:false));
        uploaded.add(('alin-files',path));
        payload['cover_path'] = path;
      }
      payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
      if (existing == null) {
        payload['id'] = id;
        await client.from('booklets').insert(payload);
      } else {
        await client.from('booklets').update(payload).eq('id', id);
      }
      notice(existing == null ? 'تمت إضافة الملزمة بنجاح' : 'تم تحديث الملزمة بنجاح');
      await load();
    } catch(e) {
      for (final obj in uploaded) {
        try { await client.storage.from(obj.$1).remove([obj.$2]); } catch (_) {}
      }
      notice(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget dropdown(String label, String value, List<String> choices,
    ValueChanged<String> change, {String? allName}) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value, isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: 'all',child: Text(allName ?? 'الكل')),
        ...choices.map((v) => DropdownMenuItem(value: v,
          child: Text(label == 'الحالة' ? this.label(v) : v,
            overflow: TextOverflow.ellipsis))),
      ],
      onChanged: (v) { if(v != null) setState(() => change(v)); },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = visible;
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الملازم'),
        actions:[IconButton(onPressed: () => load(),
          tooltip:'تحديث',icon:const Icon(Icons.refresh_rounded))]),
      floatingActionButton: loading || error != null ? null :
        FloatingActionButton.extended(
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add_rounded),label: const Text('إضافة ملزمة')),
      body: loading ? const Center(child:CircularProgressIndicator()) :
        error != null ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          Text(error!),FilledButton(onPressed:()=>load(),
            child:const Text('إعادة المحاولة')),
        ])) : RefreshIndicator(
          onRefresh: load,
          child: ListView.builder(
            padding:const EdgeInsets.fromLTRB(14,14,14,100),
            itemCount: rows.length+1,
            itemBuilder:(context,index) {
              if(index==0) return Column(
                crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                  Wrap(spacing:8,runSpacing:8,children:[
                    _stat('الإجمالي',booklets.length,Icons.menu_book_rounded,BusinessBrand.navy),
                    _stat('المنشورة',booklets.where((b)=>status(b)=='published').length,
                      Icons.check_circle_rounded,BusinessBrand.success),
                    _stat('المخفية',booklets.where((b)=>status(b)=='hidden').length,
                      Icons.visibility_off_rounded,const Color(0xFF7958A8)),
                    _stat('المسودات والمراجعة',booklets.where((b)=>
                      {'draft','review','pending'}.contains(status(b))).length,
                      Icons.edit_note_rounded,BusinessBrand.warning),
                  ]),
                  const SizedBox(height:12),
                  Container(padding:const EdgeInsets.all(12),
                    decoration:BusinessBrand.panelDecoration(),child:Column(children:[
                      TextField(controller:searchController,
                        onChanged:(v)=>setState(()=>query=v),
                        decoration:const InputDecoration(
                          labelText:'بحث باسم الملزمة أو المدرس أو المادة',
                          prefixIcon:Icon(Icons.search_rounded))),
                      const SizedBox(height:8),
                      LayoutBuilder(builder:(context,constraints) {
                        final width=constraints.maxWidth<600
                            ? constraints.maxWidth : (constraints.maxWidth-10)/2;
                        return Wrap(spacing:10,runSpacing:10,children:[
                          SizedBox(width:width,child:dropdown('الحالة',statusFilter,
                            ['published','hidden','draft','review','archived'],
                            (v)=>statusFilter=v)),
                          SizedBox(width:width,child:dropdown('الصف',gradeFilter,
                            values('grade'),(v)=>gradeFilter=v)),
                          SizedBox(width:width,child:dropdown('المادة',subjectFilter,
                            values('subject'),(v)=>subjectFilter=v)),
                          SizedBox(width:width,child:DropdownButtonFormField<String>(
                            key:ValueKey('teacher:$teacherFilter'),
                            initialValue:teacherFilter,
                            isExpanded:true,
                            decoration:const InputDecoration(labelText:'المدرس'),
                            items:[
                              const DropdownMenuItem(value:'all',child:Text('كل المدرسين')),
                              ...teachers.map((t)=>DropdownMenuItem(
                                value:text(t['id']),child:Text(text(t['name']),
                                  overflow:TextOverflow.ellipsis))),
                            ],
                            onChanged:(v){if(v!=null)setState(()=>teacherFilter=v);},
                          )),
                        ]);
                      }),
                    ]),
                  ),
                  const SizedBox(height:12),
                  Text('${rows.length} ملزمة مطابقة',
                    style:const TextStyle(fontWeight:FontWeight.w900)),
                  const SizedBox(height:10),
                  if(rows.isEmpty) const Padding(padding:EdgeInsets.all(35),
                    child:Center(child:Text('ماكو ملازم مطابقة'))),
                ]);
              final b=rows[index-1];
              final current=status(b), accent=tint(current);
              final cover=text(b['cover_path']);
              final url=cover.startsWith('http')?cover:
                client.storage.from('alin-files').getPublicUrl(cover);
              return Card(
                color:BusinessBrand.pastel(accent,strength:.075),
                margin:const EdgeInsets.only(bottom:9),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),
                  side:BorderSide(color:accent.withValues(alpha:.22))),
                child:ListTile(
                  leading:SizedBox(width:53,height:65,child:cover.isEmpty
                    ? Icon(Icons.menu_book_rounded,color:accent,size:28)
                    : Image.network(url,fit:BoxFit.cover,errorBuilder:(_,__,___)=>
                        Icon(Icons.menu_book_rounded,color:accent))),
                  title:Text(text(b['title']),
                    style:const TextStyle(fontWeight:FontWeight.w900)),
                  subtitle:Text('${teacherName(text(b['teacher_id']))} • ${text(b['subject'])} • ${text(b['grade'])}\n${money(b['price'])} • ${label(current)}',
                    maxLines:3,overflow:TextOverflow.ellipsis),
                  trailing:IconButton(tooltip:'تعديل',onPressed:busy?null:()=>edit(b),
                    icon:Icon(Icons.edit_rounded,color:accent)),
                  onTap:busy?null:()=>edit(b),
                ),
              );
            },
          ),
        ),
    );
  }

  Widget _stat(String title,int value,IconData icon,Color accent) =>
    Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
      decoration:BusinessBrand.pastelCard(accent,strength:.12),
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(icon,color:accent,size:18),const SizedBox(width:7),
        Text('$value',style:const TextStyle(fontWeight:FontWeight.w900)),
        const SizedBox(width:5),Text(title,style:const TextStyle(fontSize:11)),
      ]),
    );
}
