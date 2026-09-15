from pathlib import Path

# Fix the typed library list used by the independent books screen before analyze.
books_path = Path('flutter_business/lib/screens/admin_books_screen.dart')
books = books_path.read_text(encoding='utf-8')
old_libraries = """        libraries = (values[1] as List)
            .where((e) => '${e['role']}' == 'library' && '${e['status']}' == 'active' && e['deleted_at'] == null)
            .toList();"""
new_libraries = """        libraries = (values[1] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => '${e['role']}' == 'library' && '${e['status']}' == 'active' && e['deleted_at'] == null)
            .toList();"""
if old_libraries in books:
    books = books.replace(old_libraries, new_libraries, 1)
    books_path.write_text(books, encoding='utf-8')
    print('Fixed typed book supplier libraries')

path = Path('flutter_business/lib/screens/business_role_tools_screen.dart')
text = path.read_text(encoding='utf-8')
marker = '// Admin old-web parity tools Build 17'
if marker in text:
    print('Admin old-web tools already linked')
    raise SystemExit(0)

imports_anchor = "import 'admin_backup_screen.dart';\n"
if imports_anchor not in text:
    raise SystemExit('Missing admin import anchor')
text = text.replace(
    imports_anchor,
    imports_anchor
    + "import 'admin_books_screen.dart';\n"
    + "import 'admin_courier_hub_screen.dart';\n"
    + "import 'admin_teacher_courses_screen.dart';\n"
    + "// Admin old-web parity tools Build 17\n",
    1,
)

card_anchor = "        _RoleTool(\n          title: 'المالية والتسويات',"
if card_anchor not in text:
    raise SystemExit('Missing admin tools card anchor')
new_cards = """        _RoleTool(
          title: 'دورات المدرسين',
          subtitle: 'مراجعة الدورات والموافقة والنشر والإخفاء والرفض',
          icon: Icons.video_library_rounded,
          onTap: () => open(AdminTeacherCoursesScreen(repository: repository)),
        ),
        _RoleTool(
          title: 'إدارة الكتب',
          subtitle: 'الكتب والمخزون والموردون والنسب والتسويات',
          icon: Icons.menu_book_rounded,
          onTap: () => open(AdminBooksScreen(repository: repository)),
        ),
        _RoleTool(
          title: 'مركز المندوبين',
          subtitle: 'حالة المندوبين والطلبات والمناطق والحسابات',
          icon: Icons.delivery_dining_rounded,
          onTap: () => open(AdminCourierHubScreen(repository: repository)),
        ),
"""
text = text.replace(card_anchor, new_cards + card_anchor, 1)
path.write_text(text, encoding='utf-8')
print('Linked admin courses, books and courier hub')
