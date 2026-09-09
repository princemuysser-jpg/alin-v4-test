import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/business_config.dart';
import 'data/business_repository.dart';
import 'models/business_account.dart';
import 'screens/courier_dashboard_screen.dart';
import 'screens/library_dashboard_screen.dart';
import 'screens/printer_dashboard_screen.dart';
import 'screens/teacher_dashboard_screen.dart';

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

  Future<void> _logout() async {
    await repository.logout();
    if (!mounted) return;
    setState(() => account = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (account == null) {
      return LoginScreen(
        repository: repository,
        onLoggedIn: (value) => setState(() => account = value),
      );
    }
    if (account!.role == 'courier') {
      return CourierDashboardScreen(
        repository: repository,
        account: account!,
        onLogout: _logout,
      );
    }
    if (account!.role == 'library') {
      return LibraryDashboardScreen(
        repository: repository,
        account: account!,
        onLogout: _logout,
      );
    }
    if (account!.role == 'printer') {
      return PrinterDashboardScreen(
        repository: repository,
        account: account!,
        onLogout: _logout,
      );
    }
    if (account!.role == 'teacher') {
      return TeacherDashboardScreen(
        repository: repository,
        account: account!,
        onLogout: _logout,
      );
    }
    return GenericRoleDashboard(
      repository: repository,
      account: account!,
      onLogout: _logout,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final BusinessRepository repository;
  final ValueChanged<BusinessAccount> onLoggedIn;
  const LoginScreen({super.key, required this.repository, required this.onLoggedIn});
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
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'اكتب اسم الدخول وكلمة المرور');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final account = await widget.repository.login(
        username: username.text.trim(),
        password: password.text,
      );
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
              child: Column(children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: const Color(0xFF143B68),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 22),
                Text(BusinessConfig.appName,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
                const SizedBox(height: 6),
                Text(BusinessConfig.appSubtitle, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 32),
                TextField(
                  controller: username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'اسم الدخول', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline),
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
                    decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(height: 16),
                Text('يتم تحديد نوع الحساب تلقائياً من السيرفر', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class GenericRoleDashboard extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;
  const GenericRoleDashboard({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });
  @override
  State<GenericRoleDashboard> createState() => _GenericRoleDashboardState();
}

class _GenericRoleDashboardState extends State<GenericRoleDashboard> {
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
      final data = await widget.repository.dashboardSummary(widget.account);
      if (!mounted) return;
      setState(() => summary = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<_Section> get sections => switch (widget.account.role) {
        'admin' || 'accountant' => const [
            _Section('الطلبات', Icons.receipt_long_rounded),
            _Section('الحسابات', Icons.groups_rounded),
            _Section('المالية', Icons.account_balance_wallet_rounded),
            _Section('الكتب والملازم', Icons.menu_book_rounded),
          ],
        _ => const [],
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('لوحة ${widget.account.roleLabel}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'logout') widget.onLogout(); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(error!)))
            else
              _SummaryView(role: widget.account.role, summary: summary),
            const SizedBox(height: 18),
            const Text('الأقسام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...sections.map((section) => Card(
                  child: ListTile(
                    leading: Icon(section.icon, color: const Color(0xFF143B68)),
                    title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('قسم ${section.title} هو المرحلة التالية بالبناء')),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final String role;
  final Map<String, dynamic> summary;
  const _SummaryView({required this.role, required this.summary});

  @override
  Widget build(BuildContext context) {
    final entries = summary.entries.take(4).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final item = entries[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF143B68)),
            const Spacer(),
            Text('${item.value}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text(item.key, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );
      },
    );
  }
}

class _Section {
  final String title;
  final IconData icon;
  const _Section(this.title, this.icon);
}
