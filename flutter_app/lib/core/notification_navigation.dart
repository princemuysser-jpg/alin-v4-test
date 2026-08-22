import 'package:flutter/material.dart';

import '../screens/account_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/details_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/tracking_screen.dart';
import '../models/catalog.dart';
import '../state/app_controller.dart';

class NotificationNavigation {
  static Map<String, String>? _pending;

  static void queue(Map<String, dynamic> data) {
    _pending = data.map(
      (key, value) => MapEntry(key.toString(), value == null ? '' : '$value'),
    );
  }

  static Future<void> flush(
    NavigatorState navigator,
    AppController controller,
  ) async {
    final data = _pending;
    if (data == null) return;
    _pending = null;
    await open(navigator, controller, data);
  }

  static Future<void> open(
    NavigatorState navigator,
    AppController controller,
    Map<String, String> data,
  ) async {
    final type = (data['type'] ?? '').trim().toLowerCase();
    final rawLink = (data['link'] ?? data['url'] ?? '').trim();
    final uri = Uri.tryParse(rawLink);
    final normalized = rawLink.toLowerCase();

    final orderNumber = (data['order_number'] ??
            uri?.queryParameters['order'] ??
            uri?.queryParameters['order_number'] ??
            '')
        .trim();

    if (type.contains('order') ||
        normalized.contains('tracking') ||
        normalized.startsWith('order:') ||
        orderNumber.isNotEmpty) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => _ShellPage(
            title: 'تتبع الطلب',
            child: TrackingScreen(
              initialOrderCode: orderNumber.isEmpty ? null : orderNumber,
            ),
          ),
        ),
      );
      return;
    }

    if (normalized.contains('cart')) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const _ShellPage(
            title: 'السلة',
            child: CartScreen(),
          ),
        ),
      );
      return;
    }

    if (normalized.contains('favorite')) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const _ShellPage(
            title: 'المفضلة',
            child: FavoritesScreen(),
          ),
        ),
      );
      return;
    }

    if (normalized.contains('account') || normalized.contains('orders')) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const _ShellPage(
            title: 'خيارات',
            child: AccountScreen(),
          ),
        ),
      );
      return;
    }

    final itemId = (data['item_id'] ??
            data['product_id'] ??
            uri?.queryParameters['item'] ??
            uri?.queryParameters['item_id'] ??
            uri?.queryParameters['product_id'] ??
            '')
        .trim();
    if (itemId.isNotEmpty) {
      final items = controller.bootstrap?.items ?? const <StoreItem>[];
      for (final item in items) {
        if (item.id == itemId) {
          await navigator.push(
            MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
          );
          return;
        }
      }
    }

    await navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}

class _ShellPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _ShellPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}
