import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/alin_receipt_template.dart';

class PrinterBookletFinanceScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const PrinterBookletFinanceScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<PrinterBookletFinanceScreen> createState() =>
      _PrinterBookletFinanceScreenState();
}

class _PrinterBookletFinanceScreenState
    extends State<PrinterBookletFinanceScreen> {
  Map<String, dynamic> summary = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  num n(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${n(value).round()} د.ع';

  List<Map<String, dynamic>> listOf(String key) {
    final raw = summary[key];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await widget.repository.dashboardSummary(widget.account);
      if (!mounted) return;
      setState(() => summary = value);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlements = listOf('collector_settlements');
    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب الملازم'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
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
                        const Icon(Icons.error_outline_rounded, size: 42),
                        const SizedBox(height: 12),
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF143B68), Color(0xFF255B91)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'حساب الملازم — المطبعة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.account.name,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'هذا الحساب خاص بطباعة وتسليم الملازم فقط، ومنفصل بالكامل عن توريد الكتب.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth >= 800 ? 3 : 2;
                          final gap = 10.0;
                          final width =
                              (c.maxWidth - gap * (columns - 1)) / columns;
                          final cards = [
                            _metric(
                              'مبيعات الملازم',
                              money(summary['booklet_sales_total']),
                              Icons.payments_rounded,
                            ),
                            _metric(
                              'ربح المطبعة من الملازم',
                              money(summary['booklet_profit']),
                              Icons.savings_rounded,
                            ),
                            _metric(
                              'طلبات الملازم',
                              '${summary['booklet_orders_count'] ?? 0}',
                              Icons.receipt_long_rounded,
                            ),
                            _metric(
                              'إجمالي ذمة الملازم',
                              money(summary['collector_debt_total']),
                              Icons.account_balance_wallet_rounded,
                            ),
                            _metric(
                              'المسدّد من ذمة الملازم',
                              money(summary['collector_settled']),
                              Icons.check_circle_rounded,
                            ),
                            _metric(
                              'المتبقي من ذمة الملازم',
                              money(summary['collector_remaining']),
                              Icons.pending_actions_rounded,
                            ),
                          ];
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: cards
                                .map((card) => SizedBox(width: width, child: card))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'تسويات حساب الملازم',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (settlements.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('لا توجد تسويات ملازم مسجلة بعد'),
                            ),
                          ),
                        )
                      else
                        ...settlements.map(
                          (row) => Card(
                            margin: const EdgeInsets.only(bottom: 9),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_long_rounded),
                              ),
                              title: Text(
                                '${row['receipt_number'] ?? row['id'] ?? 'تسوية ملازم'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${_date(row['created_at'])}${'${row['payment_method'] ?? ''}'.isNotEmpty ? ' — ${row['payment_method']}' : ''}',
                              ),
                              trailing: Text(
                                money(row['amount']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green,
                                ),
                              ),
                              onTap: () => showAlinSettlementReceipt(
                                context,
                                row,
                                partyName: widget.account.name,
                                partyRole: 'printer',
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'توريد الكتب لا يدخل بهذا الحساب ولا بهذه التسويات. له حساب مستقل داخل نظام توريد الكتب.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF143B68)),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF143B68),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  static String _date(dynamic value) {
    final s = '${value ?? ''}';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}
