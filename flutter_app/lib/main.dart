import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/alin_config.dart';
import 'core/alin_theme.dart';
import 'core/app_scope.dart';
import 'core/device_store.dart';
import 'data/alin_repository.dart';
import 'screens/splash_screen.dart';
import 'state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
  }

  void _controllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    widget.controller.disposeController();
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: widget.controller,
      child: MaterialApp(
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
        home: const SplashScreen(),
      ),
    );
  }
}
