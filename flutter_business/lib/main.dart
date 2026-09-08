import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/business_config.dart';
import 'data/business_repository.dart';
import 'models/business_account.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: BusinessConfig.supabaseUrl,
    publishableKey: BusinessConfig.supabasePublishableKey,
  );
  runApp(const AlinBusinessApp());
}

class AlinBusinessApp extends StatelessWidget {
  const AlinBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF143B68);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: BusinessConfig.appName,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: navy),
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const BusinessGate(),
    );
  }
}

class BusinessGate extends StatefulWidget {
  const BusinessGate({super.key});

  @override
  State<BusinessGate> createState() => _BusinessGateState();
}

class _BusinessGateState extends State<BusinessGate> {
  late final BusinessRepository repository;
  BusinessAccount? account;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repository = BusinessRepository(Supabase.instance.client);
    _restore();
  }

  Future<void> _restore() async {
    final restored = await repository.restoreAccount();
    if (!mounted) return;
    setState(() {
      account = restored;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (account == null) {
      return LoginScreen(
        repository: repository,
        onLoggedIn: (value) => setState(() => account = value),
      );
    }
    return RoleDashboard(
      repository: repository,
      account: account!,
      onLogout: () async {
        await repository.logout();
        if (!mounted) return;
        setState(() => account = null);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final BusinessRepository repository;
  final ValueChanged<BusinessAccount> onLoggedIn;

  const LoginScreen({
    super.key,
    required this.repository,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    final u = username.text.trim();
    final p = password.text;
    if (u.isEmpty || p.isEmpty) {
      setState(() => error = 'اكتب اسم الدخول وكلمة المرور');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final account = await widget.repository.login(username: u, password: p);
      widget.onLoggedIn(account);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      color: const Color(0xFF143B68),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    BusinessConfig.appName,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF143B68)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    BusinessConfig.appSubtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: username,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدخول',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(error!, style: const TextStyle(color: Color(0xFFB42318))),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: busy ? null : submit,
                      icon: busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.login_rounded),
                      label: Text(busy ? 'جارٍ تسجيل الدخول...' : 'تسجيل الدخول'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'يتم تحديد نوع حسابك تلقائياً بعد تسجيل الدخول',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoleDashboard extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const RoleDashboard({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  Map<String, dynamic> summary = {};
  bool loading = true;
  String? error;

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
      final value = await widget.repository.dashboardSummary(widget.account);
      if (!mounted) return;
      setState(() => summary = value);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _RoleSpec.forRole(widget.account.role);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(onPressed: load, tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WelcomeCard(account: widget.account, spec: spec),
            const SizedBox(height: 14),
            if (loading)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              _ErrorCard(message: error!, onRetry: load)
            else
              _SummaryGrid(cards: spec.cards(summary)),
            const SizedBox(height: 18),
            const Text('الأقسام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...spec.sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: section.color.withValues(alpha: .12),
                        child: Icon(section.icon, color: section.color),
                      ),
                      title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(section.subtitle),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('قسم ${section.title} ضمن المرحلة الجاية من البناء')),
                        );
                      },
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final BusinessAccount account;
  final _RoleSpec spec;
  const _WelcomeCard({required this.account, required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: .16),
            child: Icon(spec.icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً ${account.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
                const SizedBox(height: 5),
                Text('حساب ${account.roleLabel}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final List<_MetricCard> cards;
  const _SummaryGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemCount: cards.length,
      itemBuilder: (_, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: card.color.withValues(alpha: .09), borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(card.icon, color: card.color),
              const Spacer(),
              Text(card.value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: card.color)),
              Text(card.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

class _MetricCard {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);
}

class _SectionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _SectionItem(this.title, this.subtitle, this.icon, this.color);
}

class _RoleSpec {
  final String title;
  final IconData icon;
  final List<_SectionItem> sections;
  final List<_MetricCard> Function(Map<String, dynamic>) cards;

  const _RoleSpec({required this.title, required this.icon, required this.sections, required this.cards});

  static String n(dynamic value) => '${value ?? 0}';
  static String money(dynamic value) {
    final number = num.tryParse('${value ?? 0}') ?? 0;
    return '${number.round()} ${BusinessConfig.currency}';
  }

  static _RoleSpec forRole(String role) {
    switch (role) {
      case 'admin':
      case 'accountant':
        return _RoleSpec(
          title: role == 'accountant' ? 'لوحة الحسابات' : 'لوحة الإدارة',
          icon: Icons.admin_panel_settings_rounded,
          cards: (s) => [
            _MetricCard('الطلبات', n(s['orders']), Icons.receipt_long_rounded, Colors.blue),
            _MetricCard('طلبات جديدة', n(s['new_orders']), Icons.notifications_active_rounded, Colors.orange),
            _MetricCard('المبيعات', money(s['total_sales']), Icons.payments_rounded, Colors.green),
            _MetricCard('المطابع', n(s['printers']), Icons.print_rounded, Colors.purple),
          ],
          sections: const [
            _SectionItem('الطلبات', 'إدارة وتجهيز الطلبات', Icons.receipt_long_rounded, Colors.blue),
            _SectionItem('الحسابات', 'مدرسين، مكتبات، مطابع ومندوبين', Icons.groups_rounded, Colors.teal),
            _SectionItem('المالية', 'الأرباح والذمم والتسويات', Icons.account_balance_wallet_rounded, Colors.green),
            _SectionItem('الكتب والملازم', 'إدارة المحتوى والموردين', Icons.menu_book_rounded, Colors.purple),
            _SectionItem('الإشعارات', 'تنبيهات لجميع الأدوار', Icons.notifications_rounded, Colors.orange),
          ],
        );
      case 'courier':
        return _RoleSpec(
          title: 'لوحة المندوب',
          icon: Icons.local_shipping_rounded,
          cards: (s) => [
            _MetricCard('كل الطلبات', n(s['orders']), Icons.receipt_long_rounded, Colors.blue),
            _MetricCard('قيد التنفيذ', n(s['active']), Icons.delivery_dining_rounded, Colors.orange),
            _MetricCard('مكتملة', n(s['completed']), Icons.check_circle_rounded, Colors.green),
            _MetricCard('أجور التوصيل', money(s['profit']), Icons.payments_rounded, Colors.teal),
          ],
          sections: const [
            _SectionItem('طلباتي', 'الطلبات الحالية والجديدة', Icons.list_alt_rounded, Colors.blue),
            _SectionItem('الخريطة', 'مواقع الاستلام والتسليم', Icons.map_rounded, Colors.green),
            _SectionItem('التسويات', 'أجور المندوب والحسابات', Icons.wallet_rounded, Colors.teal),
          ],
        );
      case 'library':
        return _RoleSpec(
          title: 'لوحة المكتبة',
          icon: Icons.storefront_rounded,
          cards: (s) => [
            _MetricCard('الطلبات', n(s['orders']), Icons.receipt_long_rounded, Colors.blue),
            _MetricCard('للتجهيز', n(s['new_orders']), Icons.print_rounded, Colors.orange),
            _MetricCard('جاهزة/مكتملة', n(s['completed']), Icons.check_circle_rounded, Colors.green),
            const _MetricCard('الحالة', 'مفتوح', Icons.store_rounded, Colors.teal),
          ],
          sections: const [
            _SectionItem('طلبات الطباعة', 'تجهيز الملازم والطلبات', Icons.print_rounded, Colors.blue),
            _SectionItem('التسليم', 'الطلبات الجاهزة والمسلّمة', Icons.inventory_2_rounded, Colors.green),
            _SectionItem('الحسابات', 'الأرباح والذمم والتسويات', Icons.account_balance_wallet_rounded, Colors.teal),
          ],
        );
      case 'printer':
        return _RoleSpec(
          title: 'لوحة المطبعة',
          icon: Icons.print_rounded,
          cards: (s) => [
            _MetricCard('توريد مستحق', money(s['book_supply_pending']), Icons.menu_book_rounded, Colors.orange),
            _MetricCard('توريد مسدد', money(s['book_supply_settled']), Icons.check_circle_rounded, Colors.green),
            _MetricCard('ذمة متبقية', money(s['collector_remaining']), Icons.account_balance_wallet_rounded, Colors.red),
            _MetricCard('طلبات كتب', n(s['book_orders_count']), Icons.receipt_long_rounded, Colors.blue),
          ],
          sections: const [
            _SectionItem('طلبات التجهيز', 'الكتب والطباعة المطلوبة', Icons.inventory_2_rounded, Colors.blue),
            _SectionItem('توريد الكتب', 'المستحق والمسدد', Icons.menu_book_rounded, Colors.purple),
            _SectionItem('الذمة', 'الحساب بين الإدارة والمطبعة', Icons.account_balance_wallet_rounded, Colors.orange),
            _SectionItem('التسويات', 'سجل التسويات والتصفير', Icons.receipt_long_rounded, Colors.green),
          ],
        );
      case 'teacher':
        return _RoleSpec(
          title: 'لوحة المدرس',
          icon: Icons.school_rounded,
          cards: (s) => [
            _MetricCard('الطلبات', n(s['orders']), Icons.receipt_long_rounded, Colors.blue),
            _MetricCard('مكتملة', n(s['completed']), Icons.check_circle_rounded, Colors.green),
            _MetricCard('المبيعات', money(s['sales']), Icons.payments_rounded, Colors.teal),
            const _MetricCard('الملازم', '—', Icons.menu_book_rounded, Colors.purple),
          ],
          sections: const [
            _SectionItem('ملازمي', 'الملازم المنشورة والمراجعة', Icons.menu_book_rounded, Colors.blue),
            _SectionItem('رفع ملزمة', 'إرسال ملف للإدارة', Icons.upload_file_rounded, Colors.purple),
            _SectionItem('المبيعات', 'المبيعات والأرباح', Icons.bar_chart_rounded, Colors.green),
            _SectionItem('التسويات', 'المبالغ المسددة والمستحقة', Icons.account_balance_wallet_rounded, Colors.teal),
          ],
        );
      default:
        return _RoleSpec(title: 'آلين للأعمال', icon: Icons.apps, cards: (_) => const [], sections: const []);
    }
  }
}
