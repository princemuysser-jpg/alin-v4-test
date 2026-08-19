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
    final size = MediaQuery.sizeOf(context);
    final tablet = size.shortestSide >= 600;
    final unread = c.unreadNotificationCount;

    Widget header() => Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(tablet ? 28 : 16, 10, tablet ? 28 : 12, 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Image.asset('assets/images/alin_icon.png', width: tablet ? 52 : 44, height: tablet ? 52 : 44, fit: BoxFit.contain),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('منصة آلين', style: TextStyle(fontSize: tablet ? 19 : 16, fontWeight: FontWeight.w900, color: AlinTheme.navy)),
                      Text(
                        c.student == null ? 'ملازم • قرطاسية • هدايا' : 'أهلاً ${c.student!.name} 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AlinTheme.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'الإشعارات',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'السلة',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
                  icon: Badge(
                    isLabelVisible: c.cartCount > 0,
                    label: Text('${c.cartCount}'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ],
            ),
          ),
        );

    if (tablet) {
      return Scaffold(
        body: Column(
          children: [
            header(),
            const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: (value) => setState(() => index = value),
                    labelType: NavigationRailLabelType.all,
                    leading: const SizedBox(height: 8),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: Text('المتجر')),
                      NavigationRailDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: Text('المفضلة')),
                      NavigationRailDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: Text('التتبع')),
                      NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('حسابي')),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: IndexedStack(index: index, children: pages)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(children: [header(), const Divider(height: 1), Expanded(child: IndexedStack(index: index, children: pages))]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'المتجر'),
          NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'التتبع'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}
