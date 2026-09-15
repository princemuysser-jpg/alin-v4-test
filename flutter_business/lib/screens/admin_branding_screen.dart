import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminBrandingScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminBrandingScreen({super.key, required this.repository});

  @override
  State<AdminBrandingScreen> createState() => _AdminBrandingScreenState();
}

class _AdminBrandingScreenState extends State<AdminBrandingScreen> {
  static const _bucket = 'alin-files';

  bool loading = true;
  bool saving = false;
  bool uploadingLogo = false;
  bool uploadingIcon = false;
  String? error;

  final primary = TextEditingController();
  final secondary = TextEditingController();
  final background = TextEditingController();
  final card = TextEditingController();
  final success = TextEditingController();
  final warning = TextEditingController();
  final danger = TextEditingController();
  final logo = TextEditingController();
  final logoDark = TextEditingController();
  final icon = TextEditingController();

  String theme = 'alin-original';
  String font = 'Cairo';
  String shadow = 'soft';
  double radius = 18;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final controller in [
      primary,
      secondary,
      background,
      card,
      success,
      warning,
      danger,
      logo,
      logoDark,
      icon,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await widget.repository.client
          .from('settings')
          .select('key,value');
      final settings = <String, String>{};
      for (final row in raw) {
        settings['${row['key']}'] = '${row['value'] ?? ''}';
      }
      if (!mounted) return;
      setState(() {
        theme = settings['visual_theme']?.trim().isNotEmpty == true
            ? settings['visual_theme']!
            : 'alin-original';
        primary.text = settings['visual_primary'] ?? '#0B3158';
        secondary.text = settings['visual_secondary'] ?? '#C9A24A';
        background.text = settings['visual_background'] ?? '#F6F8FB';
        card.text = settings['visual_card'] ?? '#FFFFFF';
        success.text = settings['visual_success'] ?? '#2F7D62';
        warning.text = settings['visual_warning'] ?? '#B98532';
        danger.text = settings['visual_danger'] ?? '#B44B4B';
        font = settings['visual_font']?.trim().isNotEmpty == true
            ? settings['visual_font']!
            : 'Cairo';
        radius = double.tryParse(settings['visual_radius'] ?? '') ?? 18;
        shadow = settings['visual_shadow']?.trim().isNotEmpty == true
            ? settings['visual_shadow']!
            : 'soft';
        logo.text =
            settings['platform_logo_path'] ??
            settings['platform_logo_url'] ??
            '';
        logoDark.text = settings['platform_logo_dark_path'] ?? '';
        icon.text =
            settings['platform_icon_path'] ??
            settings['platform_icon_url'] ??
            '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _validHex(String value) =>
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value.trim());

  Color _color(String value, Color fallback) {
    final raw = value.trim().replaceFirst('#', '');
    final parsed = int.tryParse('FF$raw', radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  Future<String?> _pickAndUpload(String kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) throw Exception('تعذر قراءة الصورة');
    if (bytes.length > 3 * 1024 * 1024) {
      throw Exception('حجم الصورة يجب أن يكون أقل من 3MB');
    }
    final extension = (file.extension ?? 'png').toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final path =
        'brand/$kind/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await widget.repository.client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );
    return widget.repository.client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> uploadLogo({bool dark = false}) async {
    if (uploadingLogo) return;
    setState(() => uploadingLogo = true);
    try {
      final url = await _pickAndUpload(dark ? 'logo-dark' : 'logo');
      if (url != null && mounted) {
        setState(() {
          if (dark) {
            logoDark.text = url;
          } else {
            logo.text = url;
          }
        });
      }
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploadingLogo = false);
    }
  }

  Future<void> uploadIcon() async {
    if (uploadingIcon) return;
    setState(() => uploadingIcon = true);
    try {
      final url = await _pickAndUpload('icon');
      if (url != null && mounted) setState(() => icon.text = url);
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploadingIcon = false);
    }
  }

  Future<void> save() async {
    if (saving) return;
    final colors = [
      primary.text,
      secondary.text,
      background.text,
      card.text,
      success.text,
      warning.text,
      danger.text,
    ];
    if (colors.any((value) => !_validHex(value))) {
      _toast('أحد أكواد الألوان غير صحيح. استخدم صيغة مثل #143B68');
      return;
    }
    setState(() => saving = true);
    try {
      final values = <String, dynamic>{
        'visual_theme': theme,
        'visual_primary': primary.text.toUpperCase(),
        'visual_secondary': secondary.text.toUpperCase(),
        'visual_background': background.text.toUpperCase(),
        'visual_card': card.text.toUpperCase(),
        'visual_success': success.text.toUpperCase(),
        'visual_warning': warning.text.toUpperCase(),
        'visual_danger': danger.text.toUpperCase(),
        'visual_font': font,
        'visual_radius': radius.round().toString(),
        'visual_shadow': shadow,
        'platform_logo_path': logo.text.trim(),
        'platform_logo_dark_path': logoDark.text.trim(),
        'platform_icon_path': icon.text.trim(),
      };
      await widget.repository.client
          .from('settings')
          .upsert(
            values.entries
                .map((entry) => {'key': entry.key, 'value': entry.value})
                .toList(),
            onConflict: 'key',
          );
      BusinessBrand.configure(
        values.map((key, value) => MapEntry(key, '$value')),
      );
      if (!mounted) return;
      _toast('تم حفظ الهوية البصرية. ستظهر بالكامل بعد إعادة فتح التطبيق.');
      setState(() {});
    } catch (e) {
      if (mounted) _toast('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void applyPreset(String value) {
    final preset = switch (value) {
      'sky-calm' => [
        '#315D7A',
        '#9EB9C9',
        '#F3F7F9',
        '#FFFFFF',
        '#4E806D',
        '#B38A4E',
        '#A95B5B',
        'Tajawal',
        '20',
      ],
      'sage-calm' => [
        '#456B5F',
        '#B9A878',
        '#F4F7F3',
        '#FFFFFF',
        '#3F7B5D',
        '#A98045',
        '#A95555',
        'Cairo',
        '20',
      ],
      'sand-calm' => [
        '#6F5948',
        '#C2A278',
        '#FAF7F1',
        '#FFFDFA',
        '#5F8067',
        '#AD7B3C',
        '#AA5952',
        'Tajawal',
        '18',
      ],
      'lavender-calm' => [
        '#5D5D7D',
        '#B8AFCA',
        '#F7F6FA',
        '#FFFFFF',
        '#5E806E',
        '#A98652',
        '#A95B67',
        'Cairo',
        '22',
      ],
      'rose-calm' => [
        '#765861',
        '#D0AEB5',
        '#FAF6F7',
        '#FFFFFF',
        '#5B7D6B',
        '#AA8050',
        '#A64F5A',
        'Tajawal',
        '22',
      ],
      'graphite-calm' => [
        '#3F4B59',
        '#AEB7C0',
        '#F4F6F8',
        '#FFFFFF',
        '#4D7B69',
        '#9E7D4E',
        '#A65353',
        'Cairo',
        '16',
      ],
      _ => [
        '#0B3158',
        '#C9A24A',
        '#F6F8FB',
        '#FFFFFF',
        '#2F7D62',
        '#B98532',
        '#B44B4B',
        'Cairo',
        '18',
      ],
    };
    setState(() {
      theme = value;
      primary.text = preset[0];
      secondary.text = preset[1];
      background.text = preset[2];
      card.text = preset[3];
      success.text = preset[4];
      warning.text = preset[5];
      danger.text = preset[6];
      font = preset[7];
      radius = double.parse(preset[8]);
      shadow = 'soft';
    });
  }

  void _toast(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الهوية البصرية'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 980;
                final editor = _editor();
                final preview = _preview();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (desktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: editor),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: preview),
                        ],
                      )
                    else ...[
                      preview,
                      const SizedBox(height: 14),
                      editor,
                    ],
                  ],
                );
              },
            ),
      bottomNavigationBar: loading || error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('حفظ الهوية وتطبيقها'),
                ),
              ),
            ),
    );
  }

  Widget _editor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(
        title: 'القوالب الجاهزة',
        icon: Icons.palette_rounded,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              const {
                    'alin-original': 'آلين الأصلي',
                    'sky-calm': 'سماء هادئة',
                    'sage-calm': 'مريمي هادئ',
                    'sand-calm': 'رملي دافئ',
                    'lavender-calm': 'لافندر هادئ',
                    'rose-calm': 'وردي ترابي',
                    'graphite-calm': 'رمادي احترافي',
                  }.entries
                  .map(
                    (entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: theme == entry.key,
                      onSelected: (_) => applyPreset(entry.key),
                    ),
                  )
                  .toList(),
        ),
      ),
      const SizedBox(height: 12),
      _section(
        title: 'الشعار والأيقونة',
        icon: Icons.image_rounded,
        child: Column(
          children: [
            _imageField('شعار المنصة', logo, () => uploadLogo()),
            const SizedBox(height: 10),
            _imageField(
              'الشعار للوضع الداكن',
              logoDark,
              () => uploadLogo(dark: true),
            ),
            const SizedBox(height: 10),
            _imageField('أيقونة المنصة', icon, uploadIcon),
            const SizedBox(height: 8),
            const Text(
              'PNG / JPG / WebP — الحد الأقصى 3MB. تحفظ الصور في Supabase / alin-files.',
              style: TextStyle(color: BusinessBrand.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _section(
        title: 'ألوان الواجهة',
        icon: Icons.format_color_fill_rounded,
        child: LayoutBuilder(
          builder: (context, c) {
            final fields = [
              _colorField('اللون الرئيسي', primary),
              _colorField('اللون الثانوي', secondary),
              _colorField('الخلفية', background),
              _colorField('البطاقات', card),
              _colorField('النجاح', success),
              _colorField('التنبيه', warning),
              _colorField('الخطر', danger),
            ];
            if (c.maxWidth >= 650) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: fields
                    .map(
                      (e) => SizedBox(width: (c.maxWidth - 10) / 2, child: e),
                    )
                    .toList(),
              );
            }
            return Column(
              children: fields
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: e,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      _section(
        title: 'الشكل والخط',
        icon: Icons.tune_rounded,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: font,
              decoration: const InputDecoration(labelText: 'الخط'),
              items: const ['Cairo', 'Tajawal', 'Arial']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => font = value ?? 'Cairo'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: shadow,
              decoration: const InputDecoration(labelText: 'الظل'),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('بدون ظل')),
                DropdownMenuItem(value: 'soft', child: Text('ظل هادئ')),
                DropdownMenuItem(value: 'medium', child: Text('ظل متوسط')),
              ],
              onChanged: (value) => setState(() => shadow = value ?? 'soft'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'استدارة البطاقات',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text('${radius.round()} px'),
              ],
            ),
            Slider(
              value: radius.clamp(8.0, 28.0).toDouble(),
              min: 8,
              max: 28,
              divisions: 20,
              onChanged: (value) => setState(() => radius = value),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _preview() {
    final p = _color(primary.text, BusinessBrand.navy);
    final s = _color(secondary.text, BusinessBrand.teal);
    final bg = _color(background.text, BusinessBrand.background);
    final surface = _color(card.text, Colors.white);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'معاينة الهوية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: Row(
                      children: [
                        _previewImage(
                          icon.text,
                          42,
                          fallback: Icons.auto_awesome_mosaic_rounded,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'منصة آلين',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _previewImage(
                              logo.text,
                              58,
                              fallback: Icons.school_rounded,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'لوحة آلين للأعمال',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: p,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: s,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewImage(String url, double size, {required IconData fallback}) {
    if (url.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(size * .24),
        ),
        child: Icon(fallback, color: Colors.white),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.network(
        url.trim(),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Colors.white12,
          child: Icon(fallback, color: Colors.white),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BusinessBrand.navy),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );

  Widget _imageField(
    String label,
    TextEditingController controller,
    Future<void> Function() upload,
  ) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            hintText: 'رابط الصورة أو ارفع صورة',
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: uploadingLogo || uploadingIcon ? null : upload,
        icon: const Icon(Icons.upload_rounded),
        label: const Text('رفع'),
      ),
    ],
  );

  Widget _colorField(String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        onChanged: (_) => setState(() => theme = 'custom'),
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _color(controller.text, Colors.grey),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ),
      );
}
