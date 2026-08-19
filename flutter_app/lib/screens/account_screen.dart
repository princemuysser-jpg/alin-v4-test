import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool createMode = false;
  bool busy = false;
  String? message;
  final name = TextEditingController();
  final phone = TextEditingController();
  final pin = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    pin.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final c = AppScope.of(context);
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (createMode) {
        if (name.text.trim().length < 2) throw Exception('اكتب اسم الطالب بصورة صحيحة');
        await c.registerStudent(name: name.text.trim(), phone: phone.text.trim(), pin: pin.text);
      } else {
        await c.loginStudent(phone: phone.text.trim(), pin: pin.text);
      }
      if (!mounted) return;
      name.clear();
      phone.clear();
      pin.clear();
      setState(() => message = createMode ? 'تم إنشاء الحساب وتسجيل الدخول' : 'تم تسجيل الدخول');
    } catch (e) {
      if (!mounted) return;
      setState(() => message = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final student = c.student;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return ListView(
      padding: EdgeInsets.all(tablet ? 28 : 16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.tr('خيارات', ku: 'هەڵبژاردەکان', en: 'Options'),
                  style: TextStyle(fontSize: tablet ? 26 : 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  c.tr('الحساب واللغة ومظهر المنصة', ku: 'هەژمار و زمان و ڕووکار', en: 'Account, language and appearance'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 14),
                student == null ? _signedOut(c, tablet) : _signedIn(c, tablet),
                const SizedBox(height: 14),
                _preferencesCard(c),
                const SizedBox(height: 14),
                _supportCard(c),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _signedOut(dynamic c, bool tablet) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tablet ? 28 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset('assets/images/alin_icon.png', width: tablet ? 64 : 54, height: tablet ? 64 : 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(createMode ? 'إنشاء حساب طالب' : 'تسجيل دخول الطالب', style: TextStyle(fontSize: tablet ? 25 : 21, fontWeight: FontWeight.w900)),
                      Text(c.tr('الحساب يبقى محفوظ إلى أن تسوي تسجيل خروج.', ku: 'هەژمارەکە پارێزراوە تا دەرچوون بکەیت.', en: 'Your account stays signed in until you log out.'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('تسجيل دخول'), icon: Icon(Icons.login)),
                ButtonSegment(value: true, label: Text('إنشاء حساب'), icon: Icon(Icons.person_add_alt_1)),
              ],
              selected: {createMode},
              onSelectionChanged: busy ? null : (values) => setState(() {
                createMode = values.first;
                message = null;
              }),
            ),
            const SizedBox(height: 18),
            if (createMode) ...[
              TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'اسم الطالب', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 12),
            ],
            TextField(controller: phone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined))),
            const SizedBox(height: 12),
            TextField(controller: pin, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'الرمز السري', prefixIcon: Icon(Icons.lock_outline), helperText: '6 أحرف أو أرقام على الأقل')),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: busy ? null : submit,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(createMode ? Icons.person_add_alt_1 : Icons.login),
              label: Text(busy ? 'جارٍ التنفيذ...' : createMode ? 'إنشاء الحساب' : 'دخول'),
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!, textAlign: TextAlign.center, style: TextStyle(color: message!.startsWith('تم') ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _signedIn(dynamic c, bool tablet) {
    final student = c.student;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(tablet ? 28 : 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: tablet ? 38 : 32,
                  backgroundColor: const Color(0xFFE9F2FA),
                  child: Text(student.name.isEmpty ? 'ط' : student.name.substring(0, 1), style: TextStyle(fontSize: tablet ? 28 : 24, fontWeight: FontWeight.w900, color: AlinTheme.navy)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهلاً ${student.name} 👋', style: TextStyle(fontSize: tablet ? 24 : 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(student.phone, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (c.studentVerifying) Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.tr('جارٍ تأكيد الجلسة...', ku: 'پشتڕاستکردنەوەی دانیشتن...', en: 'Verifying session...'), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('طلباتي'),
                subtitle: const Text('عرض طلباتك السابقة وحالتها'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentOrdersScreen())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.card_giftcard_outlined),
                title: const Text('العروض الخاصة'),
                subtitle: const Text('الخصومات المخصصة لحسابك'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PersonalOffersScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700, minimumSize: const Size(0, 48)),
          onPressed: () async {
            final yes = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('تسجيل خروج'),
                content: const Text('بعد تسجيل الخروج تحتاج تدخل الحساب مرة ثانية.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل خروج')),
                ],
              ),
            );
            if (yes == true) await c.logoutStudent();
          },
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل خروج'),
        ),
      ],
    );
  }

  String _setting(dynamic c, String key, String fallback) {
    final value = '${c.bootstrap?.settings[key] ?? ''}'.trim();
    return value.isEmpty ? fallback : value;
  }

  Widget _preferencesCard(dynamic c) {
    final dark = c.themeMode == 'dark';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.language_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.tr('اللغة', ku: 'زمان', en: 'Language'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(c.tr('اختر لغة واجهة المنصة', ku: 'زمانی ڕووکار هەڵبژێرە', en: 'Choose the interface language'), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: const Text('العربية'), selected: c.languageCode == 'ar', onSelected: (_) => c.setLanguageCode('ar')),
                ChoiceChip(label: const Text('کوردی'), selected: c.languageCode == 'ku', onSelected: (_) => c.setLanguageCode('ku')),
                ChoiceChip(label: const Text('English'), selected: c.languageCode == 'en', onSelected: (_) => c.setLanguageCode('en')),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.tr('المظهر', ku: 'ڕووکار', en: 'Appearance'), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(c.tr('الوضع النهاري أو الليلي', ku: 'ڕووناک یان تاریک', en: 'Light or dark mode'), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode_outlined), label: Text(c.tr('نهاري', ku: 'ڕووناک', en: 'Light'))),
                ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode_outlined), label: Text(c.tr('ليلي', ku: 'تاریک', en: 'Dark'))),
              ],
              selected: {c.themeMode},
              onSelectionChanged: (values) => c.setThemeMode(values.first),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportCard(dynamic c) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: Text(c.tr('تواصل معنا', ku: 'پەیوەندیمان پێوە بکە', en: 'Contact us'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(c.tr('للاستفسار والدعم', ku: 'بۆ پرسیار و پشتگیری', en: 'Questions and support')),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => _showContact(c),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(c.tr('حول منصة آلين', ku: 'دەربارەی پلاتفۆرمی ئالین', en: 'About Alin Platform'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(c.tr('معلومات عن المنصة وخدماتها', ku: 'زانیاری دەربارەی پلاتفۆرم', en: 'Platform information and services')),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => _showAbout(c),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternal(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _whatsAppUrl(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = '964${digits.substring(1)}';
    return digits.isEmpty ? '' : 'https://wa.me/$digits';
  }

  void _showContact(dynamic c) {
    final title = _setting(c, 'contact_title', 'تواصل معنا');
    final text = _setting(c, 'contact_text', 'للاستفسار أو الدعم، تواصل مع إدارة منصة آلين.');
    final whatsapp = _setting(c, 'whatsapp', _setting(c, 'platform_phone', ''));
    final facebook = _setting(c, 'facebook_url', '');
    final instagram = _setting(c, 'instagram_url', '');
    final tiktok = _setting(c, 'tiktok_url', '');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(text, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 14),
              if (whatsapp.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.chat_rounded)),
                  title: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(whatsapp),
                  onTap: () => _openExternal(_whatsAppUrl(whatsapp)),
                ),
              if (facebook.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.facebook_rounded), title: const Text('Facebook'), onTap: () => _openExternal(facebook)),
              if (instagram.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.camera_alt_outlined), title: const Text('Instagram'), onTap: () => _openExternal(instagram)),
              if (tiktok.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.music_note_rounded), title: const Text('TikTok'), onTap: () => _openExternal(tiktok)),
              if ([whatsapp, facebook, instagram, tiktok].every((e) => e.isEmpty))
                Text(c.tr('بيانات التواصل غير مضافة حالياً.', ku: 'زانیاری پەیوەندی بەردەست نییە.', en: 'Contact details are not available yet.')),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(dynamic c) {
    final title = _setting(c, 'about_title', 'حول منصة آلين');
    final text = _setting(c, 'about_text', 'منصة آلين تجمع الملازم والقرطاسية والهدايا في مكان واحد، وتربط الطالب بالمدرس والمكتبة وخدمة التوصيل.');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset('assets/images/alin_icon.png', width: 54, height: 54),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 14),
              Text(text, style: const TextStyle(height: 1.75, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

}

class StudentOrdersScreen extends StatelessWidget {
  const StudentOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: c.loadStudentOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('${snapshot.error}'.replaceFirst('Exception: ', ''))));
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('ما عندك طلبات سابقة حالياً'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.shopping_bag_outlined)),
                  title: Text('${row['order_number'] ?? row['id'] ?? 'طلب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${row['item_name'] ?? 'طلب'}\n${row['status'] ?? ''}'),
                  isThreeLine: true,
                  trailing: Text('${row['total'] ?? ''} د.ع', style: const TextStyle(fontWeight: FontWeight.w800, color: AlinTheme.navy)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PersonalOffersScreen extends StatelessWidget {
  const PersonalOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('العروض الخاصة')),
      body: c.studentToken == null
          ? const Center(child: Text('سجل دخول أولاً'))
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: c.repository.personalOffers(token: c.studentToken!, deviceId: c.store.deviceId()),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) return const Center(child: Text('ما عندك عرض خاص فعال حالياً'));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [Icon(Icons.card_giftcard, color: AlinTheme.gold), SizedBox(width: 8), Text('عرض خاص مخصص إلك', style: TextStyle(fontWeight: FontWeight.w900))]),
                          const SizedBox(height: 10),
                          Text('${row['offer_title'] ?? 'عرض خاص لك من منصة آلين 🎁'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text('${row['offer_message'] ?? ''}', style: const TextStyle(height: 1.6)),
                          const SizedBox(height: 12),
                          SelectableText('الكود: ${row['code'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, color: AlinTheme.navy)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                final code = '${row['code'] ?? ''}'.trim();
                                if (code.isEmpty) return;
                                c.useCoupon(code);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز العرض. افتح السلة وأكمل الطلب.')));
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.redeem),
                              label: const Text('استخدم العرض'),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
