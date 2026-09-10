import 'package:flutter/material.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';
import 'teacher_publishing_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final BusinessRepository repository;
  final BusinessAccount account;
  final Future<void> Function() onLogout;

  const TeacherDashboardScreen({
    super.key,
    required this.repository,
    required this.account,
    required this.onLogout,
  });

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<Map<String, dynamic>> booklets = [];
  List<Map<String, dynamic>> orders = [];
  List<Map<String, dynamic>> settlements = [];
  bool loading = true;
  String? error;
  String tab = 'booklets';

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
      final client = widget.repository.client;
      final results = await Future.wait([
        client
            .from('booklets')
            .select('id,title,subject,grade,term,edition,year,price,status,publish_status,published,is_published,teacher_approved,admin_note,created_at,updated_at')
            .eq('teacher_id', widget.account.id)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(200),
        client
            .from('alin_teacher_orders')
            .select('id,order_number,title,kind,qty,unit_price,total,status,teacher_profit,created_at,updated_at,teacher_id')
            .eq('teacher_id', widget.account.id)
            .order('created_at', ascending: false)
            .limit(300),
        client
            .from('teacher_settlements')
            .select('id,receipt_number,teacher_id,amount,payment_method,status,note,created_at,updated_at')
            .eq('teacher_id', widget.account.id)
            .order('created_at', ascending: false)
            .limit(200),
      ]);
      if (!mounted) return;
      setState(() {
        booklets = (results[0] as List).cast<Map<String, dynamic>>();
        orders = (results[1] as List).cast<Map<String, dynamic>>();
        settlements = (results[2] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openPublishing() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherPublishingScreen(
          repository: widget.repository,
          account: widget.account,
        ),
      ),
    );
    if (mounted) await load();
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  bool isDone(Map<String, dynamic> o) => const {'completed', 'delivered', 'done', 'received', 'settled'}.contains('${o['status']}'.toLowerCase());
  bool isCancelled(Map<String, dynamic> o) => const {'cancelled', 'canceled', 'rejected'}.contains('${o['status']}'.toLowerCase());

  String bookletStatus(Map<String, dynamic> b) {
    if (b['is_published'] == true || b['published'] == true || '${b['publish_status']}'.toLowerCase() == 'published') return 'منشورة';
    if (b['teacher_approved'] == true) return 'بانتظار النشر';
    final s = '${b['status'] ?? b['publish_status'] ?? ''}'.toLowerCase();
    if (s.contains('reject')) return 'مرفوضة';
    if (s.contains('review') || s.contains('pending')) return 'قيد المراجعة';
    return 'مسودة/قيد المراجعة';
  }

  @override
  Widget build(BuildContext context) {
    final doneOrders = orders.where(isDone).toList();
    final earned = doneOrders.fold<num>(0, (sum, o) => sum + number(o['teacher_profit']));
    final paid = settlements
        .where((s) => const {'paid', 'received'}.contains('${s['status']}'.toLowerCase()))
        .fold<num>(0, (sum, s) => sum + number(s['amount']));
    final balance = earned - paid;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('لوحة المدرس', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
        ]),
        actions: [
          IconButton(
            tooltip: 'رفع ومتابعة الملازم',
            onPressed: openPublishing,
            icon: const Icon(Icons.upload_file_rounded),
          ),
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(children: [
                const CircleAvatar(radius: 27, backgroundColor: Color(0x26FFFFFF), child: Icon(Icons.school_rounded, color: Colors.white, size: 30)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('ملازمك ومبيعاتك وأرباحك', style: TextStyle(color: Colors.white70)),
                ])),
                FilledButton.tonalIcon(
                  onPressed: openPublishing,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('رفع ملزمة'),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
              ])))
            else ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  _metric('الملازم', '${booklets.length}', Icons.menu_book_rounded),
                  _metric('الطلبات المكتملة', '${doneOrders.length}', Icons.check_circle_rounded),
                  _metric('إجمالي الأرباح', money(earned), Icons.payments_rounded),
                  _metric('الرصيد الحالي', money(balance < 0 ? 0 : balance), Icons.account_balance_wallet_rounded),
                ],
              ),
              const SizedBox(height: 15),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'booklets', label: Text('ملازمي'), icon: Icon(Icons.menu_book_rounded)),
                  ButtonSegment(value: 'orders', label: Text('المبيعات'), icon: Icon(Icons.receipt_long_rounded)),
                  ButtonSegment(value: 'finance', label: Text('التسويات'), icon: Icon(Icons.account_balance_wallet_rounded)),
                ],
                selected: {tab},
                onSelectionChanged: (v) => setState(() => tab = v.first),
              ),
              const SizedBox(height: 14),
              if (tab == 'booklets') _booklets(),
              if (tab == 'orders') _orders(),
              if (tab == 'finance') _finance(earned, paid, balance < 0 ? 0 : balance),
            ],
          ],
        ),
      ),
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

  Widget _booklets() {
    if (booklets.isEmpty) return const _TeacherEmpty(text: 'لا توجد ملازم مرتبطة بحسابك حالياً');
    return Column(children: booklets.map((b) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.menu_book_rounded)),
        title: Text('${b['title'] ?? 'ملزمة'}', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text([b['subject'], b['grade'], b['year']].where((x) => '${x ?? ''}'.trim().isNotEmpty).join(' — ')),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(b['price']), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(bookletStatus(b), style: const TextStyle(fontSize: 12, color: Color(0xFF143B68))),
        ]),
      ),
    )).toList());
  }

  Widget _orders() {
    if (orders.isEmpty) return const _TeacherEmpty(text: 'لا توجد طلبات مرتبطة بملازمك حالياً');
    return Column(children: orders.map((o) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(isCancelled(o) ? Icons.cancel_outlined : isDone(o) ? Icons.check_circle_outline : Icons.schedule_rounded),
        title: Text('${o['order_number'] ?? o['id']} — ${o['title'] ?? 'ملزمة'}', style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('النسخ: ${o['qty'] ?? 1} • ${_date(o['created_at'])} • الحالة: ${o['status'] ?? '-'}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(money(o['total']), style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('ربحك ${money(o['teacher_profit'])}', style: const TextStyle(fontSize: 11, color: Colors.green)),
        ]),
      ),
    )).toList());
  }

  Widget _finance(num earned, num paid, num balance) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _line('إجمالي الأرباح', money(earned)),
        _line('المبلغ المدفوع', money(paid)),
        const Divider(),
        _line('الرصيد الحالي', money(balance), strong: true),
      ]))),
      const SizedBox(height: 12),
      const Text('التسويات السابقة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (settlements.isEmpty)
        const _TeacherEmpty(text: 'لا توجد تسويات سابقة')
      else
        ...settlements.map((s) => Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: ListTile(
            leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFF143B68)),
            title: Text('${s['receipt_number'] ?? s['id']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${_date(s['created_at'])}${'${s['payment_method'] ?? ''}'.isNotEmpty ? ' — ${s['payment_method']}' : ''}'),
            trailing: Text(money(s['amount']), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
          ),
        )),
    ]);
  }

  Widget _line(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(label)),
      Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 18 : 15, color: strong ? const Color(0xFF143B68) : null)),
    ]),
  );

  static String _date(dynamic value) {
    final s = '${value ?? ''}';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }
}

class _TeacherEmpty extends StatelessWidget {
  final String text;
  const _TeacherEmpty({required this.text});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(22), child: Center(child: Text(text))));
}
