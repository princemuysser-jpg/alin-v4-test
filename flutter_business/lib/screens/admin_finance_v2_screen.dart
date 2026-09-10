import 'package:flutter/material.dart';

import '../data/business_finance_repository.dart';
import '../data/business_repository.dart';

class AdminFinanceV2Screen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminFinanceV2Screen({super.key, required this.repository});

  @override
  State<AdminFinanceV2Screen> createState() => _AdminFinanceV2ScreenState();
}

class _AdminFinanceV2ScreenState extends State<AdminFinanceV2Screen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> overview = {};
  List<Map<String, dynamic>> accounts = [];
  List<Map<String, dynamic>> settlements = [];
  List<Map<String, dynamic>> suppliers = [];
  String roleFilter = 'all';

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
        widget.repository.adminFinanceOverviewV2(),
        widget.repository.adminAccounts(),
        widget.repository.adminSettlements(),
        widget.repository.adminBookSupplierBalancesV2(),
      ]);
      if (!mounted) return;
      setState(() {
        overview = Map<String, dynamic>.from(values[0] as Map);
        accounts = (values[1] as List).cast<Map<String, dynamic>>();
        settlements = (values[2] as List).cast<Map<String, dynamic>>();
        suppliers = (values[3] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get financeAccounts {
    final rows = accounts.where((a) {
      final role = '${a['role']}';
      return a['deleted_at'] == null && ['teacher', 'library', 'courier', 'delegate', 'printer'].contains(role);
    }).toList();
    if (roleFilter == 'all') return rows;
    if (roleFilter == 'courier') {
      return rows.where((a) => ['courier', 'delegate'].contains('${a['role']}')).toList();
    }
    return rows.where((a) => '${a['role']}' == roleFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المالية والتسويات'),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: load, child: const Text('إعادة المحاولة')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _overviewCards(),
                      const SizedBox(height: 18),
                      const Text('الحسابات المالية', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'all', label: Text('الكل')),
                            ButtonSegment(value: 'teacher', label: Text('المدرسون')),
                            ButtonSegment(value: 'library', label: Text('المكتبات')),
                            ButtonSegment(value: 'courier', label: Text('المندوبون')),
                            ButtonSegment(value: 'printer', label: Text('المطابع')),
                          ],
                          selected: {roleFilter},
                          onSelectionChanged: (value) => setState(() => roleFilter = value.first),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...financeAccounts.map(_accountCard),
                      const SizedBox(height: 18),
                      if (suppliers.isNotEmpty) ...[
                        const Text('مستحقات توريد الكتب للمطابع', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        ...suppliers.map(_supplierCard),
                        const SizedBox(height: 18),
                      ],
                      const Text('آخر التسويات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      if (settlements.isEmpty)
                        const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد تسويات'))))
                      else
                        ...settlements.take(80).map(_settlementCard),
                    ],
                  ),
                ),
    );
  }

  Widget _overviewCards() {
    final cards = [
      ('ربح المنصة', overview['platform_profit'], Icons.trending_up_rounded),
      ('مستحق المدرسين', overview['teacher_remaining'], Icons.school_rounded),
      ('ذمم التحصيل', overview['collector_remaining'], Icons.account_balance_wallet_rounded),
      ('توريد كتب للمطابع', overview['book_supplier_pending'], Icons.print_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.45),
      itemBuilder: (_, i) {
        final c = cards[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(c.$3, color: const Color(0xFF143B68)),
              const Spacer(),
              Text(money(c.$2), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
              Text(c.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      },
    );
  }

  Widget _accountCard(Map<String, dynamic> account) {
    final role = '${account['role']}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_roleIcon(role))),
        title: Text('${account['name'] ?? 'بدون اسم'}', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(_roleLabel(role)),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => _openParty(account),
      ),
    );
  }

  Future<void> _openParty(Map<String, dynamic> account) async {
    final role = '${account['role']}';
    final normalized = role == 'courier' ? 'delegate' : role;
    try {
      final summary = await widget.repository.financePartySummaryV2(role: normalized, partyId: '${account['id']}');
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          maxChildSize: .92,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('${summary['party_name'] ?? account['name']}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              Text(_roleLabel(normalized)),
              const SizedBox(height: 14),
              _line(normalized == 'teacher' ? 'الأرباح المستحقة' : 'إجمالي الذمة', money(normalized == 'teacher' ? summary['earned'] : summary['debt_total'])),
              _line('المسدد', money(summary['settled'])),
              _line('المتبقي', money(summary['remaining']), strong: true),
              _line('عدد الطلبات', '${summary['orders_count'] ?? 0}'),
              if (normalized == 'printer') ...[
                const Divider(height: 28),
                _line('توريد كتب مستحق', money(summary['book_supply_pending'])),
                _line('توريد كتب مسدد', money(summary['book_supply_settled'])),
              ],
              const SizedBox(height: 16),
              if (n(summary['remaining']) > 0)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _recordSettlement(account, summary);
                  },
                  icon: const Icon(Icons.add_card_rounded),
                  label: Text(normalized == 'teacher' ? 'دفع مستحق للمدرس' : 'استلام تسوية'),
                ),
              const SizedBox(height: 14),
              const Text('السندات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              ...((summary['settlements'] as List? ?? const []).map((e) => _settlementCard(Map<String, dynamic>.from(e as Map)))),
            ],
          ),
        ),
      );
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _recordSettlement(Map<String, dynamic> account, Map<String, dynamic> summary) async {
    final amount = TextEditingController(text: '${n(summary['remaining']).round()}');
    final note = TextEditingController();
    String method = 'cash';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('${account['name']} — تسوية'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('الرصيد المتبقي: ${money(summary['remaining'])}'),
            const SizedBox(height: 10),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'طريقة الدفع'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                DropdownMenuItem(value: 'transfer', child: Text('تحويل')),
              ],
              onChanged: (value) {
                if (value != null) setLocal(() => method = value);
              },
            ),
            const SizedBox(height: 8),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تثبيت')),
          ],
        ),
      ),
    );
    if (ok != true) {
      amount.dispose();
      note.dispose();
      return;
    }
    try {
      final value = num.tryParse(amount.text.trim()) ?? 0;
      if (value <= 0) throw Exception('أدخل مبلغ صحيح');
      final role = '${account['role']}' == 'courier' ? 'delegate' : '${account['role']}';
      final result = await widget.repository.adminRecordSettlementV2(
        role: role,
        partyId: '${account['id']}',
        amount: value,
        method: method,
        note: note.text,
      );
      await load();
      _snack('تم تثبيت السند ${result['receipt_number'] ?? ''}');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      amount.dispose();
      note.dispose();
    }
  }

  Widget _settlementCard(Map<String, dynamic> settlement) {
    final reversed = '${settlement['status']}' == 'reversed' || '${settlement['status']}' == 'cancelled';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(reversed ? Icons.undo_rounded : Icons.receipt_long_rounded, color: reversed ? Colors.red : const Color(0xFF143B68)),
        title: Text('${settlement['receipt_number'] ?? settlement['id']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_roleLabel('${settlement['party_role']}')} • ${_date(settlement['created_at'])}\n${settlement['payment_method'] ?? ''} ${settlement['note'] ?? ''}'),
        isThreeLine: true,
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(settlement['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
          if (!reversed && '${settlement['reversed_from'] ?? ''}'.isEmpty)
            TextButton(onPressed: () => _reverseSettlement(settlement), child: const Text('عكس')),
        ]),
      ),
    );
  }

  Future<void> _reverseSettlement(Map<String, dynamic> settlement) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عكس التسوية'),
        content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب العكس'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد العكس')),
        ],
      ),
    );
    if (ok != true) {
      reason.dispose();
      return;
    }
    try {
      if (reason.text.trim().length < 3) throw Exception('اكتب سبب العكس بوضوح');
      await widget.repository.adminReverseSettlementV2(settlementId: '${settlement['id']}', reason: reason.text);
      await load();
      _snack('تم عكس التسوية');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      reason.dispose();
    }
  }

  Widget _supplierCard(Map<String, dynamic> supplier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.print_rounded)),
        title: Text('${supplier['supplier_name'] ?? 'مطبعة'}', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('طلبات: ${supplier['orders_count'] ?? 0} • مسدد: ${money(supplier['settled_amount'])}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(money(supplier['pending_amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
          if (n(supplier['pending_amount']) > 0)
            TextButton(onPressed: () => _settleSupplier(supplier), child: const Text('تسديد')),
        ]),
      ),
    );
  }

  Future<void> _settleSupplier(Map<String, dynamic> supplier) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسوية توريد الكتب'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${supplier['supplier_name']} — ${money(supplier['pending_amount'])}'),
          const SizedBox(height: 10),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة'), maxLines: 2),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسديد الكل')),
        ],
      ),
    );
    if (ok != true) {
      note.dispose();
      return;
    }
    try {
      await widget.repository.adminSettleBookSupplier(supplierKey: '${supplier['supplier_key']}', note: note.text);
      await load();
      _snack('تم تسديد مستحقات توريد الكتب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      note.dispose();
    }
  }

  Widget _line(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 17 : 14)),
        ]),
      );

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String _date(dynamic value) {
    final text = '${value ?? ''}';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  static String _roleLabel(String role) => switch (role) {
        'teacher' => 'مدرس',
        'library' => 'مكتبة',
        'courier' || 'delegate' => 'مندوب',
        'printer' => 'مطبعة',
        _ => role,
      };

  static IconData _roleIcon(String role) => switch (role) {
        'teacher' => Icons.school_rounded,
        'library' => Icons.store_rounded,
        'courier' || 'delegate' => Icons.delivery_dining_rounded,
        'printer' => Icons.print_rounded,
        _ => Icons.person_rounded,
      };
}
