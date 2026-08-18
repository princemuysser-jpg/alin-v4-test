import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final controller = AppScope.of(context);
    final started = DateTime.now();
    await controller.initialize();
    final elapsed = DateTime.now().difference(started);
    if (elapsed < const Duration(milliseconds: 1500)) {
      await Future.delayed(const Duration(milliseconds: 1500) - elapsed);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tablet = size.shortestSide >= 600;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF4F9FF), Color(0xFFE5F2FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: tablet ? 620 : 380),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tablet ? 48 : 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/alin_logo.png', width: tablet ? 360 : 260, fit: BoxFit.contain),
                    const SizedBox(height: 22),
                    Text(
                      'للملازم والقرطاسية والهدايا',
                      style: TextStyle(
                        color: AlinTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: tablet ? 22 : 17,
                      ),
                    ),
                    const SizedBox(height: 34),
                    const LinearProgressIndicator(
                      minHeight: 7,
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      backgroundColor: Color(0xFFDCE9F5),
                      color: AlinTheme.navy,
                    ),
                    const SizedBox(height: 14),
                    const Text('جارٍ فتح منصة آلين...', style: TextStyle(color: AlinTheme.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
