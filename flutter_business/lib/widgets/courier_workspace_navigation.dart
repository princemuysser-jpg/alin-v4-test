import 'package:flutter/material.dart';

import 'business_app_mark.dart';
import 'business_brand.dart';

/// One navigation model for the courier portal.
/// Wide screens use the sidebar; narrow screens use the bottom bar.
/// Never render both navigations for the same screen.
class CourierWorkspaceNavigation {
  CourierWorkspaceNavigation._();

  static const sections = ['home', 'active', 'completed', 'receipts', 'finance'];

  static int selectedIndex(String section) {
    final index = sections.indexOf(section);
    return index < 0 ? 0 : index;
  }

  static String label(String section) => switch (section) {
    'active' => 'طلبات التوصيل',
    'completed' => 'المكتملة',
    'receipts' => 'الوصولات',
    'finance' => 'الحساب المالي',
    _ => 'الرئيسية',
  };

  static IconData icon(String section) => switch (section) {
    'active' => Icons.local_shipping_rounded,
    'completed' => Icons.task_alt_rounded,
    'receipts' => Icons.receipt_long_rounded,
    'finance' => Icons.account_balance_wallet_rounded,
    _ => Icons.dashboard_customize_rounded,
  };

  static Color color(String section) => switch (section) {
    'active' => const Color(0xFF3988C8),
    'completed' => BusinessBrand.success,
    'receipts' => const Color(0xFF8863B6),
    'finance' => BusinessBrand.warning,
    _ => BusinessBrand.teal,
  };
}

class CourierWorkspaceSidebar extends StatelessWidget {
  final String name;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onLogout;
  final int unread;

  const CourierWorkspaceSidebar({
    super.key,
    required this.name,
    required this.selected,
    required this.onSelect,
    required this.onNotifications,
    required this.onProfile,
    required this.onLogout,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 252,
    decoration: const BoxDecoration(gradient: BusinessBrand.heroGradient),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 21, 14, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const BusinessAppMark(size: 46),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('منصة الين', style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19)),
              Text('بوابة المندوب', style: TextStyle(
                color: Color(0xFFA7E8D8), fontSize: 12)),
            ],
          )),
        ]),
        const SizedBox(height: 19),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .09),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF286C7C),
              child: Icon(Icons.delivery_dining_rounded, color: Colors.white)),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const Text('حساب المندوب', style: TextStyle(
                color: Colors.white70, fontSize: 11)),
            ])),
          ]),
        ),
        const SizedBox(height: 15),
        Expanded(child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(9, 8, 9, 10),
              child: Text('مساحة العمل', style: TextStyle(
                color: Color(0xFFA9BCCD), fontSize: 11,
                fontWeight: FontWeight.w800)),
            ),
            for (final section in CourierWorkspaceNavigation.sections)
              _tab(section),
          ],
        )),
        Divider(color: Colors.white.withValues(alpha: .17)),
        _footer(Icons.notifications_none_rounded,
          unread > 0 ? 'الإشعارات ($unread)' : 'الإشعارات', onNotifications),
        _footer(Icons.person_outline_rounded, 'ملفي الشخصي', onProfile),
        _footer(Icons.logout_rounded, 'تسجيل الخروج', onLogout),
      ]),
    )),
  );

  Widget _tab(String section) {
    final active = selected == section;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: active ? Colors.white.withValues(alpha: .17) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => onSelect(section),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active
                ? Colors.white.withValues(alpha: .16) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(CourierWorkspaceNavigation.icon(section),
                size: 21,
                color: active ? const Color(0xFF6CF0D8) : Colors.white70),
              const SizedBox(width: 12),
              Expanded(child: Text(CourierWorkspaceNavigation.label(section),
                style: TextStyle(color: Colors.white, fontWeight: active
                  ? FontWeight.w900 : FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _footer(IconData icon, String label, VoidCallback onTap) =>
    SizedBox(height: 40,
      child: TextButton.icon(
        style: TextButton.styleFrom(alignment: Alignment.centerRight),
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white70, size: 19),
        label: Text(label, style: const TextStyle(
          color: Colors.white70, fontWeight: FontWeight.w700)),
      ));
}

class CourierWorkspaceBottomBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const CourierWorkspaceBottomBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 72,
    backgroundColor: Colors.white,
    indicatorColor: BusinessBrand.softTeal,
    selectedIndex: CourierWorkspaceNavigation.selectedIndex(selected),
    onDestinationSelected: (index) =>
      onSelect(CourierWorkspaceNavigation.sections[index]),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
      NavigationDestination(
        icon: Icon(Icons.local_shipping_outlined),
        selectedIcon: Icon(Icons.local_shipping_rounded), label: 'الطلبات'),
      NavigationDestination(
        icon: Icon(Icons.task_alt_outlined),
        selectedIcon: Icon(Icons.task_alt_rounded), label: 'المكتملة'),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded), label: 'الوصولات'),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'المالية'),
    ],
  );
}
