import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';
import 'admin_delivery_pricing_screen.dart';
import 'admin_finance_v2_screen.dart';

class AdminCourierHubScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminCourierHubScreen({super.key, required this.repository});

  @override
  State<AdminCourierHubScreen> createState() => _AdminCourierHubScreenState();
}

class _AdminCourierHubScreenState extends State<AdminCourierHubScreen> {
  bool loading = true;
  String? error;
  String search = '';
  List<Map<String, dynamic>> couriers = [];
  List<Map<String, dynamic>> orders = [];

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
        widget.repository.adminAccounts(),
        widget.repository.adminOrders(),
      ]);
      if (!mounted) return;
      final accounts = values[0];
      setState(() {
        couriers = accounts
            .where(
              (e) =>
                  const {'courier', 'delegate'}.contains('${e['role']}') &&
                  e['deleted_at'] == null,
            )
            .toList();
        orders = values[1];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;

  bool isClosed(Map<String, dynamic> order) => const {
    'completed',
    'delivered',
    'done',
    'cancelled',
    'canceled',
    'rejected',
  }.contains('${order['status'] ?? ''}'.toLowerCase());

  List<Map<String, dynamic>> ordersFor(String courierId) => orders.where((row) {
    final id = '${row['courier_id'] ?? row['delegate_id'] ?? ''}';
    return id == courierId;
  }).toList();

  List<Map<String, dynamic>> get filtered {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return couriers;
    return couriers.where((row) {
      final text =
          '${row['name'] ?? ''} ${row['username'] ?? ''} ${row['phone'] ?? ''} ${row['area'] ?? ''}'
              .toLowerCase();
      return text.contains(q);
    }).toList();
  }

  String statusLabel(dynamic value) => switch ('${value ?? ''}'.toLowerCase()) {
    'active' || 'available' => 'فعال / متاح',
    'busy' => 'مشغول',
    'offline' => 'خارج الخدمة',
    'inactive' => 'غير فعال',
    'pending' => 'معلق',
    _ => '${value ?? '—'}',
  };

  @override
  Widget build(BuildContext context) {
    final active = couriers.where((e) => '${e['status']}' == 'active').length;
    final currentOrders = orders.where((e) {
      final courier = '${e['courier_id'] ?? e['delegate_id'] ?? ''}';
      return courier.isNotEmpty && !isClosed(e);
    }).length;
    final completedOrders = orders.where((e) {
      final courier = '${e['courier_id'] ?? e['delegate_id'] ?? ''}';
      return courier.isNotEmpty &&
          isClosed(e) &&
          '${e['status']}'.toLowerCase() != 'cancelled';
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز المندوبين'),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, c) {
                      final count = c.maxWidth >= 900 ? 4 : 2;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: count,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: c.maxWidth >= 900 ? 2.25 : 1.5,
                        children: [
                          _metric(
                            'كل المندوبين',
                            '${couriers.length}',
                            Icons.groups_rounded,
                          ),
                          _metric(
                            'الفعالون',
                            '$active',
                            Icons.check_circle_rounded,
                          ),
                          _metric(
                            'طلبات حالية',
                            '$currentOrders',
                            Icons.local_shipping_rounded,
                          ),
                          _metric(
                            'طلبات مكتملة',
                            '$completedOrders',
                            Icons.task_alt_rounded,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: (value) => setState(() => search = value),
                        decoration: const InputDecoration(
                          labelText: 'بحث بالمندوب',
                          hintText: 'الاسم أو الهاتف أو المنطقة',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: Text('لا يوجد مندوبون')),
                      ),
                    )
                  else
                    ...filtered.map(_courierCard),
                ],
              ),
            ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: BusinessBrand.heroGradient,
      borderRadius: BorderRadius.circular(24),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final title = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة المندوبين والتوصيل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'المندوبون والطلبات والمناطق والحسابات في مركز واحد.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: BusinessBrand.navy,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AdminDeliveryPricingScreen(repository: widget.repository),
                ),
              ),
              icon: const Icon(Icons.map_rounded),
              label: const Text('المناطق والأسعار'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AdminFinanceV2Screen(repository: widget.repository),
                ),
              ),
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('الحسابات'),
            ),
          ],
        );
        if (c.maxWidth >= 750)
          return Row(
            children: [
              Expanded(child: title),
              actions,
            ],
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [title, const SizedBox(height: 14), actions],
        );
      },
    ),
  );

  Widget _metric(String label, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: BusinessBrand.softBlue,
            child: Icon(icon, color: BusinessBrand.navy),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _courierCard(Map<String, dynamic> courier) {
    final id = '${courier['id'] ?? ''}';
    final assigned = ordersFor(id);
    final current = assigned.where((e) => !isClosed(e)).length;
    final done = assigned.where(isClosed).length;
    final availability =
        '${courier['availability'] ?? courier['courier_status'] ?? courier['status'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final info = Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: BusinessBrand.softBlue,
                  child: Text(
                    '${courier['name'] ?? 'م'}'.isEmpty
                        ? 'م'
                        : '${courier['name'] ?? 'م'}'.substring(0, 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: BusinessBrand.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${courier['name'] ?? courier['username'] ?? 'مندوب'}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${courier['phone'] ?? 'بدون هاتف'} • ${courier['area'] ?? 'بدون منطقة'}',
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          Chip(label: Text(statusLabel(availability))),
                          Chip(label: Text('الحالية $current')),
                          Chip(label: Text('المكتملة $done')),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
            if (c.maxWidth < 700) return info;
            return Row(
              children: [
                Expanded(child: info),
                Text(
                  'إجمالي الطلبات ${assigned.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: BusinessBrand.navy,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
