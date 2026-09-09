import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/business_config.dart';
import 'data/business_repository.dart';
import 'models/business_account.dart';
import 'screens/admin_dashboard_screen.dart';
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
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (account == null) {
      return LoginScreen(
        repository: repository,
        onLoggedIn: (value) => setState(() => account = value),
      );
    }

    switch (account!.role) {
      case 'admin':
      case 'accountant':
        return AdminDashboardScreen(repository: repository, account: account!, onLogout: _logout);
      case 'courier':
        return CourierDashboardScreen(repository: repository, account: account!, onLogout: _logout);
      case 'library':
        return LibraryDashboardScreen(repository: repository, account: account!, onLogout: _logout);
      case 'printer':
        return PrinterDashboardScreen(repository: repository, account: account!, onLogout: _logout);
      case 'teacher':
        return TeacherDashboardScreen(repository: repository, account: account!, onLogout: _logout);
      default:
        return Scaffold(
          appBar: AppBar(title: const Text('آلين للأعمال')),
          body: Center(child: Text('نوع الحساب غير مدعوم: ${account!.role}')),
        );
    }
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
                Text(
                  BusinessConfig.appName,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF143B68)),
                ),
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
