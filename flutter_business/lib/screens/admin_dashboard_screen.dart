import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';

class AdminDashboardScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const AdminDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int index = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> couriers = [];
  List<Map<String, dynamic>> booklets = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> settlements = [];
  List<Map<String, dynamic>> ledger = [];
  String orderFilter = 'active';
  String accountFilter = 'all';

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
        widget.repository.dashboardSummary(widget.account),
        widget.repository.adminOrders(),
        widget.repository.adminAccounts(),
        widget.repository.adminCouriers(),
        widget.repository.adminBooklets(),
        widget.repository.adminProducts(),
        widget.repository.adminSettlements(),
        widget.repository.adminLedger(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(values[0] as Map);
        orders = (values[1] as List).cast<Map<String, dynamic>>();
        accounts = (values[2] as List).cast<Map<String, dynamic>>();
        couriers = (values[3] as List).cast<Map<String, dynamic>>();
        booklets = (values[4] as List).cast<Map<String, dynamic>>();
        products = (values[5] as List).cast<Map<String, dynamic>>();
        settlements = (values[6] as List).cast<Map<String, dynamic>>();
        ledger = (values[7] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  bool isClosed(Map<String, dynamic> o) {
    final items = (o['_items'] as List?)?.cast<Map<String, dynamic>>() ?? [o];
    return items.every((row) => ['completed', 'delivered', 'cancelled', 'rejected'].contains('${row['status']}'));
  }

  String checkoutKey(Map<String, dynamic> o) {
    final group = '${o['checkout_group_id'] ?? ''}'.trim();
    if (group.isNotEmpty) return 'group:$group';
    final request = '${o['checkout_request_key'] ?? ''}'.trim();
    if (request.isNotEmpty) return 'request:$request';
    return 'single:${o['id'] ?? o['order_number']}';
  }

  List<Map<String, dynamic>> groupOrders(List<Map<String, dynamic>> source) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in source) {
      groups.putIfAbsent(checkoutKey(row), () => []).add(row);
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final items = entry.value;
      final anchor = items.firstWhere((row) => number(row['delivery_fee']) > 0 || number(row['courier_fee']) > 0, orElse: () => items.first);
      final statuses = items.map((row) => '${row['status']}').toSet();
      result.add({...anchor, '_checkout_key': entry.key, '_items': items, '_item_count': items.length, '_qty_count': items.fold<num>(0, (sum, row) => sum + (number(row['qty']) <= 0 ? 1 : number(row['qty']))), 'total': items.fold<num>(0, (sum, row) => sum + number(row['total'])), 'delivery_fee': items.fold<num>(0, (sum, row) => sum + number(row['delivery_fee'])), 'courier_fee': items.fold<num>(0, (sum, row) => sum + number(row['courier_fee'] ?? row['courier_profit'] ?? row['delegate_profit'])), '_mixed_status': statuses.length > 1});
    }
    result.sort((a, b) => '${b['created_at'] ?? b['updated_at'] ?? ''}'.compareTo('${a['created_at'] ?? a['updated_at'] ?? ''}'));
    return result;
  }

  bool isDeliveryOrder(Map<String, dynamic> order) {
    final fulfillment = '${order['fulfillment_type']}'.toLowerCase();
    final deliveryType = '${order['delivery_type']}'.toLowerCase();
    return fulfillment == 'home_delivery' || fulfillment == 'courier' || fulfillment == 'delivery' || deliveryType == 'courier';
  }

  List<Map<String, dynamic>> get groupedOrders => groupOrders(orders);

  List<Map<String, dynamic>> get visibleOrders {
    final grouped = groupedOrders;
    if (orderFilter == 'all') return grouped;
    if (orderFilter == 'done') return grouped.where((e) => ((e['_items'] as List).cast<Map<String, dynamic>>()).every((row) => ['completed', 'delivered'].contains('${row['status']}'))).toList();
    if (orderFilter == 'cancelled') return grouped.where((e) => ((e['_items'] as List).cast<Map<String, dynamic>>()).every((row) => ['cancelled', 'rejected'].contains('${row['status']}'))).toList();
    return grouped.where((e) => !isClosed(e)).toList();
  }

  List<Map<String, dynamic>> get visibleAccounts {
    if (accountFilter == 'all') return accounts.where((e) => e['deleted_at'] == null).toList();
    return accounts.where((e) => e['deleted_at'] == null && '${e['role']}' == accountFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_home(), _orders(), _accounts(), _finance(), _catalog()];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.account.role == 'accountant' ? 'لوحة الحسابات' : 'لوحة إدارة آلين', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: load, child: const Text('إعادة المحاولة'))])))
              : RefreshIndicator(onRefresh: load, child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.groups_rounded), label: 'الحسابات'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: 'المالية'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المحتوى'),
        ],
      ),
    );
  }

  Widget _scroll(List<Widget> children) => ListView(padding: const EdgeInsets.all(16), children: children);

  Widget _home() {
    return _scroll([
      _hero(),
      const SizedBox(height: 14),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          _metric('الطلبات', '${summary['orders'] ?? orders.length}', Icons.receipt_long_rounded),
          _metric('طلبات تحتاج متابعة', '${summary['new_orders'] ?? 0}', Icons.notifications_active_rounded),
          _metric('إجمالي المبيعات', money(summary['total_sales']), Icons.payments_rounded),
          _metric('ربح المنصة', money(summary['platform_profit']), Icons.account_balance_wallet_rounded),
          _metric('المكتبات', '${summary['libraries'] ?? 0}', Icons.store_rounded),
          _metric('المندوبون', '${summary['couriers'] ?? 0}', Icons.delivery_dining_rounded),
          _metric('المطابع', '${summary['printers'] ?? 0}', Icons.print_rounded),
          _metric('المدرسون', '${summary['teachers'] ?? 0}', Icons.school_rounded),
        ],
      ),
      const SizedBox(height: 18),
      const Text('آخر الطلبات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...groupedOrders.take(5).map(_orderCard),
    ]);
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('إدارة الطلبات والحسابات والمالية والمحتوى من مكان واحد', style: TextStyle(color: Colors.white70)),
        ]),
      );

  Widget _metric(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: const Color(0xFF143B68)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _orders() {
    return _scroll([
      const Text('إدارة الطلبات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'active', label: Text('الحالية')),
          ButtonSegment(value: 'done', label: Text('المكتملة')),
          ButtonSegment(value: 'cancelled', label: Text('الملغاة')),
          ButtonSegment(value: 'all', label: Text('الكل')),
        ],
        selected: {orderFilter},
        onSelectionChanged: (value) => setState(() => orderFilter = value.first),
      ),
      const SizedBox(height: 12),
      if (visibleOrders.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('لا توجد طلبات'))))
      else
        ...visibleOrders.map(_orderCard),
    ]);
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final deliveryOrder = isDeliveryOrder(o);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o['order_number'] ?? o['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(number(o['_item_count']) > 1 ? 'طلب واحد • ${number(o['_item_count']).round()} مواد' : '${o['title'] ?? 'طلب'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ])),
            Chip(label: Text(_status('${o['status']}'))),
          ]),
          const Divider(),
          if (number(o['_item_count']) > 1) ...[
            const Text('مواد الطلب', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
            const SizedBox(height: 6),
            ...((o['_items'] as List).cast<Map<String, dynamic>>()).asMap().entries.map((entry) {
              final item = entry.value;
              final qty = number(item['qty']) <= 0 ? 1 : number(item['qty']);
              return Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [Expanded(child: Text('${entry.key + 1}. ${item['title'] ?? 'مادة'}', style: const TextStyle(fontWeight: FontWeight.w700))), Text('× ${qty.round()} • ${money(item['total'])}', style: const TextStyle(fontWeight: FontWeight.w700))]));
            }),
            const Divider(),
          ],
          _line('الطالب', '${o['student_name'] ?? '—'}'),
          _line('الهاتف', '${o['student_phone'] ?? '—'}'),
          _line('المنطقة', '${o['delivery_area'] ?? '—'}'),
          _line('الإجمالي', money(o['total'])),
          if ('${o['courier_id'] ?? o['delegate_id'] ?? ''}'.isNotEmpty) _line('المندوب', _courierName('${o['courier_id'] ?? o['delegate_id']}')),
          if ('${o['library_id'] ?? o['pickup_library_id'] ?? ''}'.isNotEmpty) _line('المكتبة', '${o['library_id'] ?? o['pickup_library_id']}'),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (deliveryOrder && !isClosed(o))
              OutlinedButton.icon(onPressed: () => _assignCourier(o), icon: const Icon(Icons.delivery_dining_rounded), label: const Text('تعيين مندوب')),
            if (!isClosed(o)) OutlinedButton.icon(onPressed: () => _changeOrderStatus(o), icon: const Icon(Icons.sync_alt_rounded), label: const Text('تغيير الحالة')),
          ]),
        ]),
      ),
    );
  }

  String _courierName(String id) {
    for (final courier in couriers) {
      if ('${courier['id']}' == id) return '${courier['name'] ?? id}';
    }
    return id;
  }

  Widget _accounts() {
    return _scroll([
      Row(children: [
        const Expanded(child: Text('إدارة الحسابات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        FilledButton.icon(onPressed: _createAccount, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('إضافة')),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('الكل')),
            ButtonSegment(value: 'teacher', label: Text('مدرس')),
            ButtonSegment(value: 'library', label: Text('مكتبة')),
            ButtonSegment(value: 'courier', label: Text('مندوب')),
            ButtonSegment(value: 'printer', label: Text('مطبعة')),
            ButtonSegment(value: 'accountant', label: Text('حسابات')),
          ],
          selected: {accountFilter},
          onSelectionChanged: (value) => setState(() => accountFilter = value.first),
        ),
      ),
      const SizedBox(height: 12),
      ...visibleAccounts.map((a) => Card(
            margin: const EdgeInsets.only(bottom: 9),
            child: ListTile(
              leading: CircleAvatar(child: Icon(_roleIcon('${a['role']}'))),
              title: Text('${a['name'] ?? 'بدون اسم'}', style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${_roleLabel('${a['role']}')} • ${a['username'] ?? ''}\n${a['phone'] ?? ''} ${a['area'] ?? ''}'),
              isThreeLine: true,
              trailing: Chip(label: Text('${a['status']}' == 'active' ? 'فعال' : 'غير فعال')),
              onTap: () => _editAccount(a),
            ),
          )),
    ]);
  }

  Widget _finance() {
    final platform = ledger.fold<num>(0, (sum, e) => sum + number(e['alin'] ?? e['admin']));
    final receivables = ledger.fold<num>(0, (sum, e) => sum + number(e['collector_debt']));
    return _scroll([
      const Text('المالية والتسويات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _metric('ربح المنصة', money(platform), Icons.trending_up_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _metric('إجمالي الذمم', money(receivables), Icons.account_balance_wallet_rounded)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(child: Text('آخر التسويات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        FilledButton.icon(onPressed: _recordSettlement, icon: const Icon(Icons.add_card_rounded), label: const Text('تسوية')),
      ]),
      const SizedBox(height: 8),
      if (settlements.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('لا توجد تسويات'))))
      else
        ...settlements.take(60).map((s) => Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF143B68)),
                title: Text('${s['receipt_number'] ?? s['id']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${_roleLabel('${s['party_role']}')} • ${s['party_id']}\n${_date(s['created_at'])} • ${s['payment_method'] ?? ''}'),
                isThreeLine: true,
                trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
              ),
            )),
    ]);
  }

  Widget _catalog() {
    return _scroll([
      const Text('الملازم والمنتجات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Text('الملازم (${booklets.where((e) => e['deleted_at'] == null).length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...booklets.where((e) => e['deleted_at'] == null).take(80).map((b) => Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF143B68)),
              title: Text('${b['title'] ?? 'ملزمة'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${b['subject'] ?? ''} • ${b['grade'] ?? ''}\nالسعر: ${money(b['price'])}'),
              isThreeLine: true,
              trailing: Chip(label: Text((b['published'] == true || b['is_published'] == true) ? 'منشورة' : '${b['publish_status'] ?? b['status'] ?? 'مراجعة'}')),
            ),
          )),
      const SizedBox(height: 14),
      Text('المنتجات (${products.where((e) => e['deleted_at'] == null).length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...products.where((e) => e['deleted_at'] == null).take(80).map((p) => Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_rounded, color: Color(0xFF143B68)),
              title: Text('${p['name'] ?? p['title'] ?? 'منتج'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${p['category'] ?? p['type'] ?? ''}\nالسعر: ${money(p['sale_price'] ?? p['price'])} • المخزون: ${p['stock'] ?? 0}'),
              isThreeLine: true,
              trailing: Chip(label: Text('${p['status']}' == 'active' ? 'فعال' : '${p['status'] ?? '—'}')),
            ),
          )),
    ]);
  }

  Future<void> _assignCourier(Map<String, dynamic> order) async {
    if (!isDeliveryOrder(order)) {
      _snack('طلبات المكتبة تذهب مباشرة إلى المكتبة المختارة ولا تحتاج تعيين');
      return;
    }
    final courierItems = couriers.where((e) => '${e['status']}' == 'active').toList();
    if (courierItems.isEmpty) {
      _snack('لا يوجد مندوب فعّال حالياً');
      return;
    }
    String? courierId = '${order['courier_id'] ?? order['delegate_id'] ?? ''}'.isEmpty ? null : '${order['courier_id'] ?? order['delegate_id']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: Text(number(order['_item_count']) > 1 ? 'تعيين مندوب للطلب كامل' : 'تعيين مندوب'),
        content: DropdownButtonFormField<String?>(
          initialValue: courierId,
          decoration: const InputDecoration(labelText: 'المندوب'),
          items: [const DropdownMenuItem<String?>(value: null, child: Text('اختر المندوب')), ...courierItems.map((e) => DropdownMenuItem<String?>(value: '${e['id']}', child: Text('${e['name']}')))],
          onChanged: (v) => setLocal(() => courierId = v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: courierId == null ? null : () => Navigator.pop(context, true), child: const Text('تعيين')),
        ],
      )),
    );
    if (ok != true || courierId == null) return;
    try {
      await widget.repository.adminAssignOrder('${order['id']}', courierId: courierId);
      await load();
      _snack(number(order['_item_count']) > 1 ? 'تم تعيين المندوب لكل مواد الطلب' : 'تم تعيين المندوب');
    } catch (e) { _snack('$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _changeOrderStatus(Map<String, dynamic> order) async {
    const statuses = ['processing', 'ready', 'completed', 'delivered', 'cancelled'];
    String value = '${order['status']}';
    if (!statuses.contains(value)) value = 'processing';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير حالة الطلب'),
        content: StatefulBuilder(builder: (context, setLocal) => DropdownButtonFormField<String>(
          initialValue: value,
          items: statuses.map((e) => DropdownMenuItem(value: e, child: Text(_status(e)))).toList(),
          onChanged: (v) { if (v != null) setLocal(() => value = v); },
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, value), child: const Text('تأكيد'))],
      ),
    );
    if (selected == null) return;
    try {
      await widget.repository.adminTransitionOrder('${order['id']}', selected);
      await load();
      _snack('تم تحديث الطلب');
    } catch (e) { _snack('$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _createAccount() async {
    final result = await _accountDialog();
    if (result == null) return;
    try {
      await widget.repository.adminCreateAccount(result);
      await load();
      _snack('تم إنشاء الحساب');
    } catch (e) { _snack('$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _editAccount(Map<String, dynamic> account) async {
    final result = await _accountDialog(existing: account);
    if (result == null) return;
    try {
      await widget.repository.adminUpdateAccount('${account['id']}', result);
      await load();
      _snack('تم تحديث الحساب');
    } catch (e) { _snack('$e'.replaceFirst('Exception: ', '')); }
  }

  Future<Map<String, dynamic>?> _accountDialog({Map<String, dynamic>? existing}) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final username = TextEditingController(text: '${existing?['username'] ?? ''}');
    final password = TextEditingController();
    final phone = TextEditingController(text: '${existing?['phone'] ?? ''}');
    final area = TextEditingController(text: '${existing?['area'] ?? ''}');
    String role = '${existing?['role'] ?? 'teacher'}';
    if (!['teacher', 'library', 'courier', 'printer', 'accountant'].contains(role)) role = 'teacher';
    String status = '${existing?['status'] ?? 'active'}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: Text(existing == null ? 'إضافة حساب' : 'تعديل الحساب'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 8),
          TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم الدخول')),
          const SizedBox(height: 8),
          TextField(controller: password, obscureText: true, decoration: InputDecoration(labelText: existing == null ? 'كلمة المرور' : 'كلمة مرور جديدة (اختياري)')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(labelText: 'نوع الحساب'), items: const [
            DropdownMenuItem(value: 'teacher', child: Text('مدرس')),
            DropdownMenuItem(value: 'library', child: Text('مكتبة')),
            DropdownMenuItem(value: 'courier', child: Text('مندوب')),
            DropdownMenuItem(value: 'printer', child: Text('مطبعة')),
            DropdownMenuItem(value: 'accountant', child: Text('حسابات')),
          ], onChanged: (v) { if (v != null) setLocal(() => role = v); }),
          const SizedBox(height: 8),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
          const SizedBox(height: 8),
          TextField(controller: area, decoration: const InputDecoration(labelText: 'المنطقة')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'الحالة'), items: const [
            DropdownMenuItem(value: 'active', child: Text('فعال')),
            DropdownMenuItem(value: 'inactive', child: Text('غير فعال')),
            DropdownMenuItem(value: 'pending', child: Text('معلق')),
          ], onChanged: (v) { if (v != null) setLocal(() => status = v); }),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            final map = <String, dynamic>{
              'name': name.text.trim(), 'username': username.text.trim(), 'role': role, 'phone': phone.text.trim(), 'area': area.text.trim(), 'status': status,
            };
            if (password.text.isNotEmpty) map['password'] = password.text;
            Navigator.pop(context, map);
          }, child: const Text('حفظ')),
        ],
      )),
    );
    name.dispose(); username.dispose(); password.dispose(); phone.dispose(); area.dispose();
    return result;
  }

  Future<void> _recordSettlement() async {
    final parties = accounts.where((e) => ['teacher', 'library', 'courier', 'printer'].contains('${e['role']}') && e['deleted_at'] == null).toList();
    if (parties.isEmpty) return;
    String partyId = '${parties.first['id']}';
    String role = '${parties.first['role']}';
    final amount = TextEditingController();
    final note = TextEditingController();
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: const Text('تثبيت تسوية'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: partyId,
            decoration: const InputDecoration(labelText: 'الحساب'),
            items: parties.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['name']} — ${_roleLabel('${e['role']}')}'))).toList(),
            onChanged: (v) { if (v != null) setLocal(() { partyId = v; role = '${parties.firstWhere((e) => '${e['id']}' == v)['role']}'; }); },
          ),
          const SizedBox(height: 8),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'طريقة الدفع'), items: const [
            DropdownMenuItem(value: 'cash', child: Text('نقدي')),
            DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
          ], onChanged: (v) { if (v != null) setLocal(() => method = v); }),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تثبيت'))],
      )),
    );
    if (ok == true) {
      try {
        final value = num.tryParse(amount.text.trim()) ?? 0;
        if (value <= 0) throw Exception('أدخل مبلغ صحيح');
        await widget.repository.adminRecordSettlement(role: role, partyId: partyId, amount: value, method: method, note: note.text);
        await load();
        _snack('تم تثبيت التسوية');
      } catch (e) { _snack('$e'.replaceFirst('Exception: ', '')); }
    }
    amount.dispose(); note.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [SizedBox(width: 82, child: Text(label, style: TextStyle(color: Colors.grey.shade600))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );

  static String _date(dynamic value) {
    final s = '${value ?? ''}';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  static String _status(String s) => switch (s) {
        'new' => 'جديد',
        'pending' || 'pending_admin' => 'قيد الانتظار',
        'assigned' => 'معيّن',
        'accepted' => 'مقبول',
        'processing' || 'printing' => 'قيد التجهيز',
        'ready' => 'جاهز',
        'picked_up' => 'تم الاستلام',
        'out_for_delivery' => 'قيد التوصيل',
        'completed' || 'delivered' => 'مكتمل',
        'cancelled' => 'ملغي',
        'rejected' => 'مرفوض',
        _ => s,
      };

  static String _roleLabel(String r) => switch (r) {
        'admin' => 'إدارة',
        'accountant' => 'حسابات',
        'teacher' => 'مدرس',
        'library' => 'مكتبة',
        'courier' || 'delegate' => 'مندوب',
        'printer' => 'مطبعة',
        _ => r,
      };

  static IconData _roleIcon(String r) => switch (r) {
        'teacher' => Icons.school_rounded,
        'library' => Icons.store_rounded,
        'courier' || 'delegate' => Icons.delivery_dining_rounded,
        'printer' => Icons.print_rounded,
        'accountant' => Icons.calculate_rounded,
        _ => Icons.person_rounded,
      };
}
