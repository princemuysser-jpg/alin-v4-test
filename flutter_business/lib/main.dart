import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/business_config.dart';
import 'core/business_notification_service.dart';
import 'data/business_repository.dart';
import 'models/business_account.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/business_order_details_screen.dart';
import 'screens/courier_dashboard_screen.dart';
import 'screens/library_dashboard_screen.dart';
import 'screens/printer_dashboard_screen.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'widgets/admin_quick_actions_button.dart';
import 'widgets/business_notification_bell.dart';

final GlobalKey<NavigatorState> businessNavigatorKey = GlobalKey<NavigatorState>();

const FirebaseOptions _alinBusinessAndroidFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDjd9BA_V6qqiN96OcqBtC521VPzew9occ',
  appId: '1:622701050570:android:03331d662c3dddc2f49233',
  messagingSenderId: '622701050570',
  projectId: 'alin-platform',
  storageBucket: 'alin-platform.firebasestorage.app',
);

const FirebaseOptions _alinBusinessIOSFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCaZ4S-1o2mPv2o-n0WbH9p23EWtG1EZ_Y',
  appId: '1:622701050570:ios:9b1cd7dc67be549cf49233',
  messagingSenderId: '622701050570',
  projectId: 'alin-platform',
  storageBucket: 'alin-platform.firebasestorage.app',
  iosBundleId: 'com.alin.business',
);

Future<void> _initializeFirebase() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp(options: _alinBusinessIOSFirebaseOptions);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(options: _alinBusinessAndroidFirebaseOptions);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await _initializeFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  if (!kIsWeb) FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
      navigatorKey: businessNavigatorKey,
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
        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
  late final BusinessNotificationService notifications;
  BusinessAccount? account;
  bool loading = true;
  int notificationTick = 0;
  String? pendingOrderId;

  @override
  void initState() {
    super.initState();
    repository = BusinessRepository(Supabase.instance.client);
    notifications = BusinessNotificationService(
      client: Supabase.instance.client,
      onReceived: _notificationReceived,
      onOpen: _notificationOpened,
    );
    unawaited(notifications.start());
    _restore();
  }

  Future<void> _notificationReceived() async {
    if (!mounted) return;
    setState(() => notificationTick++);
  }

  String? _orderIdFromPayload(Map<String, dynamic> payload) {
    final direct = '${payload['order_id'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    final link = '${payload['url'] ?? payload['link'] ?? ''}'.trim();
    if (link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    final value = uri?.queryParameters['order'] ?? uri?.queryParameters['order_id'];
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  Future<void> _notificationOpened(Map<String, dynamic> payload) async {
    final orderId = _orderIdFromPayload(payload);
    if (!mounted) return;
    setState(() {
      notificationTick++;
      if (orderId != null) pendingOrderId = orderId;
    });
    _openPendingOrderAfterFrame();
  }

  void _openPendingOrderAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || account == null) return;
      final orderId = pendingOrderId;
      final navigator = businessNavigatorKey.currentState;
      if (orderId == null || navigator == null) return;
      pendingOrderId = null;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BusinessOrderDetailsScreen(
            repository: repository,
            orderId: orderId,
          ),
        ),
      );
    });
  }

  Future<void> _restore() async {
    final restored = await repository.restoreAccount();
    if (restored != null) await notifications.registerCurrentDevice();
    if (!mounted) return;
    setState(() {
      account = restored;
      loading = false;
    });
    _openPendingOrderAfterFrame();
  }

  Future<void> _loggedIn(BusinessAccount value) async {
    await notifications.registerCurrentDevice();
    if (!mounted) return;
    setState(() => account = value);
    _openPendingOrderAfterFrame();
  }

  Future<void> _logout() async {
    await notifications.unregisterCurrentDevice();
    await repository.logout();
    if (!mounted) return;
    setState(() {
      account = null;
      pendingOrderId = null;
    });
  }

  @override
  void dispose() {
    unawaited(notifications.dispose());
    super.dispose();
  }

  Future<void> _refreshBusinessView() async {
    if (!mounted) return;
    setState(() => notificationTick++);
  }

  Widget _withBusinessOverlays(Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (account?.role == 'admin')
          Positioned(
            left: 14,
            bottom: 88,
            child: AdminQuickActionsButton(
              repository: repository,
              onChanged: _refreshBusinessView,
            ),
          ),
        Positioned(
          right: 14,
          bottom: 88,
          child: Material(
            elevation: 8,
            color: const Color(0xFF143B68),
            shape: const CircleBorder(),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: BusinessNotificationBell(
                key: ValueKey('bell-$notificationTick'),
                repository: repository,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (account == null) {
      return LoginScreen(repository: repository, onLoggedIn: _loggedIn);
    }

    final pageKey = ValueKey('${account!.role}-$notificationTick');
    Widget page;
    switch (account!.role) {
      case 'admin':
      case 'accountant':
        page = AdminDashboardScreen(key: pageKey, repository: repository, account: account!, onLogout: _logout);
      case 'courier':
        page = CourierDashboardScreen(key: pageKey, repository: repository, account: account!, onLogout: _logout);
      case 'library':
        page = LibraryDashboardScreen(key: pageKey, repository: repository, account: account!, onLogout: _logout);
      case 'printer':
        page = PrinterDashboardScreen(key: pageKey, repository: repository, account: account!, onLogout: _logout);
      case 'teacher':
        page = TeacherDashboardScreen(key: pageKey, repository: repository, account: account!, onLogout: _logout);
      default:
        page = Scaffold(
          appBar: AppBar(title: const Text('آلين للأعمال')),
          body: Center(child: Text('نوع الحساب غير مدعوم: ${account!.role}')),
        );
    }
    return _withBusinessOverlays(page);
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
      final loggedAccount = await widget.repository.login(username: username.text.trim(), password: password.text);
      widget.onLoggedIn(loggedAccount);
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
                  decoration: BoxDecoration(color: const Color(0xFF143B68), borderRadius: BorderRadius.circular(28)),
                  child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 22),
                Text(BusinessConfig.appName, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
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
                    icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded),
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
