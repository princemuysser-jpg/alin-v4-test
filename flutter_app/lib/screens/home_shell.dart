import 'dart:async';
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
  final Future<void> Function()? onStoreReady;
  const HomeShell({super.key, this.onStoreReady});

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.onStoreReady != null) {
        unawaited(widget.onStoreReady!());
      }
    });
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
          color: Theme.of(context).colorScheme.surface,
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
                                    c.tr('منصة آلين', ku: 'پلاتفۆرمی ئالین', en: 'Alin Platform'),
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
                                      c.tr('ملازم • قرطاسية • هدايا', ku: 'ملزمە • نووسینگە • دیاری', en: 'Booklets • Stationery • Gifts'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: roomy ? 11.5 : 10.5,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                        c.tr('أهلاً ${c.student!.name} 👋', ku: 'بەخێربێیت ${c.student!.name} 👋', en: 'Welcome ${c.student!.name} 👋'),
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
                    tooltip: c.tr('الإشعارات', ku: 'ئاگادارکردنەوەکان', en: 'Notifications'),
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
                    tooltip: c.tr('السلة', ku: 'سەبەتە', en: 'Cart'),
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
        homeLabel: c.tr('المتجر', ku: 'فرۆشگا', en: 'Store'),
        cartLabel: c.tr('السلة', ku: 'سەبەتە', en: 'Cart'),
        favoritesLabel: c.tr('المفضلة', ku: 'دڵخوازەکان', en: 'Favorites'),
        trackingLabel: c.tr('التتبع', ku: 'بەدواداچوون', en: 'Tracking'),
        optionsLabel: c.tr('خيارات', ku: 'هەڵبژاردەکان', en: 'Options'),
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
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(color: Theme.of(context).dividerColor),
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
  final String homeLabel;
  final String cartLabel;
  final String favoritesLabel;
  final String trackingLabel;
  final String optionsLabel;

  const _WebStyleBottomBar({
    required this.selectedPage,
    required this.cartCount,
    required this.onHome,
    required this.onCart,
    required this.onFavorites,
    required this.onTracking,
    required this.onOptions,
    required this.homeLabel,
    required this.cartLabel,
    required this.favoritesLabel,
    required this.trackingLabel,
    required this.optionsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 18,
      child: SafeArea(
        top: false,
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomItem(
                  label: homeLabel,
                  icon: Icons.storefront_outlined,
                  selectedIcon: Icons.storefront_rounded,
                  selected: selectedPage == 0,
                  onTap: onHome,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: cartLabel,
                  icon: Icons.shopping_bag_outlined,
                  selectedIcon: Icons.shopping_bag,
                  badge: cartCount,
                  onTap: onCart,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: favoritesLabel,
                  icon: Icons.favorite_border_rounded,
                  selectedIcon: Icons.favorite_rounded,
                  selected: selectedPage == 1,
                  onTap: onFavorites,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: trackingLabel,
                  icon: Icons.local_shipping_outlined,
                  selectedIcon: Icons.local_shipping_rounded,
                  selected: selectedPage == 2,
                  onTap: onTracking,
                ),
              ),
              Expanded(
                child: _BottomItem(
                  label: optionsLabel,
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
                color: selected ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF173E60) : const Color(0xFFE8F1FB)) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Badge(
                  isLabelVisible: badge > 0,
                  label: Text(badge > 99 ? '99+' : '$badge'),
                  child: Icon(selected ? selectedIcon : icon, size: 22, color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
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
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
