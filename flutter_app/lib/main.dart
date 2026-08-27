import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/alin_config.dart';
import 'core/alin_theme.dart';
import 'core/app_scope.dart';
import 'core/app_update_service.dart';
import 'core/device_store.dart';
import 'core/native_notification_service.dart';
import 'core/notification_navigation.dart';
import 'data/alin_repository.dart';
import 'screens/splash_screen.dart';
import 'state/app_controller.dart';

const FirebaseOptions _alinIOSFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCaZ4S-1o2mPv2o-n0WbH9p23EWtG1EZ_Y',
  appId: '1:622701050570:ios:9b1cd7dc67be549cf49233',
  messagingSenderId: '622701050570',
  projectId: 'alin-platform',
  storageBucket: 'alin-platform.firebasestorage.app',
  iosBundleId: 'com.alin.platform',
);

Future<void> _initializeFirebase() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp(options: _alinIOSFirebaseOptions);
    return;
  }
  await Firebase.initializeApp();
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await Supabase.initialize(
    url: AlinConfig.supabaseUrl,
    publishableKey: AlinConfig.supabasePublishableKey,
  );
  final prefs = await SharedPreferences.getInstance();
  final controller = AppController(
    repository: AlinRepository(Supabase.instance.client),
    store: DeviceStore(prefs, secureStorage: const FlutterSecureStorage()),
  );
  runApp(AlinApp(controller: controller));
}

class AlinApp extends StatefulWidget {
  final AppController controller;
  const AlinApp({super.key, required this.controller});

  @override
  State<AlinApp> createState() => _AlinAppState();
}

class _AlinAppState extends State<AlinApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final NativeNotificationService _notifications;
  bool _storeReady = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    _notifications = NativeNotificationService(
      client: Supabase.instance.client,
      store: widget.controller.store,
      studentTokenProvider: () => widget.controller.studentToken,
      onNotificationReceived: widget.controller.refreshNotifications,
      onNotificationOpened: _handleNotificationOpened,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifications.start();
    });
  }

  Future<void> _handleNotificationOpened(Map<String, dynamic> payload) async {
    NotificationNavigation.queue(payload);
    if (!_storeReady) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    await NotificationNavigation.flush(navigator, widget.controller);
  }

  Future<void> _showNotificationPermissionPrimerFromStore() async {
    if (!mounted) return;
    if (await _notifications.notificationPermissionGranted()) return;

    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    final enableNow = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded),
            SizedBox(width: 10),
            Expanded(child: Text('لا تفوّت العروض 🎁')),
          ],
        ),
        content: const Text(
          'فعّل الإشعارات حتى توصلك الخصومات، العروض الجديدة، وتحديثات طلبك أول بأول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لاحقًا'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('تفعيل الإشعارات'),
          ),
        ],
      ),
    );

    if (enableNow == true) {
      await _notifications.requestNotificationPermission();
    }
  }

  Future<void> _onStoreReady() async {
    _storeReady = true;

    await _showNotificationPermissionPrimerFromStore();
    if (!mounted) return;

    final updateContext = _navigatorKey.currentContext;
    final settings = widget.controller.bootstrap?.settings;
    if (updateContext != null && updateContext.mounted && settings != null) {
      await AppUpdateService.maybePrompt(updateContext, settings);
    }

    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      await NotificationNavigation.flush(navigator, widget.controller);
    }
  }

  void _controllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    unawaited(_notifications.dispose());
    widget.controller.disposeController();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: AlinConfig.appName,
        locale: widget.controller.languageCode == 'en' ? const Locale('en', 'US') : const Locale('ar', 'IQ'),
        supportedLocales: const [Locale('ar', 'IQ'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AlinTheme.light(),
        darkTheme: AlinTheme.dark(),
        themeMode: widget.controller.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => Directionality(
          textDirection: widget.controller.languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: SplashScreen(onStoreReady: _onStoreReady),
      ),
    );
  }
}
