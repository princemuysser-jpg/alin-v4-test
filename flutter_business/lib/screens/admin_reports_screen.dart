import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../widgets/business_brand.dart';

class AdminReportsScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminReportsScreen({super.key, required this.repository});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool loading = true;
  String? error;
  String period = 'all';
  String kind = 'all';
  String search = '';
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> ledger = [];
  List<Map<String, dynamic>> accounts = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  num n(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${n(value).round()} د.ع';

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.adminOrders(),
        widget.repository.adminLedger(),
        widget.repository.adminAccounts(),
      ]);
      if (!mounted) return;
      setState(() {
        orders = (values[0] as List).cast<Map<String, dynamic>>();
        ledger = (values[1] as List).cast<Map<String, dynamic>>();
        accounts = (values[2] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  DateTime? orderDate(Map<String, dynamic> row) =>
      DateTime.tryParse('${row['created_at'] ?? row['updated_at'] ?? ''}')?.toLocal();

  bool inPeriod(Map<String, dynamic> row) {
    if (period == 'all') return true;
    final date = orderDate(row);
    if (date == null) return false;
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    if (period == 'today') return !date.isBefore(startToday);
    if (period == 'week') return !date.isBefore(startToday.subtract(const Duration(days: 6)));
    if (period == 'month') return date.year == now.year && date.month == now.month;
    return true;
  }

  bool isBooklet(Map<String, dynamic> row) {
    final value = '${row['kind'] ?? ''}'.toLowerCase();
    return value.contains('book') || value.contains('booklet') || value.contains('mulazama');
  }

  List<Map<String, dynamic>> get filteredOrders {
    final q = search.trim().toLowerCase();
    return orders.where((row) {
      if (!inPeriod(row)) return false;
      if (kind == 'booklet' && !isBooklet(row)) return false;
      if (kind == 'product' && isBooklet(row)) return false;
      if (q.isEmpty) return true;
      final text = '${row['order_number'] ?? ''} ${row['student_name'] ?? ''} ${row['title'] ?? ''}'.toLowerCase();
      return text.contains(q);
    }).toList();
  }

  Set<String> orderKeys(Map<String, dynamic> row) => {
        '${row['id'] ?? ''}',
        '${row['order_number'] ?? ''}',
      }..remove('');

  Set<String> ledgerKeys(Map<String, dynamic> row) => {
        '${row['order_id'] ?? ''}',
        '${row['order_number'] ?? ''}',
      }..remove('');

  List<Map<String, dynamic>> get filteredLedger {
    if (period == 'all' && kind == 'all' && search.trim().isEmpty) return ledger;
    final allowed = filteredOrders.expand(orderKeys).toSet();
    return ledger.where((row) => ledgerKeys(row).any(allowed.contains)).toList();
  }

  String accountName(String id, String fallback) {
    final match = accounts.where((row) => '${row['id']}' == id).cast<Map<String, dynamic>>().toList();
    if (match.isEmpty) return fallback;
    final row = match.first;
    return '${row['name'] ?? row['username'] ?? fallback}';
  }

  Map<String, Map<String, dynamic>> rankBy(Iterable<Map<String, dynamic>> rows, String Function(Map<String, dynamic>) keyOf, String Function(Map<String, dynamic>) labelOf) {
    final result = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final key = keyOf(row).trim();
      if (key.isEmpty) continue;
      final current = result.putIfAbsent(key, () => {'label': labelOf(row), 'qty': 0, 'total': 0});
      current['qty'] = n(current['qty']) + (n(row['qty']) <= 0 ? 1 : n(row['qty']));
      current['total'] = n(current['total']) + n(row['total']);
    }
    return result;
  }

  List<Map<String, dynamic>> sortedRank(Map<String, Map<String, dynamic>> map) {
    final values = map.values.toList();
    values.sort((a, b) {
      final byQty = n(b['qty']).compareTo(n(a['qty']));
      return byQty != 0 ? byQty : n(b['total']).compareTo(n(a['total']));
    });
    return values.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = filteredOrders;
    final moneyRows = filteredLedger;
    final sales = moneyRows.fold<num>(0, (sum, row) => sum + n(row['total']));
    final platform = moneyRows.fold<num>(0, (sum, row) => sum + n(row['admin'] ?? row['alin']));
    final teachers = moneyRows.fold<num>(0, (sum, row) => sum + n(row['teacher']));
    final libraries = moneyRows.fold<num>(0, (sum, row) => sum + n(row['library']));
    final couriers = moneyRows.fold<num>(0, (sum, row) => sum + n(row['courier'] ?? row['delegate']));

    final completed = rows.where((row) => const {'completed', 'delivered', 'done', 'received'}.contains('${row['status']}'.toLowerCase())).length;
    final cancelled = rows.where((row) => const {'cancelled', 'canceled', 'rejected'}.contains('${row['status']}'.toLowerCase())).length;

    final topItems = sortedRank(rankBy(rows, (row) => '${row['item_id'] ?? row['title'] ?? ''}', (row) => '${row['title'] ?? 'عنصر'}'));
    final topLibraries = sortedRank(rankBy(
      rows,
      (row) => '${row['library_id'] ?? row['pickup_library_id'] ?? ''}',
      (row) {
        final id = '${row['library_id'] ?? row['pickup_library_id'] ?? ''}';
        return accountName(id, 'مكتبة');
      },
    ));
    final topCouriers = sortedRank(rankBy(
      rows,
      (row) => '${row['courier_id'] ?? row['delegate_id'] ?? ''}',
      (row) {
        final id = '${row['courier_id'] ?? row['delegate_id'] ?? ''}';
        return accountName(id, 'مندوب');
      },
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والتحليلات'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _filters(),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, c) {
                          final count = c.maxWidth >= 1100 ? 4 : 2;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: count,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: c.maxWidth >= 1100 ? 2.3 : 1.5,
                            children: [
                              _metric('عدد الطلبات', '${rows.length}', Icons.receipt_long_rounded),
                              _metric('مكتملة', '$completed', Icons.task_alt_rounded),
                              _metric('ملغاة', '$cancelled', Icons.cancel_outlined),
                              _metric('إجمالي المبيعات', money(sales), Icons.payments_rounded),
                              _metric('ربح المنصة', money(platform), Icons.trending_up_rounded),
                              _metric('حصة المدرسين', money(teachers), Icons.school_rounded),
                              _metric('حصة المكتبات', money(libraries), Icons.store_rounded),
                              _metric('حصة المندوبين', money(couriers), Icons.delivery_dining_rounded),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, c) {
                          final desktop = c.maxWidth >= 950;
                          final cards = [
                            _rankCard('الأكثر مبيعاً', topItems, Icons.workspace_premium_rounded),
                            _rankCard('أفضل المكتبات', topLibraries, Icons.storefront_rounded),
                            _rankCard('أفضل المندوبين', topCouriers, Icons.delivery_dining_rounded),
                          ];
                          return desktop
                              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: cards.map((e) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: e))).toList())
                              : Column(children: cards.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10), child: e)).toList());
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('تفاصيل الطلبات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, c) => c.maxWidth >= 850 ? _table(rows) : _cards(rows),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _filters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 800;
            final fields = [
              DropdownButtonFormField<String>(
                value: period,
                decoration: const InputDecoration(labelText: 'الفترة'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كل الفترات')),
                  DropdownMenuItem(value: 'today', child: Text('اليوم')),
                  DropdownMenuItem(value: 'week', child: Text('آخر 7 أيام')),
                  DropdownMenuItem(value: 'month', child: Text('هذا الشهر')),
                ],
                onChanged: (v) => setState(() => period = v ?? 'all'),
              ),
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'booklet', child: Text('الملازم')),
                  DropdownMenuItem(value: 'product', child: Text('المنتجات')),
                ],
                onChanged: (v) => setState(() => kind = v ?? 'all'),
              ),
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(labelText: 'بحث', prefixIcon: Icon(Icons.search_rounded), hintText: 'رقم الطلب أو الطالب أو العنصر'),
              ),
            ];
            if (wide) {
              return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 10), Expanded(child: fields[1]), const SizedBox(width: 10), Expanded(flex: 2, child: fields[2])]);
            }
            return Column(children: [fields[0], const SizedBox(height: 10), fields[1], const SizedBox(height: 10), fields[2]]);
          },
        ),
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: BusinessBrand.border)),
        child: Row(children: [
          CircleAvatar(backgroundColor: BusinessBrand.softBlue, child: Icon(icon, color: BusinessBrand.navy)),
          const SizedBox(width: 10),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BusinessBrand.navy)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  Widget _rankCard(String title, List<Map<String, dynamic>> rows, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: BusinessBrand.navy), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text('لا توجد بيانات كافية')
            else
              ...rows.asMap().entries.map((entry) {
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    CircleAvatar(radius: 13, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11))),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${row['label'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${n(row['qty']).round()} • ${money(row['total'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                );
              }),
          ]),
        ),
      );

  Widget _table(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات ضمن الفلتر'))));
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('رقم الطلب')),
            DataColumn(label: Text('الطالب')),
            DataColumn(label: Text('العنصر')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('المبلغ')),
          ],
          rows: rows.take(300).map((row) => DataRow(cells: [
                DataCell(Text('${row['order_number'] ?? row['id'] ?? '—'}')),
                DataCell(Text('${row['student_name'] ?? '—'}')),
                DataCell(SizedBox(width: 220, child: Text('${row['title'] ?? '—'}', overflow: TextOverflow.ellipsis))),
                DataCell(Text('${row['status'] ?? '—'}')),
                DataCell(Text(_date(row['created_at']))),
                DataCell(Text(money(row['total']))),
              ])).toList(),
        ),
      ),
    );
  }

  Widget _cards(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات ضمن الفلتر'))));
    return Column(children: rows.take(300).map((row) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('${row['order_number'] ?? row['id'] ?? '—'} — ${row['title'] ?? 'طلب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${row['student_name'] ?? '—'} • ${_date(row['created_at'])} • ${row['status'] ?? '—'}'),
            trailing: Text(money(row['total']), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        )).toList());
  }

  String _date(dynamic value) {
    final raw = '${value ?? ''}';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    return '${parsed.year}/${parsed.month.toString().padLeft(2, '0')}/${parsed.day.toString().padLeft(2, '0')}';
  }
}
