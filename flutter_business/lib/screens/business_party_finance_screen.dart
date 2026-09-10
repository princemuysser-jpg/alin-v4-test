import 'package:flutter/material.dart';

import '../data/business_finance_repository.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';

class BusinessPartyFinanceScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;

  const BusinessPartyFinanceScreen({
    super.key,
    required this.repository,
    required this.account,
  });

  @override
  State<BusinessPartyFinanceScreen> createState() => _BusinessPartyFinanceScreenState();
}

class _BusinessPartyFinanceScreenState extends State<BusinessPartyFinanceScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> summary = {};

  String get financeRole {
    if (widget.account.role == 'courier') return 'delegate';
    return widget.account.role;
  }

  num n(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${n(value).round()} د.ع';

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
      final value = await widget.repository.financePartySummaryV2(
        role: financeRole,
        partyId: widget.account.id,
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي المالي'),
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
                      _header(),
                      const SizedBox(height: 12),
                      _summaryGrid(),
                      if (financeRole == 'printer') ...[
                        const SizedBox(height: 18),
                        const Text('توريد الكتب', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              _line('مستحق غير مسدد', money(summary['book_supply_pending']), strong: true),
                              _line('تم تسديده', money(summary['book_supply_settled'])),
                              _line('إجمالي التوريد', money(summary['book_supply_total'])),
                              _line('عدد طلبات الكتب', '${summary['book_orders_count'] ?? 0}'),
                            ]),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text('سجل التسويات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      _settlements(),
                    ],
                  ),
                ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: Colors.white,
          child: Icon(_roleIcon(financeRole), color: const Color(0xFF143B68), size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${summary['party_name'] ?? widget.account.name}',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(_roleLabel(financeRole), style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      ]),
    );
  }

  Widget _summaryGrid() {
    final teacher = financeRole == 'teacher';
    final cards = teacher
        ? [
            ('الأرباح المستحقة', summary['earned'], Icons.trending_up_rounded),
            ('المسدد', summary['settled'], Icons.payments_rounded),
            ('المتبقي', summary['remaining'], Icons.account_balance_wallet_rounded),
            ('الطلبات', summary['orders_count'], Icons.receipt_long_rounded),
          ]
        : [
            ('إجمالي الذمة', summary['debt_total'], Icons.account_balance_wallet_rounded),
            ('المسدد', summary['settled'], Icons.payments_rounded),
            ('المتبقي', summary['remaining'], Icons.warning_amber_rounded),
            ('الطلبات', summary['orders_count'], Icons.receipt_long_rounded),
          ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (_, index) {
        final card = cards[index];
        final isOrders = card.$1 == 'الطلبات';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(card.$3, color: const Color(0xFF143B68)),
              const Spacer(),
              Text(
                isOrders ? '${card.$2 ?? 0}' : money(card.$2),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF143B68)),
              ),
              Text(card.$1, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      },
    );
  }

  Widget _settlements() {
    final raw = summary['settlements'];
    final rows = raw is List
        ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Center(child: Text('لا توجد تسويات مسجلة لحد الآن')),
        ),
      );
    }
    return Column(
      children: rows.map((row) {
        final reversed = '${row['status']}' == 'reversed' || '${row['status']}' == 'cancelled';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              reversed ? Icons.undo_rounded : Icons.receipt_long_rounded,
              color: reversed ? Colors.red : const Color(0xFF143B68),
            ),
            title: Text(
              '${row['receipt_number'] ?? row['id'] ?? 'سند'}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${_date(row['created_at'])} • ${_method(row['payment_method'])}'
              '${('${row['note'] ?? ''}'.trim().isNotEmpty) ? '\n${row['note']}' : ''}',
            ),
            isThreeLine: '${row['note'] ?? ''}'.trim().isNotEmpty,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(money(row['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(reversed ? 'معكوس' : _status('${row['status']}'), style: TextStyle(fontSize: 12, color: reversed ? Colors.red : Colors.green)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _line(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 16 : 14)),
        ]),
      );

  static String _date(dynamic value) {
    final text = '${value ?? ''}';
    if (text.length >= 16) return '${text.substring(0, 10)} ${text.substring(11, 16)}';
    return text;
  }

  static String _method(dynamic value) => switch ('${value ?? ''}') {
        'cash' => 'نقدي',
        'transfer' => 'تحويل',
        _ => '${value ?? ''}',
      };

  static String _status(String value) => switch (value) {
        'paid' => 'مدفوع',
        'received' => 'مستلم',
        _ => value,
      };

  static String _roleLabel(String role) => switch (role) {
        'teacher' => 'مدرس',
        'library' => 'مكتبة',
        'delegate' || 'courier' => 'مندوب',
        'printer' => 'مطبعة',
        _ => role,
      };

  static IconData _roleIcon(String role) => switch (role) {
        'teacher' => Icons.school_rounded,
        'library' => Icons.store_rounded,
        'delegate' || 'courier' => Icons.delivery_dining_rounded,
        'printer' => Icons.print_rounded,
        _ => Icons.person_rounded,
      };
}
