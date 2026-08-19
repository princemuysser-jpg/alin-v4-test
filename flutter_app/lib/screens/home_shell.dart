import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'favorites_screen.dart';
import 'notifications_screen.dart';
import 'store_screen.dart';
import 'tracking_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;
  DateTime? _lastResume;

  static const pages = [
    StoreScreen(),
    FavoritesScreen(),
    TrackingScreen(),
    AccountScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResume == null || now.difference(_lastResume!) > const Duration(seconds: 10)) {
        _lastResume = now;
        final c = AppScope.of(context);
        if (c.lastCatalogRefresh == null || now.difference(c.lastCatalogRefresh!) > const Duration(minutes: 5)) {
          c.refreshCatalog();
        } else {
          c.refreshNotifications();
        }
        c.restoreStudent();
        c.touchStudent();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final roomy = width >= 700;
    final unread = c.unreadNotificationCount;

    Widget header() => Material(
          color: Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(roomy ? 24 : 14, 9, roomy ? 24 : 12, 9),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => index = 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/alin_icon.png',
                              width: roomy ? 50 : 42,
                              height: roomy ? 50 : 42,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'منصة آلين',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: roomy ? 20 : 17,
                                      fontWeight: FontWeight.w900,
                                      color: AlinTheme.navy,
                                    ),
                                  ),
                                  if (c.student == null)
                                    Text(
                                      'ملازم • قرطاسية • هدايا',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: roomy ? 11.5 : 10.5,
                                        color: AlinTheme.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  else
                                    Container(
                                      margin: const EdgeInsets.only(top: 3),
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7E2),
                                        border: Border.all(color: const Color(0xFFE2BE69)),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'أهلاً ${c.student!.name} 👋',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: roomy ? 12.5 : 11.5,
                                          color: AlinTheme.navy,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderAction(
                    tooltip: 'الإشعارات',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                    child: Badge(
                      isLabelVisible: unread > 0,
                      label: Text(unread > 99 ? '99+' : '$unread'),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _HeaderAction(
                    tooltip: 'السلة',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                    child: Badge(
                      isLabelVisible: c.cartCount > 0,
                      label: Text('${c.cartCount}'),
                      child: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    return Scaffold(
      body: Column(
        children: [
          header(),
          const Divider(height: 1),
          Expanded(child: IndexedStack(index: index, children: pages)),
        ],
      ),
      bottomNavigationBar: _WebStyleBottomBar(
        selectedPage: index,
        cartCount: c.cartCount,
        onHome: () => setState(() => index = 0),
        onCart: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
        onFavorites: () => setState(() => index = 1),
        onTracking: () => setState(() => index = 2),
        onOptions: () => setState(() => index = 3),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  const _HeaderAction({required this.tooltip, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: AlinTheme.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _WebStyleBottomBar extends StatelessWidget {
  final int selectedPage;
  final int cartCount;
  final VoidCallback onHome;
  final VoidCallback onCart;
  final VoidCallback onFavorites;
  final VoidCallback onTracking;
  final VoidCallback onOptions;

  const _WebStyleBottomBar({
    required this.selectedPage,
    required this.cartCount,
    required this.onHome,
    required this.onCart,
    required this.onFavorites,
    required this.onTracking,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 18,
      child: SafeArea(
        top: false,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AlinTheme.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomItem(
                  label: 'المتجر',
                  icon: Icons.storefront_outlined,
                  selectedIcon: Icons.storefront_rounded,
                  selected: selectedPage == 0,
                  onTap: onHome,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: 'السلة',
                  icon: Icons.shopping_bag_outlined,
                  selectedIcon: Icons.shopping_bag,
                  badge: cartCount,
                  onTap: onCart,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: 'المفضلة',
                  icon: Icons.favorite_border_rounded,
                  selectedIcon: Icons.favorite_rounded,
                  selected: selectedPage == 1,
                  onTap: onFavorites,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: 'التتبع',
                  icon: Icons.local_shipping_outlined,
                  selectedIcon: Icons.local_shipping_rounded,
                  selected: selectedPage == 2,
                  onTap: onTracking,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: 'خيارات',
                  icon: Icons.tune_rounded,
                  selectedIcon: Icons.tune_rounded,
                  selected: selectedPage == 3,
                  onTap: onOptions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _BottomItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.onTap,
    this.selected = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE8F1FB) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text(badge > 99 ? '99+' : '$badge'),
                  child: Icon(selected ? selectedIcon : icon, size: 22, color: selected ? AlinTheme.navy : const Color(0xFF3D4650)),
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? AlinTheme.navy : const Color(0xFF3D4650),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
