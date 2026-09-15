from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = ROOT / 'flutter_business/lib/main.dart'
PUBSPEC = ROOT / 'flutter_business/pubspec.yaml'

text = MAIN.read_text(encoding='utf-8')

import_marker = "import 'screens/business_party_finance_screen.dart';\n"
import_line = "import 'screens/business_role_tools_screen.dart';\n"
if import_line not in text:
    if import_marker not in text:
        raise SystemExit('main import marker not found')
    text = text.replace(import_marker, import_marker + import_line, 1)

method_marker = "  void _openPersonalFinance() {\n"
method_block = """  void _openRoleTools() {
    final value = account;
    final navigator = businessNavigatorKey.currentState;
    if (value == null || navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => BusinessRoleToolsScreen(
          repository: repository,
          account: value,
        ),
      ),
    );
  }

"""
if 'void _openRoleTools()' not in text:
    if method_marker not in text:
        raise SystemExit('open personal finance marker not found')
    text = text.replace(method_marker, method_block + method_marker, 1)

# Detect the button by heroTag instead of exact formatting so dart format cannot
# make the patch add a duplicate on later workflow runs.
overlay_marker = """        Positioned(
          right: 14,
          bottom: 88,
          child: Material(
"""
tools_button = """        Positioned(
          left: 14,
          bottom: _hasPersonalFinance || account?.role == 'admin' ? 154 : 88,
          child: FloatingActionButton.extended(
            heroTag: 'business-role-tools',
            onPressed: _openRoleTools,
            icon: const Icon(Icons.apps_rounded),
            label: const Text('أدواتي'),
          ),
        ),
"""
if "heroTag: 'business-role-tools'" not in text:
    if overlay_marker not in text:
        raise SystemExit('overlay marker not found')
    text = text.replace(overlay_marker, tools_button + overlay_marker, 1)

MAIN.write_text(text, encoding='utf-8')

# Do not downgrade a newer build. Build 14 is only the minimum version for this patch.
pub = PUBSPEC.read_text(encoding='utf-8')
if 'version: 1.0.6+14' not in pub and 'version: 1.0.7+15' not in pub:
    import re
    pub = re.sub(r'version:\s*[^\n]+', 'version: 1.0.6+14', pub, count=1)
    lines = pub.splitlines()
    for i, line in enumerate(lines):
        if line.startswith('# Build '):
            lines[i] = '# Build 14: responsive role tools hub, admin coupons and reports.'
            break
    pub = '\n'.join(lines) + ('\n' if pub.endswith('\n') else '')
PUBSPEC.write_text(pub, encoding='utf-8')

print('Business role tools hub integrated.')
