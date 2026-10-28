import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../data/business_notification_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_role_navigation.dart';
import '../widgets/grouped_order_receipt_card.dart';
import 'business_order_details_screen.dart';
import 'business_notifications_screen.dart';

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
  String cancelReasonFilter = 'all';
  String orderSearch = '';
  final TextEditingController orderSearchController = TextEditingController();
  String accountFilter = 'all';
  String accountSearch = '';
  final TextEditingController accountSearchController = TextEditingController();
  String receiptFilter = 'all';
  String receiptSearch = '';
  final TextEditingController receiptSearchController = TextEditingController();
  String financeFilter = 'all';
  String financeSearch = '';
  final TextEditingController financeSearchController = TextEditingController();
  int unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    load();
    refreshUnreadNotifications();
  }

  @override
  void dispose() {
    orderSearchController.dispose();
    accountSearchController.dispose();
    receiptSearchController.dispose();
    financeSearchController.dispose();
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

  Future<void> refreshUnreadNotifications() async {
    try {
      final value = await widget.repository.businessNotificationUnreadCount();
      if (!mounted) return;
      setState(() => unreadNotifications = value);
    } catch (_) {
      // Keep the dashboard usable even if the unread-count RPC is unavailable.
    }
  }

  Future<void> _refreshAll() async {
    await load();
    await refreshUnreadNotifications();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            BusinessNotificationsScreen(repository: widget.repository),
      ),
    );
    await refreshUnreadNotifications();
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
        '_cancellation_reason': items
            .map((row) => '${row['cancellation_reason'] ?? ''}'.trim())
            .firstWhere((reason) => reason.isNotEmpty, orElse: () => ''),
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

  String _cancellationReason(Map<String, dynamic> order) {
    final grouped = '${order['_cancellation_reason'] ?? ''}'.trim();
    if (grouped.isNotEmpty) return grouped;
    final direct = '${order['cancellation_reason'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    final items =
        ((order['_items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e));
    for (final item in items) {
      final reason = '${item['cancellation_reason'] ?? ''}'.trim();
      if (reason.isNotEmpty) return reason;
    }
    return '';
  }

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

    if (orderFilter == 'cancelled' && cancelReasonFilter != 'all') {
      rows = rows.where((order) {
        final reason = _cancellationReason(order);
        if (cancelReasonFilter == '__without_reason__') return reason.isEmpty;
        return reason == cancelReasonFilter;
      });
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
        _cancellationReason(order),
        ...items.map((e) => '${e['title'] ?? ''}'),
        ...items.map((e) => '${e['cancellation_reason'] ?? ''}'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get visibleAccounts {
    Iterable<Map<String, dynamic>> rows =
        accounts.where((e) => e['deleted_at'] == null);
    if (accountFilter != 'all') {
      rows = rows.where((e) => '${e['role']}' == accountFilter);
    }

    final query = accountSearch.trim().toLowerCase();
    if (query.isEmpty) return rows.toList();

    return rows.where((e) {
      final searchable = [
        '${e['name'] ?? ''}',
        '${e['username'] ?? ''}',
        '${e['phone'] ?? ''}',
        '${e['area'] ?? ''}',
        _roleLabel('${e['role'] ?? ''}'),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
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
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;

    final content = Scaffold(
      drawer: desktop
          ? null
          : BusinessRoleNavigationDrawer(
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
        automaticallyImplyLeading: !desktop,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.account.role == 'accountant'
                  ? 'لوحة الحسابات'
                  : 'لوحة إدارة آلين',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              widget.account.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_rounded),
                if (unreadNotifications > 0)
                  PositionedDirectional(
                    top: -7,
                    start: -8,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (!desktop)
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
    );

    if (!desktop) return content;

    return Scaffold(
      body: Row(
        textDirection: TextDirection.rtl,
        children: [
          AdminDesktopNavigationSidebar(
            repository: widget.repository,
            account: widget.account,
            selectedSection: index,
            onSectionChanged: (value) {
              if (!mounted) return;
              setState(() => index = value);
            },
            onLogout: widget.onLogout,
          ),
          Expanded(child: content),
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
  ) {
    final deep = Color.lerp(accent, Colors.black, .10)!;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [accent, deep],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .20),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -8,
            top: 24,
            child: Icon(
              icon,
              size: 82,
              color: Colors.white.withValues(alpha: .16),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 62,
            child: Container(
              height: 1,
              color: Colors.black.withValues(alpha: .10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _quickSection(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    final accent = switch (title) {
      'الطلبات' => const Color(0xFFFF7A00),
      'الحسابات' => const Color(0xFF7C3AED),
      'المالية' => const Color(0xFF00A86B),
      'المحتوى' => const Color(0xFF0088FF),
      'الوصولات' => const Color(0xFFE11D8A),
      _ => const Color(0xFF14B8A6),
    };
    final emoji = switch (title) {
      'الطلبات' => '🛒',
      'الحسابات' => '👥',
      'المالية' => '💰',
      'المحتوى' => '📚',
      'الوصولات' => '🧾',
      _ => '✨',
    };

    return Material(
      color: accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: .20)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$emoji $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
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
              Icon(Icons.chevron_left_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }


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
    final cancellationReasons =
        groupedOrders
            .where(_groupCancelled)
            .map(_cancellationReason)
            .where((reason) => reason.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final selectedCancellationReason =
        cancelReasonFilter == 'all' ||
            cancelReasonFilter == '__without_reason__' ||
            cancellationReasons.contains(cancelReasonFilter)
        ? cancelReasonFilter
        : 'all';

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
        if (orderFilter == 'cancelled') ...[
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC9D5)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: selectedCancellationReason,
              decoration: const InputDecoration(
                labelText: 'فلتر سبب الإلغاء',
                prefixIcon: Icon(Icons.report_gmailerrorred_rounded),
                filled: true,
                fillColor: Colors.white,
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('كل أسباب الإلغاء'),
                ),
                const DropdownMenuItem(
                  value: '__without_reason__',
                  child: Text('طلبات قديمة بدون سبب'),
                ),
                ...cancellationReasons.map(
                  (reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => cancelReasonFilter = value);
                }
              },
            ),
          ),
        ],
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
    final accent = switch (value) {
      'new' => const Color(0xFF18A957),
      'processing' => const Color(0xFFFF8A00),
      'ready' => const Color(0xFF0088FF),
      'done' => const Color(0xFF7C3AED),
      'cancelled' => const Color(0xFFE11D48),
      'active' => const Color(0xFF14B8A6),
      _ => const Color(0xFF475569),
    };
    final emoji = switch (value) {
      'new' => '🆕',
      'processing' => '🛠️',
      'ready' => '📦',
      'done' => '✅',
      'cancelled' => '❌',
      'active' => '⚡',
      _ => '📋',
    };

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => orderFilter = value),
        label: Text('$emoji $label  $count'),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: selected ? Colors.white : accent,
        ),
        selectedColor: accent,
        backgroundColor: accent.withValues(alpha: .08),
        side: BorderSide(color: accent.withValues(alpha: selected ? 1 : .25)),
      ),
    );
  }


  Widget _orderCard(Map<String, dynamic> o) {
    final deliveryOrder = isDeliveryOrder(o);
    final status = '${o['status'] ?? ''}';
    final cancelReason = _cancellationReason(o);
    final accent = switch (status) {
      'cancelled' || 'canceled' || 'rejected' => const Color(0xFFE11D48),
      'completed' || 'delivered' || 'done' => const Color(0xFF16A34A),
      'ready' => const Color(0xFF0088FF),
      'processing' || 'printing' || 'assigned' || 'accepted' =>
        const Color(0xFFFF8A00),
      'out_for_delivery' || 'picked_up' => const Color(0xFF7C3AED),
      _ => const Color(0xFF14B8A6),
    };
    final itemCount = number(o['_item_count']).round();
    final qtyCount = number(o['_qty_count']).round();
    final items =
        ((o['_items'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    final courierId = '${o['courier_id'] ?? o['delegate_id'] ?? ''}'.trim();
    final libraryId =
        '${o['library_id'] ?? o['pickup_library_id'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: .22)),
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
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      deliveryOrder
                          ? Icons.delivery_dining_rounded
                          : Icons.storefront_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طلب #${o['order_number'] ?? o['id']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF143B68),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          itemCount > 1
                              ? '$itemCount مواد • $qtyCount قطعة'
                              : '${o['title'] ?? 'طلب'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 12.5,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  children: [
                    _orderSafeLine(
                      Icons.person_rounded,
                      'الطالب',
                      '${o['student_name'] ?? '—'}',
                    ),
                    const SizedBox(height: 7),
                    _orderSafeLine(
                      Icons.phone_rounded,
                      'الهاتف',
                      '${o['student_phone'] ?? '—'}',
                    ),
                    const SizedBox(height: 7),
                    _orderSafeLine(
                      deliveryOrder
                          ? Icons.local_shipping_rounded
                          : Icons.store_rounded,
                      'الاستلام',
                      deliveryOrder ? 'توصيل مندوب' : 'استلام من مكتبة',
                    ),
                    const SizedBox(height: 7),
                    _orderSafeLine(
                      Icons.location_on_rounded,
                      'المنطقة',
                      '${o['delivery_area'] ?? o['delivery_landmark'] ?? '—'}',
                    ),
                    const SizedBox(height: 7),
                    _orderSafeLine(
                      Icons.payments_rounded,
                      'الإجمالي',
                      money(o['total']),
                      valueColor: const Color(0xFFFF7A00),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مواد الطلب',
                        style: TextStyle(
                          color: Color(0xFF143B68),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...items.take(4).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${item['title'] ?? 'مادة'} × ${(number(item['qty']) <= 0 ? 1 : number(item['qty'])).round()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF475467),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (items.length > 4)
                        Text(
                          '+ ${items.length - 4} مواد أخرى',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (courierId.isNotEmpty) ...[
                const SizedBox(height: 8),
                _orderSafeLine(
                  Icons.delivery_dining_rounded,
                  'المندوب',
                  _courierName(courierId),
                ),
              ],
              if (libraryId.isNotEmpty) ...[
                const SizedBox(height: 8),
                _orderSafeLine(
                  Icons.storefront_rounded,
                  'المكتبة',
                  _accountName(libraryId),
                ),
              ],
              if (cancelReason.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE9EE),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: const Color(0xFFFFC2D0)),
                  ),
                  child: Text(
                    'سبب الإلغاء: $cancelReason',
                    style: const TextStyle(
                      color: Color(0xFF9F1239),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openOrderDetails(o),
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text('التفاصيل'),
                  ),
                  if (deliveryOrder && !isClosed(o))
                    OutlinedButton.icon(
                      onPressed: () => _assignCourier(o),
                      icon: const Icon(Icons.delivery_dining_rounded, size: 18),
                      label: const Text('تعيين مندوب'),
                    ),
                  if (!isClosed(o))
                    OutlinedButton.icon(
                      onPressed: () => _cancelOrder(o),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC1123F),
                        side: const BorderSide(color: Color(0xFFFFB7C7)),
                      ),
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: const Text('إلغاء الطلب'),
                    ),
                  if (!isClosed(o))
                    FilledButton.icon(
                      onPressed: () => _changeOrderStatus(o),
                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
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

  Widget _orderSafeLine(
    IconData icon,
    String label,
    String value, {
    Color valueColor = const Color(0xFF143B68),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF667085)),
        const SizedBox(width: 7),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _orderMiniPanel({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color accent,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: .13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF667085),
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

  Widget _orderAssignmentPill(
    IconData icon,
    String label,
    String value,
    Color accent,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF143B68),
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
    final (background, foreground, emoji) = switch (status) {
      'completed' || 'delivered' || 'done' => (
          const Color(0xFFDDFCE8),
          const Color(0xFF087A36),
          '✅',
        ),
      'cancelled' || 'canceled' || 'rejected' => (
          const Color(0xFFFFE0E7),
          const Color(0xFFC1123F),
          '❌',
        ),
      'ready' => (
          const Color(0xFFDBEEFF),
          const Color(0xFF006DCC),
          '📦',
        ),
      'processing' || 'printing' || 'assigned' || 'accepted' => (
          const Color(0xFFFFE9C7),
          const Color(0xFFB85C00),
          '🛠️',
        ),
      'out_for_delivery' || 'picked_up' => (
          const Color(0xFFEDE1FF),
          const Color(0xFF6C21C9),
          '🚚',
        ),
      'new' => (
          const Color(0xFFDCFCE7),
          const Color(0xFF11823F),
          '🆕',
        ),
      'pending' || 'pending_admin' => (
          const Color(0xFFFFF2BF),
          const Color(0xFF9A6500),
          '⏳',
        ),
      _ => (
          const Color(0xFFE8F1FB),
          const Color(0xFF143B68),
          '📌',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: .16)),
      ),
      child: Text(
        '$emoji ${_status(status)}',
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
      final items =
          ((order['_items'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final source = items.isEmpty ? <Map<String, dynamic>>[order] : items;
      return source.isNotEmpty &&
          source.every(
            (row) => const {
              'completed',
              'delivered',
              'done',
            }.contains('${row['status']}'),
          );
    }).toList();

    bool isDelivery(Map<String, dynamic> order) => isDeliveryOrder(order);

    Iterable<Map<String, dynamic>> filtered = completed;
    if (receiptFilter == 'delivery') {
      filtered = filtered.where(isDelivery);
    } else if (receiptFilter == 'pickup') {
      filtered = filtered.where((order) => !isDelivery(order));
    }

    final query = receiptSearch.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((order) {
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
          '${order['delivery_landmark'] ?? ''}',
          ...items.map((e) => '${e['title'] ?? ''}'),
        ].join(' ').toLowerCase();
        return searchable.contains(query);
      });
    }

    final visibleReceipts = filtered.toList();
    final totalSales = visibleReceipts.fold<num>(
      0,
      (sum, order) => sum + number(order['total']),
    );
    final totalDelivery = visibleReceipts.fold<num>(
      0,
      (sum, order) => sum + number(order['delivery_fee']),
    );
    final deliveryCount = completed.where(isDelivery).length;
    final pickupCount = completed.length - deliveryCount;

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
                    'الوصولات',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'وصولات الطلبات المكتملة مع البحث والتصفية والإجماليات',
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
                '${visibleReceipts.length} وصل',
                style: const TextStyle(
                  color: Color(0xFF143B68),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 560
                    ? 2
                    : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: columns == 1 ? 3.15 : 2.25,
              children: [
                _receiptMetricCard(
                  'عدد الوصولات',
                  '${visibleReceipts.length}',
                  Icons.receipt_long_rounded,
                  const Color(0xFF7C3AED),
                ),
                _receiptMetricCard(
                  'إجمالي المبيعات',
                  money(totalSales),
                  Icons.payments_rounded,
                  const Color(0xFF16A34A),
                ),
                _receiptMetricCard(
                  'أجور التوصيل',
                  money(totalDelivery),
                  Icons.delivery_dining_rounded,
                  const Color(0xFFFF7A00),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 13),
        TextField(
          controller: receiptSearchController,
          onChanged: (value) => setState(() => receiptSearch = value),
          decoration: InputDecoration(
            hintText: 'ابحث برقم الطلب، الطالب، الهاتف، المنطقة أو المادة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: receiptSearch.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      receiptSearchController.clear();
                      setState(() => receiptSearch = '');
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
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _receiptFilterChip(
                'الكل',
                'all',
                completed.length,
                const Color(0xFF143B68),
                '🧾',
              ),
              _receiptFilterChip(
                'توصيل مندوب',
                'delivery',
                deliveryCount,
                const Color(0xFF0088FF),
                '🚚',
              ),
              _receiptFilterChip(
                'استلام مكتبة',
                'pickup',
                pickupCount,
                const Color(0xFF16A34A),
                '🏪',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (visibleReceipts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3EAF1)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 42,
                  color: Color(0xFF98A2B3),
                ),
                SizedBox(height: 10),
                Text(
                  'لا توجد وصولات مطابقة',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF143B68),
                  ),
                ),
              ],
            ),
          )
        else
          ...visibleReceipts.map(
            (order) => GroupedOrderReceiptCard(
              order: order,
              courierName: _courierName(
                '${order['courier_id'] ?? order['delegate_id'] ?? ''}',
              ),
            ),
          ),
      ],
    );
  }

  Widget _receiptMetricCard(
    String label,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .07),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF143B68),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptFilterChip(
    String label,
    String value,
    int count,
    Color accent,
    String emoji,
  ) {
    final selected = receiptFilter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => receiptFilter = value),
        label: Text('$emoji $label  $count'),
        labelStyle: TextStyle(
          color: selected ? Colors.white : accent,
          fontWeight: FontWeight.w900,
        ),
        selectedColor: accent,
        backgroundColor: accent.withValues(alpha: .07),
        side: BorderSide(color: accent.withValues(alpha: selected ? 1 : .20)),
      ),
    );
  }

  String _courierName(String id) {
    for (final courier in couriers) {
      if ('${courier['id']}' == id) return '${courier['name'] ?? id}';
    }
    return id;
  }

  String _accountName(String id) {
    for (final account in accounts) {
      if ('${account['id']}' == id) return '${account['name'] ?? id}';
    }
    return id;
  }

  Widget _accounts() {
    int roleCount(String role) => accounts
        .where((e) => e['deleted_at'] == null && '${e['role']}' == role)
        .length;
    final active = accounts
        .where(
          (e) => e['deleted_at'] == null && '${e['status']}' == 'active',
        )
        .length;
    final inactive = accounts
        .where(
          (e) => e['deleted_at'] == null && '${e['status']}' != 'active',
        )
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة الحسابات',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'المدرسون والمكتبات والمندوبون والمطابع والحسابات',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _createAccount,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('إضافة'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                ? 3
                : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: constraints.maxWidth >= 700 ? 2.1 : 1.45,
              children: [
                _metricCard(
                  'الحسابات الفعالة',
                  '$active',
                  Icons.verified_user_rounded,
                  const Color(0xFF16A34A),
                  const Color(0xFFE9F9EF),
                ),
                _metricCard(
                  'غير الفعالة',
                  '$inactive',
                  Icons.person_off_rounded,
                  const Color(0xFFE11D48),
                  const Color(0xFFFFEAF0),
                ),
                _metricCard(
                  'المدرسون',
                  '${roleCount('teacher')}',
                  Icons.school_rounded,
                  const Color(0xFF7C3AED),
                  const Color(0xFFF1EBFF),
                ),
                _metricCard(
                  'المكتبات',
                  '${roleCount('library')}',
                  Icons.store_rounded,
                  const Color(0xFF0284C7),
                  const Color(0xFFE8F7FF),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: accountSearchController,
          onChanged: (value) => setState(() => accountSearch = value),
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم، اسم الدخول، الهاتف أو المنطقة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: accountSearch.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      accountSearchController.clear();
                      setState(() => accountSearch = '');
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
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _accountFilterChip('الكل', 'all'),
              _accountFilterChip('مدرس', 'teacher'),
              _accountFilterChip('مكتبة', 'library'),
              _accountFilterChip('مندوب', 'courier'),
              _accountFilterChip('مطبعة', 'printer'),
              _accountFilterChip('حسابات', 'accountant'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (visibleAccounts.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE3EAF1)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.manage_accounts_outlined,
                  size: 42,
                  color: Color(0xFF98A2B3),
                ),
                SizedBox(height: 10),
                Text(
                  'لا توجد حسابات مطابقة',
                  style: TextStyle(
                    color: Color(0xFF143B68),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          )
        else
          ...visibleAccounts.map(_accountCard),
      ],
    );
  }

  Widget _accountFilterChip(String label, String value) {
    final selected = accountFilter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => accountFilter = value),
        label: Text(label),
        selectedColor: const Color(0xFF143B68),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected
              ? const Color(0xFF143B68)
              : const Color(0xFFE3EAF1),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF143B68),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _accountCard(Map<String, dynamic> account) {
    final active = '${account['status']}' == 'active';
    final role = '${account['role'] ?? ''}';
    final roleAccent = switch (role) {
      'teacher' => const Color(0xFF7C3AED),
      'library' => const Color(0xFF0088FF),
      'courier' || 'delegate' => const Color(0xFFFF7A00),
      'printer' => const Color(0xFFE11D8A),
      'accountant' => const Color(0xFF00A86B),
      _ => const Color(0xFF14B8A6),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      color: roleAccent.withValues(alpha: .035),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: roleAccent.withValues(alpha: .16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _editAccount(account),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: roleAccent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_roleIcon(role), color: roleAccent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${account['name'] ?? 'بدون اسم'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF143B68),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFE9F9EF)
                                : const Color(0xFFFFEAF0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            active ? '😊 فعال' : '😴 غير فعال',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: active
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFBE123C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_roleLabel(role)} • ${account['username'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if ('${account['phone'] ?? ''}'.trim().isNotEmpty)
                          _orderInfoPill(
                            Icons.phone_rounded,
                            '${account['phone']}',
                          ),
                        if ('${account['area'] ?? ''}'.trim().isNotEmpty)
                          _orderInfoPill(
                            Icons.location_on_rounded,
                            '${account['area']}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: OutlinedButton.icon(
                        onPressed: () => _editAccount(account),
                        icon: const Icon(Icons.edit_rounded, size: 17),
                        label: const Text('تعديل الحساب'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finance() {
    final pendingLedger = ledger
        .where((e) => '${e['settlement_status'] ?? 'pending'}' != 'settled')
        .toList();

    final platform = pendingLedger.fold<num>(
      0,
      (sum, e) => sum + number(e['alin'] ?? e['admin']),
    );
    final teacherDue = pendingLedger.fold<num>(
      0,
      (sum, e) => sum + number(e['teacher']),
    );
    final libraryDue = pendingLedger.fold<num>(
      0,
      (sum, e) => sum + number(e['library']),
    );
    final courierDue = pendingLedger.fold<num>(
      0,
      (sum, e) => sum + number(e['courier'] ?? e['delegate']),
    );
    final partnerDue = teacherDue + libraryDue + courierDue;

    final settledCollectorAmounts = <String, num>{};
    for (final settlement in settlements) {
      final status = '${settlement['status'] ?? ''}';
      if (!const {'paid', 'received'}.contains(status)) continue;
      var role = '${settlement['party_role'] ?? ''}'.trim();
      if (role == 'courier') role = 'delegate';
      if (role != 'library' && role != 'delegate') continue;
      final id = '${settlement['party_id'] ?? ''}'.trim();
      if (id.isEmpty) continue;
      final key = '$role:$id';
      settledCollectorAmounts[key] =
          (settledCollectorAmounts[key] ?? 0) + number(settlement['amount']);
    }

    Iterable<Map<String, dynamic>> filteredSettlements = settlements;
    if (financeFilter != 'all') {
      filteredSettlements = filteredSettlements.where((s) {
        final role = '${s['party_role'] ?? ''}';
        if (financeFilter == 'courier') {
          return role == 'courier' || role == 'delegate';
        }
        return role == financeFilter;
      });
    }

    final financeQuery = financeSearch.trim().toLowerCase();
    if (financeQuery.isNotEmpty) {
      filteredSettlements = filteredSettlements.where((s) {
        final role = '${s['party_role'] ?? ''}';
        final partyId = '${s['party_id'] ?? ''}';
        final partyName = _financePartyName(role, partyId);
        final searchable = [
          '${s['receipt_number'] ?? ''}',
          '${s['id'] ?? ''}',
          partyName,
          _roleLabel(role),
          '${s['payment_method'] ?? ''}',
          '${s['status'] ?? ''}',
          '${s['note'] ?? ''}',
        ].join(' ').toLowerCase();
        return searchable.contains(financeQuery);
      });
    }
    final visibleSettlements = filteredSettlements.toList();

    final openDebts = <String, Map<String, dynamic>>{};
    for (final row in pendingLedger) {
      final amount = number(row['collector_debt']);
      if (amount <= 0) continue;
      var role = '${row['collector_role'] ?? ''}'.trim();
      if (role == 'courier') role = 'delegate';
      final id = '${row['collector_id'] ?? ''}'.trim();
      if (role.isEmpty || id.isEmpty) continue;
      final key = '$role:$id';
      final current = openDebts.putIfAbsent(
        key,
        () => {
          'role': role,
          'id': id,
          'gross_amount': 0,
          'amount': 0,
          'settled': 0,
          'orders': 0,
        },
      );
      current['gross_amount'] = number(current['gross_amount']) + amount;
      current['orders'] = number(current['orders']) + 1;
    }

    final debtRows = <Map<String, dynamic>>[];
    for (final entry in openDebts.entries) {
      final row = entry.value;
      final gross = number(row['gross_amount']);
      final paid = settledCollectorAmounts[entry.key] ?? 0;
      final remaining = (gross - paid).clamp(0, double.infinity);
      row['settled'] = paid;
      row['amount'] = remaining;
      if (remaining > 0) debtRows.add(row);
    }
    debtRows.sort(
      (a, b) => number(b['amount']).compareTo(number(a['amount'])),
    );
    final receivables = debtRows.fold<num>(
      0,
      (sum, row) => sum + number(row['amount']),
    );

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
                    'المالية والتسويات',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF143B68),
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'ملخص الأرباح والمستحقات والذمم والتسويات المالية',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _recordSettlement,
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('تسوية جديدة'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050
                ? 3
                : constraints.maxWidth >= 650
                    ? 2
                    : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: columns == 1 ? 3.05 : 2.15,
              children: [
                _financeMetricCard(
                  'ربح المنصة',
                  money(platform),
                  Icons.trending_up_rounded,
                  const Color(0xFF16A34A),
                ),
                _financeMetricCard(
                  'إجمالي الذمم',
                  money(receivables),
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFFE11D48),
                ),
                _financeMetricCard(
                  'مستحقات المدرسين',
                  money(teacherDue),
                  Icons.school_rounded,
                  const Color(0xFF7C3AED),
                ),
                _financeMetricCard(
                  'مستحقات المكتبات',
                  money(libraryDue),
                  Icons.storefront_rounded,
                  const Color(0xFF0088FF),
                ),
                _financeMetricCard(
                  'مستحقات المندوبين',
                  money(courierDue),
                  Icons.delivery_dining_rounded,
                  const Color(0xFFFF7A00),
                ),
                _financeMetricCard(
                  'مستحقات الشركاء',
                  money(partnerDue),
                  Icons.groups_rounded,
                  const Color(0xFF14B8A6),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _financeSectionHeader(
          'الذمم المفتوحة للتحصيل',
          debtRows.isEmpty
              ? 'لا توجد ذمم مفتوحة حالياً'
              : '${debtRows.length} حساب عليه ذمة',
          Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),
        if (debtRows.isEmpty)
          _financeEmptyCard('لا توجد ذمم مفتوحة')
        else
          ...debtRows.take(12).map((row) {
            final role = '${row['role'] ?? ''}';
            final id = '${row['id'] ?? ''}';
            final name = _financePartyName(role, id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFF1D6DB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFF2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFFE11D48),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF143B68),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_roleLabel(role)} • ${number(row['orders']).round()} حركة'
                          '${number(row['settled']) > 0 ? ' • مسدد ${money(row['settled'])}' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money(row['amount']),
                    style: const TextStyle(
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),
        _financeSectionHeader(
          'سجل التسويات',
          '${visibleSettlements.length} تسوية ظاهرة',
          Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: financeSearchController,
          onChanged: (value) => setState(() => financeSearch = value),
          decoration: InputDecoration(
            hintText: 'ابحث برقم الوصل، اسم الحساب، طريقة الدفع أو الملاحظة',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: financeSearch.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      financeSearchController.clear();
                      setState(() => financeSearch = '');
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
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _financeFilterChip(
                'الكل',
                'all',
                settlements.length,
                const Color(0xFF143B68),
              ),
              _financeFilterChip(
                'مدرسين',
                'teacher',
                settlements
                    .where((s) => '${s['party_role']}' == 'teacher')
                    .length,
                const Color(0xFF7C3AED),
              ),
              _financeFilterChip(
                'مكتبات',
                'library',
                settlements
                    .where((s) => '${s['party_role']}' == 'library')
                    .length,
                const Color(0xFF0088FF),
              ),
              _financeFilterChip(
                'مندوبين',
                'courier',
                settlements.where((s) {
                  final role = '${s['party_role']}';
                  return role == 'courier' || role == 'delegate';
                }).length,
                const Color(0xFFFF7A00),
              ),
              _financeFilterChip(
                'مطابع',
                'printer',
                settlements
                    .where((s) => '${s['party_role']}' == 'printer')
                    .length,
                const Color(0xFFEC4899),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visibleSettlements.isEmpty)
          _financeEmptyCard('لا توجد تسويات مطابقة')
        else
          ...visibleSettlements.take(80).map(_settlementCard),
      ],
    );
  }

  Widget _financeMetricCard(
    String label,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF143B68),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeSectionHeader(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FB),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: const Color(0xFF143B68)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF143B68),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _financeFilterChip(
    String label,
    String value,
    int count,
    Color accent,
  ) {
    final selected = financeFilter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => financeFilter = value),
        label: Text('$label  $count'),
        labelStyle: TextStyle(
          color: selected ? Colors.white : accent,
          fontWeight: FontWeight.w900,
        ),
        selectedColor: accent,
        backgroundColor: accent.withValues(alpha: .07),
        side: BorderSide(color: accent.withValues(alpha: selected ? 1 : .20)),
      ),
    );
  }

  Widget _settlementCard(Map<String, dynamic> s) {
    final role = '${s['party_role'] ?? ''}';
    final partyId = '${s['party_id'] ?? ''}';
    final partyName = _financePartyName(role, partyId);
    final status = '${s['status'] ?? ''}';
    final note = '${s['note'] ?? ''}'.trim();
    final accent = switch (role) {
      'teacher' => const Color(0xFF7C3AED),
      'library' => const Color(0xFF0088FF),
      'courier' || 'delegate' => const Color(0xFFFF7A00),
      'printer' => const Color(0xFFEC4899),
      _ => const Color(0xFF14B8A6),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, color: accent, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        partyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF143B68),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      money(s['amount']),
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${s['receipt_number'] ?? s['id']} • ${_roleLabel(role)}',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_date(s['created_at'])} • ${_paymentMethodLabel('${s['payment_method'] ?? ''}')}'
                  '${status.isEmpty ? '' : ' • ${_settlementStatusLabel(status)}'}',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 11.5,
                      height: 1.3,
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

  Widget _financeEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF1)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF667085),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _financePartyName(String role, String id) {
    final accountName = _accountName(id);
    if (accountName != id && accountName.trim().isNotEmpty) return accountName;
    if (role == 'courier' || role == 'delegate') {
      final courier = _courierName(id);
      if (courier != id && courier.trim().isNotEmpty) return courier;
    }
    return id.isEmpty ? 'حساب غير محدد' : id;
  }

  String _paymentMethodLabel(String method) => switch (method) {
    'cash' => 'نقدي',
    'transfer' => 'تحويل',
    'bank' => 'تحويل مصرفي',
    _ => method.isEmpty ? '—' : method,
  };

  String _settlementStatusLabel(String status) => switch (status) {
    'paid' => 'مدفوع',
    'received' => 'مستلم',
    'settled' => 'مسدد',
    'pending' => 'معلق',
    'reversed' => 'معكوس',
    _ => status,
  };

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

  Future<String?> _askCancellationReason() async {
    final controller = TextEditingController();
    String reason = '';
    const suggestions = [
      'طلب الطالب الإلغاء',
      'تعذر التواصل مع الطالب',
      'العنوان أو البيانات غير مكتملة',
      'المادة غير متوفرة',
      'خطأ في الطلب',
    ];

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cancel_rounded, color: Color(0xFFC1123F)),
              SizedBox(width: 8),
              Text('سبب إلغاء الطلب'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'لا يمكن إلغاء الطلب بدون تسجيل السبب. سيظهر السبب في الطلب وسجل الحركة.',
                    style: TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: suggestions
                        .map(
                          (item) => ActionChip(
                            label: Text(item),
                            onPressed: () {
                              controller.text = item;
                              controller.selection = TextSelection.collapsed(
                                offset: controller.text.length,
                              );
                              setLocal(() => reason = item);
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 250,
                    onChanged: (value) =>
                        setLocal(() => reason = value.trim()),
                    decoration: const InputDecoration(
                      labelText: 'سبب الإلغاء *',
                      hintText: 'اكتب سبب واضح لإلغاء الطلب',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('رجوع'),
            ),
            FilledButton.icon(
              onPressed: reason.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, reason.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC1123F),
              ),
              icon: const Icon(Icons.cancel_rounded),
              label: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final reason = await _askCancellationReason();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await widget.repository.adminTransitionOrder(
        '${order['id']}',
        'cancelled',
        reason: reason.trim(),
      );
      await load();
      if (mounted) {
        setState(() {
          orderFilter = 'cancelled';
          cancelReasonFilter = reason.trim();
        });
      }
      _snack('تم إلغاء الطلب وتسجيل السبب');
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
                'delegate',
                'printer',
              ].contains('${e['role']}') &&
              e['deleted_at'] == null,
        )
        .toList();

    if (parties.isEmpty) {
      _snack('لا توجد حسابات مالية متاحة للتسوية');
      return;
    }

    String partyId = '${parties.first['id']}';
    String role = '${parties.first['role']}';
    final amount = TextEditingController();
    final note = TextEditingController();
    String method = 'cash';
    Map<String, dynamic>? balance;
    String? balanceError;
    bool balanceLoading = true;
    bool balanceRequested = false;

    Future<void> loadBalance(StateSetter setLocal) async {
      setLocal(() {
        balanceLoading = true;
        balanceError = null;
        balance = null;
      });
      try {
        final value = await widget.repository.adminFinancePartySummary(
          role,
          partyId,
        );
        setLocal(() {
          balance = value;
          balanceLoading = false;
        });
      } catch (e) {
        setLocal(() {
          balanceError = '$e'.replaceFirst('Exception: ', '');
          balanceLoading = false;
        });
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) {
          if (!balanceRequested &&
              balanceLoading &&
              balance == null &&
              balanceError == null) {
            balanceRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              loadBalance(setLocal);
            });
          }

          final remaining = number(balance?['remaining']);
          final earned = number(balance?['earned']);
          final settled = number(balance?['settled']);
          final debtTotal = number(balance?['debt_total']);
          final ordersCount = number(balance?['orders_count']).round();
          final entered = num.tryParse(amount.text.trim()) ?? 0;
          final validAmount =
              !balanceLoading &&
              balanceError == null &&
              remaining > 0 &&
              entered > 0 &&
              entered <= remaining;

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded),
                SizedBox(width: 8),
                Text('تسوية مالية جديدة'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: partyId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الحساب',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      items: parties
                          .map(
                            (e) => DropdownMenuItem(
                              value: '${e['id']}',
                              child: Text(
                                '${e['name']} — ${_roleLabel('${e['role']}')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: balanceLoading
                          ? null
                          : (v) {
                              if (v == null) return;
                              final selected = parties.firstWhere(
                                (e) => '${e['id']}' == v,
                              );
                              setLocal(() {
                                partyId = v;
                                role = '${selected['role']}';
                                amount.clear();
                                balance = null;
                                balanceError = null;
                                balanceLoading = true;
                                balanceRequested = true;
                              });
                              loadBalance(setLocal);
                            },
                    ),
                    const SizedBox(height: 12),
                    if (balanceLoading)
                      const Container(
                        padding: EdgeInsets.all(18),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('جاري تحميل الرصيد المالي...'),
                          ],
                        ),
                      )
                    else if (balanceError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE9EE),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: const Color(0xFFFFC2D0),
                          ),
                        ),
                        child: Text(
                          balanceError!,
                          style: const TextStyle(
                            color: Color(0xFF9F1239),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE3EAF1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _settlementBalanceLine(
                              'المكتسب',
                              money(earned),
                              const Color(0xFF7C3AED),
                            ),
                            const SizedBox(height: 7),
                            if (debtTotal > 0) ...[
                              _settlementBalanceLine(
                                'إجمالي الذمة',
                                money(debtTotal),
                                const Color(0xFFE11D48),
                              ),
                              const SizedBox(height: 7),
                            ],
                            _settlementBalanceLine(
                              'المسدد سابقاً',
                              money(settled),
                              const Color(0xFF0088FF),
                            ),
                            const Divider(height: 18),
                            _settlementBalanceLine(
                              'المتبقي للتسوية',
                              money(remaining),
                              remaining > 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF667085),
                              strong: true,
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '$ordersCount حركة مالية محسوبة',
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amount,
                        enabled: remaining > 0,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setLocal(() {}),
                        decoration: InputDecoration(
                          labelText: 'مبلغ التسوية',
                          prefixIcon: const Icon(Icons.payments_rounded),
                          helperText: remaining > 0
                              ? 'الحد الأعلى: ${money(remaining)}'
                              : 'لا يوجد رصيد قابل للتسوية',
                          errorText: entered > remaining && remaining > 0
                              ? 'المبلغ أكبر من الرصيد المتبقي'
                              : null,
                          suffixIcon: remaining > 0
                              ? TextButton(
                                  onPressed: () {
                                    amount.text = remaining
                                        .toStringAsFixed(
                                          remaining % 1 == 0 ? 0 : 2,
                                        );
                                    setLocal(() {});
                                  },
                                  child: const Text('كامل'),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: method,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الدفع',
                          prefixIcon: Icon(Icons.credit_card_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('نقدي'),
                          ),
                          DropdownMenuItem(
                            value: 'transfer',
                            child: Text('تحويل'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => method = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: note,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: validAmount
                    ? () {
                        Navigator.pop(dialogContext, {
                          'party_id': partyId,
                          'role': role,
                          'amount': entered,
                          'method': method,
                          'note': note.text.trim(),
                          'remaining': remaining,
                          'party_name':
                              '${balance?['party_name'] ?? _financePartyName(role, partyId)}',
                        });
                      }
                    : null,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('متابعة'),
              ),
            ],
          );
        },
      ),
    );

    amount.dispose();
    note.dispose();
    if (result == null) return;

    final value = number(result['amount']);
    final remainingBefore = number(result['remaining']);
    final partyName = '${result['party_name'] ?? 'الحساب'}';
    final remainingAfter = (remainingBefore - value).clamp(
      0,
      double.infinity,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) => AlertDialog(
        title: const Text('تأكيد التسوية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              partyName,
              style: const TextStyle(
                color: Color(0xFF143B68),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _settlementBalanceLine(
              'الرصيد قبل',
              money(remainingBefore),
              const Color(0xFFE11D48),
            ),
            const SizedBox(height: 7),
            _settlementBalanceLine(
              'مبلغ التسوية',
              money(value),
              const Color(0xFF0088FF),
              strong: true,
            ),
            const SizedBox(height: 7),
            _settlementBalanceLine(
              'المتبقي بعد',
              money(remainingAfter),
              const Color(0xFF16A34A),
              strong: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'بعد التأكيد سيتم إنشاء سند تسوية مالي رسمي.',
              style: TextStyle(
                color: Color(0xFF667085),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(confirmContext, true),
            icon: const Icon(Icons.verified_rounded),
            label: const Text('تأكيد التسوية'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await widget.repository.adminRecordSettlement(
        role: '${result['role']}',
        partyId: '${result['party_id']}',
        amount: value,
        method: '${result['method']}',
        note: '${result['note'] ?? ''}',
      );
      await load();
      _snack(
        'تم تثبيت التسوية • المتبقي: ${money(response['remaining_after'] ?? remainingAfter)}',
      );
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Widget _settlementBalanceLine(
    String label,
    String value,
    Color valueColor, {
    bool strong = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF667085),
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: strong ? 15 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
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
