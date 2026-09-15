from pathlib import Path

# 1) Fix branding screen numeric slider type if needed.
branding = Path('flutter_business/lib/screens/admin_branding_screen.dart')
text = branding.read_text(encoding='utf-8')
text = text.replace(
    'Slider(value: radius.clamp(8, 28), min: 8, max: 28, divisions: 20, onChanged: (value) => setState(() => radius = value)),',
    'Slider(value: radius.clamp(8.0, 28.0).toDouble(), min: 8, max: 28, divisions: 20, onChanged: (value) => setState(() => radius = value)),',
)
branding.write_text(text, encoding='utf-8')

# 2) Teach BusinessBrand to load runtime identity while preserving existing constants.
brand = Path('flutter_business/lib/widgets/business_brand.dart')
text = brand.read_text(encoding='utf-8')
marker = '// Runtime visual identity loaded from the shared settings table.'
if marker not in text:
    anchor = 'class BusinessBrand {\n'
    if anchor not in text:
        raise SystemExit('Missing BusinessBrand class anchor')
    block = '''class BusinessBrand {\n  // Runtime visual identity loaded from the shared settings table.\n  static Color runtimePrimary = navy;\n  static Color runtimeSecondary = teal;\n  static Color runtimeBackground = background;\n  static Color runtimeCard = Colors.white;\n  static Color runtimeSuccess = const Color(0xFF2F7D62);\n  static Color runtimeWarning = const Color(0xFFB98532);\n  static Color runtimeDanger = const Color(0xFFB44B4B);\n  static double runtimeRadius = 20;\n  static String runtimeLogoUrl = '';\n  static String runtimeLogoDarkUrl = '';\n  static String runtimeIconUrl = '';\n\n  static Color _hex(String? value, Color fallback) {\n    final raw = (value ?? '').trim().replaceFirst('#', '');\n    final parsed = int.tryParse('FF$raw', radix: 16);\n    return parsed == null ? fallback : Color(parsed);\n  }\n\n  static void configure(Map<String, String> settings) {\n    runtimePrimary = _hex(settings['visual_primary'], navy);\n    runtimeSecondary = _hex(settings['visual_secondary'], teal);\n    runtimeBackground = _hex(settings['visual_background'], background);\n    runtimeCard = _hex(settings['visual_card'], Colors.white);\n    runtimeSuccess = _hex(settings['visual_success'], const Color(0xFF2F7D62));\n    runtimeWarning = _hex(settings['visual_warning'], const Color(0xFFB98532));\n    runtimeDanger = _hex(settings['visual_danger'], const Color(0xFFB44B4B));\n    runtimeRadius = (double.tryParse(settings['visual_radius'] ?? '') ?? 20).clamp(8.0, 28.0).toDouble();\n    runtimeLogoUrl = (settings['platform_logo_path'] ?? settings['platform_logo_url'] ?? '').trim();\n    runtimeLogoDarkUrl = (settings['platform_logo_dark_path'] ?? '').trim();\n    runtimeIconUrl = (settings['platform_icon_path'] ?? settings['platform_icon_url'] ?? '').trim();\n  }\n'''
    text = text.replace(anchor, block, 1)

    old_scheme = '''    final scheme = ColorScheme.fromSeed(\n      seedColor: navy,\n      brightness: Brightness.light,\n    ).copyWith(\n      primary: navy,\n      secondary: teal,\n      tertiary: orange,\n      surface: Colors.white,\n    );'''
    new_scheme = '''    final scheme = ColorScheme.fromSeed(\n      seedColor: runtimePrimary,\n      brightness: Brightness.light,\n    ).copyWith(\n      primary: runtimePrimary,\n      secondary: runtimeSecondary,\n      tertiary: orange,\n      surface: runtimeCard,\n      error: runtimeDanger,\n    );'''
    if old_scheme not in text:
        raise SystemExit('Missing theme scheme anchor')
    text = text.replace(old_scheme, new_scheme, 1)
    text = text.replace('      scaffoldBackgroundColor: background,', '      scaffoldBackgroundColor: runtimeBackground,', 1)
    text = text.replace('        backgroundColor: navy,', '        backgroundColor: runtimePrimary,', 1)
    text = text.replace('        color: Colors.white,\n        surfaceTintColor:', '        color: runtimeCard,\n        surfaceTintColor:', 1)
    text = text.replace('          borderRadius: BorderRadius.circular(20),', '          borderRadius: BorderRadius.circular(runtimeRadius),', 1)
    text = text.replace('          backgroundColor: navy,', '          backgroundColor: runtimePrimary,', 1)
    text = text.replace('          foregroundColor: navy,', '          foregroundColor: runtimePrimary,', 1)
    text = text.replace('        backgroundColor: teal,', '        backgroundColor: runtimeSecondary,', 1)

    # Use uploaded brand mark in the reusable Flutter logo widget.
    mark_anchor = '''  @override\n  Widget build(BuildContext context) {\n    return Container(\n      width: size,'''
    mark_replacement = '''  @override\n  Widget build(BuildContext context) {\n    final configured = light && BusinessBrand.runtimeLogoDarkUrl.isNotEmpty\n        ? BusinessBrand.runtimeLogoDarkUrl\n        : (BusinessBrand.runtimeLogoUrl.isNotEmpty\n            ? BusinessBrand.runtimeLogoUrl\n            : BusinessBrand.runtimeIconUrl);\n    if (configured.isNotEmpty) {\n      return SizedBox(\n        width: size,\n        height: size,\n        child: ClipRRect(\n          borderRadius: BorderRadius.circular(size * .30),\n          child: Image.network(\n            configured,\n            fit: BoxFit.contain,\n            errorBuilder: (_, __, ___) => _fallbackMark(),\n          ),\n        ),\n      );\n    }\n    return _fallbackMark();\n  }\n\n  Widget _fallbackMark() {\n    return Container(\n      width: size,'''
    if mark_anchor not in text:
        raise SystemExit('Missing AlinBrandMark build anchor')
    text = text.replace(mark_anchor, mark_replacement, 1)
    brand.write_text(text, encoding='utf-8')

# 3) Load shared branding settings before runApp.
main = Path('flutter_business/lib/main.dart')
text = main.read_text(encoding='utf-8')
main_marker = '// Load the same visual identity used by the legacy web app.'
if main_marker not in text:
    old = '''  await Supabase.initialize(\n    url: BusinessConfig.supabaseUrl,\n    publishableKey: BusinessConfig.supabasePublishableKey,\n  );\n  runApp(const AlinBusinessApp());'''
    new = '''  await Supabase.initialize(\n    url: BusinessConfig.supabaseUrl,\n    publishableKey: BusinessConfig.supabasePublishableKey,\n  );\n  // Load the same visual identity used by the legacy web app.\n  try {\n    final rows = await Supabase.instance.client.from('settings').select('key,value');\n    final values = <String, String>{};\n    for (final row in rows) {\n      values['${row['key']}'] = '${row['value'] ?? ''}';\n    }\n    BusinessBrand.configure(values);\n  } catch (_) {\n    // Keep the built-in ALIN identity if public settings are temporarily unavailable.\n  }\n  runApp(const AlinBusinessApp());'''
    if old not in text:
        raise SystemExit('Missing main Supabase initialization anchor')
    text = text.replace(old, new, 1)
    main.write_text(text, encoding='utf-8')

# 4) Expose branding in Admin tools.
tools = Path('flutter_business/lib/screens/business_role_tools_screen.dart')
text = tools.read_text(encoding='utf-8')
tools_marker = '// Branding parity Build 17'
if tools_marker not in text:
    import_anchor = "import 'admin_books_screen.dart';\n"
    if import_anchor not in text:
        raise SystemExit('Missing admin books import anchor')
    text = text.replace(import_anchor, import_anchor + "import 'admin_branding_screen.dart';\n// Branding parity Build 17\n", 1)
    card_anchor = "        _RoleTool(\n          title: 'دورات المدرسين',"
    if card_anchor not in text:
        raise SystemExit('Missing admin role tools anchor')
    card = '''        _RoleTool(\n          title: 'الهوية البصرية',\n          subtitle: 'الشعار والأيقونة والألوان والقوالب البصرية',\n          icon: Icons.palette_rounded,\n          onTap: () => open(AdminBrandingScreen(repository: repository)),\n        ),\n'''
    text = text.replace(card_anchor, card + card_anchor, 1)
    tools.write_text(text, encoding='utf-8')

print('Applied Flutter branding parity')
