import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminBackupScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminBackupScreen({super.key, required this.repository});

  @override
  State<AdminBackupScreen> createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<AdminBackupScreen> {
  bool busy = false;
  String? status;
  Map<String, dynamic>? pending;
  String? pendingName;

  static const backupVersion = '3.0.3-flutter';
  static const restorableTables = ['categories', 'products', 'booklets', 'banners', 'coupons'];

  Future<Map<String, dynamic>> _snapshot() async {
    final client = widget.repository.client;
    final results = await Future.wait([
      client.from('settings').select('key,value'),
      client.from('categories').select('*'),
      client.from('products').select('*'),
      client.from('booklets').select('*'),
      client.from('banners').select('*'),
      client.from('coupons').select('*'),
    ]);

    final settingRows = (results[0] as List).whereType<Map>();
    final settings = <String, dynamic>{};
    for (final row in settingRows) {
      final key = '${row['key'] ?? ''}';
      if (key.isNotEmpty) settings[key] = row['value'];
    }

    final booklets = (results[3] as List)
        .whereType<Map>()
        .map((row) {
          final clean = Map<String, dynamic>.from(row);
          for (final key in const ['pdf_url', 'pdf_path', 'file_url', 'file_path', 'storage_path', 'signed_url']) {
            clean.remove(key);
          }
          return clean;
        })
        .toList();

    List<Map<String, dynamic>> rows(dynamic raw) =>
        (raw as List).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();

    final data = <String, dynamic>{
      'settings': settings,
      'categories': rows(results[1]),
      'products': rows(results[2]),
      'booklets': booklets,
      'banners': rows(results[4]),
      'coupons': rows(results[5]),
    };

    return {
      'app': 'ALIN',
      'format': 'alin-cloud-backup',
      'backup_version': backupVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'schema': 'catalog-settings-v2-no-personal-data',
      'counts': {
        'categories': (data['categories'] as List).length,
        'products': (data['products'] as List).length,
        'booklets': (data['booklets'] as List).length,
        'banners': (data['banners'] as List).length,
        'coupons': (data['coupons'] as List).length,
      },
      'data': data,
    };
  }

  Map<String, dynamic> _validate(dynamic raw) {
    if (raw is! Map) throw Exception('الملف ليس نسخة احتياطية صالحة');
    final object = Map<String, dynamic>.from(raw);
    if (object['app'] != 'ALIN' || object['format'] != 'alin-cloud-backup' || object['data'] is! Map) {
      throw Exception('الملف ليس نسخة احتياطية صالحة لمنصة آلين');
    }
    if ('${object['backup_version'] ?? ''}'.isEmpty) throw Exception('إصدار النسخة الاحتياطية غير معروف');
    return object;
  }

  Future<void> createBackup() async {
    if (busy) return;
    setState(() {
      busy = true;
      status = 'جارٍ تجهيز النسخة الآمنة...';
    });
    try {
      final object = await _snapshot();
      final pretty = const JsonEncoder.withIndent('  ').convert(object);
      final bytes = Uint8List.fromList(utf8.encode(pretty));
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').replaceAll('T', '-').split('.').first;
      final name = 'Alin_Backup_$stamp.json';
      await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ نسخة منصة آلين',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => status = 'تم إنشاء النسخة الاحتياطية: $name');
    } catch (e) {
      if (!mounted) return;
      setState(() => status = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseBackup() async {
    if (busy) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw Exception('تعذر قراءة ملف النسخة');
      final object = _validate(jsonDecode(utf8.decode(bytes)));
      if (!mounted) return;
      setState(() {
        pending = object;
        pendingName = file.name;
        status = 'الملف صالح وجاهز للاستعادة الآمنة';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        pending = null;
        pendingName = null;
        status = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> restoreBackup() async {
    final object = pending;
    if (object == null || busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاستعادة الآمنة'),
        content: const Text('سيتم تحديث الكتالوج والإعدادات فقط. الطلبات والحسابات والمالية لن تتغير. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('استعادة')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      busy = true;
      status = 'جارٍ الاستعادة الآمنة...';
    });
    try {
      final data = Map<String, dynamic>.from(object['data'] as Map);
      final settingValues = data['settings'];
      int count = 0;
      if (settingValues is Map) {
        for (final entry in settingValues.entries) {
          final value = entry.value;
          if (value == null || value is Map || value is List || entry.key == 'storeType') continue;
          await widget.repository.client.from('settings').upsert({
            'key': '${entry.key}',
            'value': '$value',
          }, onConflict: 'key');
          count++;
        }
      }

      for (final table in restorableTables) {
        final raw = data[table];
        if (raw is! List || raw.isEmpty) continue;
        final cleanRows = raw.whereType<Map>().map((row) {
          final value = <String, dynamic>{};
          for (final entry in row.entries) {
            if ('${entry.key}'.startsWith('_')) continue;
            value['${entry.key}'] = entry.value;
          }
          if (table == 'booklets') {
            for (final key in const ['pdf_url', 'pdf_path', 'file_url', 'file_path', 'storage_path', 'signed_url']) {
              value.remove(key);
            }
          }
          return value;
        }).toList();
        if (cleanRows.isEmpty) continue;
        await widget.repository.client.from(table).upsert(cleanRows);
        count += cleanRows.length;
      }

      if (!mounted) return;
      setState(() => status = 'تمت الاستعادة الآمنة بنجاح — $count سجل');
    } catch (e) {
      if (!mounted) return;
      setState(() => status = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = pending?['data'];
    final counts = pending?['counts'];
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ الاحتياطي والاستعادة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: BusinessBrand.softBlue,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: BusinessBrand.border),
                    ),
                    child: const Row(children: [
                      Icon(Icons.shield_outlined, color: BusinessBrand.navy, size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'النسخة تشمل الكتالوج والإعدادات العامة فقط. لا تحتوي أرقام الطلاب أو الطلبات أو الحسابات أو القيود المالية أو روابط ملفات الملازم الخاصة.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, c) {
                      final cards = [
                        _actionCard(
                          title: 'إنشاء نسخة',
                          subtitle: 'تنزيل ملف JSON آمن للكتالوج والإعدادات.',
                          icon: Icons.download_rounded,
                          button: 'إنشاء وتنزيل النسخة',
                          onPressed: busy ? null : createBackup,
                        ),
                        _actionCard(
                          title: 'استعادة آمنة',
                          subtitle: 'اختيار نسخة ALIN ثم استعادة الكتالوج والإعدادات فقط.',
                          icon: Icons.restore_rounded,
                          button: pending == null ? 'اختيار ملف النسخة' : 'اختيار ملف آخر',
                          onPressed: busy ? null : chooseBackup,
                        ),
                      ];
                      return c.maxWidth >= 700
                          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])])
                          : Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
                    },
                  ),
                  if (pending != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(pendingName ?? 'نسخة احتياطية', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Text('تاريخ النسخة: ${pending?['created_at'] ?? '—'}'),
                          Text('الإصدار: ${pending?['backup_version'] ?? '—'}'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _pill('الملازم', _count(counts, 'booklets', data)),
                            _pill('المنتجات', _count(counts, 'products', data)),
                            _pill('الأقسام', _count(counts, 'categories', data)),
                            _pill('البنرات', _count(counts, 'banners', data)),
                            _pill('الكوبونات', _count(counts, 'coupons', data)),
                          ]),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: busy ? null : restoreBackup,
                            icon: const Icon(Icons.restore_page_rounded),
                            label: const Text('استعادة الكتالوج والإعدادات'),
                          ),
                        ]),
                      ),
                    ),
                  ],
                  if (status != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          if (busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.info_outline_rounded),
                          const SizedBox(width: 10),
                          Expanded(child: Text(status!)),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({required String title, required String subtitle, required IconData icon, required String button, required VoidCallback? onPressed}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CircleAvatar(radius: 24, backgroundColor: BusinessBrand.softBlue, child: Icon(icon, color: BusinessBrand.navy)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BusinessBrand.navy)),
            const SizedBox(height: 5),
            Text(subtitle),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(button)),
          ]),
        ),
      );

  Widget _pill(String label, int value) => Chip(label: Text('$label: $value'));

  int _count(dynamic counts, String key, dynamic data) {
    if (counts is Map && counts[key] != null) return int.tryParse('${counts[key]}') ?? 0;
    if (data is Map && data[key] is List) return (data[key] as List).length;
    return 0;
  }
}
