import 'package:flutter/material.dart';

import '../data/business_notification_repository.dart';
import '../data/business_repository.dart';
import 'business_order_details_screen.dart';

class BusinessNotificationsScreen extends StatefulWidget {
  final BusinessRepository repository;

  const BusinessNotificationsScreen({super.key, required this.repository});

  @override
  State<BusinessNotificationsScreen> createState() => _BusinessNotificationsScreenState();
}

class _BusinessNotificationsScreenState extends State<BusinessNotificationsScreen> {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.businessNotifications(limit: 150);
      if (!mounted) return;
      setState(() => items = value);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int get unread => items.where((e) => e['is_read'] != true).length;

  Future<void> markAll() async {
    if (unread == 0) return;
    try {
      await widget.repository.businessNotificationsMarkAll();
      await load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> openItem(Map<String, dynamic> item) async {
    final id = '${item['id'] ?? ''}';
    if (id.isNotEmpty && item['is_read'] != true) {
      try {
        await widget.repository.businessNotificationMarkRead(id);
      } catch (_) {}
    }

    final orderId = orderIdFromNotification(item);
    if (!mounted) return;
    if (orderId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessOrderDetailsScreen(
            repository: widget.repository,
            orderId: orderId,
          ),
        ),
      );
    }
    await load();
  }

  static String? orderIdFromNotification(Map<String, dynamic> item) {
    final link = '${item['link'] ?? ''}'.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      final q = uri?.queryParameters['order'] ?? uri?.queryParameters['order_id'];
      if (q != null && q.trim().isNotEmpty) return q.trim();
    }
    final message = '${item['message'] ?? ''}';
    final match = RegExp(r'\b(O[0-9A-Za-z]+)\b').firstMatch(message);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (!loading && unread > 0)
            TextButton(
              onPressed: markAll,
              child: const Text('تحديد الكل كمقروء', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: loading
            ? const ListView(children: [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
            : error != null
                ? ListView(children: [
                    const SizedBox(height: 180),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                      ]),
                    ),
                  ])
                : items.isEmpty
                    ? const ListView(children: [SizedBox(height: 220), Center(child: Text('لا توجد إشعارات حالياً'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          final read = item['is_read'] == true;
                          return Card(
                            color: read ? Colors.white : const Color(0xFFF0F7FF),
                            child: ListTile(
                              onTap: () => openItem(item),
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFE5EEF8),
                                    child: Icon(_icon('${item['type'] ?? ''}'), color: const Color(0xFF143B68)),
                                  ),
                                  if (!read)
                                    const Positioned(
                                      top: -2,
                                      right: -2,
                                      child: CircleAvatar(radius: 5, backgroundColor: Colors.red),
                                    ),
                                ],
                              ),
                              title: Text('${item['title'] ?? 'آلين للأعمال'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: Text('${item['message'] ?? ''}\n${_dateTime(item['created_at'])}'),
                              isThreeLine: true,
                              trailing: orderIdFromNotification(item) != null ? const Icon(Icons.chevron_left_rounded) : null,
                            ),
                          );
                        },
                      ),
      ),
    );
  }

  static IconData _icon(String type) => switch (type) {
        'new_order' || 'order_new' => Icons.receipt_long_rounded,
        'courier_assigned' || 'order_assigned' => Icons.delivery_dining_rounded,
        'library_order' || 'library_assigned' => Icons.store_rounded,
        'order_update' => Icons.sync_alt_rounded,
        _ => Icons.notifications_rounded,
      };

  static String _dateTime(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${p(local.month)}/${p(local.day)} ${p(local.hour)}:${p(local.minute)}';
  }
}
