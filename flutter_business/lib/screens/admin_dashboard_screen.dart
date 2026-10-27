import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_role_navigation.dart';
import '../widgets/grouped_order_receipt_card.dart';
import 'business_order_details_screen.dart';

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
  String orderSearch = '';
  final TextEditingController orderSearchController = TextEditingController();
  String accountFilter = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    orderSearchController.dispose();
    super.dispose();
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
    return items.every(
      (row) => [
        'completed',
        'delivered',
        'cancelled',
        'rejected',
      ].contains('${row['status']}'),
    );
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
      final anchor = items.firstWhere(
        (row) =>
            number(row['delivery_fee']) > 0 || number(row['courier_fee']) > 0,
        orElse: () => items.first,
      );
      final statuses = items.map((row) => '${row['status']}').toSet();
      result.add({
        ...anchor,
        '_checkout_key': entry.key,
        '_items': items,
        '_item_count': items.length,
        '_qty_count': items.fold<num>(
          0,
          (sum, row) =>
              sum + (number(row['qty']) <= 0 ? 1 : number(row['qty'])),
        ),
        'total': items.fold<num>(0, (sum, row) => sum + number(row['total'])),
        'delivery_fee': items.fold<num>(
          0,
          (sum, row) => sum + number(row['delivery_fee']),
        ),
        'courier_fee': items.fold<num>(
          0,
          (sum, row) =>
              sum +
              number(
                row['courier_fee'] ??
                    row['courier_profit'] ??
                    row['delegate_profit'],
              ),
        ),
        '_mixed_status': statuses.length > 1,
      });
    }
    result.sort(
      (a, b) => '${b['created_at'] ?? b['updated_at'] ?? ''}'.compareTo(
        '${a['created_at'] ?? a['updated_at'] ?? ''}',
      ),
    );
    return result;
  }

  bool isDeliveryOrder(Map<String, dynamic> order) {
    final fulfillment = '${order['fulfillment_type']}'.toLowerCase();
    final deliveryType = '${order['delivery_type']}'.toLowerCase();
    return fulfillment == 'home_delivery' ||
        fulfillment == 'courier' ||
        fulfillment == 'delivery' ||
        deliveryType == 'courier';
  }

  List<Map<String, dynamic>> get groupedOrders => groupOrders(orders);

  List<Map<String, dynamic>> get visibleOrders {
    Iterable<Map<String, dynamic>> rows = groupedOrders;

    bool hasAnyStatus(Map<String, dynamic> order, Set<String> statuses) {
      final items =
          ((order['_items'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final source = items.isEmpty ? <Map<String, dynamic>>[order] : items;
      return source.any((row) => statuses.contains('${row['status']}'));
    }

    bool allStatuses(Map<String, dynamic> order, Set<String> statuses) {
      final items =
          ((order['_items'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final source = items.isEmpty ? <Map<String, dynamic>>[order] : items;
      return source.isNotEmpty &&
          source.every((row) => statuses.contains('${row['status']}'));
    }

    switch (orderFilter) {
      case 'new':
        rows = rows.where(
          (e) => hasAnyStatus(e, const {'new', 'pending', 'pending_admin'}),
        );
        break;
      case 'processing':
        rows = rows.where(
          (e) => hasAnyStatus(e, const {
            'assigned',
            'accepted',
            'processing',
            'printing',
            'picked_up',
            'out_for_delivery',
          }),
        );
        break;
      case 'ready':
        rows = rows.where((e) => hasAnyStatus(e, const {'ready'}));
        break;
      case 'done':
        rows = rows.where(
          (e) => allStatuses(e, const {'completed', 'delivered', 'done'}),
        );
        break;
      case 'cancelled':
        rows = rows.where(
          (e) => allStatuses(e, const {'cancelled', 'rejected', 'canceled'}),
        );
        break;
      case 'active':
        rows = rows.where((e) => !isClosed(e));
        break;
      case 'all':
      default:
        break;
    }

    final query = orderSearch.trim().toLowerCase();
    if (query.isEmpty) return rows.toList();

    return rows.where((order) {
      final items =
          ((order['_items'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final searchable = <String>[
        '${order['order_number'] ?? ''}',
        '${order['id'] ?? ''}',
        '${order['student_name'] ?? ''}',
        '${order['student_phone'] ?? ''}',
        '${order['delivery_area'] ?? ''}',
        '${order['title'] ?? ''}',
        ...items.map((e) => '${e['title'] ?? ''}'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get visibleAccounts {
    if (accountFilter == 'all')
      return accounts.where((e) => e['deleted_at'] == null).toList();
    return accounts
        .where(
          (e) => e['deleted_at'] == null && '${e['role']}' == accountFilter,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _home(),
      _orders(),
      _accounts(),
      _finance(),
      _catalog(),
      _receipts(),
    ];
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      drawer: BusinessRoleNavigationDrawer(
        repository: widget.repository,
        account: widget.account,
        onLogout: widget.onLogout,
        adminSection: index,
        onAdminSectionChanged: (value) {
          if (!mounted) return;
          setState(() => index = value);
        },
      ),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account.role == 'accountant'
                  ? 'لوحة الحسابات'
                  : 'لوحة إدارة آلين',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            Text(
              widget.account.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
            ],
          ),
        ],
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
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: load,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(onRefresh: load, child: pages[index]),
      bottomNavigationBar: mobile
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_rounded),
                  label: 'الطلبات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_rounded),
                  label: 'الحسابات',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'المالية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_rounded),
                  label: 'المحتوى',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_rounded),
                  label: 'الوصولات',
                ),
              ],
            ),
    );
  }

  Widget _scroll(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);

  Widget _home() {
    final grouped = groupedOrders;
    final newCount = grouped.where((o) => _groupHasStatus(o, const {
      'new',
      'pending_admin',
      'assigned',
    })).length;
    final printingCount = grouped.where((o) => _groupHasStatus(o, const {
      'accepted',
      'processing',
      'printing',
      'picked_up',
      'out_for_delivery',
    })).length;
    final readyCount = grouped.where((o) => _groupHasStatus(o, const {
      'ready',
    })).length;
    final deliveredCount = grouped.where(_groupDelivered).length;
    final cancelledCount = grouped.where(_groupCancelled).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final metricColumns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 700
            ? 3
            : 2;
        final sectionColumns = constraints.maxWidth >= 900 ? 3 : 2;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            wide ? 20 : 14,
            16,
            wide ? 20 : 14,
            28,
          ),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _sectionTitle('حالة الطلبات اليوم', 'نظرة سريعة على حركة الطلبات'),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: metricColumns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 1.9 : 1.35,
              children: [
                _metricCard(
                  'طلب جديد',
                  '${newCount}',
                  Icons.shopping_cart_checkout_rounded,
                  const Color(0xFF16A34A),
                  const Color(0xFFE9F9EF),
                ),
                _metricCard(
                  'قيد التنفيذ',
                  '${printingCount}',
                  Icons.print_rounded,
                  const Color(0xFFE58B00),
                  const Color(0xFFFFF4DB),
                ),
                _metricCard(
                  'جاهز',
                  '${readyCount}',
                  Icons.inventory_2_rounded,
                  const Color(0xFF1677FF),
                  const Color(0xFFEAF3FF),
                ),
                _metricCard(
                  'تم التسليم',
                  '${deliveredCount}',
                  Icons.check_circle_rounded,
                  const Color(0xFF6D28D9),
                  const Color(0xFFF1EBFF),
                ),
                _metricCard(
                  'ملغي',
                  '${cancelledCount}',
                  Icons.cancel_rounded,
                  const Color(0xFFE11D48),
                  const Color(0xFFFFEAF0),
                ),
                _metricCard(
                  'كل الطلبات',
                  '${summary['orders'] ?? grouped.length}',
                  Icons.receipt_long_rounded,
                  const Color(0xFF143B68),
                  const Color(0xFFEAF2FB),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('الملخص المالي', 'أهم أرقام المنصة الحالية'),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: metricColumns >= 3 ? 3 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 2.05 : 1.45,
              children: [
                _metricCard(
                  'إجمالي المبيعات',
                  money(summary['total_sales']),
                  Icons.bar_chart_rounded,
                  const Color(0xFF1677FF),
                  const Color(0xFFEAF3FF),
                ),
                _metricCard(
                  'ربح المنصة',
                  money(summary['platform_profit']),
                  Icons.savings_rounded,
                  const Color(0xFF16A34A),
                  const Color(0xFFE9F9EF),
                ),
                _metricCard(
                  'مستحقات المدرسين',
                  money(summary['teacher_remaining']),
                  Icons.school_rounded,
                  const Color(0xFF7C3AED),
                  const Color(0xFFF1EBFF),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle('نشاط المنصة', 'الحسابات الفعالة المرتبطة بالمنصة'),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: metricColumns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 1.9 : 1.35,
              children: [
                _metricCard(
                  'المكتبات',
                  '${summary['libraries'] ?? 0}',
                  Icons.store_rounded,
                  const Color(0xFFDB2777),
                  const Color(0xFFFFEAF5),
                ),
                _metricCard(
                  'المندوبون',
                  '${summary['couriers'] ?? 0}',
                  Icons.delivery_dining_rounded,
                  const Color(0xFF0284C7),
                  const Color(0xFFE8F7FF),
                ),
                _metricCard(
                  'المطابع',
                  '${summary['printers'] ?? 0}',
                  Icons.print_rounded,
                  const Color(0xFF475569),
                  const Color(0xFFF1F5F9),
                ),
                _metricCard(
                  'المدرسون',
                  '${summary['teachers'] ?? 0}',
                  Icons.groups_rounded,
                  const Color(0xFF9333EA),
                  const Color(0xFFF5EBFF),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('الأقسام الرئيسية', 'وصول سريع لأكثر أدوات المدير استخداماً'),
            const SizedBox(height: 10),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: sectionColumns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 2.35 : 1.45,
              children: [
                _quickSection(
                  'الطلبات',
                  'إدارة جميع الطلبات',
                  Icons.receipt_long_rounded,
                  () => setState(() => index = 1),
                ),
                _quickSection(
                  'الحسابات',
                  'المدرسون والمكتبات والمندوبون',
                  Icons.groups_rounded,
                  () => setState(() => index = 2),
                ),
                _quickSection(
                  'المالية',
                  'الذمم والتسويات والأرباح',
                  Icons.account_balance_wallet_rounded,
                  () => setState(() => index = 3),
                ),
                _quickSection(
                  'المحتوى',
                  'الملازم والمنتجات',
                  Icons.inventory_2_rounded,
                  () => setState(() => index = 4),
                ),
                _quickSection(
                  'الوصولات',
                  'وصولات الطلبات المكتملة',
                  Icons.receipt_rounded,
                  () => setState(() => index = 5),
                ),
                Builder(
                  builder: (drawerContext) => _quickSection(
                    'كل الأقسام',
                    'افتح القائمة الجانبية الكاملة',
                    Icons.apps_rounded,
                    () => Scaffold.of(drawerContext).openDrawer(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'آخر الطلبات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => index = 1),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (grouped.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(child: Text('لا توجد طلبات بعد')),
                ),
              )
            else
              ...grouped.take(4).map(_orderCard),
          ],
        );
      },
    );
  }

  bool _groupHasStatus(Map<String, dynamic> order, Set<String> statuses) {
    final raw = order['_items'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[order];
    return items.any((item) => statuses.contains('${item['status']}'));
  }

  bool _groupDelivered(Map<String, dynamic> order) {
    final raw = order['_items'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[order];
    return items.isNotEmpty &&
        items.every(
          (item) => const {
            'completed',
            'delivered',
            'done',
          }.contains('${item['status']}'),
        );
  }

  bool _groupCancelled(Map<String, dynamic> order) {
    final raw = order['_items'];
    final items = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[order];
    return items.isNotEmpty &&
        items.every(
          (item) => const {
            'cancelled',
            'rejected',
          }.contains('${item['status']}'),
        );
  }

  Widget _hero() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF143B68), Color(0xFF255B91)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A143B68),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.space_dashboard_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'مرحباً ${widget.account.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'كل ما تحتاجه لإدارة منصة آلين من مكان واحد',
                style: TextStyle(color: Colors.white70, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Color(0xFF143B68),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12.5,
          color: Color(0xFF667085),
        ),
      ),
    ],
  );

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color accent,
    Color soft,
  ) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3EAF1)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A143B68),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 21),
        ),
        const Spacer(),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF475467),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _quickSection(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EAF1)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FB),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: const Color(0xFF143B68)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF98A2B3),
            ),
          ],
        ),
      ),
    ),
  );


  Widget _metric(String label, String value, IconData icon) => _metricCard(
    label,
    value,
    icon,
    const Color(0xFF143B68),
    const Color(0xFFEAF2FB),
  );


  Widget _orders() {
    final all = groupedOrders;
    int countFor(String filter) {
      final previous = orderFilter;
      orderFilter = filter;
      final count = visibleOrders.length;
      orderFilter = previous;
      return count;
    }

    final activeCount = countFor('active');
    final newCount = countFor('new');
    final processingCount = countFor('processing');
    final readyCount = countFor('ready');
    final doneCount = countFor('done');
    final cancelledCount = countFor('cancelled');

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة الطلبات',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'بحث، فلترة، تعيين مندوب وتحديث حالة الطلب',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${visibleOrders.length} طلب',
                style: const TextStyle(
                  color: Color(0xFF143B68),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: orderSearchController,
          onChanged: (value) => setState(() => orderSearch = value),
          decoration: InputDecoration(
            hintText: 'ابحث برقم الطلب، اسم الطالب، الهاتف أو المنطقة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: orderSearch.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      orderSearchController.clear();
                      setState(() => orderSearch = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE3EAF1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE3EAF1)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _orderFilterChip('الحالية', 'active', activeCount),
              _orderFilterChip('جديد', 'new', newCount),
              _orderFilterChip('قيد التنفيذ', 'processing', processingCount),
              _orderFilterChip('جاهز', 'ready', readyCount),
              _orderFilterChip('مكتمل', 'done', doneCount),
              _orderFilterChip('ملغي', 'cancelled', cancelledCount),
              _orderFilterChip('الكل', 'all', all.length),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (visibleOrders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3EAF1)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 42,
                  color: Color(0xFF98A2B3),
                ),
                SizedBox(height: 10),
                Text(
                  'لا توجد طلبات مطابقة',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF143B68),
                  ),
                ),
              ],
            ),
          )
        else
          ...visibleOrders.map(_orderCard),
      ],
    );
  }

  Widget _orderFilterChip(String label, String value, int count) {
    final selected = orderFilter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => orderFilter = value),
        label: Text('$label  $count'),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : const Color(0xFF143B68),
        ),
        selectedColor: const Color(0xFF143B68),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected
              ? const Color(0xFF143B68)
              : const Color(0xFFE3EAF1),
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final deliveryOrder = isDeliveryOrder(o);
    final status = '${o['status'] ?? ''}';
    final itemCount = number(o['_item_count']).round();
    final items =
        ((o['_items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3EAF1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openOrderDetails(o),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: deliveryOrder
                          ? const Color(0xFFEAF3FF)
                          : const Color(0xFFE9F9EF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      deliveryOrder
                          ? Icons.delivery_dining_rounded
                          : Icons.store_rounded,
                      color: deliveryOrder
                          ? const Color(0xFF1677FF)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${o['order_number'] ?? o['id']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF143B68),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          itemCount > 1
                              ? '$itemCount مواد • ${number(o['_qty_count']).round()} قطعة'
                              : '${o['title'] ?? 'طلب'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _orderStatusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Color(0xFF667085),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${o['student_name'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    money(o['total']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _orderInfoPill(
                    Icons.phone_rounded,
                    '${o['student_phone'] ?? '—'}',
                  ),
                  _orderInfoPill(
                    Icons.location_on_rounded,
                    '${o['delivery_area'] ?? '—'}',
                  ),
                  _orderInfoPill(
                    deliveryOrder
                        ? Icons.local_shipping_rounded
                        : Icons.storefront_rounded,
                    deliveryOrder ? 'توصيل مندوب' : 'استلام من مكتبة',
                  ),
                ],
              ),
              if (items.length > 1) ...[
                const SizedBox(height: 11),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مواد الطلب',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF143B68),
                        ),
                      ),
                      const SizedBox(height: 5),
                      ...items.take(3).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• ${item['title'] ?? 'مادة'} × ${(number(item['qty']) <= 0 ? 1 : number(item['qty'])).round()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ),
                      ),
                      if (items.length > 3)
                        Text(
                          '+ ${items.length - 3} مواد أخرى',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1677FF),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if ('${o['courier_id'] ?? o['delegate_id'] ?? ''}'.isNotEmpty ||
                  '${o['library_id'] ?? o['pickup_library_id'] ?? ''}'
                      .isNotEmpty) ...[
                const SizedBox(height: 9),
                if ('${o['courier_id'] ?? o['delegate_id'] ?? ''}'.isNotEmpty)
                  _line(
                    'المندوب',
                    _courierName(
                      '${o['courier_id'] ?? o['delegate_id']}',
                    ),
                  ),
                if ('${o['library_id'] ?? o['pickup_library_id'] ?? ''}'
                    .isNotEmpty)
                  _line(
                    'المكتبة',
                    '${o['library_id'] ?? o['pickup_library_id']}',
                  ),
              ],
              const SizedBox(height: 11),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openOrderDetails(o),
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('التفاصيل'),
                  ),
                  if (deliveryOrder && !isClosed(o))
                    OutlinedButton.icon(
                      onPressed: () => _assignCourier(o),
                      icon: const Icon(Icons.delivery_dining_rounded),
                      label: const Text('تعيين مندوب'),
                    ),
                  if (!isClosed(o))
                    FilledButton.icon(
                      onPressed: () => _changeOrderStatus(o),
                      icon: const Icon(Icons.sync_alt_rounded),
                      label: const Text('تغيير الحالة'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderInfoPill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEF2F6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF667085)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475467),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _orderStatusChip(String status) {
    final (background, foreground) = switch (status) {
      'completed' || 'delivered' || 'done' => (
          const Color(0xFFE9F9EF),
          const Color(0xFF15803D),
        ),
      'cancelled' || 'canceled' || 'rejected' => (
          const Color(0xFFFFEAF0),
          const Color(0xFFBE123C),
        ),
      'ready' => (
          const Color(0xFFEAF3FF),
          const Color(0xFF1D4ED8),
        ),
      'processing' || 'printing' || 'assigned' || 'accepted' => (
          const Color(0xFFFFF4DB),
          const Color(0xFFB45309),
        ),
      'out_for_delivery' || 'picked_up' => (
          const Color(0xFFF1EBFF),
          const Color(0xFF6D28D9),
        ),
      _ => (
          const Color(0xFFEAF2FB),
          const Color(0xFF143B68),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _status(status),
        style: TextStyle(
          fontSize: 10.8,
          color: foreground,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _openOrderDetails(Map<String, dynamic> order) async {
    final items =
        ((order['_items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final id = '${items.isNotEmpty ? items.first['id'] : order['id']}';
    if (id.trim().isEmpty || id == 'null') return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessOrderDetailsScreen(
          repository: widget.repository,
          orderId: id,
        ),
      ),
    );
  }

  Widget _receipts() {
    final completed = groupedOrders.where((order) {
      final items = (order['_items'] as List).cast<Map<String, dynamic>>();
      return items.every(
        (row) => const {
          'completed',
          'delivered',
          'done',
        }.contains('${row['status']}'),
      );
    }).toList();
    return _scroll([
      const Text(
        'الوصولات',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      const Text('وصل واحد لكل طلب كامل ويعرض جميع المواد.'),
      const SizedBox(height: 12),
      if (completed.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: Text('لا توجد وصولات مكتملة')),
          ),
        )
      else
        ...completed.map(
          (order) => GroupedOrderReceiptCard(
            order: order,
            courierName: _courierName(
              '${order['courier_id'] ?? order['delegate_id'] ?? ''}',
            ),
          ),
        ),
    ]);
  }

  String _courierName(String id) {
    for (final courier in couriers) {
      if ('${courier['id']}' == id) return '${courier['name'] ?? id}';
    }
    return id;
  }

  Widget _accounts() {
    return _scroll([
      Row(
        children: [
          const Expanded(
            child: Text(
              'إدارة الحسابات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.icon(
            onPressed: _createAccount,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('إضافة'),
          ),
        ],
      ),
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
          onSelectionChanged: (value) =>
              setState(() => accountFilter = value.first),
        ),
      ),
      const SizedBox(height: 12),
      ...visibleAccounts.map(
        (a) => Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: CircleAvatar(child: Icon(_roleIcon('${a['role']}'))),
            title: Text(
              '${a['name'] ?? 'بدون اسم'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${_roleLabel('${a['role']}')} • ${a['username'] ?? ''}\n${a['phone'] ?? ''} ${a['area'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: Chip(
              label: Text('${a['status']}' == 'active' ? 'فعال' : 'غير فعال'),
            ),
            onTap: () => _editAccount(a),
          ),
        ),
      ),
    ]);
  }

  Widget _finance() {
    final platform = ledger.fold<num>(
      0,
      (sum, e) => sum + number(e['alin'] ?? e['admin']),
    );
    final receivables = ledger.fold<num>(
      0,
      (sum, e) => sum + number(e['collector_debt']),
    );
    return _scroll([
      const Text(
        'المالية والتسويات',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _metric(
              'ربح المنصة',
              money(platform),
              Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _metric(
              'إجمالي الذمم',
              money(receivables),
              Icons.account_balance_wallet_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          const Expanded(
            child: Text(
              'آخر التسويات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          FilledButton.icon(
            onPressed: _recordSettlement,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('تسوية'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (settlements.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Center(child: Text('لا توجد تسويات')),
          ),
        )
      else
        ...settlements
            .take(60)
            .map(
              (s) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF143B68),
                  ),
                  title: Text(
                    '${s['receipt_number'] ?? s['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${_roleLabel('${s['party_role']}')} • ${s['party_id']}\n${_date(s['created_at'])} • ${s['payment_method'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    money(s['amount']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ),
    ]);
  }

  Widget _catalog() {
    return _scroll([
      const Text(
        'الملازم والمنتجات',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 12),
      Text(
        'الملازم (${booklets.where((e) => e['deleted_at'] == null).length})',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      ...booklets
          .where((e) => e['deleted_at'] == null)
          .take(80)
          .map(
            (b) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF143B68),
                ),
                title: Text(
                  '${b['title'] ?? 'ملزمة'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${b['subject'] ?? ''} • ${b['grade'] ?? ''}\nالسعر: ${money(b['price'])}',
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(
                    (b['published'] == true || b['is_published'] == true)
                        ? 'منشورة'
                        : '${b['publish_status'] ?? b['status'] ?? 'مراجعة'}',
                  ),
                ),
              ),
            ),
          ),
      const SizedBox(height: 14),
      Text(
        'المنتجات (${products.where((e) => e['deleted_at'] == null).length})',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      ...products
          .where((e) => e['deleted_at'] == null)
          .take(80)
          .map(
            (p) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF143B68),
                ),
                title: Text(
                  '${p['name'] ?? p['title'] ?? 'منتج'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${p['category'] ?? p['type'] ?? ''}\nالسعر: ${money(p['sale_price'] ?? p['price'])} • المخزون: ${p['stock'] ?? 0}',
                ),
                isThreeLine: true,
                trailing: Chip(
                  label: Text(
                    '${p['status']}' == 'active'
                        ? 'فعال'
                        : '${p['status'] ?? '—'}',
                  ),
                ),
              ),
            ),
          ),
    ]);
  }

  Future<void> _assignCourier(Map<String, dynamic> order) async {
    if (!isDeliveryOrder(order)) {
      _snack('طلبات المكتبة تذهب مباشرة إلى المكتبة المختارة ولا تحتاج تعيين');
      return;
    }
    final courierItems = couriers
        .where((e) => '${e['status']}' == 'active')
        .toList();
    if (courierItems.isEmpty) {
      _snack('لا يوجد مندوب فعّال حالياً');
      return;
    }
    String? courierId =
        '${order['courier_id'] ?? order['delegate_id'] ?? ''}'.isEmpty
        ? null
        : '${order['courier_id'] ?? order['delegate_id']}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            number(order['_item_count']) > 1
                ? 'تعيين مندوب للطلب كامل'
                : 'تعيين مندوب',
          ),
          content: DropdownButtonFormField<String?>(
            initialValue: courierId,
            decoration: const InputDecoration(labelText: 'المندوب'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('اختر المندوب'),
              ),
              ...courierItems.map(
                (e) => DropdownMenuItem<String?>(
                  value: '${e['id']}',
                  child: Text('${e['name']}'),
                ),
              ),
            ],
            onChanged: (v) => setLocal(() => courierId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: courierId == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('تعيين'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || courierId == null) return;
    try {
      await widget.repository.adminAssignOrder(
        '${order['id']}',
        courierId: courierId,
      );
      await load();
      _snack(
        number(order['_item_count']) > 1
            ? 'تم تعيين المندوب لكل مواد الطلب'
            : 'تم تعيين المندوب',
      );
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _changeOrderStatus(Map<String, dynamic> order) async {
    const statuses = [
      'processing',
      'ready',
      'completed',
      'delivered',
      'cancelled',
    ];
    String value = '${order['status']}';
    if (!statuses.contains(value)) value = 'processing';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير حالة الطلب'),
        content: StatefulBuilder(
          builder: (context, setLocal) => DropdownButtonFormField<String>(
            initialValue: value,
            items: statuses
                .map((e) => DropdownMenuItem(value: e, child: Text(_status(e))))
                .toList(),
            onChanged: (v) {
              if (v != null) setLocal(() => value = v);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await widget.repository.adminTransitionOrder('${order['id']}', selected);
      await load();
      _snack('تم تحديث الطلب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _createAccount() async {
    final result = await _accountDialog();
    if (result == null) return;
    try {
      await widget.repository.adminCreateAccount(result);
      await load();
      _snack('تم إنشاء الحساب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editAccount(Map<String, dynamic> account) async {
    final result = await _accountDialog(existing: account);
    if (result == null) return;
    try {
      await widget.repository.adminUpdateAccount('${account['id']}', result);
      await load();
      _snack('تم تحديث الحساب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>?> _accountDialog({
    Map<String, dynamic>? existing,
  }) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final username = TextEditingController(
      text: '${existing?['username'] ?? ''}',
    );
    final password = TextEditingController();
    final phone = TextEditingController(text: '${existing?['phone'] ?? ''}');
    final area = TextEditingController(text: '${existing?['area'] ?? ''}');
    String role = '${existing?['role'] ?? 'teacher'}';
    if (![
      'teacher',
      'library',
      'courier',
      'printer',
      'accountant',
    ].contains(role))
      role = 'teacher';
    String status = '${existing?['status'] ?? 'active'}';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'إضافة حساب' : 'تعديل الحساب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'اسم الدخول'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: existing == null
                        ? 'كلمة المرور'
                        : 'كلمة مرور جديدة (اختياري)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'نوع الحساب'),
                  items: const [
                    DropdownMenuItem(value: 'teacher', child: Text('مدرس')),
                    DropdownMenuItem(value: 'library', child: Text('مكتبة')),
                    DropdownMenuItem(value: 'courier', child: Text('مندوب')),
                    DropdownMenuItem(value: 'printer', child: Text('مطبعة')),
                    DropdownMenuItem(
                      value: 'accountant',
                      child: Text('حسابات'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => role = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'الهاتف'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: area,
                  decoration: const InputDecoration(labelText: 'المنطقة'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('فعال')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('غير فعال'),
                    ),
                    DropdownMenuItem(value: 'pending', child: Text('معلق')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => status = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final map = <String, dynamic>{
                  'name': name.text.trim(),
                  'username': username.text.trim(),
                  'role': role,
                  'phone': phone.text.trim(),
                  'area': area.text.trim(),
                  'status': status,
                };
                if (password.text.isNotEmpty) map['password'] = password.text;
                Navigator.pop(context, map);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    username.dispose();
    password.dispose();
    phone.dispose();
    area.dispose();
    return result;
  }

  Future<void> _recordSettlement() async {
    final parties = accounts
        .where(
          (e) =>
              [
                'teacher',
                'library',
                'courier',
                'printer',
              ].contains('${e['role']}') &&
              e['deleted_at'] == null,
        )
        .toList();
    if (parties.isEmpty) return;
    String partyId = '${parties.first['id']}';
    String role = '${parties.first['role']}';
    final amount = TextEditingController();
    final note = TextEditingController();
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('تثبيت تسوية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: partyId,
                  decoration: const InputDecoration(labelText: 'الحساب'),
                  items: parties
                      .map(
                        (e) => DropdownMenuItem(
                          value: '${e['id']}',
                          child: Text(
                            '${e['name']} — ${_roleLabel('${e['role']}')}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null)
                      setLocal(() {
                        partyId = v;
                        role =
                            '${parties.firstWhere((e) => '${e['id']}' == v)['role']}';
                      });
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => method = v);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'ملاحظة'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تثبيت'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        final value = num.tryParse(amount.text.trim()) ?? 0;
        if (value <= 0) throw Exception('أدخل مبلغ صحيح');
        await widget.repository.adminRecordSettlement(
          role: role,
          partyId: partyId,
          amount: value,
          method: method,
          note: note.text,
        );
        await load();
        _snack('تم تثبيت التسوية');
      } catch (e) {
        _snack('$e'.replaceFirst('Exception: ', ''));
      }
    }
    amount.dispose();
    note.dispose();
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
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
