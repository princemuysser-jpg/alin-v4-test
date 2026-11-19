import 'package:flutter/material.dart';

class BusinessBrand {
  // Runtime visual identity loaded from the shared settings table.
  static Color runtimePrimary = navy;
  static Color runtimeSecondary = teal;
  static Color runtimeBackground = background;
  static Color runtimeCard = Colors.white;
  static Color runtimeSuccess = success;
  static Color runtimeWarning = warning;
  static Color runtimeDanger = danger;
  static double runtimeRadius = 20;
  static String runtimeLogoUrl = '';
  static String runtimeLogoDarkUrl = '';
  static String runtimeIconUrl = '';

  static Color _hex(String? value, Color fallback) {
    final raw = (value ?? '').trim().replaceFirst('#', '');
    final parsed = int.tryParse('FF$raw', radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }

  static void configure(Map<String, String> settings) {
    runtimePrimary = _hex(settings['visual_primary'], navy);
    runtimeSecondary = _hex(settings['visual_secondary'], teal);
    runtimeBackground = _hex(settings['visual_background'], background);
    runtimeCard = _hex(settings['visual_card'], Colors.white);
    runtimeSuccess = _hex(settings['visual_success'], success);
    runtimeWarning = _hex(settings['visual_warning'], warning);
    runtimeDanger = _hex(settings['visual_danger'], danger);
    runtimeRadius = (double.tryParse(settings['visual_radius'] ?? '') ?? 20)
        .clamp(8.0, 28.0)
        .toDouble();
    runtimeLogoUrl =
        (settings['platform_logo_path'] ?? settings['platform_logo_url'] ?? '')
            .trim();
    runtimeLogoDarkUrl = (settings['platform_logo_dark_path'] ?? '').trim();
    runtimeIconUrl =
        (settings['platform_icon_path'] ?? settings['platform_icon_url'] ?? '')
            .trim();
  }

  // ALIN Business visual system: restrained enterprise surfaces with
  // accessible, semantic highlights. Runtime admin overrides remain supported.
  static const navy = Color(0xFF102B4E);
  static const navy2 = Color(0xFF174F78);
  static const teal = Color(0xFF17B6AD);
  static const gold = Color(0xFFD5AE65);
  static const orange = Color(0xFFF79009);
  static const success = Color(0xFF12805C);
  static const warning = Color(0xFFB45F07);
  static const danger = Color(0xFFC43D45);
  static const ink = Color(0xFF172B42);
  static const muted = Color(0xFF667085);
  static const background = Color(0xFFF3F6FA);
  static const softBlue = Color(0xFFEAF2FB);
  static const softTeal = Color(0xFFDDF5F2);
  static const border = Color(0xFFE3EAF2);
  static const panelShadow = Color(0x0D102B4E);
  static const double cardRadius = 20;

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy, navy2],
  );

  static BoxDecoration panelDecoration({double radius = cardRadius}) =>
      BoxDecoration(
        color: runtimeCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(
          color: panelShadow,
          blurRadius: 20,
          offset: Offset(0, 7),
        )],
      );

  static ThemeData theme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: runtimePrimary,
          brightness: Brightness.light,
        ).copyWith(
          primary: runtimePrimary,
          secondary: runtimeSecondary,
          tertiary: orange,
          surface: runtimeCard,
          error: runtimeDanger,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: runtimeBackground,
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: runtimePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: runtimeCard,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(runtimeRadius),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: navy, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: runtimePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: runtimePrimary,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softBlue,
        selectedColor: softTeal,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: softTeal,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: runtimeSecondary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class AlinBrandMark extends StatelessWidget {
  final double size;
  final bool light;

  const AlinBrandMark({super.key, this.size = 46, this.light = false});

  @override
  Widget build(BuildContext context) {
    final configured = light && BusinessBrand.runtimeLogoDarkUrl.isNotEmpty
        ? BusinessBrand.runtimeLogoDarkUrl
        : (BusinessBrand.runtimeLogoUrl.isNotEmpty
              ? BusinessBrand.runtimeLogoUrl
              : BusinessBrand.runtimeIconUrl);
    if (configured.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * .30),
          child: Image.network(
            configured,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _fallbackMark(),
          ),
        ),
      );
    }
    return _fallbackMark();
  }

  Widget _fallbackMark() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: light
            ? const LinearGradient(colors: [Colors.white, Color(0xFFEAF3FC)])
            : BusinessBrand.heroGradient,
        borderRadius: BorderRadius.circular(size * .30),
        boxShadow: [
          BoxShadow(
            color: BusinessBrand.navy.withValues(alpha: .16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              Icons.auto_awesome_mosaic_rounded,
              size: size * .52,
              color: light ? BusinessBrand.navy : Colors.white,
            ),
          ),
          Positioned(
            right: size * .10,
            bottom: size * .10,
            child: Container(
              width: size * .20,
              height: size * .20,
              decoration: const BoxDecoration(
                color: BusinessBrand.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: size * .10,
            top: size * .12,
            child: Container(
              width: size * .18,
              height: size * .07,
              decoration: BoxDecoration(
                color: BusinessBrand.teal,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
