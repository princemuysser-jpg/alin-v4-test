import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/business_config.dart';
import 'core/business_login_memory.dart';
import 'core/business_notification_service.dart';
import 'data/business_repository.dart';
import 'models/business_account.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/business_order_details_screen.dart';
import 'screens/courier_dashboard_screen.dart';
import 'screens/library_dashboard_screen.dart';
import 'screens/printer_dual_dashboard_screen.dart';
import 'screens/teacher_dashboard_screen.dart';
import 'widgets/business_brand.dart';
import 'widgets/business_app_mark.dart';

final GlobalKey<NavigatorState> businessNavigatorKey =
    GlobalKey<NavigatorState>();

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
  if (!kIsWeb)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await Supabase.initialize(
    url: BusinessConfig.supabaseUrl,
    publishableKey: BusinessConfig.supabasePublishableKey,
  );
  // Load the same visual identity used by the legacy web app.
  try {
    final rows = await Supabase.instance.client
        .from('settings')
        .select('key,value');
    final values = <String, String>{};
    for (final row in rows) {
      values['${row['key']}'] = '${row['value'] ?? ''}';
    }
    BusinessBrand.configure(values);
  } catch (_) {
    // Keep the built-in ALIN identity if public settings are temporarily unavailable.
  }
  runApp(const AlinBusinessApp());
}

class AlinBusinessApp extends StatelessWidget {
  const AlinBusinessApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      theme: BusinessBrand.theme(),
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
  bool webPushEnabled = false;
  bool webPushBusy = false;

  Future<void> _enableBusinessWebPush() async {
    if (webPushBusy) return;
    setState(() => webPushBusy = true);
    try {
      final ok = await notifications.requestPermissionAndRegister();
      if (!mounted) return;
      setState(() => webPushEnabled = ok);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok
          ? '🔔 تم تفعيل إشعارات الطلبات'
          : 'تأكد من السماح بإشعارات الموقع')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تفعيل الإشعارات: $e')));
    } finally {
      if (mounted) setState(() => webPushBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    repository = BusinessRepository(Supabase.instance.client);
    if (kIsWeb) pendingOrderId = Uri.base.queryParameters['order'];
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
    final value =
        uri?.queryParameters['order'] ?? uri?.queryParameters['order_id'];
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

  Widget _withBusinessOverlays(Widget child) {
    if (!kIsWeb || webPushEnabled) return child;
    return Stack(children: [
      child,
      Positioned(
        bottom: 18, right: 18,
        child: SafeArea(
          child: FilledButton.icon(
            onPressed: webPushBusy ? null : _enableBusinessWebPush,
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(webPushBusy ? 'جارٍ التفعيل...' : '🔔 تفعيل تنبيهات الطلبات'),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (account == null) {
      return LoginScreen(repository: repository, onLoggedIn: _loggedIn);
    }

    final pageKey = ValueKey('${account!.role}-$notificationTick');
    Widget page;
    switch (account!.role) {
      case 'admin':
      case 'accountant':
        page = AdminDashboardScreen(
          key: pageKey,
          repository: repository,
          account: account!,
          onLogout: _logout,
        );
      case 'courier':
        page = CourierDashboardScreen(
          key: pageKey,
          repository: repository,
          account: account!,
          onLogout: _logout,
        );
      case 'library':
        page = LibraryDashboardScreen(
          key: pageKey,
          repository: repository,
          account: account!,
          onLogout: _logout,
        );
      case 'printer':
        page = PrinterDualDashboardScreen(
          key: pageKey,
          repository: repository,
          account: account!,
          onLogout: _logout,
        );
      case 'teacher':
        page = TeacherDashboardScreen(
          key: pageKey,
          repository: repository,
          account: account!,
          onLogout: _logout,
        );
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
  bool remember = false;
  bool loadingRecall = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _restoreRememberedLogin();
  }

  Future<void> _restoreRememberedLogin() async {
    try {
      final previous = await BusinessLoginMemory.load();
      if (!mounted) return;
      setState(() {
        remember = previous.remember;
        username.text = previous.username;
        password.text = previous.password;
      });
    } catch (_) {
      // Password manager / session login remain available if device storage fails.
    } finally {
      if (mounted) setState(() => loadingRecall = false);
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || loadingRecall) return;
    final name = username.text.trim();
    final secret = password.text;
    if (name.isEmpty || secret.isEmpty) {
      setState(() => error = 'اكتب اسم الدخول وكلمة المرور');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final loggedAccount = await widget.repository.login(
        username: name,
        password: secret,
      );
      if (!mounted) return;
      try {
        await BusinessLoginMemory.save(
          username: name,
          password: secret,
          remember: remember,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الدخول، لكن تعذر حفظ بيانات الدخول على هذا الجهاز')),
          );
        }
      }
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: remember);
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
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final primary = BusinessBrand.runtimePrimary;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Expanded(
                child: Container(
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF102B4E), Color(0xFF174F78), Color(0xFF0F777B)],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(56),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BusinessAppMark(size: 100),
                            const SizedBox(height: 26),
                            const Text(
                              'آلين للأعمال',
                              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'مساحة عمل واحدة لإدارة الطلبات والمبيعات والتسويات بكل ثقة.',
                              style: TextStyle(fontSize: 18, height: 1.7, color: Color(0xFFE0EDF5)),
                            ),
                            const SizedBox(height: 32),
                            const Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _LoginFeature('إدارة الطلبات', Icons.inventory_2_outlined),
                                _LoginFeature('تقارير مالية', Icons.insights_outlined),
                                _LoginFeature('طباعة وفواتير', Icons.receipt_long_outlined),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                        side: const BorderSide(color: Color(0xFFE4EBF3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(26),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!wide) ...[
                                const Center(child: BusinessAppMark(size: 76)),
                                const SizedBox(height: 18),
                              ],
                              Text(
                                'أهلاً بعودتك',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primary),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'سجّل الدخول لحساب آلين للأعمال',
                                style: TextStyle(color: Color(0xFF667085)),
                              ),
                              const SizedBox(height: 26),
                              TextField(
                                controller: username,
                                enabled: !busy && !loadingRecall,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'اسم المستخدم',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: password,
                                enabled: !busy && !loadingRecall,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                obscureText: obscure,
                                onSubmitted: (_) => submit(),
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
                                    onPressed: () => setState(() => obscure = !obscure),
                                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                value: remember,
                                onChanged: busy || loadingRecall ? null : (v) => setState(() => remember = v ?? false),
                                title: const Text('تذكّر بيانات الدخول', style: TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  kIsWeb
                                      ? 'يحفظ اسم المستخدم، ولحفظ كلمة المرور استخدم مدير كلمات المرور بالمتصفح.'
                                      : 'يحفظ اسم المستخدم وكلمة المرور في التخزين الآمن لهذا الجهاز فقط.',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              if (error != null) ...[
                                const SizedBox(height: 10),
                                Container(
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
                                height: 54,
                                child: FilledButton.icon(
                                  onPressed: busy || loadingRecall ? null : submit,
                                  icon: busy || loadingRecall
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.arrow_forward_rounded),
                                  label: Text(busy ? 'جارٍ تسجيل الدخول...' : loadingRecall ? 'جارٍ تحميل الحساب...' : 'دخول إلى لوحة الأعمال'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Center(
                                child: Text(
                                  'حسابات المدير • المدرس • المكتبة • المطبعة • المندوب',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: Color(0xFF667085)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFeature extends StatelessWidget {
  final String title;
  final IconData icon;
  const _LoginFeature(this.title, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      border: Border.all(color: Colors.white.withValues(alpha: .23)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );
}
