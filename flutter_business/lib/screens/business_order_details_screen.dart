import 'package:flutter/material.dart';

import '../data/business_notification_repository.dart';
import '../data/business_repository.dart';

class BusinessOrderDetailsScreen extends StatefulWidget {
  final BusinessRepository repository;
  final String orderId;

  const BusinessOrderDetailsScreen({
    super.key,
    required this.repository,
    required this.orderId,
  });

  @override
  State<BusinessOrderDetailsScreen> createState() => _BusinessOrderDetailsScreenState();
}

class _BusinessOrderDetailsScreenState extends State<BusinessOrderDetailsScreen> {
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> timeline = [];
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
      final values = await Future.wait([
        widget.repository.businessOrder(widget.orderId),
        widget.repository.businessOrderTimeline(widget.orderId),
      ]);
      if (!mounted) return;
      setState(() {
        order = Map<String, dynamic>.from(values[0] as Map);
        timeline = (values[1] as List<Map<String, dynamic>>);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  num _number(dynamic value) => num.tryParse('$value') ?? 0;
  String _money(dynamic value) => '${_number(value).round()} د.ع';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline_rounded, size: 42, color: Colors.red),
                      const SizedBox(height: 10),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _orderCard(),
                      const SizedBox(height: 18),
                      const Text('سجل حركة الطلب', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      if (timeline.isEmpty)
                        const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد حركات مسجلة'))))
                      else
                        ...timeline.reversed.map(_timelineCard),
                    ],
                  ),
                ),
    );
  }

  Widget _orderCard() {
    final o = order ?? const <String, dynamic>{};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['order_number'] ?? widget.orderId}', style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${o['title'] ?? 'طلب'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
            ),
            Chip(label: Text(statusLabel('${o['status'] ?? ''}'))),
          ]),
          const Divider(),
          _line('الطالب', '${o['student_name'] ?? '—'}'),
          _line('الهاتف', '${o['student_phone'] ?? '—'}'),
          _line('العدد', '${o['qty'] ?? 1}'),
          _line('الإجمالي', _money(o['total'])),
          _line('طريقة الاستلام', fulfillmentLabel('${o['fulfillment_type'] ?? o['delivery_type'] ?? ''}')),
          if ('${o['delivery_area'] ?? ''}'.trim().isNotEmpty) _line('المنطقة', '${o['delivery_area']}'),
          if ('${o['delivery_landmark'] ?? ''}'.trim().isNotEmpty) _line('نقطة دالة', '${o['delivery_landmark']}'),
          if ('${o['notes'] ?? ''}'.trim().isNotEmpty) _line('ملاحظة الطالب', '${o['notes']}'),
          if ('${o['library_note'] ?? ''}'.trim().isNotEmpty) _line('ملاحظة المكتبة', '${o['library_note']}'),
          if ('${o['delivery_note'] ?? ''}'.trim().isNotEmpty) _line('ملاحظة المندوب', '${o['delivery_note']}'),
          _line('تاريخ الطلب', _dateTime(o['created_at'])),
        ]),
      ),
    );
  }

  Widget _timelineCard(Map<String, dynamic> row) {
    final reason = '${row['reason'] ?? ''}'.trim();
    final actor = '${row['actor_name'] ?? row['actor_id'] ?? 'النظام'}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F0F8),
          child: Icon(_statusIcon('${row['status']}'), color: const Color(0xFF143B68)),
        ),
        title: Text(statusLabel('${row['status'] ?? ''}'), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${reason.isEmpty ? 'تحديث حالة الطلب' : reason}\nبواسطة: $actor • ${roleLabel('${row['actor_role'] ?? ''}')}\n${_dateTime(row['created_at'])}'),
        isThreeLine: true,
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 105, child: Text(label, style: const TextStyle(color: Color(0xFF667085)))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  static String statusLabel(String status) => switch (status) {
        'new' => 'جديد',
        'pending' || 'pending_admin' => 'بانتظار التعيين',
        'assigned' => 'تم التعيين',
        'accepted' => 'تم القبول',
        'picked_up' => 'تم الاستلام',
        'out_for_delivery' || 'out_delivery' => 'في الطريق',
        'processing' || 'printing' => 'قيد التجهيز',
        'ready' => 'جاهز',
        'completed' || 'delivered' => 'تم التسليم',
        'cancelled' || 'canceled' => 'ملغي',
        'rejected' => 'مرفوض',
        _ => status.isEmpty ? '—' : status,
      };

  static String fulfillmentLabel(String value) => switch (value) {
        'home_delivery' || 'courier' => 'توصيل مندوب',
        'library_pickup' || 'library' || 'pickup' => 'استلام من مكتبة',
        _ => value.isEmpty ? '—' : value,
      };

  static String roleLabel(String role) => switch (role) {
        'admin' => 'الإدارة',
        'accountant' => 'الحسابات',
        'courier' || 'delegate' => 'المندوب',
        'library' => 'المكتبة',
        'printer' => 'المطبعة',
        'teacher' => 'المدرس',
        'system' => 'النظام',
        _ => role.isEmpty ? 'النظام' : role,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'completed' || 'delivered' => Icons.check_circle_rounded,
        'cancelled' || 'rejected' => Icons.cancel_rounded,
        'out_for_delivery' => Icons.local_shipping_rounded,
        'picked_up' => Icons.inventory_2_rounded,
        'ready' => Icons.task_alt_rounded,
        'processing' || 'printing' => Icons.print_rounded,
        'assigned' || 'accepted' => Icons.person_pin_circle_rounded,
        _ => Icons.receipt_long_rounded,
      };

  static String _dateTime(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '${value ?? '—'}';
    final local = parsed.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${p(local.month)}/${p(local.day)} ${p(local.hour)}:${p(local.minute)}';
  }
}
