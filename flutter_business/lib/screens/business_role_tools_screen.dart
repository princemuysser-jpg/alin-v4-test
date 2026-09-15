import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_brand.dart';
import 'admin_backup_screen.dart';
import 'admin_books_screen.dart';
import 'admin_courier_hub_screen.dart';
import 'admin_teacher_courses_screen.dart';
// Admin old-web parity tools Build 17
import 'admin_coupons_screen.dart';
import 'admin_delivery_pricing_screen.dart';
import 'admin_finance_v2_screen.dart';
import 'admin_growth_controls_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_settings_screen.dart';
import 'business_notifications_screen.dart';
import 'business_party_finance_screen.dart';
import 'courier_profile_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_publishing_screen.dart';

class BusinessRoleToolsScreen extends StatelessWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const BusinessRoleToolsScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  Widget build(BuildContext context) {
    final tools = _tools(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1100
              ? 4
              : constraints.maxWidth >= 760
              ? 3
              : constraints.maxWidth >= 480
              ? 2
              : 1;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: BusinessBrand.heroGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: .14),
                      child: Icon(_roleIcon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _subtitle,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tools.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 3.2 : 1.65,
                ),
                itemBuilder: (context, index) => _ToolCard(tool: tools[index]),
              ),
            ],
          );
        },
      ),
    );
  }

  String get _title => switch (account.role) {
    'admin' || 'accountant' => 'أدوات الإدارة',
    'teacher' => 'أدوات المدرس',
    'library' => 'أدوات المكتبة',
    'courier' || 'delegate' => 'أدوات المندوب',
    'printer' => 'أدوات المطبعة',
    _ => 'أدوات الحساب',
  };

  String get _subtitle => switch (account.role) {
    'admin' || 'accountant' => 'كل أدوات الإدارة الإضافية من مكان واحد',
    'teacher' => 'الملف الشخصي والنشر والحسابات والإشعارات',
    'library' => 'الحسابات والإشعارات وأدوات العمل',
    'courier' || 'delegate' => 'الحسابات والإشعارات وأدوات التوصيل',
    'printer' => 'الحسابات والإشعارات وأدوات المطبعة',
    _ => 'أدوات الحساب',
  };

  IconData get _roleIcon => switch (account.role) {
    'admin' || 'accountant' => Icons.admin_panel_settings_rounded,
    'teacher' => Icons.school_rounded,
    'library' => Icons.store_rounded,
    'courier' || 'delegate' => Icons.delivery_dining_rounded,
    'printer' => Icons.print_rounded,
    _ => Icons.apps_rounded,
  };

  List<_RoleTool> _tools(BuildContext context) {
    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    final common = <_RoleTool>[
      _RoleTool(
        title: 'الإشعارات',
        subtitle: 'مركز الإشعارات والتنبيهات',
        icon: Icons.notifications_rounded,
        onTap: () => open(BusinessNotificationsScreen(repository: repository)),
      ),
    ];

    if (account.role == 'admin' || account.role == 'accountant') {
      return [
        _RoleTool(
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
        _RoleTool(
          title: 'المالية والتسويات',
          subtitle: 'الأرباح والذمم والتسويات والوصولات',
          icon: Icons.account_balance_wallet_rounded,
          onTap: () => open(AdminFinanceV2Screen(repository: repository)),
        ),
        _RoleTool(
          title: 'أسعار التوصيل',
          subtitle: 'المناطق وسعر الطالب وأجرة المندوب',
          icon: Icons.local_shipping_rounded,
          onTap: () => open(AdminDeliveryPricingScreen(repository: repository)),
        ),
        _RoleTool(
          title: 'العملاء والطلبات',
          subtitle: 'العملاء النشطون وإيقاف الطلبات مؤقتاً',
          icon: Icons.groups_rounded,
          onTap: () => open(AdminGrowthControlsScreen(repository: repository)),
        ),
        _RoleTool(
          title: 'العروض والكوبونات',
          subtitle: 'إضافة وتعديل وتشغيل أكواد الخصم',
          icon: Icons.confirmation_number_rounded,
          onTap: () => open(AdminCouponsScreen(repository: repository)),
        ),
        _RoleTool(
          title: 'التقارير والتحليلات',
          subtitle: 'المبيعات والأرباح وأفضل العناصر والشركاء',
          icon: Icons.analytics_rounded,
          onTap: () => open(AdminReportsScreen(repository: repository)),
        ),
        _RoleTool(
          title: 'إعدادات المنصة',
          subtitle: 'الطلبات والتوصيل والتواصل وحول المنصة',
          icon: Icons.settings_rounded,
          onTap: () => open(AdminSettingsScreen(repository: repository)),
        ),
        if (account.role == 'admin')
          _RoleTool(
            title: 'النسخ الاحتياطي',
            subtitle: 'نسخة آمنة للكتالوج والإعدادات واستعادتها',
            icon: Icons.backup_rounded,
            onTap: () => open(AdminBackupScreen(repository: repository)),
          ),
        ...common,
      ];
    }

    if (account.role == 'teacher') {
      return [
        _RoleTool(
          title: 'ملفي الشخصي',
          subtitle: 'الهاتف والمنطقة والاختصاص والصورة وكلمة المرور',
          icon: Icons.account_circle_rounded,
          onTap: () => open(
            TeacherProfileScreen(repository: repository, account: account),
          ),
        ),
        _RoleTool(
          title: 'رفع ومتابعة الملازم',
          subtitle: 'رفع الملفات ومتابعة الموافقة والنشر',
          icon: Icons.upload_file_rounded,
          onTap: () => open(
            TeacherPublishingScreen(repository: repository, account: account),
          ),
        ),
        _RoleTool(
          title: 'حسابي المالي',
          subtitle: 'الأرباح والتسويات والرصيد الحالي',
          icon: Icons.account_balance_wallet_rounded,
          onTap: () => open(
            BusinessPartyFinanceScreen(
              repository: repository,
              account: account,
            ),
          ),
        ),
        ...common,
      ];
    }

    if (account.role == 'courier' || account.role == 'delegate') {
      return [
        _RoleTool(
          title: 'حسابي',
          subtitle: 'بيانات المندوب ومناطق العمل وحالة التوفر',
          icon: Icons.account_circle_rounded,
          onTap: () => open(
            CourierProfileScreen(repository: repository, account: account),
          ),
        ),
        _RoleTool(
          title: 'حسابي المالي',
          subtitle: 'الأرباح والذمم والتسويات والوصولات',
          icon: Icons.account_balance_wallet_rounded,
          onTap: () => open(
            BusinessPartyFinanceScreen(
              repository: repository,
              account: account,
            ),
          ),
        ),
        ...common,
      ];
    }

    if (const {'library', 'printer'}.contains(account.role)) {
      return [
        _RoleTool(
          title: 'حسابي المالي',
          subtitle: 'الأرباح والذمم والتسويات والوصولات',
          icon: Icons.account_balance_wallet_rounded,
          onTap: () => open(
            BusinessPartyFinanceScreen(
              repository: repository,
              account: account,
            ),
          ),
        ),
        ...common,
      ];
    }

    return common;
  }
}

class _RoleTool {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleTool({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _ToolCard extends StatelessWidget {
  final _RoleTool tool;

  const _ToolCard({required this.tool});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tool.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: BusinessBrand.softBlue,
                child: Icon(tool.icon, color: BusinessBrand.navy),
              ),
              const Spacer(),
              Text(
                tool.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: BusinessBrand.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tool.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: BusinessBrand.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
