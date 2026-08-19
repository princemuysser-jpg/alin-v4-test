import 'package:flutter/material.dart';

class AlinTheme {
  static const navy = Color(0xFF0B3158);
  static const gold = Color(0xFFC9A24A);
  static const background = Color(0xFFF6F8FB);
  static const line = Color(0xFFE4EAF1);
  static const ink = Color(0xFF102A43);
  static const muted = Color(0xFF66788A);
  static const darkBackground = Color(0xFF071A2E);
  static const darkSurface = Color(0xFF0E2943);
  static const darkSurface2 = Color(0xFF102F4D);
  static const darkLine = Color(0xFF294762);
  static const darkInk = Color(0xFFF1F6FA);
  static const darkMuted = Color(0xFFB6C5D2);

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? darkSurface : Colors.white;
    final backgroundColor = dark ? darkBackground : background;
    final text = dark ? darkInk : ink;
    final border = dark ? darkLine : line;
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: dark ? const Color(0xFF9ACBFA) : navy,
      secondary: gold,
      surface: surface,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      fontFamily: null,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? darkSurface2 : Colors.white,
        labelStyle: TextStyle(color: dark ? darkMuted : muted),
        hintStyle: TextStyle(color: dark ? darkMuted : muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: dark ? const Color(0xFF9ACBFA) : navy, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF9ACBFA) : navy,
          foregroundColor: dark ? const Color(0xFF06203A) : Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: dark ? const Color(0xFF173E60) : const Color(0xFFE8F1FB),
      ),
    );
  }
}
