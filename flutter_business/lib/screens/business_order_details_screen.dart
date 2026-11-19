import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/business_notification_repository.dart';
import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

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


  Future<void> _copyText(String value, String label) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ $label')),
    );
  }

  String _field(Map<String, dynamic> o, String key) {
    final value = '${o[key] ?? ''}'.trim();
    return value.isEmpty || value == 'null' ? '—' : value;
  }

  bool _has(Map<String, dynamic> o, String key) => _field(o, key) != '—';

  bool _isDelivery(Map<String, dynamic> o) =>
      const {'home_delivery', 'courier', 'delivery'}
          .contains('${o['fulfillment_type'] ?? ''}'.toLowerCase()) ||
      '${o['delivery_type'] ?? ''}'.toLowerCase() == 'courier';

  String _paymentStatus(String value) => switch (value.toLowerCase()) {
    'paid' || 'completed' => 'مدفوع',
    'unpaid' => 'غير مدفوع',
    'pending' => 'قيد التحقق',
    'partial' || 'partially_paid' => 'مدفوع جزئياً',
    _ => value.isEmpty ? '—' : value,
  };

  @override
  Widget build(BuildContext context) {
    final o = order ?? const <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: BusinessBrand.ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('تفاصيل الطلب',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'تحديث بيانات الطلب',
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        shape: const Border(bottom: BorderSide(color: BusinessBrand.border)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 44,
                          color: BusinessBrand.danger),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 980;
                    final maxWidth = constraints.maxWidth >= 1300
                        ? 1220.0 : constraints.maxWidth;
                    final primary = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _studentSection(o),
                        const SizedBox(height: 14),
                        _fulfillmentSection(o),
                        const SizedBox(height: 14),
                        _orderDataSection(o),
                        if (_has(o, 'notes') ||
                            _has(o, 'library_note') ||
                            _has(o, 'delivery_note')) ...[
                          const SizedBox(height: 14),
                          _notesSection(o),
                        ],
                        if (_has(o, 'cancellation_reason')) ...[
                          const SizedBox(height: 14),
                          _cancellationNotice(o),
                        ],
                      ],
                    );
                    final secondary = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _financeSection(o),
                        const SizedBox(height: 14),
                        _timelineSection(),
                      ],
                    );
                    return RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: wide ? 24 : 14, vertical: 18),
                        children: [
                          Center(
                            child: SizedBox(
                              width: maxWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _heroCard(o),
                                  const SizedBox(height: 14),
                                  _quickActions(o),
                                  const SizedBox(height: 18),
                                  if (wide)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 6, child: primary),
                                        const SizedBox(width: 16),
                                        Expanded(flex: 4, child: secondary),
                                      ],
                                    )
                                  else ...[
                                    primary,
                                    const SizedBox(height: 14),
                                    secondary,
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _heroCard(Map<String, dynamic> o) {
    final status = _field(o, 'status');
    final isDelivery = _isDelivery(o);
    final number = _field(o, 'order_number') == '—'
        ? widget.orderId : _field(o, 'order_number');
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: BusinessBrand.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(
          color: BusinessBrand.panelShadow, blurRadius: 18, offset: Offset(0, 7),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 43, height: 43,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13)),
              child: Icon(isDelivery ? Icons.local_shipping_rounded :
                Icons.storefront_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 11),
            Expanded(child: Text('طلب #$number',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900,
                fontSize: 20, color: Colors.white))),
            const SizedBox(width: 8),
            _statusBadge(status),
          ]),
          const SizedBox(height: 12),
          Text(_field(o, 'title') == '—' ? 'تفاصيل الطلب' : _field(o, 'title'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE4EFF7), fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Wrap(spacing: 9, runSpacing: 9, children: [
            _heroTag(Icons.calendar_today_rounded, _dateTime(o['created_at'])),
            _heroTag(Icons.route_rounded, isDelivery ? 'توصيل مندوب' : 'استلام من مكتبة'),
          ]),
        ],
      ),
    );
  }

  Widget _heroTag(IconData icon, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: const Color(0xFFCBF7EF)),
      const SizedBox(width: 6),
      Text(value, style: const TextStyle(fontSize: 11.5, color: Colors.white)),
    ]),
  );

  Widget _quickActions(Map<String, dynamic> o) {
    final number = _field(o, 'order_number') == '—'
        ? widget.orderId : _field(o, 'order_number');
    final phone = _field(o, 'student_phone');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BusinessBrand.panelDecoration(radius: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(
          onPressed: () => _copyText(number, 'رقم الطلب'),
          icon: const Icon(Icons.copy_rounded, size: 17),
          label: const Text('نسخ رقم الطلب')),
        if (phone != '—')
          OutlinedButton.icon(
            onPressed: () => _copyText(phone, 'هاتف الطالب'),
            icon: const Icon(Icons.phone_rounded, size: 17),
            label: const Text('نسخ الهاتف')),
        OutlinedButton.icon(
          onPressed: load,
          icon: const Icon(Icons.sync_rounded, size: 17),
          label: const Text('تحديث الطلب')),
      ]),
    );
  }

  Widget _studentSection(Map<String, dynamic> o) => _detailsSection(
    title: 'بيانات الطالب',
    icon: Icons.person_outline_rounded,
    children: [
      _line('اسم الطالب', _field(o, 'student_name')),
      _line('رقم الهاتف', _field(o, 'student_phone')),
    ],
  );

  Widget _fulfillmentSection(Map<String, dynamic> o) {
    final delivery = _isDelivery(o);
    final library = _has(o, 'library_id')
        ? _field(o, 'library_id') : _field(o, 'pickup_library_id');
    final courier = _has(o, 'courier_id')
        ? _field(o, 'courier_id') : _field(o, 'delegate_id');
    return _detailsSection(
      title: 'التوصيل والاستلام',
      icon: delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined,
      children: [
        _line('طريقة التسليم', delivery ? 'توصيل مندوب' : 'استلام من مكتبة'),
        _line('المنطقة', _field(o, 'delivery_area')),
        if (_has(o, 'delivery_landmark'))
          _line('نقطة دالة', _field(o, 'delivery_landmark')),
        _line('المكتبة', library == '—' ? 'غير معيّنة' : 'المعرّف: $library'),
        if (delivery)
          _line('المندوب', courier == '—' ? 'غير معيّن' : 'المعرّف: $courier'),
      ],
    );
  }

  Widget _orderDataSection(Map<String, dynamic> o) => _detailsSection(
    title: 'محتوى الطلب ومواعيده',
    icon: Icons.receipt_long_outlined,
    children: [
      _line('المادة', _field(o, 'title')),
      _line('النوع', _field(o, 'kind')),
      _line('عدد النسخ', _field(o, 'qty')),
      _line('تاريخ الطلب', _dateTime(o['created_at'])),
      if (_has(o, 'updated_at'))
        _line('آخر تحديث', _dateTime(o['updated_at'])),
      if (_has(o, 'ready_at'))
        _line('وقت الجاهزية', _dateTime(o['ready_at'])),
      if (_has(o, 'delivered_at'))
        _line('وقت التسليم', _dateTime(o['delivered_at'])),
    ],
  );

  Widget _financeSection(Map<String, dynamic> o) => _detailsSection(
    title: 'المبالغ والدفع',
    icon: Icons.account_balance_wallet_outlined,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: BusinessBrand.softTeal,
          borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الإجمالي المسجل', style: TextStyle(
            color: BusinessBrand.muted, fontSize: 11)),
          const SizedBox(height: 5),
          Text(_money(o['total']), style: const TextStyle(
            color: BusinessBrand.navy, fontWeight: FontWeight.w900,
            fontSize: 25)),
        ]),
      ),
      const SizedBox(height: 9),
      _line('سعر الوحدة', _money(o['unit_price'])),
      _line('عدد النسخ', _field(o, 'qty')),
      if (_has(o, 'delivery_fee'))
        _line('أجور التوصيل', _money(o['delivery_fee'])),
      if (_has(o, 'courier_fee'))
        _line('أجر المندوب', _money(o['courier_fee'])),
      _line('طريقة الدفع', _field(o, 'payment_method')),
      _line('حالة الدفع', _paymentStatus(
        _field(o, 'payment_status') == '—' ? '' : _field(o, 'payment_status'))),
      const SizedBox(height: 5),
      const Text('المبالغ معروضة كما هي مسجلة بالطلب، بدون إعادة احتساب.',
        style: TextStyle(fontSize: 10.5, color: BusinessBrand.muted)),
    ],
  );

  Widget _notesSection(Map<String, dynamic> o) => _detailsSection(
    title: 'الملاحظات',
    icon: Icons.sticky_note_2_outlined,
    children: [
      if (_has(o, 'notes')) _line('الطالب', _field(o, 'notes')),
      if (_has(o, 'library_note')) _line('المكتبة', _field(o, 'library_note')),
      if (_has(o, 'delivery_note')) _line('المندوب', _field(o, 'delivery_note')),
    ],
  );

  Widget _cancellationNotice(Map<String, dynamic> o) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFF1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFCED3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.report_gmailerrorred_rounded, color: BusinessBrand.danger),
      const SizedBox(width: 9),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سبب إلغاء الطلب', style: TextStyle(
            color: BusinessBrand.danger, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(_field(o, 'cancellation_reason'),
            style: const TextStyle(color: BusinessBrand.ink, height: 1.4)),
        ],
      )),
    ]),
  );

  Widget _timelineSection() => _detailsSection(
    title: 'سجل حركة الطلب',
    icon: Icons.history_rounded,
    children: [
      if (timeline.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: Text('لا توجد حركات مسجلة',
            style: TextStyle(color: BusinessBrand.muted))),
        )
      else
        ...timeline.reversed.map(_timelineCard),
    ],
  );

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
