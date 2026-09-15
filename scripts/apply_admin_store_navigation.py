from pathlib import Path

path = Path('flutter_business/lib/widgets/business_role_navigation.dart')
text = path.read_text(encoding='utf-8')

store_import = "import '../screens/admin_store_management_screen.dart';"
if store_import not in text:
    anchor = "import '../screens/admin_settings_screen.dart';"
    if anchor not in text:
        raise SystemExit('navigation import anchor not found')
    text = text.replace(anchor, anchor + '\n' + store_import, 1)

# Mobile/tablet admin drawer.
drawer_anchor = "      _adminSectionTile(context, 4, Icons.inventory_2_rounded, 'المحتوى'),\n"
drawer_marker = "title: 'المنتجات',\n        subtitle: 'إضافة وتعديل الأسعار والمخزون'"
if drawer_marker not in text:
    if drawer_anchor not in text:
        raise SystemExit('drawer content anchor not found')
    drawer_block = """      _routeTile(
        context,
        icon: Icons.inventory_2_outlined,
        title: 'المنتجات',
        subtitle: 'إضافة وتعديل الأسعار والمخزون',
        page: AdminStoreManagementScreen(
          repository: repository,
          initialTab: StoreManagementTab.products,
        ),
      ),
      _routeTile(
        context,
        icon: Icons.category_rounded,
        title: 'الأقسام',
        subtitle: 'أقسام المتجر والشعب الفرعية',
        page: AdminStoreManagementScreen(
          repository: repository,
          initialTab: StoreManagementTab.categories,
        ),
      ),
      _routeTile(
        context,
        icon: Icons.campaign_rounded,
        title: 'الإعلانات',
        subtitle: 'بنرات المتجر والعروض المرئية',
        page: AdminStoreManagementScreen(
          repository: repository,
          initialTab: StoreManagementTab.banners,
        ),
      ),
"""
    text = text.replace(drawer_anchor, drawer_anchor + drawer_block, 1)

# Desktop admin sidebar.
desktop_anchor = "                  _sectionItem(Icons.inventory_2_rounded, 'المحتوى', 4),\n"
desktop_marker = "_routeItem(context, Icons.inventory_2_outlined, 'المنتجات'"
if desktop_marker not in text:
    if desktop_anchor not in text:
        raise SystemExit('desktop content anchor not found')
    desktop_block = """                  _routeItem(
                    context,
                    Icons.inventory_2_outlined,
                    'المنتجات',
                    AdminStoreManagementScreen(
                      repository: repository,
                      initialTab: StoreManagementTab.products,
                    ),
                  ),
                  _routeItem(
                    context,
                    Icons.category_rounded,
                    'الأقسام',
                    AdminStoreManagementScreen(
                      repository: repository,
                      initialTab: StoreManagementTab.categories,
                    ),
                  ),
                  _routeItem(
                    context,
                    Icons.campaign_rounded,
                    'الإعلانات',
                    AdminStoreManagementScreen(
                      repository: repository,
                      initialTab: StoreManagementTab.banners,
                    ),
                  ),
"""
    text = text.replace(desktop_anchor, desktop_anchor + desktop_block, 1)

path.write_text(text, encoding='utf-8')
print('Admin products/categories/ads navigation integration applied.')
