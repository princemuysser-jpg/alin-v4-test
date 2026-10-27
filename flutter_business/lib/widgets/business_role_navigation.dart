import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../screens/admin_backup_screen.dart';
import '../screens/admin_books_screen.dart';
import '../screens/admin_branding_screen.dart';
import '../screens/admin_coupons_screen.dart';
import '../screens/admin_courier_hub_screen.dart';
import '../screens/admin_delivery_pricing_screen.dart';
import '../screens/admin_finance_v2_screen.dart';
import '../screens/admin_growth_controls_screen.dart';
import '../screens/admin_reports_screen.dart';
import '../screens/admin_settings_screen.dart';
import '../screens/admin_store_management_screen.dart';
import '../screens/admin_teacher_courses_screen.dart';
import '../screens/business_notifications_screen.dart';
import '../screens/business_party_finance_screen.dart';
import '../screens/courier_profile_screen.dart';
import '../screens/teacher_profile_screen.dart';
import '../screens/teacher_publishing_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/printer_booklet_finance_screen.dart';
import '../screens/printer_dashboard_screen.dart';
import 'business_brand.dart';

class BusinessRoleNavigationDrawer extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;
  final ValueChanged<int>? onAdminSectionChanged;
  final int? adminSection;

  const BusinessRoleNavigationDrawer({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
    this.onAdminSectionChanged,
    this.adminSection,
  });

  @override
  State<BusinessRoleNavigationDrawer> createState() =>
      _BusinessRoleNavigationDrawerState();
}

class _BusinessRoleNavigationDrawerState
    extends State<BusinessRoleNavigationDrawer> {
  String openGroup = 'daily';

  BusinessRepository get repository => widget.repository;
  BusinessAccount get account => widget.account;
  Future<void> Function() get onLogout => widget.onLogout;
  ValueChanged<int>? get onAdminSectionChanged =>
      widget.onAdminSectionChanged;
  int? get adminSection => widget.adminSection;

  bool get _isAdmin => account.role == 'admin' || account.role == 'accountant';

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 310,
      backgroundColor: const Color(0xFFF7F9FC),
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                children: _isAdmin ? _adminMenu(context) : _roleMenu(context),
              ),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BusinessBrand.navy, Color(0xFF255B91)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          const AlinBrandMark(size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'آلين للأعمال',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _roleLabel(account.role),
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _adminMenu(BuildContext context) {
    return [
      _adminSectionTile(context, 0, Icons.dashboard_rounded, 'الرئيسية'),
      const SizedBox(height: 8),
      _adminGroup(
        keyName: 'daily',
        accent: const Color(0xFFFF7A00),
        soft: const Color(0xFFFFF0DE),
        emoji: '🛒',
        icon: Icons.receipt_long_rounded,
        title: 'الطلبات',
        subtitle: 'الطلبات والوصولات',
        children: [
          _adminSectionTile(
            context,
            1,
            Icons.receipt_long_rounded,
            'إدارة الطلبات',
          ),
          _adminSectionTile(
            context,
            5,
            Icons.receipt_long_outlined,
            'الوصولات',
          ),
        ],
      ),
      _adminGroup(
        keyName: 'accounts',
        accent: const Color(0xFF7C3AED),
        soft: const Color(0xFFF0E7FF),
        emoji: '👥',
        icon: Icons.groups_rounded,
        title: 'الحسابات',
        subtitle: 'المدرسون والمكتبات والمندوبون والمطابع',
        children: [
          _adminSectionTile(context, 2, Icons.groups_rounded, 'كل الحسابات'),
          _routeTile(
            context,
            icon: Icons.delivery_dining_rounded,
            title: 'مركز المندوبين',
            subtitle: 'الحالة والمناطق والطلبات',
            page: AdminCourierHubScreen(repository: repository),
          ),
        ],
      ),
      _adminGroup(
        keyName: 'content',
        accent: const Color(0xFF0088FF),
        soft: const Color(0xFFE3F1FF),
        emoji: '📚',
        icon: Icons.inventory_2_rounded,
        title: 'المتجر والمحتوى',
        subtitle: 'الملازم والمنتجات والأقسام',
        children: [
          _adminSectionTile(
            context,
            4,
            Icons.inventory_2_rounded,
            'نظرة المحتوى',
          ),
          _routeTile(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'المنتجات',
            subtitle: 'الأسعار والمخزون',
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
            icon: Icons.menu_book_rounded,
            title: 'إدارة الكتب',
            subtitle: 'المخزون والموردون والنسب',
            page: AdminBooksScreen(repository: repository),
          ),
          _routeTile(
            context,
            icon: Icons.video_library_rounded,
            title: 'دورات المدرسين',
            subtitle: 'المراجعة والنشر والإخفاء',
            page: AdminTeacherCoursesScreen(repository: repository),
          ),
        ],
      ),
      _adminGroup(
        keyName: 'delivery',
        accent: const Color(0xFF14B8A6),
        soft: const Color(0xFFDFF8F4),
        emoji: '🚚',
        icon: Icons.local_shipping_rounded,
        title: 'التوصيل والعملاء',
        subtitle: 'المندوبون والأسعار والتحكم',
        children: [
          _routeTile(
            context,
            icon: Icons.local_shipping_rounded,
            title: 'أسعار التوصيل',
            subtitle: 'سعر الطالب وأجرة المندوب',
            page: AdminDeliveryPricingScreen(repository: repository),
          ),
          _routeTile(
            context,
            icon: Icons.person_search_rounded,
            title: 'العملاء والتحكم بالطلبات',
            subtitle: 'النشطون وإيقاف الطلبات مؤقتاً',
            page: AdminGrowthControlsScreen(repository: repository),
          ),
        ],
      ),
      _adminGroup(
        keyName: 'finance',
        accent: const Color(0xFF00A86B),
        soft: const Color(0xFFDFF7EB),
        emoji: '💰',
        icon: Icons.account_balance_wallet_rounded,
        title: 'المالية',
        subtitle: 'الأرباح والذمم والتسويات',
        children: [
          _adminSectionTile(
            context,
            3,
            Icons.account_balance_wallet_rounded,
            'الملخص المالي',
          ),
          _routeTile(
            context,
            icon: Icons.account_balance_rounded,
            title: 'المالية والتسويات المتقدمة',
            subtitle: 'الذمم والتسويات والأرباح',
            page: AdminFinanceV2Screen(repository: repository),
          ),
        ],
      ),
      _adminGroup(
        keyName: 'marketing',
        accent: const Color(0xFFE11D8A),
        soft: const Color(0xFFFFE2F1),
        emoji: '📣',
        icon: Icons.campaign_rounded,
        title: 'التسويق',
        subtitle: 'الإعلانات والعروض والكوبونات',
        children: [
          _routeTile(
            context,
            icon: Icons.campaign_rounded,
            title: 'الإعلانات والبنرات',
            subtitle: 'بنرات المتجر والعروض المرئية',
            page: AdminStoreManagementScreen(
              repository: repository,
              initialTab: StoreManagementTab.banners,
            ),
          ),
          _routeTile(
            context,
            icon: Icons.confirmation_number_rounded,
            title: 'العروض والكوبونات',
            subtitle: 'أكواد الخصم والعروض',
            page: AdminCouponsScreen(repository: repository),
          ),
        ],
      ),
      _adminGroup(
        keyName: 'reports',
        accent: const Color(0xFF6D28D9),
        soft: const Color(0xFFEEE7FF),
        emoji: '📊',
        icon: Icons.analytics_rounded,
        title: 'التقارير',
        subtitle: 'المبيعات والأرباح والأداء',
        children: [
          _routeTile(
            context,
            icon: Icons.analytics_rounded,
            title: 'التقارير والتحليلات',
            subtitle: 'اليومي والشهري والأداء',
            page: AdminReportsScreen(repository: repository),
          ),
        ],
      ),
      _adminGroup(
        keyName: 'system',
        accent: const Color(0xFF475569),
        soft: const Color(0xFFEEF2F6),
        emoji: '⚙️',
        icon: Icons.settings_rounded,
        title: 'النظام',
        subtitle: 'الإعدادات والهوية والنسخ الاحتياطي',
        children: [
          _routeTile(
            context,
            icon: Icons.palette_rounded,
            title: 'الهوية البصرية',
            subtitle: 'الشعار والأيقونة والألوان',
            page: AdminBrandingScreen(repository: repository),
          ),
          _routeTile(
            context,
            icon: Icons.settings_rounded,
            title: 'إعدادات المنصة',
            subtitle: 'الطلبات والتوصيل والتواصل',
            page: AdminSettingsScreen(repository: repository),
          ),
          if (account.role == 'admin')
            _routeTile(
              context,
              icon: Icons.backup_rounded,
              title: 'النسخ الاحتياطي',
              subtitle: 'نسخ واستعادة الكتالوج والإعدادات',
              page: AdminBackupScreen(repository: repository),
            ),
        ],
      ),
    ];
  }

  Widget _adminGroup({
    required String keyName,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required Color soft,
    required String emoji,
    required List<Widget> children,
  }) {
    final expanded = openGroup == keyName;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: expanded ? soft : accent.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expanded
              ? accent.withValues(alpha: .28)
              : accent.withValues(alpha: .08),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: expanded ? Colors.white : soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            title: Text(
              '$emoji $title',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BusinessBrand.muted,
                fontSize: 10.5,
              ),
            ),
            trailing: AnimatedRotation(
              turns: expanded ? .5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: accent,
              ),
            ),
            onTap: () => setState(
              () => openGroup = expanded ? '' : keyName,
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _roleMenu(BuildContext context) {
    final widgets = <Widget>[
      _section('القائمة الرئيسية'),
      _closeTile(
        context,
        Icons.dashboard_rounded,
        'لوحة العمل',
        'العودة إلى الصفحة الرئيسية',
      ),
    ];

    if (account.role == 'teacher') {
      widgets.addAll([
        _section('الملازم والحساب'),
        _routeTile(
          context,
          icon: Icons.upload_file_rounded,
          title: 'رفع ومتابعة الملازم',
          subtitle: 'رفع الملفات ومتابعة الموافقة والنشر',
          page: TeacherPublishingScreen(
            repository: repository,
            account: account,
          ),
        ),
        _routeTile(
          context,
          icon: Icons.account_circle_rounded,
          title: 'الملف الشخصي',
          subtitle: 'بيانات الحساب والصورة والاختصاص',
          page: TeacherProfileScreen(repository: repository, account: account),
        ),
      ]);
    }

    if (account.role == 'courier' || account.role == 'delegate') {
      widgets.addAll([
        _section('المندوب'),
        _routeTile(
          context,
          icon: Icons.account_circle_rounded,
          title: 'حسابي',
          subtitle: 'البيانات والمناطق وحالة العمل',
          page: CourierProfileScreen(repository: repository, account: account),
        ),
      ]);
    }

    if (account.role == 'printer') {
      widgets.addAll([
        _section('المطبعة'),
        _routeTile(
          context,
          icon: Icons.auto_stories_rounded,
          title: 'حساب الملازم',
          subtitle: 'مبيعات وأرباح وذمة وتسويات الملازم',
          page: PrinterBookletFinanceScreen(
            repository: repository,
            account: account,
          ),
        ),
        _routeTile(
          context,
          icon: Icons.menu_book_rounded,
          title: 'حساب الكتب',
          subtitle: 'توريد الكتب والمستحقات والتسويات',
          page: PrinterDashboardScreen(
            repository: repository,
            account: account,
            onLogout: onLogout,
          ),
        ),
        _routeTile(
          context,
          icon: Icons.settings_rounded,
          title: 'إعدادات المطبعة',
          subtitle: 'استقبال الملازم وبيانات الحساب',
          page: PrinterSettingsScreen(
            repository: repository,
            account: account,
            onLogout: onLogout,
          ),
        ),
      ]);
    }

    widgets.addAll([
      _section('الحساب والتنبيهات'),
      if (account.role != 'printer')
        _routeTile(
          context,
          icon: Icons.account_balance_wallet_rounded,
          title: 'الحساب المالي',
          subtitle: 'الأرباح والذمم والتسويات والوصولات',
          page: BusinessPartyFinanceScreen(
            repository: repository,
            account: account,
          ),
        ),
      _routeTile(
        context,
        icon: Icons.notifications_rounded,
        title: 'الإشعارات',
        subtitle: 'مركز الإشعارات والتنبيهات',
        page: BusinessNotificationsScreen(repository: repository),
      ),
    ]);
    return widgets;
  }

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 7),
    child: Text(
      text,
      style: const TextStyle(
        color: BusinessBrand.muted,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _adminSectionTile(
    BuildContext context,
    int value,
    IconData icon,
    String title,
  ) {
    final selected = adminSection == value;
    return _menuTile(
      icon: icon,
      title: title,
      selected: selected,
      onTap: () {
        Navigator.of(context).pop();
        onAdminSectionChanged?.call(value);
      },
    );
  }

  Widget _closeTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return _menuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      selected: true,
      onTap: () => Navigator.of(context).pop(),
    );
  }

  Widget _routeTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return _menuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      },
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? BusinessBrand.softBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          dense: subtitle == null,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: selected ? Colors.white : const Color(0xFFEFF4F9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: BusinessBrand.navy),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: BusinessBrand.navy,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: BusinessBrand.muted,
                  ),
                ),
          trailing: const Icon(
            Icons.chevron_left_rounded,
            size: 19,
            color: BusinessBrand.muted,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BusinessBrand.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await onLogout();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج'),
        ),
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
    'admin' => 'مدير المنصة',
    'accountant' => 'الحسابات',
    'teacher' => 'مدرس',
    'library' => 'مكتبة',
    'courier' || 'delegate' => 'مندوب',
    'printer' => 'مطبعة',
    _ => role,
  };
}

class AdminDesktopNavigationSidebar extends StatelessWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final int selectedSection;
  final ValueChanged<int> onSectionChanged;
  final Future<void> Function() onLogout;

  const AdminDesktopNavigationSidebar({
    super.key,
    required this.repository,
    required this.account,
    required this.selectedSection,
    required this.onSectionChanged,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      color: BusinessBrand.navy,
      child: SafeArea(
        child: Column(
          children: [
            _desktopHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  _sectionItem(Icons.dashboard_rounded, '🏠 الرئيسية', 0),
                  const SizedBox(height: 8),
                  _desktopGroup(
                    '🛒 الطلبات',
                    Icons.receipt_long_rounded,
                    const Color(0xFFFF7A00),
                    [
                      _sectionItem(Icons.receipt_long_rounded, 'إدارة الطلبات', 1),
                      _sectionItem(Icons.receipt_long_outlined, 'الوصولات', 5),
                    ],
                  ),
                  _desktopGroup(
                    '👥 الحسابات',
                    Icons.groups_rounded,
                    const Color(0xFF7C3AED),
                    [
                      _sectionItem(Icons.groups_rounded, 'كل الحسابات', 2),
                      _routeItem(
                        context,
                        Icons.delivery_dining_rounded,
                        'مركز المندوبين',
                        AdminCourierHubScreen(repository: repository),
                      ),
                    ],
                  ),
                  _desktopGroup(
                    '📚 المتجر والمحتوى',
                    Icons.inventory_2_rounded,
                    const Color(0xFF0088FF),
                    [
                      _sectionItem(Icons.inventory_2_rounded, 'نظرة المحتوى', 4),
                      _routeItem(
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
                        Icons.menu_book_rounded,
                        'إدارة الكتب',
                        AdminBooksScreen(repository: repository),
                      ),
                      _routeItem(
                        context,
                        Icons.video_library_rounded,
                        'دورات المدرسين',
                        AdminTeacherCoursesScreen(repository: repository),
                      ),
                    ],
                  ),
                  _desktopGroup(
                    '🚚 التوصيل والعملاء',
                    Icons.local_shipping_rounded,
                    const Color(0xFF14B8A6),
                    [
                      _routeItem(
                        context,
                        Icons.local_shipping_rounded,
                        'أسعار التوصيل',
                        AdminDeliveryPricingScreen(repository: repository),
                      ),
                      _routeItem(
                        context,
                        Icons.person_search_rounded,
                        'العملاء والتحكم بالطلبات',
                        AdminGrowthControlsScreen(repository: repository),
                      ),
                    ],
                  ),
                  _desktopGroup(
                    '💰 المالية',
                    Icons.account_balance_wallet_rounded,
                    const Color(0xFF00A86B),
                    [
                      _sectionItem(
                        Icons.account_balance_wallet_rounded,
                        'الملخص المالي',
                        3,
                      ),
                      _routeItem(
                        context,
                        Icons.account_balance_rounded,
                        'المالية والتسويات المتقدمة',
                        AdminFinanceV2Screen(repository: repository),
                      ),
                    ],
                  ),
                  _desktopGroup(
                    '📣 التسويق',
                    Icons.campaign_rounded,
                    const Color(0xFFE11D8A),
                    [
                      _routeItem(
                        context,
                        Icons.campaign_rounded,
                        'الإعلانات والبنرات',
                        AdminStoreManagementScreen(
                          repository: repository,
                          initialTab: StoreManagementTab.banners,
                        ),
                      ),
                      _routeItem(
                        context,
                        Icons.confirmation_number_rounded,
                        'العروض والكوبونات',
                        AdminCouponsScreen(repository: repository),
                      ),
                    ],
                  ),
                  _desktopGroup(
                    '📊 التقارير',
                    Icons.analytics_rounded,
                    const Color(0xFF6D28D9),
                    [
                      _routeItem(
                        context,
                        Icons.analytics_rounded,
                        'التقارير والتحليلات',
                        AdminReportsScreen(repository: repository),
                      ),
                    ],
                  ),
                  _desktopGroup(
                    '⚙️ النظام',
                    Icons.settings_rounded,
                    const Color(0xFF64748B),
                    [
                      _routeItem(
                        context,
                        Icons.palette_rounded,
                        'الهوية البصرية',
                        AdminBrandingScreen(repository: repository),
                      ),
                      _routeItem(
                        context,
                        Icons.settings_rounded,
                        'إعدادات المنصة',
                        AdminSettingsScreen(repository: repository),
                      ),
                      if (account.role == 'admin')
                        _routeItem(
                          context,
                          Icons.backup_rounded,
                          'النسخ الاحتياطي',
                          AdminBackupScreen(repository: repository),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _desktopFooter(),
          ],
        ),
      ),
    );
  }

  Widget _desktopHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
    child: Row(
      children: [
        const AlinBrandMark(size: 48),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'آلين للأعمال',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              Text(
                account.role == 'accountant' ? 'لوحة الحسابات' : 'لوحة الإدارة',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _desktopGroup(
    String title,
    IconData icon,
    Color accent,
    List<Widget> children,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .24)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          iconColor: accent,
          collapsedIconColor: accent,
          initiallyExpanded: title.contains('الطلبات'),
          children: children,
        ),
      ),
    );
  }

  Widget _group(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(11, 15, 11, 6),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    ),
  );

  Widget _sectionItem(IconData icon, String title, int value) {
    final selected = selectedSection == value;
    return _desktopItem(
      icon: icon,
      title: title,
      selected: selected,
      onTap: () => onSectionChanged(value),
    );
  }

  Widget _routeItem(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) => _desktopItem(
    icon: icon,
    title: title,
    onTap: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
  );

  Widget _desktopItem({
    required IconData icon,
    required String title,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: .14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10.5),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopFooter() => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          account.role == 'accountant' ? 'الحسابات' : 'مدير المنصة',
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: onLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
          ),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    ),
  );
}
