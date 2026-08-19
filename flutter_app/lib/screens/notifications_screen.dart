import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).markAllNotificationsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final rows = c.bootstrap?.notifications ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(onPressed: c.refreshNotifications, icon: const Icon(Icons.refresh), tooltip: 'تحديث'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: c.refreshNotifications,
        child: rows.isEmpty
            ? ListView(children: const [SizedBox(height: 220), Center(child: Text('ماكو إشعارات حالياً'))])
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final row = rows[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: const Color(0xFFEAF3FB), borderRadius: BorderRadius.circular(13)),
                            child: const Icon(Icons.notifications_active_outlined, color: AlinTheme.navy),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(row.title.isEmpty ? 'إشعار من منصة آلين' : row.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                if (row.message.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(row.message, style: const TextStyle(height: 1.55, color: AlinTheme.ink)),
                                ],
                                if (row.createdAt != null) ...[
                                  const SizedBox(height: 8),
                                  Text(_date(row.createdAt!), style: const TextStyle(color: AlinTheme.muted, fontSize: 11)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)}  ${two(local.hour)}:${two(local.minute)}';
  }
}
