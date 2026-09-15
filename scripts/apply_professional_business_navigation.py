from pathlib import Path

ROOT = Path('flutter_business/lib')


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def write(rel, text):
    (ROOT / rel).write_text(text, encoding='utf-8')


def ensure_import(text, anchor, line):
    if line in text:
        return text
    if anchor not in text:
        raise RuntimeError(f'import anchor not found: {anchor}')
    return text.replace(anchor, anchor + '\n' + line, 1)


def add_drawer(rel):
    text = read(rel)
    text = ensure_import(
        text,
        "import '../models/business_account.dart';",
        "import '../widgets/business_role_navigation.dart';",
    )
    marker = "return Scaffold(\n      appBar:"
    replacement = (
        "return Scaffold(\n"
        "      drawer: BusinessRoleNavigationDrawer(\n"
        "        repository: widget.repository,\n"
        "        account: widget.account,\n"
        "        onLogout: widget.onLogout,\n"
        "      ),\n"
        "      appBar:"
    )
    if 'drawer: BusinessRoleNavigationDrawer(' not in text:
        if marker not in text:
            raise RuntimeError(f'Scaffold appBar marker not found in {rel}')
        text = text.replace(marker, replacement, 1)
    write(rel, text)


# Mobile/tablet role dashboards get a real role-aware navigation drawer.
for file in [
    'screens/admin_dashboard_screen.dart',
    'screens/teacher_dashboard_screen.dart',
    'screens/library_dashboard_screen.dart',
    'screens/courier_dashboard_screen.dart',
    'screens/printer_dashboard_screen.dart',
]:
    add_drawer(file)

# Admin desktop replaces the old 6-item sidebar with the complete grouped navigation.
rel = 'screens/admin_desktop_dashboard_screen.dart'
text = read(rel)
text = ensure_import(
    text,
    "import '../models/business_account.dart';",
    "import '../widgets/business_role_navigation.dart';",
)
old = "          _sidebar(),"
new = (
    "          AdminDesktopNavigationSidebar(\n"
    "            repository: widget.repository,\n"
    "            account: widget.account,\n"
    "            selectedSection: section,\n"
    "            onSectionChanged: (value) => setState(() => section = value),\n"
    "            onLogout: widget.onLogout,\n"
    "          ),"
)
if old in text:
    text = text.replace(old, new, 1)
write(rel, text)

# Remove the old floating 'Tools' / finance / bell overlay layer from the global gate.
rel = 'main.dart'
text = read(rel)
for line in [
    "import 'screens/business_party_finance_screen.dart';\n",
    "import 'screens/business_role_tools_screen.dart';\n",
    "import 'widgets/admin_quick_actions_button.dart';\n",
    "import 'widgets/business_notification_bell.dart';\n",
]:
    text = text.replace(line, '')

start = text.find('  Future<void> _refreshBusinessView() async {')
end = text.find('  @override\n  Widget build(BuildContext context) {', start)
if start != -1 and end != -1:
    text = text[:start] + '  Widget _withBusinessOverlays(Widget child) => child;\n\n' + text[end:]
elif 'Widget _withBusinessOverlays(Widget child) => child;' not in text:
    raise RuntimeError('Unable to locate old business overlay block in main.dart')
write(rel, text)

# Trigger marker: navigation migration v1.
print('Professional ALIN Business navigation patch applied.')
