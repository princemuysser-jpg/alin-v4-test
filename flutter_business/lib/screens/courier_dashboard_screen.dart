import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/business_courier_repository.dart';
import '../data/business_finance_repository.dart';
import '../data/business_notification_repository.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_role_navigation.dart';
import '../widgets/business_brand.dart';
import '../widgets/grouped_order_receipt_list.dart';
import 'business_notifications_screen.dart';
import 'business_party_finance_screen.dart';
import 'courier_profile_screen.dart';

// Courier old-web parity Build 17

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
  List<Map<String, dynamic>> orderRows = [];
  bool loading = true;
  String? error;
  String filter = 'home';
  String receiptSearch = '';
  String orderSearch = '';
  String orderStageFilter = 'all';
  String availability = 'available';
  int unreadNotifications = 0;
  Map<String, dynamic> financeSummary = {};
  String courierArea = '';
  List<String> courierAreas = [];
  final Set<String> busyOrders = {};

  static const doneStatuses = {'completed', 'delivered'};
  static const closedStatuses = {
    'completed',
    'delivered',
    'cancelled',
    'rejected',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  String _groupKey(Map<String, dynamic> row) {
    final group = '${row['checkout_group_id'] ?? ''}'.trim();
    if (group.isNotEmpty) return 'group:$group';
    final request = '${row['checkout_request_key'] ?? ''}'.trim();
    if (request.isNotEmpty) return 'request:$request';
    return 'single:${row['id']}';
  }

  List<Map<String, dynamic>> get groupedOrders {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in orderRows) {
      groups
          .putIfAbsent(_groupKey(row), () => <Map<String, dynamic>>[])
          .add(row);
    }

    final result = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final rows = entry.value;
      rows.sort(
        (a, b) =>
            '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}'),
      );
      final anchor = rows.firstWhere(
        (row) =>
            number(row['delivery_fee']) > 0 || number(row['courier_fee']) > 0,
        orElse: () => rows.first,
      );
      final statuses = rows.map((e) => '${e['status'] ?? 'assigned'}').toSet();
      final combined = Map<String, dynamic>.from(anchor);
      combined['_group_key'] = entry.key;
      combined['_items'] = rows;
      combined['_item_count'] = rows.length;
      combined['_qty_count'] = rows.fold<num>(
        0,
        (sum, row) => sum + number(row['qty'] ?? 1),
      );
      combined['_group_total'] = rows.fold<num>(
        0,
        (sum, row) => sum + number(row['total']),
      );
      combined['_delivery_fee'] = rows.fold<num>(
        0,
        (sum, row) => sum + number(row['delivery_fee']),
      );
      combined['_courier_fee'] = rows.fold<num>(0, (sum, row) {
        final value =
            row['courier_fee'] ??
            row['courier_profit'] ??
            row['delegate_profit'];
        return sum + number(value);
      });
      combined['_mixed_status'] = statuses.length > 1;
      result.add(combined);
    }
    return result;
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.courierGroupedOrderRows(widget.account.id),
        widget.repository.courierProfile(),
      ]);
      Map<String, dynamic> finance = {};
      try {
        finance = await widget.repository.financePartySummaryV2(
          role: 'delegate',
          partyId: widget.account.id,
        );
      } catch (_) {
        // Orders must remain usable even if the finance summary is unavailable.
      }
      var unread = unreadNotifications;
      try {
        unread = await widget.repository.businessNotificationUnreadCount();
      } catch (_) {
        // Notifications must not block the courier dashboard.
      }
      if (!mounted) return;
      final profile = Map<String, dynamic>.from(values[1] as Map);
      final rawAreas = profile['areas'];
      final areas = rawAreas is List
          ? rawAreas.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];
      setState(() {
        orderRows = (values[0] as List).cast<Map<String, dynamic>>();
        availability = '${profile['availability'] ?? 'available'}';
        courierArea = '${profile['area'] ?? ''}'.trim();
        courierAreas = areas;
        financeSummary = finance;
        unreadNotifications = unread;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool isDone(Map<String, dynamic> o) =>
      doneStatuses.contains('${o['status']}');
  bool isClosed(Map<String, dynamic> o) =>
      closedStatuses.contains('${o['status']}');

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
    final grouped = groupedOrders;
    Iterable<Map<String, dynamic>> rows;
    if (filter == 'completed') {
      rows = grouped.where(isDone);
    } else if (filter == 'all') {
      rows = grouped;
    } else {
      rows = grouped.where((o) => !isClosed(o));
      if (orderStageFilter != 'all') {
        rows = rows.where((o) => _matchesOrderStage(o, orderStageFilter));
      }
    }

    final query = orderSearch.trim().toLowerCase();
    if (query.isNotEmpty) {
      rows = rows.where((order) {
        final items = ((order['_items'] as List?) ?? const <dynamic>[])
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
          '${order['pickup_source_label'] ?? ''}',
          ...items.map((e) => '${e['title'] ?? ''}'),
        ].join(' ').toLowerCase();
        return searchable.contains(query);
      });
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

  bool _matchesOrderStage(Map<String, dynamic> order, String stage) {
    final statuses = ((order['_items'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) => '${e['status'] ?? ''}')
        .where((e) => e.isNotEmpty)
        .toSet();
    if (statuses.isEmpty) statuses.add('${order['status'] ?? ''}');

    return switch (stage) {
      'new' => statuses.any(
          (s) => const {'assigned', 'new', 'pending', 'pending_admin'}.contains(s),
        ),
      'accepted' => statuses.any((s) => s == 'accepted'),
      'picked_up' => statuses.any((s) => s == 'picked_up'),
      'delivery' => statuses.any(
          (s) => const {'out_for_delivery', 'out_delivery'}.contains(s),
        ),
      _ => true,
    };
  }

  int _stageCount(List<Map<String, dynamic>> grouped, String stage) {
    return grouped
        .where((o) => !isClosed(o))
        .where((o) => _matchesOrderStage(o, stage))
        .length;
  }

  String statusLabel(String status) => switch (status) {
    'available' => 'متاح',
    'busy' => 'مشغول',
    'offline' => 'خارج الخدمة',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة المندوب')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> transition(
    Map<String, dynamic> order,
    String status, {
    String reason = '',
  }) async {
    final id = '${order['id']}';
    final key = '${order['_group_key'] ?? id}';
    if (busyOrders.contains(key)) return;
    setState(() => busyOrders.add(key));
    try {
      await widget.repository.courierTransitionGroup(
        id,
        status,
        reason: reason,
      );
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث الطلب بالكامل')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busyOrders.remove(key));
    }
  }

  Future<String?> askText(String title, {String hint = ''}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
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
      await widget.repository.courierSetNoteGroup('${order['id']}', note);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الملاحظة لكل الطلب')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
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
    await launchUrl(
      Uri.parse('https://wa.me/$clean'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> openMap(Map<String, dynamic> order) async {
    final lat = num.tryParse('${order['delivery_latitude']}');
    final lng = num.tryParse('${order['delivery_longitude']}');
    Uri? uri;
    if (lat != null && lng != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      );
    } else {
      final stored = '${order['delivery_location_url'] ?? ''}'.trim();
      if (stored.startsWith('https://')) uri = Uri.tryParse(stored);
      if (uri == null) {
        final q = [
          order['delivery_landmark'],
          order['delivery_area'],
          'كركوك',
          'العراق',
        ].where((v) => '${v ?? ''}'.trim().isNotEmpty).join('، ');
        if (q.isNotEmpty)
          uri = Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}',
          );
      }
    }
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupedOrders;
    final newCount = grouped.where((o) {
      final status = '${o['status'] ?? ''}';
      return const {'assigned', 'new', 'pending_admin'}.contains(status);
    }).length;
    final inDeliveryCount = grouped.where((o) {
      final status = '${o['status'] ?? ''}';
      return const {
        'accepted',
        'picked_up',
        'out_for_delivery',
        'out_delivery',
        'processing',
      }.contains(status);
    }).length;
    final completed = grouped.where(isDone).length;
    final today = DateTime.now();
    final deliveredToday = grouped.where((o) {
      if (!isDone(o)) return false;
      final value = o['delivered_at'] ?? o['completed_at'] ?? o['updated_at'];
      final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
      return date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;
    final profit = grouped
        .where(isDone)
        .fold<num>(0, (sum, o) => sum + number(o['_courier_fee']));
    final debt = number(
      financeSummary['remaining'] ?? financeSummary['debt_total'],
    );
    return Scaffold(
      drawer: BusinessRoleNavigationDrawer(
        repository: widget.repository,
        account: widget.account,
        onLogout: widget.onLogout,
      ),
      appBar: AppBar(
        title: Row(
          children: [
            const AlinBrandMark(size: 36, light: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'آلين للمندوب',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  Text(
                    widget.account.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'الإشعارات',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BusinessNotificationsScreen(
                        repository: widget.repository,
                      ),
                    ),
                  );
                  if (mounted) await load();
                },
                icon: const Icon(Icons.notifications_rounded),
              ),
              if (unreadNotifications > 0)
                PositionedDirectional(
                  top: 5,
                  end: 4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width > 1280
                ? (MediaQuery.sizeOf(context).width - 1240) / 2
                : 16,
            vertical: 16,
          ),
          children: [
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: BusinessBrand.heroGradient,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: BusinessBrand.navy.withValues(alpha: .16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: -26,
                    top: -34,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .06),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -18,
                    bottom: -45,
                    child: Container(
                      width: 145,
                      height: 145,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: BusinessBrand.teal.withValues(alpha: .18),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: LayoutBuilder(
                      builder: (context, heroConstraints) {
                        final compactHero = heroConstraints.maxWidth < 760;
                        final details = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مرحباً ${widget.account.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'طلباتك وتوصيلاتك ووصولاتك بمكان واحد',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (courierArea.isNotEmpty ||
                                courierAreas.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'مناطقك: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 11),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('متاح'),
                                  selected: availability == 'available',
                                  onSelected: (_) =>
                                      setAvailability('available'),
                                ),
                                ChoiceChip(
                                  label: const Text('مشغول'),
                                  selected: availability == 'busy',
                                  onSelected: (_) => setAvailability('busy'),
                                ),
                                ChoiceChip(
                                  label: const Text('خارج الخدمة'),
                                  selected: availability == 'offline',
                                  onSelected: (_) => setAvailability('offline'),
                                ),
                              ],
                            ),
                          ],
                        );

                        final icon = Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.delivery_dining_rounded,
                            color: Colors.white,
                            size: 31,
                          ),
                        );

                        if (compactHero) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              icon,
                              const SizedBox(height: 12),
                              details,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            icon,
                            const SizedBox(width: 13),
                            Expanded(child: details),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 6
                    : constraints.maxWidth >= 760
                    ? 3
                    : 2;
                final gap = 10.0;
                final width =
                    (constraints.maxWidth - (gap * (columns - 1))) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'طلبات جديدة',
                        value: '$newCount',
                        icon: Icons.fiber_new_rounded,
                        accent: BusinessBrand.orange,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'قيد التوصيل',
                        value: '$inDeliveryCount',
                        icon: Icons.delivery_dining_rounded,
                        accent: BusinessBrand.navy2,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'تم التسليم اليوم',
                        value: '$deliveredToday',
                        icon: Icons.today_rounded,
                        accent: BusinessBrand.teal,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'كل المكتملة',
                        value: '$completed',
                        icon: Icons.task_alt_rounded,
                        accent: BusinessBrand.teal,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'أجرة التوصيل',
                        value: money(profit),
                        icon: Icons.account_balance_wallet_rounded,
                        accent: BusinessBrand.navy,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'ذمتي للإدارة',
                        value: money(debt),
                        icon: Icons.account_balance_rounded,
                        accent: BusinessBrand.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, tabConstraints) {
                final wideTabs = tabConstraints.maxWidth >= 760;
                final tabs = SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'home',
                      label: Text('الرئيسية'),
                      icon: Icon(Icons.home_rounded),
                    ),
                    ButtonSegment(
                      value: 'active',
                      label: Text('طلبات التوصيل'),
                      icon: Icon(Icons.local_shipping_rounded),
                    ),
                    ButtonSegment(
                      value: 'completed',
                      label: Text('المكتملة'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'finance',
                      label: Text('الحسابات'),
                      icon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    ButtonSegment(
                      value: 'receipts',
                      label: Text('الوصولات'),
                      icon: Icon(Icons.receipt_long_rounded),
                    ),
                    ButtonSegment(
                      value: 'notifications',
                      label: Text('الإشعارات'),
                      icon: Icon(Icons.notifications_rounded),
                    ),
                    ButtonSegment(
                      value: 'profile',
                      label: Text('حسابي'),
                      icon: Icon(Icons.account_circle_rounded),
                    ),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) => _selectCourierTab(value.first),
                );
                if (wideTabs) {
                  return Align(alignment: Alignment.centerRight, child: tabs);
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabs,
                );
              },
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(error!),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else if (filter == 'home')
              _homeCenter(grouped)
            else if (filter == 'receipts')
              _receiptCenter(grouped)
            else ...[
              if (filter == 'active') _activeOrdersToolbar(grouped),
              if (filter == 'completed') _completedOrdersToolbar(),
              if (filter == 'active' || filter == 'completed')
                const SizedBox(height: 12),
              if (visibleOrders.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'لا توجد طلبات مطابقة حالياً',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                )
              else
                ...visibleOrders.map(orderCard),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectCourierTab(String value) async {
    if (value == 'finance') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessPartyFinanceScreen(
            repository: widget.repository,
            account: widget.account,
          ),
        ),
      );
      if (mounted) await load();
      return;
    }
    if (value == 'notifications') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              BusinessNotificationsScreen(repository: widget.repository),
        ),
      );
      if (mounted) await load();
      return;
    }
    if (value == 'profile') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourierProfileScreen(
            repository: widget.repository,
            account: widget.account,
          ),
        ),
      );
      if (mounted) await load();
      return;
    }
    setState(() => filter = value);
  }

  Widget _homeCenter(List<Map<String, dynamic>> grouped) {
    final current = grouped.where((o) => !isClosed(o)).take(5).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;
        final shortcutColumns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;

        final shortcuts = GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: shortcutColumns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: shortcutColumns == 1 ? 3.2 : 2.2,
          children: [
            _courierQuickCard(
              title: 'طلبات التوصيل',
              subtitle: 'الجديدة، المقبولة، المستلمة وبالطريق',
              emoji: '🛵',
              icon: Icons.local_shipping_rounded,
              accent: const Color(0xFFFF7A00),
              onTap: () => setState(() => filter = 'active'),
            ),
            _courierQuickCard(
              title: 'الوصولات',
              subtitle: 'الطلبات المكتملة ووصولات التسليم',
              emoji: '🧾',
              icon: Icons.receipt_long_rounded,
              accent: const Color(0xFFE11D8A),
              onTap: () => setState(() => filter = 'receipts'),
            ),
            _courierQuickCard(
              title: 'الحساب المالي',
              subtitle: 'الأجرة، الذمة، التسويات والوصولات',
              emoji: '💰',
              icon: Icons.account_balance_wallet_rounded,
              accent: const Color(0xFF00A86B),
              onTap: () => _selectCourierTab('finance'),
            ),
            _courierQuickCard(
              title: 'الإشعارات',
              subtitle: unreadNotifications > 0
                  ? '$unreadNotifications إشعار غير مقروء'
                  : 'لا توجد إشعارات جديدة',
              emoji: '🔔',
              icon: Icons.notifications_rounded,
              accent: const Color(0xFF7C3AED),
              onTap: () => _selectCourierTab('notifications'),
            ),
          ],
        );

        final statusCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF14B8A6).withValues(alpha: .18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14B8A6).withValues(alpha: .06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.work_history_rounded,
                    color: Color(0xFF14B8A6),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'حالة العمل',
                    style: TextStyle(
                      color: BusinessBrand.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                statusLabel(availability),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: BusinessBrand.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'مناطق العمل: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ').isEmpty ? 'غير محددة' : [courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}',
                style: const TextStyle(color: BusinessBrand.muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('متاح'),
                    selected: availability == 'available',
                    onSelected: (_) => setAvailability('available'),
                  ),
                  ChoiceChip(
                    label: const Text('مشغول'),
                    selected: availability == 'busy',
                    onSelected: (_) => setAvailability('busy'),
                  ),
                  ChoiceChip(
                    label: const Text('خارج الخدمة'),
                    selected: availability == 'offline',
                    onSelected: (_) => setAvailability('offline'),
                  ),
                ],
              ),
            ],
          ),
        );

        final ordersCard = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BusinessBrand.border),
            boxShadow: [
              BoxShadow(
                color: BusinessBrand.navy.withValues(alpha: .05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'طلبات تحتاج متابعة',
                      style: TextStyle(
                        color: BusinessBrand.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => filter = 'active'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 17),
                    label: const Text('عرض الكل'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (current.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('لا توجد طلبات حالياً'),
                )
              else
                ...current.map((order) {
                  final accent = _courierStatusColor(
                    '${order['status'] ?? ''}',
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: accent.withValues(alpha: .13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.delivery_dining_rounded,
                            color: accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'طلب #${order['order_number'] ?? order['id'] ?? '—'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BusinessBrand.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${order['delivery_area'] ?? '—'} • ${order['_item_count'] ?? 1} مادة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BusinessBrand.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          statusLabel('${order['status'] ?? ''}'),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الوصول السريع',
                style: TextStyle(
                  color: BusinessBrand.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            shortcuts,
            const SizedBox(height: 12),
            if (!desktop) ...[
              statusCard,
              const SizedBox(height: 10),
              ordersCard,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: statusCard),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: ordersCard),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _courierQuickCard({
    required String title,
    required String subtitle,
    required String emoji,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
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
                  color: Colors.white.withValues(alpha: .94),
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
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10.5,
                        height: 1.25,
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

  Widget _receiptCenter(List<Map<String, dynamic>> grouped) {
    final completed = grouped.where(isDone).toList();
    final query = receiptSearch.trim().toLowerCase();
    final visible = completed.where((order) {
      if (query.isEmpty) return true;
      final items = (order['_items'] as List? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      final haystack = [
        order['order_number'],
        order['id'],
        order['student_name'],
        order['student_phone'],
        ...items.map(
          (item) => item['title'] ?? item['product_name'] ?? item['item_name'],
        ),
      ].map((value) => '${value ?? ''}'.toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();
    final totalAmounts = completed.fold<num>(
      0,
      (sum, order) => sum + number(order['_group_total']),
    );
    final totalDelivery = completed.fold<num>(
      0,
      (sum, order) => sum + number(order['_courier_fee']),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: BusinessBrand.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: BusinessBrand.softBlue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: BusinessBrand.navy,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الوصولات',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: BusinessBrand.navy,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'وصولات الطلبات المكتملة بصورة مرتبة مثل صفحة الويب القديمة.',
                          style: TextStyle(
                            fontSize: 13,
                            color: BusinessBrand.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: BusinessBrand.navy,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${completed.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: desktop
                      ? (constraints.maxWidth - 30) / 4
                      : (constraints.maxWidth - 10) / 2,
                  child: _Metric(
                    label: 'جميع الوصولات',
                    value: '${completed.length}',
                    icon: Icons.receipt_long_rounded,
                    accent: BusinessBrand.navy,
                  ),
                ),
                SizedBox(
                  width: desktop
                      ? (constraints.maxWidth - 30) / 4
                      : (constraints.maxWidth - 10) / 2,
                  child: _Metric(
                    label: 'الطلبات المكتملة',
                    value: '${completed.length}',
                    icon: Icons.task_alt_rounded,
                    accent: BusinessBrand.teal,
                  ),
                ),
                SizedBox(
                  width: desktop
                      ? (constraints.maxWidth - 30) / 4
                      : (constraints.maxWidth - 10) / 2,
                  child: _Metric(
                    label: 'إجمالي مبالغ الطلبات',
                    value: money(totalAmounts),
                    icon: Icons.payments_rounded,
                    accent: BusinessBrand.orange,
                  ),
                ),
                SizedBox(
                  width: desktop
                      ? (constraints.maxWidth - 30) / 4
                      : (constraints.maxWidth - 10) / 2,
                  child: _Metric(
                    label: 'أجرة التوصيل',
                    value: money(totalDelivery),
                    icon: Icons.account_balance_wallet_rounded,
                    accent: BusinessBrand.navy2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => receiptSearch = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'بحث في الوصولات',
                hintText: 'رقم الوصول أو الطلب أو اسم الطالب أو المادة',
              ),
            ),
            const SizedBox(height: 12),
            if (desktop)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: BusinessBrand.softBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 178,
                      child: Text(
                        'رقم الوصول / الطلب',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        'النوع',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'التاريخ',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 118,
                      child: Text(
                        'المبلغ',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 76,
                      child: Text(
                        'الحالة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 262,
                      child: Text(
                        'الإجراءات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (desktop) const SizedBox(height: 8),
            if (completed.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'لا توجد وصولات مكتملة بعد',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else if (visible.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'لا توجد نتائج مطابقة للبحث',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...visible.map(
                (order) => GroupedOrderReceiptListTile(
                  order: order,
                  courierName: widget.account.name,
                  courierView: true,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _activeOrdersToolbar(List<Map<String, dynamic>> grouped) {
    final filters = <(String, String, String, Color)>[
      ('all', 'الكل', '🚚', BusinessBrand.navy),
      ('new', 'جديد', '🆕', BusinessBrand.orange),
      ('accepted', 'مقبول', '✅', const Color(0xFF7C3AED)),
      ('picked_up', 'مستلم', '📦', const Color(0xFF0088FF)),
      ('delivery', 'بالطريق', '🛵', BusinessBrand.teal),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessBrand.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: (value) => setState(() => orderSearch = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'بحث في طلبات التوصيل',
              hintText: 'رقم الطلب، الطالب، الهاتف، المنطقة أو المادة',
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((item) {
                final selected = orderStageFilter == item.$1;
                final count = item.$1 == 'all'
                    ? grouped.where((o) => !isClosed(o)).length
                    : _stageCount(grouped, item.$1);
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 7),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => orderStageFilter = item.$1),
                    label: Text('${item.$3} ${item.$2}  $count'),
                    selectedColor: item.$4,
                    backgroundColor: item.$4.withValues(alpha: .07),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : item.$4,
                      fontWeight: FontWeight.w900,
                    ),
                    side: BorderSide(
                      color: item.$4.withValues(alpha: selected ? 1 : .18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedOrdersToolbar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessBrand.border),
      ),
      child: TextField(
        onChanged: (value) => setState(() => orderSearch = value),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded),
          labelText: 'بحث في الطلبات المكتملة',
          hintText: 'رقم الطلب، الطالب، الهاتف، المنطقة أو المادة',
        ),
      ),
    );
  }

  Color _courierStatusColor(String status) => switch (status) {
    'assigned' || 'new' || 'pending' || 'pending_admin' =>
      BusinessBrand.orange,
    'accepted' => const Color(0xFF7C3AED),
    'picked_up' => const Color(0xFF0088FF),
    'out_for_delivery' || 'out_delivery' => BusinessBrand.teal,
    'completed' || 'delivered' => const Color(0xFF16A34A),
    'cancelled' || 'rejected' => const Color(0xFFE11D48),
    _ => BusinessBrand.navy,
  };

  Widget orderCard(Map<String, dynamic> order) {
    final status = '${order['status'] ?? 'assigned'}';
    final id = '${order['id']}';
    final key = '${order['_group_key'] ?? id}';
    final busy = busyOrders.contains(key);
    final phone = '${order['student_phone'] ?? ''}';
    final pickup = '${order['pickup_source_label'] ?? ''}'.trim();
    final preferred = areaPriority(order) == 0;
    final items = (order['_items'] as List? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final itemCount = number(order['_item_count']).toInt();
    final qtyCount = number(order['_qty_count']).toInt();
    final mixedStatus = order['_mixed_status'] == true;
    final accent = _courierStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.delivery_dining_rounded,
                    color: accent,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order['order_number'] ?? id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BusinessBrand.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemCount > 1
                            ? '$itemCount مواد • $qtyCount قطعة/نسخة'
                            : '${order['title'] ?? 'طلب توصيل'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BusinessBrand.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: accent.withValues(alpha: .22),
                        ),
                      ),
                      child: Text(
                        mixedStatus ? 'حالة غير موحدة' : statusLabel(status),
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (preferred) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: BusinessBrand.teal.withValues(alpha: .09),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text(
                          'ضمن منطقتك',
                          style: TextStyle(
                            color: BusinessBrand.teal,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
                  _courierInfoLine(
                    Icons.person_rounded,
                    'الطالب',
                    '${order['student_name'] ?? '—'}',
                  ),
                  const SizedBox(height: 7),
                  _courierInfoLine(
                    Icons.phone_rounded,
                    'الهاتف',
                    phone.isEmpty ? '—' : phone,
                  ),
                  const SizedBox(height: 7),
                  _courierInfoLine(
                    Icons.location_on_rounded,
                    'المنطقة',
                    '${order['delivery_area'] ?? '—'}',
                  ),
                  const SizedBox(height: 7),
                  _courierInfoLine(
                    Icons.flag_rounded,
                    'نقطة دالة',
                    '${order['delivery_landmark'] ?? '—'}',
                  ),
                  if (pickup.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _courierInfoLine(
                      Icons.inventory_2_rounded,
                      'الاستلام من',
                      pickup,
                    ),
                  ],
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
                        color: BusinessBrand.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ...items.take(4).map((item) {
                      final qty = number(item['qty'] ?? 1).toInt();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '• ${item['title'] ?? 'مادة'} × $qty',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF475467),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              money(item['total']),
                              style: const TextStyle(
                                color: BusinessBrand.navy,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 650 ? 3 : 1;
                final gap = 8.0;
                final width = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: _courierAmountCard(
                        'المبلغ المطلوب',
                        money(order['_group_total']),
                        Icons.payments_rounded,
                        const Color(0xFFFF7A00),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _courierAmountCard(
                        'توصيل الطالب',
                        money(order['_delivery_fee']),
                        Icons.local_shipping_rounded,
                        const Color(0xFF0088FF),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _courierAmountCard(
                        'أجرة المندوب',
                        money(order['_courier_fee']),
                        Icons.account_balance_wallet_rounded,
                        const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                );
              },
            ),
            if ('${order['delivery_note'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFFFD9A3)),
                ),
                child: Text(
                  'ملاحظتك: ${order['delivery_note']}',
                  style: const TextStyle(
                    color: Color(0xFF8A4B08),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openPhone(phone),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('اتصال'),
                  ),
                if (phone.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => openWhatsApp(phone),
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('واتساب'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openMap(order),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('المسار'),
                ),
                if (!isClosed(order))
                  OutlinedButton.icon(
                    onPressed: () => sendNote(order),
                    icon: const Icon(Icons.note_alt_rounded),
                    label: const Text('ملاحظة'),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            _courierProgressBar(status),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: accent.withValues(alpha: .12)),
              ),
              child: mixedStatus
                  ? const Text(
                      'هذا طلب قديم بحالات مواد مختلفة؛ وحّد حالاته من الإدارة قبل متابعة التوصيل.',
                      style: TextStyle(
                        color: Color(0xFFE11D48),
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : busy
                  ? LinearProgressIndicator(color: accent)
                  : _actions(order, status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courierInfoLine(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF667085)),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
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
            style: TextStyle(
              color: valueColor ?? const Color(0xFF143B68),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _courierAmountCard(
    String label,
    String value,
    IconData icon,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .09),
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
                    fontSize: 13,
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

  Widget _actions(Map<String, dynamic> order, String status) {
    if (['assigned', 'new', 'pending', 'pending_admin'].contains(status)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: () => transition(order, 'accepted'),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('قبول الطلب والبدء'),
          ),
          const SizedBox(height: 7),
          OutlinedButton.icon(
            onPressed: () => reject(order),
            icon: const Icon(Icons.close_rounded),
            label: const Text('رفض الطلب'),
          ),
        ],
      );
    }
    if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          onPressed: () => transition(order, 'picked_up'),
          icon: const Icon(Icons.inventory_2_rounded),
          label: const Text('استلمت الطلب بالكامل'),
        ),
      );
    }
    if (status == 'picked_up') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          onPressed: () => transition(order, 'out_for_delivery'),
          icon: const Icon(Icons.delivery_dining_rounded),
          label: const Text('بدء التوصيل للطالب'),
        ),
      );
    }
    if (['out_for_delivery', 'out_delivery'].contains(status)) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF16A34A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          onPressed: () => transition(order, 'completed'),
          icon: const Icon(Icons.done_all_rounded),
          label: const Text('تم التسليم واستلام المبلغ'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _courierProgressBar(String status) {
    final steps = <(String, String, IconData)>[
      ('accepted', 'مقبول', Icons.check_circle_rounded),
      ('picked_up', 'مستلم', Icons.inventory_2_rounded),
      ('out_for_delivery', 'بالطريق', Icons.delivery_dining_rounded),
      ('completed', 'تم التسليم', Icons.done_all_rounded),
    ];

    int currentIndex = switch (status) {
      'assigned' || 'new' || 'pending' || 'pending_admin' => -1,
      'accepted' => 0,
      'picked_up' => 1,
      'out_for_delivery' || 'out_delivery' => 2,
      'completed' || 'delivered' => 3,
      _ => -1,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: i <= currentIndex
                          ? const Color(0xFF143B68)
                          : const Color(0xFFE8EEF5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      steps[i].$3,
                      size: 16,
                      color: i <= currentIndex
                          ? Colors.white
                          : const Color(0xFF98A2B3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: i <= currentIndex
                          ? const Color(0xFF143B68)
                          : const Color(0xFF98A2B3),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (i != steps.length - 1)
              Container(
                width: 18,
                height: 2,
                color: i < currentIndex
                    ? const Color(0xFF143B68)
                    : const Color(0xFFD6DFE9),
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(accent, Colors.black, .10)!;

    return Container(
      constraints: const BoxConstraints(minHeight: 118),
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
            top: 58,
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
                    fontSize: 27,
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
}
