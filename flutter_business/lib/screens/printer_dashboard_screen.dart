import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';

class PrinterDashboardScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const PrinterDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<PrinterDashboardScreen> createState() => _PrinterDashboardScreenState();
}

class _PrinterDashboardScreenState extends State<PrinterDashboardScreen> {
  Map<String, dynamic> summary = {};
  bool loading = true;
  String? error;
  String tab = 'books';

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
      final data = await widget.repository.dashboardSummary(widget.account);
      if (!mounted) return;
      setState(() => summary = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  List<Map<String, dynamic>> listOf(String key) {
    final raw = summary[key];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لوحة المطبعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(onPressed: load, tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _hero(),
            const SizedBox(height: 12),
            if (loading)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              _errorCard()
            else ...[
              _metrics(),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'books', label: Text('توريد الكتب'), icon: Icon(Icons.menu_book_rounded)),
                  ButtonSegment(value: 'debt', label: Text('الذمة'), icon: Icon(Icons.account_balance_wallet_rounded)),
                  ButtonSegment(value: 'settlements', label: Text('التسويات'), icon: Icon(Icons.receipt_long_rounded)),
                ],
                selected: {tab},
                onSelectionChanged: (value) => setState(() => tab = value.first),
              ),
              const SizedBox(height: 14),
              if (tab == 'books') _booksSection(),
              if (tab == 'debt') _debtSection(),
              if (tab == 'settlements') _settlementsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x26FFFFFF),
            child: Icon(Icons.print_rounded, color: Colors.white, size: 31),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text('حساب المطبعة وتوريد الكتب والتسويات', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _metric('ذمة المطبعة للإدارة', money(summary['collector_remaining']), Icons.account_balance_wallet_rounded),
        _metric('المسدّد من الذمة', money(summary['collector_settled']), Icons.check_circle_rounded),
        _metric('توريد كتب مستحق', money(summary['book_supply_pending']), Icons.menu_book_rounded),
        _metric('طلبات الكتب', '${summary['book_orders_count'] ?? 0}', Icons.receipt_long_rounded),
      ],
    );
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF143B68)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _booksSection() {
    final rows = listOf('book_rows');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('طلبات وحركات توريد الكتب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('المستحق ${money(summary['book_supply_pending'])} — المسدد ${money(summary['book_supply_settled'])}', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const _EmptyCard(text: 'لا توجد حركات توريد كتب حالياً')
        else
          ...rows.map((row) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.menu_book_rounded)),
                  title: Text('${row['order_number'] ?? row['order_id'] ?? 'طلب كتاب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${row['title'] ?? 'كتاب'}\n${_date(row['created_at'])}'),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(money(row['amount']), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('${row['status']}' == 'settled' ? 'مسدد' : 'مستحق', style: TextStyle(color: '${row['status']}' == 'settled' ? Colors.green : Colors.orange)),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _debtSection() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ذمة المطبعة مع الإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              _row('إجمالي الذمة', money(summary['collector_debt_total'])),
              _row('المسدّد', money(summary['collector_settled'])),
              const Divider(),
              _row('المتبقي', money(summary['collector_remaining']), strong: true),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF143B68)),
              const SizedBox(width: 10),
              Expanded(child: Text('ذمة المطبعة منفصلة عن مستحق توريد الكتب. التسوية من الإدارة تحفظ السجل ولا تمس حساب توريد الكتب.', style: TextStyle(color: Colors.grey.shade700))),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _settlementsSection() {
    final book = listOf('book_settlements');
    final debt = listOf('collector_settlements');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('تسويات توريد الكتب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (book.isEmpty)
        const _EmptyCard(text: 'لا توجد تسويات توريد كتب بعد')
      else
        ...book.map((row) => _settlementCard(row, fallback: 'تسوية توريد كتب')),
      const SizedBox(height: 14),
      const Text('تسويات ذمة المطبعة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (debt.isEmpty)
        const _EmptyCard(text: 'لا توجد تسويات ذمة بعد')
      else
        ...debt.map((row) => _settlementCard(row, fallback: 'تسوية ذمة')),
    ]);
  }

  Widget _settlementCard(Map<String, dynamic> row, {required String fallback}) {
    final title = '${row['receipt_number'] ?? row['id'] ?? fallback}';
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF143B68)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${_date(row['created_at'])}${'${row['payment_method'] ?? ''}'.isNotEmpty ? ' — ${row['payment_method']}' : ''}'),
        trailing: Text(money(row['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
      ),
    );
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 18 : 15, color: strong ? const Color(0xFF143B68) : null)),
      ]),
    );
  }

  Widget _errorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 36),
          const SizedBox(height: 8),
          Text(error ?? 'تعذر تحميل بيانات المطبعة', textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
        ]),
      ),
    );
  }

  static String _date(dynamic value) {
    final s = '${value ?? ''}';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(22), child: Center(child: Text(text))));
  }
}
