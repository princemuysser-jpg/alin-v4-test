import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/library_print_repository.dart';
import '../models/business_account.dart';
import 'library_booklet_preview_screen.dart';

class LibraryDashboardScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const LibraryDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<LibraryDashboardScreen> createState() => _LibraryDashboardScreenState();
}

class _LibraryDashboardScreenState extends State<LibraryDashboardScreen> {
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> settlements = [];
  Map<String, dynamic> profile = {};
  bool loading = true;
  String? error;
  String filter = 'work';
  final Set<String> busyOrders = {};

  static const doneStatuses = {'completed', 'delivered'};
  static const closedStatuses = {'completed', 'delivered', 'cancelled', 'rejected'};

  @override
  void initState() {
    super.initState();
    load();
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.libraryOrders(widget.account.id),
        widget.repository.libraryProfile(widget.account.id),
        widget.repository.librarySettlements(widget.account.id),
      ]);
      if (!mounted) return;
      setState(() {
        orders = values[0] as List<Map<String, dynamic>>;
        profile = values[1] as Map<String, dynamic>;
        settlements = values[2] as List<Map<String, dynamic>>;
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

  List<Map<String, dynamic>> get visibleOrders {
    if (filter == 'ready') return orders.where((o) => '${o['status']}' == 'ready').toList();
    if (filter == 'completed') return orders.where(isDone).toList();
    if (filter == 'all') return orders;
    return orders.where((o) => !isClosed(o) && '${o['status']}' != 'ready').toList();
  }

  String statusLabel(String status) => switch (status) {
        'new' || 'pending' || 'pending_admin' || 'accepted' => 'جديد',
        'processing' || 'printing' => 'قيد التجهيز',
        'ready' => 'جاهز',
        'completed' || 'delivered' => 'مسلّم',
        'cancelled' => 'ملغي',
        'rejected' => 'مرفوض',
        _ => status,
      };

  Future<void> setOpen(bool value) async {
    try {
      await widget.repository.librarySetOpen(value);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'تم فتح المكتبة' : 'تم غلق المكتبة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> transition(Map<String, dynamic> order, String status, {String reason = ''}) async {
    final id = '${order['id']}';
    if (busyOrders.contains(id)) return;
    setState(() => busyOrders.add(id));
    try {
      await widget.repository.libraryTransition(id, status, reason: reason);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الطلب')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busyOrders.remove(id));
    }
  }

  Future<String?> askReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الإلغاء'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'اكتب سبب الإلغاء'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('تأكيد')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> cancel(Map<String, dynamic> order) async {
    final reason = await askReason();
    if (reason == null || reason.length < 2) return;
    await transition(order, 'cancelled', reason: reason);
  }

  Future<void> saveLibraryNote(Map<String, dynamic> order) async {
    final controller = TextEditingController(text: '${order['library_note'] ?? ''}');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ملاحظة المكتبة'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(hintText: 'اكتب ملاحظة خاصة بهذا الطلب'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.length < 2) return;

    final id = '${order['id']}';
    if (busyOrders.contains(id)) return;
    setState(() => busyOrders.add(id));
    try {
      await widget.repository.librarySetOrderNote(id, result);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ ملاحظة المكتبة')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => busyOrders.remove(id));
    }
  }

  Future<void> openBookletPreview(Map<String, dynamic> order) async {
    final status = '${order['status']}';
    if (!['processing', 'printing', 'ready'].contains(status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ابدأ تجهيز الطلب أولاً حتى تتاح المعاينة والطباعة')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LibraryBookletPreviewScreen(repository: widget.repository, order: order),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = profile['is_open'] != false && '${profile['open_status'] ?? 'open'}' != 'closed';
    final preparing = orders.where((o) => ['new', 'pending', 'pending_admin', 'accepted', 'processing', 'printing'].contains('${o['status']}')).length;
    final ready = orders.where((o) => '${o['status']}' == 'ready').length;
    final completed = orders.where(isDone).length;
    final profit = orders.where(isDone).fold<num>(0, (sum, o) => sum + number(o['library_profit']));
    final settled = settlements.where((s) => ['received', 'paid', 'settled'].contains('${s['status']}'.toLowerCase())).fold<num>(0, (sum, s) => sum + number(s['amount']));

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('لوحة المكتبة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
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
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 6),
                  Text('${profile['area'] ?? widget.account.area}${('${profile['landmark'] ?? widget.account.landmark}').trim().isEmpty ? '' : ' — ${profile['landmark'] ?? widget.account.landmark}'}', style: const TextStyle(color: Colors.white70)),
                ])),
                Column(children: [
                  Text(isOpen ? 'مفتوح' : 'مغلق', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  Switch(value: isOpen, onChanged: setOpen),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Metric(label: 'للتجهيز', value: '$preparing', icon: Icons.print_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'جاهز', value: '$ready', icon: Icons.inventory_2_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'مسلّم', value: '$completed', icon: Icons.check_circle_rounded)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Metric(label: 'أرباح المكتبة', value: money(profit), icon: Icons.payments_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _Metric(label: 'تسويات مسجلة', value: money(settled), icon: Icons.account_balance_wallet_rounded)),
            ]),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'work', label: Text('للتجهيز')),
                ButtonSegment(value: 'ready', label: Text('جاهز')),
                ButtonSegment(value: 'completed', label: Text('مسلّم')),
                ButtonSegment(value: 'all', label: Text('الكل')),
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
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات في هذا القسم'))))
            else
              ...visibleOrders.map(orderCard),
            const SizedBox(height: 18),
            const Text('آخر التسويات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (settlements.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('لا توجد تسويات مسجلة بعد.')))
            else
              ...settlements.take(5).map((s) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt_long_rounded)),
                      title: Text('${s['receipt_number'] ?? s['id']}'),
                      subtitle: Text('${s['payment_method'] ?? '—'} • ${s['status'] ?? '—'}'),
                      trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget orderCard(Map<String, dynamic> order) {
    final status = '${order['status'] ?? 'new'}';
    final id = '${order['id']}';
    final busy = busyOrders.contains(id);
    final booklet = '${order['kind']}' == 'booklet';
    final previewAllowed = booklet && ['processing', 'printing', 'ready'].contains(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${order['order_number'] ?? id}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${order['title'] ?? 'طلب طباعة'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ])),
            Chip(label: Text(statusLabel(status))),
          ]),
          const Divider(),
          _line(Icons.person_outline, 'الطالب', '${order['student_name'] ?? '—'}'),
          _line(Icons.phone_outlined, 'الهاتف', '${order['student_phone'] ?? '—'}'),
          _line(Icons.inventory_2_outlined, 'العدد', '${order['qty'] ?? 1}'),
          _line(Icons.payments_outlined, 'الإجمالي', money(order['total'])),
          _line(Icons.account_balance_wallet_outlined, 'ربح المكتبة', money(order['library_profit'])),
          if ('${order['notes'] ?? ''}'.trim().isNotEmpty) _line(Icons.note_alt_outlined, 'ملاحظة الطالب', '${order['notes']}'),
          if ('${order['library_note'] ?? ''}'.trim().isNotEmpty) _line(Icons.sticky_note_2_outlined, 'ملاحظة المكتبة', '${order['library_note']}'),
          const SizedBox(height: 10),
          if (!isClosed(order))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => saveLibraryNote(order),
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: const Text('ملاحظة المكتبة'),
                ),
                if (booklet)
                  FilledButton.tonalIcon(
                    onPressed: busy || !previewAllowed ? null : () => openBookletPreview(order),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(previewAllowed ? 'معاينة / طباعة' : 'ابدأ التجهيز أولاً'),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          if (busy) const LinearProgressIndicator(),
          if (!busy) _actions(order, status),
        ]),
      ),
    );
  }

  Widget _actions(Map<String, dynamic> order, String status) {
    if (['new', 'pending', 'pending_admin', 'accepted'].contains(status)) {
      return Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => transition(order, 'processing'), icon: const Icon(Icons.print_rounded), label: const Text('بدء التجهيز'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => cancel(order), icon: const Icon(Icons.close), label: const Text('إلغاء'))),
      ]);
    }
    if (['processing', 'printing'].contains(status)) {
      return Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => transition(order, 'ready'), icon: const Icon(Icons.inventory_2_rounded), label: const Text('جاهز'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => cancel(order), icon: const Icon(Icons.close), label: const Text('إلغاء'))),
      ]);
    }
    if (status == 'ready') {
      return Row(children: [
        Expanded(child: FilledButton.icon(onPressed: () => transition(order, 'completed'), icon: const Icon(Icons.check_circle_rounded), label: const Text('تم التسليم'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: () => cancel(order), icon: const Icon(Icons.close), label: const Text('إلغاء'))),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _line(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 19, color: const Color(0xFF49647E)),
          const SizedBox(width: 8),
          SizedBox(width: 105, child: Text(label, style: const TextStyle(color: Color(0xFF667085)))),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
      ]),
    );
  }
}
