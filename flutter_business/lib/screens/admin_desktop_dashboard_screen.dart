import 'package:flutter/material.dart';

import '../data/business_finance_repository.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/grouped_order_receipt_card.dart';
import 'admin_finance_v2_screen.dart';

class AdminDesktopDashboardScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const AdminDesktopDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<AdminDesktopDashboardScreen> createState() => _AdminDesktopDashboardScreenState();
}

class _AdminDesktopDashboardScreenState extends State<AdminDesktopDashboardScreen> {
  int section = 0;
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};
  Map<String, dynamic> finance = {};
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> couriers = [];
  List<Map<String, dynamic>> booklets = [];
  List<Map<String, dynamic>> products = [];
  String orderFilter = 'active';
  String accountFilter = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  num _n(dynamic value) => num.tryParse('$value') ?? 0;
  String _money(dynamic value) => '${_n(value).round()} د.ع';

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
        widget.repository.adminFinanceOverviewV2(),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(values[0] as Map);
        orders = (values[1] as List).cast<Map<String, dynamic>>();
        accounts = (values[2] as List).cast<Map<String, dynamic>>();
        couriers = (values[3] as List).cast<Map<String, dynamic>>();
        booklets = (values[4] as List).cast<Map<String, dynamic>>();
        products = (values[5] as List).cast<Map<String, dynamic>>();
        finance = Map<String, dynamic>.from(values[6] as Map);
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _closed(Map<String, dynamic> o) => const ['completed', 'delivered', 'cancelled', 'rejected'].contains('${o['status']}');
  bool _delivery(Map<String, dynamic> o) {
    final f = '${o['fulfillment_type']}'.toLowerCase();
    final d = '${o['delivery_type']}'.toLowerCase();
    return f == 'home_delivery' || f == 'courier' || f == 'delivery' || d == 'courier';
  }

  List<Map<String, dynamic>> get groupedOrders => groupOrdersForReceipts(orders);

  bool _groupClosed(Map<String, dynamic> order) {
    final items = (order['_items'] as List).cast<Map<String, dynamic>>();
    return items.every((row) => const ['completed', 'delivered', 'cancelled', 'rejected'].contains('${row['status']}'));
  }

  List<Map<String, dynamic>> get visibleOrders {
    final grouped = groupedOrders;
    if (orderFilter == 'all') return grouped;
    if (orderFilter == 'done') return grouped.where(receiptGroupCompleted).toList();
    if (orderFilter == 'cancelled') return grouped.where((e) => ((e['_items'] as List).cast<Map<String, dynamic>>()).every((row) => const ['cancelled', 'rejected'].contains('${row['status']}'))).toList();
    return grouped.where((e) => !_groupClosed(e)).toList();
  }

  List<Map<String, dynamic>> get visibleAccounts {
    final alive = accounts.where((e) => e['deleted_at'] == null);
    if (accountFilter == 'all') return alive.toList();
    return alive.where((e) => '${e['role']}' == accountFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Row(
        textDirection: TextDirection.rtl,
        children: [
          _sidebar(),
          Expanded(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : error != null
                          ? _errorView()
                          : _sectionBody(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    final items = const [
      (Icons.dashboard_rounded, 'الرئيسية'),
      (Icons.receipt_long_rounded, 'الطلبات'),
      (Icons.groups_rounded, 'الحسابات'),
      (Icons.account_balance_wallet_rounded, 'المالية'),
      (Icons.inventory_2_rounded, 'المحتوى'),
      (Icons.receipt_long_rounded, 'الوصولات'),
    ];
    return Container(
      width: 245,
      color: const Color(0xFF143B68),
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white,
              child: Icon(Icons.business_center_rounded, color: Color(0xFF143B68), size: 28),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('آلين للأعمال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              Text('لوحة الإدارة', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
          const SizedBox(height: 28),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: section == i ? Colors.white.withValues(alpha: .14) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => section = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                    child: Row(children: [
                      Icon(items[i].$1, color: Colors.white, size: 21),
                      const SizedBox(width: 11),
                      Text(items[i].$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ),
          const Spacer(),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Text(widget.account.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          Text(widget.account.role == 'accountant' ? 'حسابات' : 'مدير', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onLogout,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 78,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titleForSection(), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
              Text('مرحباً ${widget.account.name}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        IconButton(tooltip: 'تحديث', onPressed: load, icon: const Icon(Icons.refresh_rounded)),
      ]),
    );
  }

  String _titleForSection() => const ['الرئيسية', 'إدارة الطلبات', 'إدارة الحسابات', 'المالية والتسويات', 'المحتوى', 'الوصولات'][section];

  Widget _sectionBody() {
    switch (section) {
      case 1:
        return _ordersPage();
      case 2:
        return _accountsPage();
      case 3:
        return _financePage();
      case 4:
        return _catalogPage();
      case 5:
        return _receiptsPage();
      default:
        return _homePage();
    }
  }

  Widget _page(List<Widget> children) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ],
      );

  Widget _homePage() {
    final cards = [
      ('الطلبات', '${summary['orders'] ?? orders.length}', Icons.receipt_long_rounded),
      ('تحتاج متابعة', '${summary['new_orders'] ?? 0}', Icons.notifications_active_rounded),
      ('إجمالي المبيعات', _money(summary['total_sales']), Icons.payments_rounded),
      ('ربح المنصة', _money(finance['platform_profit'] ?? summary['platform_profit']), Icons.trending_up_rounded),
      ('المكتبات', '${summary['libraries'] ?? 0}', Icons.store_rounded),
      ('المندوبون', '${summary['couriers'] ?? 0}', Icons.delivery_dining_rounded),
      ('المطابع', '${summary['printers'] ?? 0}', Icons.print_rounded),
      ('المدرسون', '${summary['teachers'] ?? 0}', Icons.school_rounded),
    ];
    return _page([
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إدارة أعمال آلين من شاشة واحدة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text('متابعة الطلبات والحسابات والمالية والمحتوى بصورة أوضح على الكمبيوتر.', style: TextStyle(color: Colors.white70)),
          ])),
          Icon(Icons.space_dashboard_rounded, color: Colors.white, size: 60),
        ]),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, c) {
        final count = c.maxWidth >= 1250 ? 4 : c.maxWidth >= 850 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: cards.map((e) => _metric(e.$1, e.$2, e.$3)).toList(),
        );
      }),
      const SizedBox(height: 22),
      _sectionHeader('آخر الطلبات', action: TextButton(onPressed: () => setState(() => section = 1), child: const Text('عرض الكل'))),
      const SizedBox(height: 10),
      _ordersTable(groupedOrders.take(8).toList()),
    ]);
  }

  Widget _metric(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF2))),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFFEAF2FB), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: const Color(0xFF143B68)),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  Widget _ordersPage() => _page([
        Row(children: [
          Expanded(child: _sectionHeader('الطلبات (${visibleOrders.length})')),
          SizedBox(
            width: 470,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'active', label: Text('الحالية')),
                ButtonSegment(value: 'done', label: Text('المكتملة')),
                ButtonSegment(value: 'cancelled', label: Text('الملغاة')),
                ButtonSegment(value: 'all', label: Text('الكل')),
              ],
              selected: {orderFilter},
              onSelectionChanged: (v) => setState(() => orderFilter = v.first),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _ordersTable(visibleOrders),
      ]);

  Widget _ordersTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return _empty('لا توجد طلبات');
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('رقم الطلب')),
            DataColumn(label: Text('الطالب')),
            DataColumn(label: Text('الطلب')),
            DataColumn(label: Text('المنطقة')),
            DataColumn(label: Text('الإجمالي')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الإجراء')),
          ],
          rows: rows.map((o) => DataRow(cells: [
                DataCell(Text('${o['order_number'] ?? o['id']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                DataCell(Text('${o['student_name'] ?? '—'}')),
                DataCell(SizedBox(width: 220, child: Text('${o['title'] ?? 'طلب'}', overflow: TextOverflow.ellipsis))),
                DataCell(Text('${o['delivery_area'] ?? '—'}')),
                DataCell(Text(_money(o['total']))),
                DataCell(_statusChip('${o['status']}')),
                DataCell(PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'courier') _assignCourier(o);
                    if (value == 'status') _changeStatus(o);
                  },
                  itemBuilder: (_) => [
                    if (_delivery(o) && !_closed(o)) const PopupMenuItem(value: 'courier', child: Text('تعيين مندوب')),
                    if (!_closed(o)) const PopupMenuItem(value: 'status', child: Text('تغيير الحالة')),
                  ],
                )),
              ])).toList(),
        ),
      ),
    );
  }

  Widget _receiptsPage() {
    final completed = groupedOrders.where(receiptGroupCompleted).toList();
    return _page([
      _sectionHeader('الوصولات (${completed.length})'),
      const SizedBox(height: 6),
      const Text('وصل واحد لكل طلب مكتمل مع جميع المواد والتوصيل والإجمالي.'),
      const SizedBox(height: 14),
      if (completed.isEmpty)
        _empty('لا توجد وصولات مكتملة')
      else
        ...completed.map((order) => GroupedOrderReceiptCard(order: order, courierName: _courierName('${order['courier_id'] ?? order['delegate_id'] ?? ''}'))),
    ]);
  }

  String _courierName(String id) {
    if (id.trim().isEmpty) return '';
    for (final courier in couriers) {
      if ('${courier['id']}' == id) return '${courier['name'] ?? id}';
    }
    return id;
  }

  Widget _accountsPage() => _page([
        Row(children: [
          Expanded(child: _sectionHeader('الحسابات (${visibleAccounts.length})')),
          DropdownButton<String>(
            value: accountFilter,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('كل الحسابات')),
              DropdownMenuItem(value: 'teacher', child: Text('المدرسون')),
              DropdownMenuItem(value: 'library', child: Text('المكتبات')),
              DropdownMenuItem(value: 'courier', child: Text('المندوبون')),
              DropdownMenuItem(value: 'printer', child: Text('المطابع')),
              DropdownMenuItem(value: 'accountant', child: Text('الحسابات')),
            ],
            onChanged: (v) => v == null ? null : setState(() => accountFilter = v),
          ),
        ]),
        const SizedBox(height: 14),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('الاسم')),
                DataColumn(label: Text('النوع')),
                DataColumn(label: Text('اسم الدخول')),
                DataColumn(label: Text('الهاتف')),
                DataColumn(label: Text('المنطقة')),
                DataColumn(label: Text('الحالة')),
              ],
              rows: visibleAccounts.map((a) => DataRow(cells: [
                    DataCell(Text('${a['name'] ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w800))),
                    DataCell(Text(_role('${a['role']}'))),
                    DataCell(Text('${a['username'] ?? '—'}')),
                    DataCell(Text('${a['phone'] ?? '—'}')),
                    DataCell(Text('${a['area'] ?? '—'}')),
                    DataCell(Chip(label: Text('${a['status']}' == 'active' ? 'فعال' : 'غير فعال'))),
                  ])).toList(),
            ),
          ),
        ),
      ]);

  Widget _financePage() => _page([
        LayoutBuilder(builder: (context, c) {
          final cards = [
            ('ربح المنصة', finance['platform_profit'], Icons.trending_up_rounded),
            ('مستحق المدرسين', finance['teacher_remaining'], Icons.school_rounded),
            ('ذمم التحصيل', finance['collector_remaining'], Icons.account_balance_wallet_rounded),
            ('مستحق توريد الكتب', finance['book_supplier_pending'], Icons.menu_book_rounded),
          ];
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: c.maxWidth > 1000 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.0,
            children: cards.map((e) => _metric(e.$1, _money(e.$2), e.$3)).toList(),
          );
        }),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المركز المالي V2', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('التسويات، الأرصدة، عكس السندات، وحسابات الموردين من المصدر الرسمي.'),
              ])),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminFinanceV2Screen(repository: widget.repository))),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('فتح المركز المالي'),
              ),
            ]),
          ),
        ),
      ]);

  Widget _catalogPage() => _page([
        LayoutBuilder(builder: (context, c) {
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: c.maxWidth > 900 ? 3 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 2.5,
            children: [
              _metric('الملازم', '${booklets.where((e) => e['deleted_at'] == null).length}', Icons.menu_book_rounded),
              _metric('المنتجات', '${products.where((e) => e['deleted_at'] == null).length}', Icons.inventory_2_rounded),
              _metric('المندوبون', '${couriers.length}', Icons.delivery_dining_rounded),
            ],
          );
        }),
        const SizedBox(height: 20),
        _sectionHeader('آخر الملازم'),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: booklets.take(8).map((b) => ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text('${b['title'] ?? 'ملزمة'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${b['subject'] ?? ''} • ${_money(b['price'])}'),
                  trailing: Chip(label: Text('${b['published'] == true || b['is_published'] == true ? 'منشورة' : 'غير منشورة'}')),
                )).toList(),
          ),
        ),
      ]);

  Widget _sectionHeader(String title, {Widget? action}) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF143B68)))),
        if (action != null) action,
      ]);

  Widget _empty(String text) => Card(child: Padding(padding: const EdgeInsets.all(36), child: Center(child: Text(text))));

  Widget _statusChip(String status) {
    return Chip(label: Text(_status(status)));
  }

  String _status(String s) {
    switch (s) {
      case 'new': return 'جديد';
      case 'pending_admin': return 'بانتظار التعيين';
      case 'assigned': return 'بانتظار القبول';
      case 'accepted': return 'مقبول';
      case 'picked_up': return 'تم الاستلام';
      case 'out_for_delivery': return 'في الطريق';
      case 'processing': return 'قيد التنفيذ';
      case 'printing': return 'قيد الطباعة';
      case 'ready': return 'جاهز';
      case 'completed':
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغي';
      case 'rejected': return 'مرفوض';
      default: return s.isEmpty ? '—' : s;
    }
  }

  String _role(String role) {
    switch (role) {
      case 'teacher': return 'مدرس';
      case 'library': return 'مكتبة';
      case 'courier': return 'مندوب';
      case 'printer': return 'مطبعة';
      case 'accountant': return 'حسابات';
      case 'admin': return 'مدير';
      default: return role;
    }
  }

  Future<void> _assignCourier(Map<String, dynamic> order) async {
    final active = couriers.where((c) => '${c['status']}' == 'active').toList();
    if (active.isEmpty) {
      _snack('لا يوجد مندوب فعال');
      return;
    }
    String? selected = '${order['courier_id'] ?? order['delegate_id'] ?? ''}'.trim();
    if (!active.any((e) => '${e['id']}' == selected)) selected = null;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعيين مندوب'),
        content: StatefulBuilder(builder: (context, setLocal) => DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'المندوب'),
              items: active.map((c) => DropdownMenuItem(value: '${c['id']}', child: Text('${c['name'] ?? c['username'] ?? c['id']}'))).toList(),
              onChanged: (v) => setLocal(() => selected = v),
            )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: selected == null ? null : () => Navigator.pop(context, selected), child: const Text('تعيين')),
        ],
      ),
    );
    if (result == null) return;
    try {
      await widget.repository.adminAssignOrder('${order['id']}', courierId: result);
      await load();
      _snack('تم تعيين المندوب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> order) async {
    const statuses = ['new', 'pending_admin', 'assigned', 'accepted', 'picked_up', 'out_for_delivery', 'processing', 'printing', 'ready', 'completed', 'cancelled', 'rejected'];
    String selected = statuses.contains('${order['status']}') ? '${order['status']}' : 'processing';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير حالة الطلب'),
        content: StatefulBuilder(builder: (context, setLocal) => DropdownButtonFormField<String>(
              initialValue: selected,
              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(_status(s)))).toList(),
              onChanged: (v) { if (v != null) setLocal(() => selected = v); },
            )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('حفظ')),
        ],
      ),
    );
    if (result == null || result == '${order['status']}') return;
    String reason = '';
    if (result == 'cancelled' || result == 'rejected') {
      final c = TextEditingController();
      final r = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('سبب الإلغاء/الرفض'),
          content: TextField(controller: c, decoration: const InputDecoration(labelText: 'السبب')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
            FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('تأكيد')),
          ],
        ),
      );
      c.dispose();
      if (r == null || r.length < 2) return;
      reason = r;
    }
    try {
      await widget.repository.adminTransitionOrder('${order['id']}', result, reason: reason);
      await load();
      _snack('تم تحديث الحالة');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error ?? 'حدث خطأ', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
        ]),
      );

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
