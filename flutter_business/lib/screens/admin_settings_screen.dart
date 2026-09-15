import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminSettingsScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminSettingsScreen({super.key, required this.repository});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool loading = true;
  bool saving = false;
  String? error;
  Map<String, String> settings = {};

  final platformName = TextEditingController();
  final shortName = TextEditingController();
  final lowStock = TextEditingController();
  final libraryDebt = TextEditingController();
  final adminNote = TextEditingController();
  final courierProfit = TextEditingController();
  final deliveryFee = TextEditingController();
  final pauseReason = TextEditingController();
  final heroTitle = TextEditingController();
  final heroText = TextEditingController();
  final contactTitle = TextEditingController();
  final contactText = TextEditingController();
  final whatsapp = TextEditingController();
  final facebook = TextEditingController();
  final instagram = TextEditingController();
  final tiktok = TextEditingController();
  final aboutTitle = TextEditingController();
  final aboutText = TextEditingController();

  String pauseScope = '';
  bool deliveryEnabled = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final c in [
      platformName,
      shortName,
      lowStock,
      libraryDebt,
      adminNote,
      courierProfit,
      deliveryFee,
      pauseReason,
      heroTitle,
      heroText,
      contactTitle,
      contactText,
      whatsapp,
      facebook,
      instagram,
      tiktok,
      aboutTitle,
      aboutText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String v(String key, String fallback) => settings[key] ?? fallback;

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final raw = await widget.repository.client.from('settings').select('key,value');
      final map = <String, String>{};
      for (final row in (raw as List).whereType<Map>()) {
        final key = '${row['key'] ?? ''}';
        if (key.isNotEmpty) map[key] = '${row['value'] ?? ''}';
      }
      if (!mounted) return;
      settings = map;
      platformName.text = v('platform_name', 'منصة آلين');
      shortName.text = v('platform_short_name', 'آلين');
      lowStock.text = v('low_stock_default', '5');
      libraryDebt.text = v('library_debt_alert_limit', '500000');
      adminNote.text = v('admin_internal_note', '');
      courierProfit.text = v('delegate_profit_percent', '30');
      deliveryFee.text = v('delivery_fee', '0');
      pauseScope = v('order_pause_scope', '');
      pauseReason.text = v('order_pause_reason', '');
      deliveryEnabled = v('delivery_enabled', 'true') != 'false';
      heroTitle.text = v('hero_title', 'كل ما تحتاجه للدراسة بمكان واحد');
      heroText.text = v('hero_text', 'اختر ملزمتك أو قرطاسيتك واطلبها بسهولة.');
      contactTitle.text = v('contact_title', 'تواصل معنا');
      contactText.text = v('contact_text', 'للاستفسار أو الانضمام، تواصل مع إدارة منصة آلين.');
      whatsapp.text = v('whatsapp', v('platform_phone', ''));
      facebook.text = v('facebook_url', '');
      instagram.text = v('instagram_url', '');
      tiktok.text = v('tiktok_url', '');
      aboutTitle.text = v('about_title', 'حول منصة آلين');
      aboutText.text = v('about_text', 'منصة آلين تجمع الملازم والقرطاسية والهدايا في مكان واحد، وتربط الطالب بالمدرس والمكتبة وخدمة التوصيل.');
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save(Map<String, String> values) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      for (final entry in values.entries) {
        await widget.repository.client.from('settings').upsert({
          'key': entry.key,
          'value': entry.value,
        }, onConflict: 'key');
      }
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات المنصة'),
          actions: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Chip(label: Text('Flutter Business'))),
            ),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'عام'),
              Tab(text: 'الأرباح'),
              Tab(text: 'الطلبات'),
              Tab(text: 'التواصل'),
              Tab(text: 'حول المنصة'),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
                : TabBarView(
                    children: [
                      _general(),
                      _profits(),
                      _orders(),
                      _contact(),
                      _about(),
                    ],
                  ),
      ),
    );
  }

  Widget _page(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _general() => _page([
        _head('الإعدادات العامة', Icons.settings_rounded),
        _field(platformName, 'اسم المنصة'),
        _field(shortName, 'الاسم المختصر'),
        _two(
          _field(lowStock, 'حد تنبيه المخزون', number: true),
          _field(libraryDebt, 'حد تنبيه ذمة المكتبة', number: true),
        ),
        _field(adminNote, 'ملاحظة إدارية داخلية', lines: 4),
        _saveButton(() => save({
              'platform_name': platformName.text.trim(),
              'platform_short_name': shortName.text.trim(),
              'low_stock_default': lowStock.text.trim(),
              'library_debt_alert_limit': libraryDebt.text.trim(),
              'admin_internal_note': adminNote.text.trim(),
            })),
      ]);

  Widget _profits() => _page([
        _head('إعدادات الأرباح', Icons.percent_rounded),
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text('نسب المنصة والمدرس والمكتبة تبقى مستقلة داخل كل ملزمة. هنا يتم تحديد عمولة المندوب من أجرة التوصيل فقط.'),
        ),
        _field(courierProfit, 'عمولة المندوب من أجرة التوصيل %', number: true),
        _saveButton(() => save({'delegate_profit_percent': courierProfit.text.trim()})),
      ]);

  Widget _orders() => _page([
        _head('الطلبات والتوصيل', Icons.local_shipping_rounded),
        _field(deliveryFee, 'أجرة التوصيل الافتراضية', number: true),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: pauseScope,
          decoration: const InputDecoration(labelText: 'حالة استقبال الطلبات'),
          items: const [
            DropdownMenuItem(value: '', child: Text('الطلبات مفتوحة')),
            DropdownMenuItem(value: 'all', child: Text('إيقاف الكل')),
            DropdownMenuItem(value: 'booklet', child: Text('إيقاف الملازم')),
            DropdownMenuItem(value: 'stationery', child: Text('إيقاف القرطاسية')),
            DropdownMenuItem(value: 'gift', child: Text('إيقاف الهدايا')),
          ],
          onChanged: (value) => setState(() => pauseScope = value ?? ''),
        ),
        _field(pauseReason, 'سبب إيقاف الطلبات', lines: 3),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('التوصيل للبيت'),
          subtitle: const Text('السماح للطالب باختيار التوصيل عن طريق المندوب.'),
          value: deliveryEnabled,
          onChanged: (value) => setState(() => deliveryEnabled = value),
        ),
        _saveButton(() => save({
              'delivery_fee': deliveryFee.text.trim(),
              'order_pause_scope': pauseScope,
              'order_pause_reason': pauseReason.text.trim(),
              'delivery_enabled': '$deliveryEnabled',
            })),
      ]);

  Widget _contact() => _page([
        _head('تواصل معنا وروابط المنصة', Icons.contact_support_rounded),
        _field(heroTitle, 'عنوان الواجهة'),
        _field(heroText, 'نص الواجهة', lines: 3),
        _field(contactTitle, 'عنوان التواصل'),
        _field(contactText, 'نص التواصل', lines: 3),
        _field(whatsapp, 'رقم واتساب المنصة'),
        _field(facebook, 'رابط صفحة فيسبوك'),
        _field(instagram, 'رابط صفحة إنستغرام'),
        _field(tiktok, 'رابط صفحة تيك توك'),
        _saveButton(() => save({
              'hero_title': heroTitle.text.trim(),
              'hero_text': heroText.text.trim(),
              'contact_title': contactTitle.text.trim(),
              'contact_text': contactText.text.trim(),
              'whatsapp': whatsapp.text.trim(),
              'facebook_url': facebook.text.trim(),
              'instagram_url': instagram.text.trim(),
              'tiktok_url': tiktok.text.trim(),
            })),
      ]);

  Widget _about() => _page([
        _head('حول منصة آلين', Icons.info_outline_rounded),
        _field(aboutTitle, 'عنوان حول المنصة'),
        _field(aboutText, 'نبذة عن منصة آلين', lines: 7),
        _saveButton(() => save({
              'about_title': aboutTitle.text.trim(),
              'about_text': aboutText.text.trim(),
            })),
      ]);

  Widget _head(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(children: [
          CircleAvatar(backgroundColor: BusinessBrand.softBlue, child: Icon(icon, color: BusinessBrand.navy)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: BusinessBrand.navy)),
        ]),
      );

  Widget _field(TextEditingController controller, String label, {int lines = 1, bool number = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: lines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _two(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 620
            ? Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)])
            : Column(children: [a, b]),
      );

  Widget _saveButton(VoidCallback action) => Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: saving ? null : action,
          icon: saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ'),
        ),
      );
}
