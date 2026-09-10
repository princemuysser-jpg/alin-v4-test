import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/business_courier_repository.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';

class CourierDashboardScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const CourierDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  List<Map<String, dynamic>> orders = [];
  bool loading = true;
  String? error;
  String filter = 'active';
  String availability = 'available';
  String courierArea = '';
  List<String> courierAreas = [];
  final Set<String> busyOrders = {};

  static const doneStatuses = {'completed', 'delivered'};
  static const closedStatuses = {'completed', 'delivered', 'cancelled', 'rejected'};

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
        widget.repository.courierOrders(widget.account.id),
        widget.repository.courierProfile(),
      ]);
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(values[1] as Map);
      final rawAreas = profile['areas'];
      final areas = rawAreas is List
          ? rawAreas.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      setState(() {
        orders = (values[0] as List).cast<Map<String, dynamic>>();
        availability = '${profile['availability'] ?? 'available'}';
        courierArea = '${profile['area'] ?? ''}'.trim();
        courierAreas = areas;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool isDone(Map<String, dynamic> o) => doneStatuses.contains('${o['status']}');
  bool isClosed(Map<String, dynamic> o) => closedStatuses.contains('${o['status']}');

  int areaPriority(Map<String, dynamic> order) {
    final area = '${order['delivery_area'] ?? ''}'.trim().toLowerCase();
    if (area.isEmpty) return 2;
    final preferred = <String>{
      if (courierArea.isNotEmpty) courierArea.toLowerCase(),
      ...courierAreas.map((e) => e.toLowerCase()),
    };
    return preferred.contains(area) ? 0 : 1;
  }

  List<Map<String, dynamic>> get visibleOrders {
    Iterable<Map<String, dynamic>> rows;
    if (filter == 'completed') {
      rows = orders.where(isDone);
    } else if (filter == 'all') {
      rows = orders;
    } else {
      rows = orders.where((o) => !isClosed(o));
    }
    final list = rows.toList();
    list.sort((a, b) {
      final p = areaPriority(a).compareTo(areaPriority(b));
      if (p != 0) return p;
      final ad = DateTime.tryParse('${a['created_at'] ?? ''}');
      final bd = DateTime.tryParse('${b['created_at'] ?? ''}');
      if (ad != null && bd != null) return bd.compareTo(ad);
      return 0;
    });
    return list;
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  String statusLabel(String status) => switch (status) {
        'new' => 'جديد',
        'pending' || 'pending_admin' => 'بانتظار التعيين',
        'assigned' => 'بانتظار القبول',
        'accepted' => 'مقبول',
        'picked_up' => 'تم استلام الطلب',
        'out_for_delivery' || 'out_delivery' => 'في الطريق',
        'completed' || 'delivered' => 'تم التسليم',
        'cancelled' => 'ملغي',
        'rejected' => 'مرفوض',
        _ => status,
      };

  Future<void> setAvailability(String value) async {
    try {
      await widget.repository.courierSetAvailability(value);
      if (!mounted) return;
      setState(() => availability = value);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث حالة المندوب')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> transition(Map<String, dynamic> order, String status, {String reason = ''}) async {
    final id = '${order['id']}';
    if (busyOrders.contains(id)) return;
    setState(() => busyOrders.add(id));
    try {
      await widget.repository.courierTransition(id, status, reason: reason);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الطلب')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busyOrders.remove(id));
    }
  }

  Future<String?> askText(String title, {String hint = ''}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, maxLines: 4, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> reject(Map<String, dynamic> order) async {
    final reason = await askText('سبب رفض الطلب', hint: 'اكتب سبب الرفض');
    if (reason == null || reason.length < 2) return;
    await transition(order, 'rejected', reason: reason);
  }

  Future<void> sendNote(Map<String, dynamic> order) async {
    final note = await askText('ملاحظة للإدارة', hint: 'اكتب الملاحظة');
    if (note == null || note.length < 2) return;
    try {
      await widget.repository.courierSetNote('${order['id']}', note);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الملاحظة')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> openPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    await launchUrl(Uri.parse('tel:$clean'));
  }

  Future<void> openWhatsApp(String phone) async {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '964${clean.substring(1)}';
    if (clean.isEmpty) return;
    await launchUrl(Uri.parse('https://wa.me/$clean'), mode: LaunchMode.externalApplication);
  }

  Future<void> openMap(Map<String, dynamic> order) async {
    final lat = num.tryParse('${order['delivery_latitude']}');
    final lng = num.tryParse('${order['delivery_longitude']}');
    Uri? uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      final stored = '${order['delivery_location_url'] ?? ''}'.trim();
      if (stored.startsWith('https://')) uri = Uri.tryParse(stored);
      if (uri == null) {
        final q = [order['delivery_landmark'], order['delivery_area'], 'كركوك', 'العراق']
            .where((v) => '${v ?? ''}'.trim().isNotEmpty)
            .join('، ');
        if (q.isNotEmpty) uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}');
      }
    }
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final active = orders.where((o) => !isClosed(o)).length;
    final completed = orders.where(isDone).length;
    final profit = orders.where(isDone).fold<num>(0, (sum, o) => sum + number(o['courier_fee'] ?? o['courier_profit'] ?? o['delegate_profit']));
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('لوحة المندوب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'logout') widget.onLogout(); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                if (courierArea.isNotEmpty || courierAreas.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text('مناطقك: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}', style: const TextStyle(color: Colors.white70)),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(label: const Text('متاح'), selected: availability == 'available', onSelected: (_) => setAvailability('available')),
                  ChoiceChip(label: const Text('مشغول'), selected: availability == 'busy', onSelected: (_) => setAvailability('busy')),
                  ChoiceChip(label: const Text('خارج الخدمة'), selected: availability == 'offline', onSelected: (_) => setAvailability('offline')),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Metric(label: 'قيد التنفيذ', value: '$active', icon: Icons.delivery_dining_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'مكتملة', value: '$completed', icon: Icons.check_circle_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'أجور التوصيل', value: money(profit), icon: Icons.payments_rounded)),
            ]),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('الحالية'), icon: Icon(Icons.local_shipping_rounded)),
                ButtonSegment(value: 'completed', label: Text('المكتملة'), icon: Icon(Icons.check_circle_outline)),
                ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),
              ],
              selected: {filter},
              onSelectionChanged: (value) => setState(() => filter = value.first),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(error!), const SizedBox(height: 8), OutlinedButton(onPressed: load, child: const Text('إعادة المحاولة'))])))
            else if (visibleOrders.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات حالياً'))))
            else
              ...visibleOrders.map(orderCard),
          ],
        ),
      ),
    );
  }

  Widget orderCard(Map<String, dynamic> order) {
    final status = '${order['status'] ?? 'assigned'}';
    final id = '${order['id']}';
    final busy = busyOrders.contains(id);
    final phone = '${order['student_phone'] ?? ''}';
    final fee = order['courier_fee'] ?? order['courier_profit'] ?? order['delegate_profit'] ?? 0;
    final pickup = '${order['pickup_source_label'] ?? ''}'.trim();
    final preferred = areaPriority(order) == 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${order['order_number'] ?? id}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${order['title'] ?? 'طلب توصيل'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ])),
            if (preferred) const Padding(padding: EdgeInsets.only(left: 6), child: Chip(label: Text('ضمن منطقتك'))),
            Chip(label: Text(statusLabel(status))),
          ]),
          const Divider(),
          _line(Icons.person_outline, 'الطالب', '${order['student_name'] ?? '—'}'),
          _line(Icons.phone_outlined, 'الهاتف', phone.isEmpty ? '—' : phone),
          _line(Icons.location_on_outlined, 'المنطقة', '${order['delivery_area'] ?? '—'}'),
          _line(Icons.flag_outlined, 'أقرب نقطة دالة', '${order['delivery_landmark'] ?? '—'}'),
          if (pickup.isNotEmpty) _line(Icons.inventory_2_outlined, 'الاستلام من', pickup),
          _line(Icons.payments_outlined, 'المبلغ المطلوب', money(order['total'])),
          _line(Icons.account_balance_wallet_outlined, 'أجرة المندوب', money(fee)),
          if ('${order['delivery_note'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)), child: Text('ملاحظتك: ${order['delivery_note']}')),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (phone.isNotEmpty) OutlinedButton.icon(onPressed: () => openPhone(phone), icon: const Icon(Icons.call), label: const Text('اتصال')),
            if (phone.isNotEmpty) OutlinedButton.icon(onPressed: () => openWhatsApp(phone), icon: const Icon(Icons.chat_outlined), label: const Text('واتساب')),
            OutlinedButton.icon(onPressed: () => openMap(order), icon: const Icon(Icons.navigation_rounded), label: const Text('المسار')),
            if (!isClosed(order)) OutlinedButton.icon(onPressed: () => sendNote(order), icon: const Icon(Icons.note_alt_outlined), label: const Text('ملاحظة')),
          ]),
          const SizedBox(height: 10),
          if (busy) const LinearProgressIndicator(),
          if (!busy) _actions(order, status),
        ]),
      ),
    );
  }

  Widget _actions(Map<String, dynamic> order, String status) {
    if (['assigned', 'new', 'pending', 'pending_admin'].contains(status)) {
      return Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => transition(order, 'accepted'), icon: const Icon(Icons.check), label: const Text('قبول الطلب'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => reject(order), icon: const Icon(Icons.close), label: const Text('رفض'))),
      ]);
    }
    if (status == 'accepted') {
      return SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => transition(order, 'picked_up'), icon: const Icon(Icons.inventory_2), label: const Text('استلمت الطلب')));
    }
    if (status == 'picked_up') {
      return SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => transition(order, 'out_for_delivery'), icon: const Icon(Icons.local_shipping), label: const Text('بدء التوصيل')));
    }
    if (['out_for_delivery', 'out_delivery'].contains(status)) {
      return SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => transition(order, 'completed'), icon: const Icon(Icons.done_all), label: const Text('تم التسليم واستلام المبلغ')));
    }
    return const SizedBox.shrink();
  }

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF143B68)),
        const SizedBox(height: 8),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ]),
    );
  }
}
