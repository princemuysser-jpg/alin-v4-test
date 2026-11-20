import 'package:flutter/material.dart';
import '../widgets/business_brand.dart';
import '../data/business_repository.dart';
import '../models/business_account.dart';
import '../widgets/business_app_mark.dart';
import '../widgets/alin_receipt_template.dart';
import 'teacher_publishing_screen.dart';
import 'teacher_profile_screen.dart';
import 'business_notifications_screen.dart';

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
  String tab = 'home';
  String bookletFilter = 'all';
  String orderFilter = 'all';
  int bookletLimit = 36;
  int orderLimit = 36;
  final bookletSearchController = TextEditingController();
  final orderSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    bookletSearchController.dispose();
    orderSearchController.dispose();
    super.dispose();
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
            .select(
              'id,title,subject,grade,term,edition,year,price,status,publish_status,published,is_published,teacher_approved,admin_note,created_at,updated_at',
            )
            .eq('teacher_id', widget.account.id)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false)
            .limit(200),
        client
            .from('alin_teacher_orders')
            .select(
              'id,order_number,title,kind,qty,unit_price,total,status,teacher_profit,created_at,updated_at,teacher_id,student_name',
            )
            .eq('teacher_id', widget.account.id)
            .order('created_at', ascending: false)
            .limit(300),
        client
            .from('teacher_settlements')
            .select(
              'id,receipt_number,teacher_id,amount,payment_method,status,note,created_at,updated_at',
            )
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

  Future<void> openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherProfileScreen(
          repository: widget.repository,
          account: widget.account,
        ),
      ),
    );
    if (mounted) await load();
  }

  num number(dynamic value) => num.tryParse('$value') ?? 0;
  String money(dynamic value) => '${number(value).round()} د.ع';

  bool isDone(Map<String, dynamic> o) => const {
    'completed',
    'delivered',
    'done',
    'received',
    'settled',
  }.contains('${o['status']}'.toLowerCase());
  bool isCancelled(Map<String, dynamic> o) => const {
    'cancelled',
    'canceled',
    'rejected',
  }.contains('${o['status']}'.toLowerCase());

  String bookletStatus(Map<String, dynamic> b) {
    if (b['is_published'] == true ||
        b['published'] == true ||
        '${b['publish_status']}'.toLowerCase() == 'published') {
      return 'منشورة';
    }
    if (b['teacher_approved'] == true) return 'بانتظار النشر';
    final s = '${b['status'] ?? b['publish_status'] ?? ''}'.toLowerCase();
    if (s.contains('reject')) return 'مرفوضة';
    if (s.contains('review') || s.contains('pending')) return 'قيد المراجعة';
    return 'مسودة/قيد المراجعة';
  }

  static const _teacherTeal = Color(0xFF0EA99B);
  static const _teacherPurple = Color(0xFF8661BE);
  static const _teacherBlue = Color(0xFF4C83BD);

  String get sectionTitle => switch (tab) {
    'booklets' => 'ملازمي',
    'orders' => 'المبيعات والطلاب',
    'finance' => 'الأرباح والتسويات',
    _ => 'الرئيسية',
  };

  IconData get sectionIcon => switch (tab) {
    'booklets' => Icons.auto_stories_rounded,
    'orders' => Icons.receipt_long_rounded,
    'finance' => Icons.account_balance_wallet_rounded,
    _ => Icons.dashboard_customize_rounded,
  };

  Color get sectionColor => switch (tab) {
    'booklets' => _teacherBlue,
    'orders' => _teacherPurple,
    'finance' => BusinessBrand.success,
    _ => _teacherTeal,
  };

  void selectTab(String value) {
    if (tab == value) return;
    setState(() => tab = value);
  }

  Future<void> openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BusinessNotificationsScreen(
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> signOut() async => widget.onLogout();

  Widget _sidebar() => Container(
    width: 252,
    decoration: const BoxDecoration(gradient: BusinessBrand.heroGradient),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(15, 22, 15, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: ListView(
          padding: EdgeInsets.zero,
          children: [
        Row(children: [
          const BusinessAppMark(size: 47),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('منصة الين', style: TextStyle(
                fontWeight: FontWeight.w900, color: Colors.white, fontSize: 19)),
              Text('بوابة المدرس', style: TextStyle(
                color: Color(0xFFA9DCD8), fontSize: 12)),
            ],
          )),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .1)),
          ),
          child: Row(children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF31647A),
              child: Icon(Icons.school_rounded, color: Colors.white),
            ),
            const SizedBox(width: 9),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.account.name, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
                const Text('حساب المدرس', style: TextStyle(
                  color: Colors.white70, fontSize: 11)),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 25),
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 9, bottom: 10),
          child: Text('مساحة العمل', style: TextStyle(
            color: Color(0xFFA5BCCD), fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        _sideTab('home', Icons.dashboard_customize_rounded, 'الرئيسية'),
        _sideTab('booklets', Icons.auto_stories_rounded, 'ملازمي'),
        _sideTab('orders', Icons.receipt_long_rounded, 'المبيعات'),
        _sideTab('finance', Icons.account_balance_wallet_rounded, 'الأرباح'),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: openPublishing,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('رفع ومتابعة الملازم'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDDF8F0),
            foregroundColor: BusinessBrand.navy,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
          ],
        )),
        const SizedBox(height: 7),
        Divider(color: Colors.white.withValues(alpha: .18)),
        _sideAction(Icons.notifications_none_rounded, 'الإشعارات', openNotifications),
        _sideAction(Icons.person_outline_rounded, 'الملف الشخصي', openProfile),
        _sideAction(Icons.logout_rounded, 'تسجيل الخروج', signOut),
      ]),
    )),
  );

  Widget _sideTab(String value, IconData icon, String label) {
    final selected = tab == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: .16) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => selectTab(value),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected
                ? Colors.white.withValues(alpha: .16) : Colors.transparent),
            ),
            child: Row(children: [
              Icon(icon, color: selected ? const Color(0xFF6AF0D9) : Colors.white70,
                size: 21),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(
                color: Colors.white, fontWeight: selected
                  ? FontWeight.w900 : FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sideAction(IconData icon, String label, Future<void> Function() action) =>
    Padding(padding: const EdgeInsets.only(top: 2),
      child: TextButton.icon(
        onPressed: action,
        icon: Icon(icon, color: Colors.white70, size: 19),
        label: Text(label, style: const TextStyle(
          color: Colors.white70, fontWeight: FontWeight.w700)),
        style: TextButton.styleFrom(alignment: Alignment.centerRight),
      ),
    );

  Widget _mobileBar() => NavigationBar(
    height: 70,
    backgroundColor: Colors.white,
    indicatorColor: BusinessBrand.softTeal,
    selectedIndex: const ['home','booklets','orders','finance'].indexOf(tab),
    onDestinationSelected: (index) => selectTab(
      const ['home','booklets','orders','finance'][index]),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
      NavigationDestination(icon: Icon(Icons.menu_book_outlined),
        selectedIcon: Icon(Icons.menu_book_rounded), label: 'ملازمي'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded), label: 'المبيعات'),
      NavigationDestination(icon: Icon(Icons.wallet_outlined),
        selectedIcon: Icon(Icons.wallet_rounded), label: 'الأرباح'),
    ],
  );

  Widget _sectionHeading() => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(children: [
      Container(
        width: 45, height: 45,
        decoration: BoxDecoration(
          color: BusinessBrand.pastel(sectionColor, strength: .16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(sectionIcon, color: sectionColor),
      ),
      const SizedBox(width: 11),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sectionTitle, style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900,
            color: BusinessBrand.ink)),
          Text(switch(tab) {
            'booklets' => 'الملفات وحالات النشر والمتابعة',
            'orders' => 'طلبات الطلاب المرتبطة بملازمك',
            'finance' => 'أرباحك وتسوياتك ووصولاتك',
            _ => 'ملخص نشاطك التعليمي في مكان واحد',
          }, style: const TextStyle(
            fontSize: 12, color: BusinessBrand.muted)),
        ],
      )),
      IconButton(
        tooltip: 'تحديث البيانات',
        onPressed: load,
        icon: const Icon(Icons.refresh_rounded, color: BusinessBrand.navy),
      ),
    ]),
  );

  Widget _homeSummary(num earned, num balance, int completed) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF102B4E), Color(0xFF195F79), Color(0xFF1B8F8C)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
            color: BusinessBrand.navy.withValues(alpha: .12),
            blurRadius: 24, offset: const Offset(0, 9),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_stories_rounded, color: Color(0xFFD5EDE8), size: 30),
            SizedBox(width: 10),
            Text('مساحة المدرس', style: TextStyle(
              color: Color(0xFFA6F5E0), fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          Text('أهلاً أستاذ ${widget.account.name}',
            style: const TextStyle(
              color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('كل ما يخص ملازمك ومبيعاتك ومستحقاتك بواجهة واحدة.',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 930 ? 4 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          SizedBox(width: width, child: _metric(
            'ملازمي', '${booklets.length}',
            Icons.menu_book_rounded, _teacherBlue)),
          SizedBox(width: width, child: _metric(
            'الطلبات المكتملة', '$completed',
            Icons.task_alt_rounded, _teacherTeal)),
          SizedBox(width: width, child: _metric(
            'إجمالي الأرباح', money(earned),
            Icons.payments_rounded, _teacherPurple)),
          SizedBox(width: width, child: _metric(
            'رصيدي الحالي', money(balance),
            Icons.account_balance_wallet_rounded, BusinessBrand.success)),
        ]);
      }),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BusinessBrand.pastelCard(_teacherTeal, strength: .055),
        child: Row(children: [
          const Icon(Icons.lightbulb_outline_rounded, color: BusinessBrand.teal),
          const SizedBox(width: 11),
          Expanded(child: Text(
            'تابع ملازمك وطلبات الطلاب والأرباح من شريط التنقل.',
            style: const TextStyle(color: BusinessBrand.ink, fontSize: 12.5),
          )),
        ]),
      ),
    ]);

  @override
  Widget build(BuildContext context) {
    final completedOrders = orders.where(isDone).toList();
    final earned = completedOrders.fold<num>(
      0, (sum, o) => sum + number(o['teacher_profit']));
    final paid = settlements.where((row) =>
      const {'paid','received'}.contains('${row['status']}'.toLowerCase()))
      .fold<num>(0, (sum, row) => sum + number(row['amount']));
    final balance = earned - paid;
    return LayoutBuilder(builder: (context, layout) {
      final desktop = layout.maxWidth >= 1020;
      final tablet = layout.maxWidth >= 680;
      final sidePadding = desktop ? 28.0 : tablet ? 22.0 : 13.0;
      return Scaffold(
        backgroundColor: BusinessBrand.background,
        appBar: desktop ? null : AppBar(
          backgroundColor: Colors.white,
          foregroundColor: BusinessBrand.navy,
          automaticallyImplyLeading: false,
          titleSpacing: 14,
          title: Row(children: [
            const BusinessAppMark(size: 37),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('لوحة المدرس', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900)),
              Text(widget.account.name, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: BusinessBrand.muted)),
            ])),
          ]),
          actions: [
            IconButton(
              tooltip: 'رفع ملزمة',
              onPressed: openPublishing,
              icon: const Icon(Icons.upload_file_rounded),
            ),
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: openNotifications,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'إعدادات الحساب',
              onSelected: (action) {
                if (action == 'profile') openProfile();
                if (action == 'logout') signOut();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
                PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
              ],
            ),
          ],
        ),
        bottomNavigationBar: desktop ? null : _mobileBar(),
        body: Row(children: [
          if (desktop) _sidebar(),
          Expanded(child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(sidePadding, desktop ? 28 : 19,
                sidePadding, 28),
              children: [
                _sectionHeading(),
                if (loading)
                  const Padding(padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()))
                else if (error != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BusinessBrand.pastelCard(BusinessBrand.danger,
                      strength: .07),
                    child: Column(children: [
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      FilledButton.icon(onPressed: load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة')),
                    ]),
                  )
                else if (tab == 'home')
                  _homeSummary(earned, balance < 0 ? 0 : balance,
                    completedOrders.length)
                else if (tab == 'booklets') _booklets()
                else if (tab == 'orders') _orders()
                else if (tab == 'finance')
                  _finance(earned, paid, balance < 0 ? 0 : balance),
              ],
            ),
          )),
        ]),
      );
    });
  }

  Widget _metric(String label, String value, IconData icon, Color accent) {
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(14),
      decoration: BusinessBrand.pastelCard(accent, strength: .11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .75),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19, fontWeight: FontWeight.w900,
              color: BusinessBrand.ink,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12,
              color: BusinessBrand.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, String selected,
      ValueChanged<String> select) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 7),
    child: ChoiceChip(
      label: Text(label), selected: selected == value,
      onSelected: (_) => select(value),
    ),
  );

  Widget _searchBox(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty ? null : IconButton(
            tooltip: 'مسح البحث',
            onPressed: () {
              controller.clear();
              setState(() {});
            },
            icon: const Icon(Icons.close_rounded),
          ),
          filled: true,
          fillColor: BusinessBrand.softBlue,
        ),
      );

  Widget _booklets() {
    final q = bookletSearchController.text.trim().toLowerCase();
    final filtered = booklets.where((b) {
      final st = bookletStatus(b);
      if (bookletFilter != 'all' && bookletFilter != st) return false;
      if (q.isEmpty) return true;
      return [
        b['title'], b['subject'], b['grade'], b['year'], b['edition']
      ].map((v) => '${v ?? ''}'.toLowerCase()).join(' ').contains(q);
    }).toList();

    if (booklets.isEmpty) {
      return const _TeacherEmpty(text: 'لا توجد ملازم مرتبطة بحسابك حالياً');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchBox(bookletSearchController, 'ابحث عن ملزمة أو مادة أو صف'),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('الكل', 'all', bookletFilter,
              (v) => setState(() => bookletFilter = v)),
            for (final state in [
              'منشورة', 'بانتظار النشر', 'قيد المراجعة',
              'مسودة/قيد المراجعة', 'مرفوضة',
            ]) _filterChip(state, state, bookletFilter,
              (v) => setState(() => bookletFilter = v)),
          ]),
        ),
        const SizedBox(height: 9),
        Text('${filtered.length} ملزمة مطابقة',
          style: const TextStyle(color: BusinessBrand.muted)),
        const SizedBox(height: 9),
        if (filtered.isEmpty)
          const _TeacherEmpty(text: 'لا توجد ملازم مطابقة للبحث'),
        ...filtered.take(bookletLimit)
          .map(
            (b) => Card(
              color: BusinessBrand.pastel(
                bookletStatus(b) == 'منشورة' ? BusinessBrand.success : BusinessBrand.warning,
                strength: .075),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.menu_book_rounded),
                ),
                title: Text(
                  '${b['title'] ?? 'ملزمة'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  [
                    b['subject'],
                    b['grade'],
                    b['year'],
                  ].where((x) => '${x ?? ''}'.trim().isNotEmpty).join(' — '),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(b['price']),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      bookletStatus(b),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF143B68),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
        if (filtered.length > bookletLimit)
          OutlinedButton.icon(
            onPressed: () => setState(() => bookletLimit += 36),
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('عرض المزيد من الملازم'),
          ),
      ],
    );
  }

  String _studentName(Map<String, dynamic> order) {
    final name = '${order['student_name'] ?? ''}'.trim();
    return name.isEmpty ? 'غير مسجل' : name;
  }

  Widget _teacherProfitDetails() {
    final completed = orders.where(isDone).toList();
    if (completed.isEmpty) {
      return const _TeacherEmpty(text: 'لا توجد أرباح مكتملة بعد');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'تفاصيل أرباح الطلبات المكتملة',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
        ...completed.map((o) => Card(
          margin: const EdgeInsets.only(bottom: 9),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_studentName(o),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${o['title'] ?? 'ملزمة'} • ${o['qty'] ?? 1} نسخة',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text('طلب: ${o['order_number'] ?? o['id']} • ${_date(o['created_at'])}',
                    style: const TextStyle(fontSize: 12)),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(child: Text('قيمة الطلب: ${money(o['total'])}')),
                    Text('ربح المدرس: ${money(o['teacher_profit'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF168450),
                        )),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _orders() {
    final q = orderSearchController.text.trim().toLowerCase();
    final filtered = orders.where((o) {
      if (orderFilter == 'completed' && !isDone(o)) return false;
      if (orderFilter == 'cancelled' && !isCancelled(o)) return false;
      if (orderFilter == 'active' && (isDone(o) || isCancelled(o))) return false;
      if (q.isEmpty) return true;
      return [o['order_number'], o['id'], o['title'], o['student_name']]
        .map((v) => '${v ?? ''}'.toLowerCase()).join(' ').contains(q);
    }).toList();

    if (orders.isEmpty) {
      return const _TeacherEmpty(text: 'لا توجد طلبات مرتبطة بملازمك حالياً');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchBox(orderSearchController, 'ابحث برقم الطلب أو الطالب أو الملزمة'),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('الكل', 'all', orderFilter,
              (v) => setState(() => orderFilter = v)),
            _filterChip('قيد التنفيذ', 'active', orderFilter,
              (v) => setState(() => orderFilter = v)),
            _filterChip('مكتملة', 'completed', orderFilter,
              (v) => setState(() => orderFilter = v)),
            _filterChip('ملغاة', 'cancelled', orderFilter,
              (v) => setState(() => orderFilter = v)),
          ]),
        ),
        const SizedBox(height: 9),
        Text('${filtered.length} طلب مطابق',
          style: const TextStyle(color: BusinessBrand.muted)),
        const SizedBox(height: 9),
        if (filtered.isEmpty)
          const _TeacherEmpty(text: 'لا توجد مبيعات مطابقة'),
        ...filtered.take(orderLimit)
          .map(
            (o) => Card(
              color: BusinessBrand.pastel(
                isCancelled(o) ? BusinessBrand.danger :
                isDone(o) ? BusinessBrand.success : BusinessBrand.warning,
                strength: .075,
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Icon(
                  isCancelled(o)
                      ? Icons.cancel_outlined
                      : isDone(o)
                      ? Icons.check_circle_outline
                      : Icons.schedule_rounded,
                ),
                title: Text(
                  '${o['order_number'] ?? o['id']} — ${o['title'] ?? 'ملزمة'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'الطالب: ${_studentName(o)}\nالنسخ: ${o['qty'] ?? 1} • ${_date(o['created_at'])} • الحالة: ${o['status'] ?? '-'}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(o['total']),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'ربحك ${money(o['teacher_profit'])}',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
        if (filtered.length > orderLimit)
          OutlinedButton.icon(
            onPressed: () => setState(() => orderLimit += 36),
            icon: const Icon(Icons.expand_more_rounded),
            label: const Text('عرض المزيد من المبيعات'),
          ),
      ],
    );
  }

  Widget _finance(num earned, num paid, num balance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _line('إجمالي الأرباح', money(earned)),
                _line('المبلغ المدفوع', money(paid)),
                const Divider(),
                _line('الرصيد الحالي', money(balance), strong: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _teacherProfitDetails(),
        const SizedBox(height: 16),
        const Text(
          'التسويات السابقة',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (settlements.isEmpty)
          const _TeacherEmpty(text: 'لا توجد تسويات سابقة')
        else
          ...settlements.map(
            (s) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                leading: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF143B68),
                ),
                title: Text(
                  '${s['receipt_number'] ?? s['id']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${_date(s['created_at'])}${'${s['payment_method'] ?? ''}'.isNotEmpty ? ' — ${s['payment_method']}' : ''}',
                ),
                trailing: Text(
                  money(s['amount']),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
                onTap: () => showAlinSettlementReceipt(
                  context,
                  s,
                  partyName: widget.account.name,
                  partyRole: 'teacher',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _line(String label, String value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            fontSize: strong ? 18 : 15,
            color: strong ? const Color(0xFF143B68) : null,
          ),
        ),
      ],
    ),
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Center(child: Text(text)),
    ),
  );
}
