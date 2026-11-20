import 'dart:async';

import 'package:flutter/material.dart';

import '../core/business_notification_signal.dart';
import '../data/business_notification_repository.dart';
import '../data/business_repository.dart';
import '../screens/business_notifications_screen.dart';

class BusinessNotificationBell extends StatefulWidget {
  final BusinessRepository repository;

  const BusinessNotificationBell({super.key, required this.repository});

  @override
  State<BusinessNotificationBell> createState() => _BusinessNotificationBellState();
}

class _BusinessNotificationBellState extends State<BusinessNotificationBell> {
  int unread = 0;
  Timer? _refreshTimer;
  bool _refreshBusy = false;

  @override
  void initState() {
    super.initState();
    refresh();
    BusinessNotificationSignal.revision.addListener(_onPush);
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(refresh());
    });
  }

  void _onPush() => unawaited(refresh());

  @override
  void dispose() {
    _refreshTimer?.cancel();
    BusinessNotificationSignal.revision.removeListener(_onPush);
    super.dispose();
  }

  Future<void> refresh() async {
    if (_refreshBusy || !mounted) return;
    _refreshBusy = true;
    try {
      final value = await widget.repository.businessNotificationUnreadCount();
      if (mounted && unread != value) setState(() => unread = value);
    } catch (_) {
      // Keep the bell visible during a temporary notification outage.
    } finally {
      _refreshBusy = false;
    }
  }

  Future<void> open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessNotificationsScreen(repository: widget.repository),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'الإشعارات',
      onPressed: open,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_rounded),
          if (unread > 0)
            Positioned(
              top: -7,
              right: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
