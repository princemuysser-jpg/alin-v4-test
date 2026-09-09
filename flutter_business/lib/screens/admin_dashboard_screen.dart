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

  bool isClosed(Map<String, dynamic> o) => ['completed', 'delivered', 'cancelled', 'rejected'].contains('${o['status']}');

  List<Map<String, dynamic>> get visibleOrders {
    if (orderFilter == 'all') return orders;
    if (orderFilter == 'done') return orders.where((e) => ['completed', 'delivered'].contains('${e['status']}')).toList();
    if (orderFilter == 'cancelled') return orders.where((e) => ['cancelled', 'rejected'].contains('${e['status']}')).toList();
    return orders.where((e) => !isClosed(e)).toList();
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
      ...orders.take(5).map(_orderCard),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${o['order_number'] ?? o['id']}', style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('${o['title'] ?? 'طلب'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ])),
            Chip(label: Text(_status('${o['status']}'))),
          ]),
          const Divider(),
          _line('الطالب', '${o['student_name'] ?? '—'}'),
          _line('الهاتف', '${o['student_phone'] ?? '—'}'),
          _line('المنطقة', '${o['delivery_area'] ?? '—'}'),
          _line('الإجمالي', money(o['total'])),
          if ('${o['courier_id'] ?? o['delegate_id'] ?? ''}'.isNotEmpty) _line('المندوب', '${o['courier_id'] ?? o['delegate_id']}'),
          if ('${o['library_id'] ?? o['pickup_library_id'] ?? ''}'.isNotEmpty) _line('المكتبة', '${o['library_id'] ?? o['pickup_library_id']}'),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => _assignOrder(o), icon: const Icon(Icons.assignment_ind_rounded), label: const Text('تعيين')),
            if (!isClosed(o)) OutlinedButton.icon(onPressed: () => _changeOrderStatus(o), icon: const Icon(Icons.sync_alt_rounded), label: const Text('تغيير الحالة')),
          ]),
        ]),
      ),
    );
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

  Future<void> _assignOrder(Map<String, dynamic> order) async {
    final courierItems = couriers.where((e) => '${e['status']}' == 'active').toList();
    final libraryItems = accounts.where((e) => '${e['role']}' == 'library' && '${e['status']}' == 'active' && e['deleted_at'] == null).toList();
    String? courierId = '${order['courier_id'] ?? order['delegate_id'] ?? ''}'.isEmpty ? null : '${order['courier_id'] ?? order['delegate_id']}';
    String? libraryId = '${order['library_id'] ?? order['pickup_library_id'] ?? ''}'.isEmpty ? null : '${order['library_id'] ?? order['pickup_library_id']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: const Text('تعيين الطلب'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String?>(
            value: courierId,
            decoration: const InputDecoration(labelText: 'المندوب'),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('بدون مندوب')), ...courierItems.map((e) => DropdownMenuItem<String?>(value: '${e['id']}', child: Text('${e['name']}')))],
            onChanged: (v) => setLocal(() => courierId = v),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: libraryId,
            decoration: const InputDecoration(labelText: 'المكتبة'),
            items: [const DropdownMenuItem<String?>(value: null, child: Text('بدون مكتبة')), ...libraryItems.map((e) => DropdownMenuItem<String?>(value: '${e['id']}', child: Text('${e['name']}')))],
            onChanged: (v) => setLocal(() => libraryId = v),
          ),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ'))],
      )),
    );
    if (ok != true) return;
    try {
      await widget.repository.adminAssignOrder('${order['id']}', courierId: courierId, libraryId: libraryId);
      await load();
      _snack('تم تعيين الطلب');
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
          value: value,
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
          DropdownButtonFormField<String>(value: role, decoration: const InputDecoration(labelText: 'نوع الحساب'), items: const [
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
          DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'الحالة'), items: const [
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
            value: partyId,
            decoration: const InputDecoration(labelText: 'الحساب'),
            items: parties.map((e) => DropdownMenuItem(value: '${e['id']}', child: Text('${e['name']} — ${_roleLabel('${e['role']}')}'))).toList(),
            onChanged: (v) { if (v != null) setLocal(() { partyId = v; role = '${parties.firstWhere((e) => '${e['id']}' == v)['role']}'; }); },
          ),
          const SizedBox(height: 8),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'طريقة الدفع'), items: const [
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
