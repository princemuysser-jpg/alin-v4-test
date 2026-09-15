from pathlib import Path

path = Path('flutter_business/lib/screens/courier_dashboard_screen.dart')
text = path.read_text(encoding='utf-8')
marker = '// Courier old-web parity Build 17'
if marker in text:
    print('Courier parity patch already applied')
    raise SystemExit(0)

replacements = []

def replace_once(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f'Missing target: {label}')
    text = text.replace(old, new, 1)
    replacements.append(label)

replace_once(
"import '../data/business_courier_repository.dart';\nimport '../data/business_repository.dart';\nimport '../models/business_account.dart';\nimport '../widgets/business_brand.dart';\nimport '../widgets/grouped_order_receipt_list.dart';",
"import '../data/business_courier_repository.dart';\nimport '../data/business_finance_repository.dart';\nimport '../data/business_repository.dart';\nimport '../models/business_account.dart';\nimport '../widgets/business_brand.dart';\nimport '../widgets/grouped_order_receipt_list.dart';\nimport 'business_notifications_screen.dart';\nimport 'business_party_finance_screen.dart';\nimport 'courier_profile_screen.dart';\n\n// Courier old-web parity Build 17",
'import parity dependencies',
)

replace_once(
"  String filter = 'active';\n  String receiptSearch = '';\n  String availability = 'available';",
"  String filter = 'home';\n  String receiptSearch = '';\n  String availability = 'available';\n  Map<String, dynamic> financeSummary = {};",
'courier state',
)

replace_once(
"      final values = await Future.wait([\n        widget.repository.courierGroupedOrderRows(widget.account.id),\n        widget.repository.courierProfile(),\n      ]);\n      if (!mounted) return;\n      final profile = Map<String, dynamic>.from(values[1] as Map);",
"      final values = await Future.wait([\n        widget.repository.courierGroupedOrderRows(widget.account.id),\n        widget.repository.courierProfile(),\n      ]);\n      Map<String, dynamic> finance = {};\n      try {\n        finance = await widget.repository.financePartySummaryV2(\n          role: 'delegate',\n          partyId: widget.account.id,\n        );\n      } catch (_) {\n        // Orders must remain usable even if the finance summary is unavailable.\n      }\n      if (!mounted) return;\n      final profile = Map<String, dynamic>.from(values[1] as Map);",
'load finance summary',
)

replace_once(
"        courierAreas = areas;\n      });",
"        courierAreas = areas;\n        financeSummary = finance;\n      });",
'assign finance summary',
)

replace_once(
"    final grouped = groupedOrders;\n    final active = grouped.where((o) => !isClosed(o)).length;\n    final completed = grouped.where(isDone).length;\n    final profit = grouped\n        .where(isDone)\n        .fold<num>(0, (sum, o) => sum + number(o['_courier_fee']));",
"    final grouped = groupedOrders;\n    final newCount = grouped.where((o) {\n      final status = '${o['status'] ?? ''}';\n      return const {'assigned', 'new', 'pending_admin'}.contains(status);\n    }).length;\n    final inDeliveryCount = grouped.where((o) {\n      final status = '${o['status'] ?? ''}';\n      return const {\n        'accepted',\n        'picked_up',\n        'out_for_delivery',\n        'out_delivery',\n        'processing',\n      }.contains(status);\n    }).length;\n    final completed = grouped.where(isDone).length;\n    final today = DateTime.now();\n    final deliveredToday = grouped.where((o) {\n      if (!isDone(o)) return false;\n      final value = o['delivered_at'] ?? o['completed_at'] ?? o['updated_at'];\n      final date = DateTime.tryParse('${value ?? ''}')?.toLocal();\n      return date != null &&\n          date.year == today.year &&\n          date.month == today.month &&\n          date.day == today.day;\n    }).length;\n    final profit = grouped\n        .where(isDone)\n        .fold<num>(0, (sum, o) => sum + number(o['_courier_fee']));\n    final debt = number(\n      financeSummary['remaining'] ?? financeSummary['debt_total'],\n    );",
'old web metrics data',
)

old_metrics = """                final columns = constraints.maxWidth >= 900 ? 4 : 2;
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
                        label: 'قيد التنفيذ',
                        value: '$active',
                        icon: Icons.delivery_dining_rounded,
                        accent: BusinessBrand.orange,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'مكتملة',
                        value: '$completed',
                        icon: Icons.task_alt_rounded,
                        accent: BusinessBrand.teal,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'كل الطلبات',
                        value: '${grouped.length}',
                        icon: Icons.inventory_2_rounded,
                        accent: BusinessBrand.navy2,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: 'أجور التوصيل',
                        value: money(profit),
                        icon: Icons.account_balance_wallet_rounded,
                        accent: BusinessBrand.navy,
                      ),
                    ),
                  ],
                );"""
new_metrics = """                final columns = constraints.maxWidth >= 1100
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
                );"""
replace_once(old_metrics, new_metrics, 'six courier metrics')

old_tabs = """                  segments: const [
                    ButtonSegment(
                      value: 'active',
                      label: Text('الحالية'),
                      icon: Icon(Icons.local_shipping_rounded),
                    ),
                    ButtonSegment(
                      value: 'completed',
                      label: Text('المكتملة'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'all',
                      label: Text('الكل'),
                      icon: Icon(Icons.list_alt_rounded),
                    ),
                    ButtonSegment(
                      value: 'receipts',
                      label: Text('الوصولات'),
                      icon: Icon(Icons.receipt_long_rounded),
                    ),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) =>
                      setState(() => filter = value.first),"""
new_tabs = """                  segments: const [
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
                  onSelectionChanged: (value) => _selectCourierTab(value.first),"""
replace_once(old_tabs, new_tabs, 'old web courier tabs')

replace_once(
"            else if (filter == 'receipts')\n              _receiptCenter(grouped)\n            else if (visibleOrders.isEmpty)",
"            else if (filter == 'home')\n              _homeCenter(grouped)\n            else if (filter == 'receipts')\n              _receiptCenter(grouped)\n            else if (visibleOrders.isEmpty)",
'home body',
)

anchor = "  Widget _receiptCenter(List<Map<String, dynamic>> grouped) {"
if anchor not in text:
    raise SystemExit('Missing target: receipt center anchor')
insert = r'''  Future<void> _selectCourierTab(String value) async {
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
          builder: (_) => BusinessNotificationsScreen(
            repository: widget.repository,
          ),
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
        final statusCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.work_history_rounded, color: BusinessBrand.navy),
                    SizedBox(width: 8),
                    Text(
                      'حالة العمل',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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
          ),
        );

        final ordersCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'طلبات تحتاج متابعة',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => filter = 'active'),
                      child: const Text('عرض الكل'),
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
                  ...current.map(
                    (order) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: BusinessBrand.softBlue,
                        child: Icon(
                          Icons.delivery_dining_rounded,
                          color: BusinessBrand.navy,
                        ),
                      ),
                      title: Text(
                        '${order['order_number'] ?? order['id'] ?? 'طلب'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${order['delivery_area'] ?? '—'} • ${order['_item_count'] ?? 1} مادة',
                      ),
                      trailing: Text(
                        statusLabel('${order['status'] ?? ''}'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: BusinessBrand.navy,
                        ),
                      ),
                      onTap: () => setState(() => filter = 'active'),
                    ),
                  ),
              ],
            ),
          ),
        );

        if (!desktop) {
          return Column(children: [statusCard, const SizedBox(height: 10), ordersCard]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: statusCard),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ordersCard),
          ],
        );
      },
    );
  }

'''
text = text.replace(anchor, insert + anchor, 1)
replacements.append('home/tools methods')

path.write_text(text, encoding='utf-8')
print('Applied:', ', '.join(replacements))
