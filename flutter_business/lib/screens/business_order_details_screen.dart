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
    final status = '${o['status'] ?? ''}';
    final cancellationReason = '${o['cancellation_reason'] ?? ''}'.trim();
    final delivery =
        ['home_delivery', 'courier', 'delivery']
            .contains('${o['fulfillment_type'] ?? ''}'.toLowerCase()) ||
        '${o['delivery_type'] ?? ''}'.toLowerCase() == 'courier';
    final accent = _statusColor(status);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: accent.withValues(alpha: .22), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .08),
              border: Border(
                right: BorderSide(color: accent, width: 4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    delivery
                        ? Icons.delivery_dining_rounded
                        : Icons.storefront_rounded,
                    color: accent,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${o['order_number'] ?? widget.orderId}',
                        style: const TextStyle(
                          color: Color(0xFF143B68),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${o['title'] ?? 'طلب'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 560;
                    final student = _summaryPanel(
                      Icons.person_rounded,
                      'الطالب',
                      '${o['student_name'] ?? '—'}',
                      '${o['student_phone'] ?? '—'}',
                      const Color(0xFF7C3AED),
                    );
                    final fulfillment = _summaryPanel(
                      delivery
                          ? Icons.local_shipping_rounded
                          : Icons.store_rounded,
                      'الاستلام',
                      fulfillmentLabel(
                        '${o['fulfillment_type'] ?? o['delivery_type'] ?? ''}',
                      ),
                      '${o['delivery_area'] ?? o['delivery_landmark'] ?? '—'}',
                      delivery
                          ? const Color(0xFF0088FF)
                          : const Color(0xFF16A34A),
                    );
                    final payment = _summaryPanel(
                      Icons.payments_rounded,
                      'الإجمالي',
                      _money(o['total']),
                      '${o['payment_method'] ?? '—'}',
                      const Color(0xFFFF7A00),
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          student,
                          const SizedBox(height: 8),
                          fulfillment,
                          const SizedBox(height: 8),
                          payment,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: student),
                        const SizedBox(width: 8),
                        Expanded(child: fulfillment),
                        const SizedBox(width: 8),
                        Expanded(child: payment),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                _detailsSection(
                  title: 'بيانات الطلب',
                  icon: Icons.receipt_long_rounded,
                  children: [
                    _line('العدد', '${o['qty'] ?? 1}'),
                    if ('${o['delivery_landmark'] ?? ''}'.trim().isNotEmpty)
                      _line('نقطة دالة', '${o['delivery_landmark']}'),
                    _line('تاريخ الطلب', _dateTime(o['created_at'])),
                    if ('${o['updated_at'] ?? ''}'.trim().isNotEmpty)
                      _line('آخر تحديث', _dateTime(o['updated_at'])),
                  ],
                ),
                if ('${o['notes'] ?? ''}'.trim().isNotEmpty ||
                    '${o['library_note'] ?? ''}'.trim().isNotEmpty ||
                    '${o['delivery_note'] ?? ''}'.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _detailsSection(
                    title: 'الملاحظات',
                    icon: Icons.sticky_note_2_rounded,
                    children: [
                      if ('${o['notes'] ?? ''}'.trim().isNotEmpty)
                        _line('الطالب', '${o['notes']}'),
                      if ('${o['library_note'] ?? ''}'.trim().isNotEmpty)
                        _line('المكتبة', '${o['library_note']}'),
                      if ('${o['delivery_note'] ?? ''}'.trim().isNotEmpty)
                        _line('المندوب', '${o['delivery_note']}'),
                    ],
                  ),
                ],
                if (cancellationReason.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9EE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFC2D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFC1123F),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'سبب إلغاء الطلب',
                                style: TextStyle(
                                  color: Color(0xFF9F1239),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cancellationReason,
                                style: const TextStyle(
                                  color: Color(0xFF9F1239),
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryPanel(
    IconData icon,
    String label,
    String value,
    String subtitle,
    Color accent,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: .13)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF143B68),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF143B68)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF143B68),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final accent = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'completed' || 'delivered' => const Color(0xFF16A34A),
        'cancelled' || 'canceled' || 'rejected' => const Color(0xFFE11D48),
        'ready' => const Color(0xFF0088FF),
        'processing' || 'printing' || 'assigned' || 'accepted' =>
          const Color(0xFFFF8A00),
        'out_for_delivery' || 'picked_up' => const Color(0xFF7C3AED),
        _ => const Color(0xFF14B8A6),
      };

  Widget _timelineCard(Map<String, dynamic> row) {
    final reason = '${row['reason'] ?? ''}'.trim();
    final actor = '${row['actor_name'] ?? row['actor_id'] ?? 'النظام'}'.trim();
    final accent = _statusColor('${row['status']}');
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withValues(alpha: .14)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: .10),
          child: Icon(_statusIcon('${row['status']}'), color: accent),
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
