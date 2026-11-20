import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../core/business_notification_helpers.dart';
import '../core/business_notification_service.dart';
import '../core/business_web_push_stub.dart' if (dart.library.js_interop) '../core/business_web_push_web.dart' as browserPush;
import '../core/business_notification_signal.dart';
import '../data/business_notification_repository.dart';
import '../data/business_repository.dart';
import '../widgets/business_brand.dart';
import 'business_order_details_screen.dart';

class BusinessNotificationsScreen extends StatefulWidget {
  final BusinessRepository repository;

  const BusinessNotificationsScreen({super.key, required this.repository});

  @override
  State<BusinessNotificationsScreen> createState() =>
      _BusinessNotificationsScreenState();

  static String? orderIdFromNotification(Map<String, dynamic> item) =>
      BusinessNotificationHelpers.orderId(item);
}

class _BusinessNotificationsScreenState extends State<BusinessNotificationsScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> items = [];
  Timer? _refreshTimer;
  bool loading = true;
  bool busy = false;
  bool _refreshing = false;
  bool unreadOnly = false;
  bool pushBusy = false;
  String pushStatus = 'default';
  String? pushError;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readPushStatus();
    BusinessNotificationSignal.revision.addListener(_onPush);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(load(silent: true)),
    );
    unawaited(load());
  }

  void _onPush() => unawaited(load(silent: true));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readPushStatus();
      unawaited(load(silent: true));
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    BusinessNotificationSignal.revision.removeListener(_onPush);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _readPushStatus() {
    if (!kIsWeb) return;
    try {
      final value = browserPush.webPushPermissionStatus();
      if (mounted) setState(() => pushStatus = value);
    } catch (_) {
      if (mounted) setState(() => pushStatus = 'unsupported');
    }
  }

  Future<void> _enablePush() async {
    if (!kIsWeb || pushBusy || pushStatus == 'ios-browser' ||
        pushStatus == 'unsupported' || pushStatus == 'denied') return;
    setState(() { pushBusy = true; pushError = null; });
    try {
      final ok = await BusinessNotificationService(
        client: widget.repository.client,
      ).requestPermissionAndRegister();
      if (!mounted) return;
      _readPushStatus();
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم تفعيل إشعارات لوحة تحكم منصة الين بنجاح')));
      } else {
        setState(() => pushError = 'تعذر ربط الإشعارات. تحقق من الاتصال وحاول مجدداً.');
      }
    } catch (e) {
      if (mounted) setState(() => pushError =
        '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => pushBusy = false);
    }
  }

  Widget _pushSettings() {
    if (!kIsWeb) return const SizedBox.shrink();
    final iosBrowser = pushStatus == 'ios-browser';
    final granted = pushStatus == 'granted';
    final denied = pushStatus == 'denied';
    final unsupported = pushStatus == 'unsupported';
    final accent = granted ? BusinessBrand.success :
      iosBrowser ? const Color(0xFF3C72A7) : BusinessBrand.teal;
    final title = granted ? 'الإشعارات مفعّلة على هذا الجهاز' :
      iosBrowser ? 'إشعارات الآيفون تحتاج أيقونة الشاشة الرئيسية' :
      denied ? 'الإشعارات محظورة من المتصفح' :
      unsupported ? 'إشعارات الويب غير مدعومة هنا' :
      'تفعيل إشعارات الطلبات';
    final description = granted
      ? 'الإذن محفوظ بالمتصفح، وراح يبقى بدون طلب موافقة بكل دخول.'
      : iosBrowser
        ? 'من سفاري اضغط مشاركة، بعدها «إضافة إلى الشاشة الرئيسية». افتح لوحة التحكم من الأيقونة الجديدة، وفعّل الإشعارات مرة وحدة.'
        : denied
          ? 'افتح إعدادات الموقع في المتصفح واسمح بالإشعارات؛ التطبيق ما يگدر يغيّر الإذن تلقائياً.'
          : unsupported
            ? 'استخدم متصفحاً يدعم Web Push أو نسخة التطبيق الخاصة بالجهاز.'
            : 'فعّلها مرة وحدة. بعد الموافقة، التطبيق يعيد تسجيل الجهاز تلقائياً عند تسجيل الدخول.';
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(14),
      decoration: BusinessBrand.pastelCard(accent, strength: .07),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(granted ? Icons.notifications_active_rounded :
          iosBrowser ? Icons.add_to_home_screen_rounded :
          Icons.notifications_none_rounded, color: accent, size: 25),
        const SizedBox(width: 11),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              fontWeight: FontWeight.w900, color: BusinessBrand.ink)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(
              color: BusinessBrand.muted, fontSize: 12.5)),
            if (!granted && !iosBrowser && !denied && !unsupported) ...[
              const SizedBox(height: 9),
              FilledButton.icon(
                onPressed: pushBusy ? null : _enablePush,
                icon: const Icon(Icons.notifications_active_rounded, size: 17),
                label: Text(pushBusy ? 'جارٍ التفعيل...' : 'تفعيل الإشعارات'),
              ),
            ],
            if (pushError != null) ...[
              const SizedBox(height: 8),
              Text(pushError!, style: const TextStyle(
                fontSize: 12, color: BusinessBrand.danger)),
            ],
          ],
        )),
      ]),
    );
  }

  Future<void> load({bool silent = false}) async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    if (!silent) setState(() { loading = true; error = null; });
    try {
      final result = await widget.repository.businessNotifications(limit: 150);
      if (!mounted) return;
      setState(() {
        items = BusinessNotificationHelpers.distinctById(result);
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => error = '$e'.replaceFirst('Exception: ', ''));
      }
    } finally {
      _refreshing = false;
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  int get unread => items.where((e) => e['is_read'] != true).length;

  Future<void> markAll() async {
    if (unread == 0 || busy) return;
    setState(() => busy = true);
    try {
      await widget.repository.businessNotificationsMarkAll();
      if (!mounted) return;
      setState(() {
        items = items.map((e) => {...e, 'is_read': true}).toList();
      });
      BusinessNotificationSignal.received();
      await load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openItem(Map<String, dynamic> item) async {
    if (busy) return;
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isNotEmpty && item['is_read'] != true) {
      try {
        final marked = await widget.repository.businessNotificationMarkRead(id);
        if (marked && mounted) {
          setState(() {
            items = items.map((e) =>
              '${e['id'] ?? ''}' == id ? {...e, 'is_read': true} : e).toList();
          });
          BusinessNotificationSignal.received();
        }
      } catch (_) {
        // Opening a notification should still work if marking it read fails.
      }
    }

    final orderId = BusinessNotificationHelpers.orderId(item);
    if (!mounted) return;
    if (orderId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BusinessOrderDetailsScreen(
            repository: widget.repository,
            orderId: orderId,
          ),
        ),
      );
    }
    if (mounted) await load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final visible = unreadOnly
        ? items.where((item) => item['is_read'] != true).toList()
        : items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الإشعارات',
          style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'تحديث الإشعارات',
            onPressed: () => unawaited(load(silent: true)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (!loading && unread > 0)
            TextButton(
              onPressed: busy ? null : markAll,
              child: const Text('قراءة الكل',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => load(silent: true),
        child: loading
            ? ListView(children: const [
                SizedBox(height: 240),
                Center(child: CircularProgressIndicator()),
              ])
            : error != null
                ? ListView(children: [
                    const SizedBox(height: 160),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة')),
                      ]),
                    ),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(children: [
                          _pushSettings(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BusinessBrand.pastelCard(
                              BusinessBrand.teal, strength: .10),
                            child: Row(children: [
                              const Icon(Icons.notifications_active_rounded,
                                color: BusinessBrand.navy, size: 29),
                              const SizedBox(width: 11),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('$unread غير مقروء',
                                    style: const TextStyle(
                                      color: BusinessBrand.ink,
                                      fontWeight: FontWeight.w900, fontSize: 17)),
                                  Text('${items.length} إشعار ضمن آخر التنبيهات',
                                    style: const TextStyle(
                                      color: BusinessBrand.muted, fontSize: 11.5)),
                                ],
                              )),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          Row(children: [
                            ChoiceChip(
                              label: Text('الكل (${items.length})'),
                              selected: !unreadOnly,
                              onSelected: (_) => setState(() => unreadOnly = false),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text('غير مقروء ($unread)'),
                              selected: unreadOnly,
                              onSelected: (_) => setState(() => unreadOnly = true),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          if (visible.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 60),
                              child: Column(children: [
                                Icon(Icons.notifications_none_rounded, size: 43,
                                  color: BusinessBrand.muted),
                                SizedBox(height: 10),
                                Text('ماكو إشعارات بهالقسم',
                                  style: TextStyle(
                                    color: BusinessBrand.muted,
                                    fontWeight: FontWeight.w700)),
                              ]),
                            ),
                        ]);
                      }
                      final item = visible[index - 1];
                      final read = item['is_read'] == true;
                      final type = '${item['type'] ?? ''}';
                      final accent = _accent(type);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        decoration: BusinessBrand.pastelCard(
                          accent, strength: read ? .025 : .13),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 5),
                          onTap: () => unawaited(openItem(item)),
                          leading: Stack(clipBehavior: Clip.none, children: [
                            Container(
                              width: 43, height: 43,
                              decoration: BoxDecoration(
                                color: BusinessBrand.pastel(accent, strength: .23),
                                borderRadius: BorderRadius.circular(13)),
                              child: Icon(_icon(type), color: accent),
                            ),
                            if (!read) const Positioned(
                              top: -2, right: -2,
                              child: CircleAvatar(radius: 5,
                                backgroundColor: BusinessBrand.danger),
                            ),
                          ]),
                          title: Text('${item['title'] ?? 'لوحة تحكم منصة الين'}',
                            maxLines: 2,
                            style: const TextStyle(fontWeight: FontWeight.w900,
                              color: BusinessBrand.ink)),
                          subtitle: Text(
                            '${item['message'] ?? ''}\n${_dateTime(item['created_at'])}',
                            maxLines: 5, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: BusinessBrand.muted)),
                          trailing: BusinessNotificationHelpers.orderId(item) != null
                              ? Icon(Icons.chevron_left_rounded, color: accent)
                              : null,
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  static Color _accent(String type) => switch (type) {
    'new_order' || 'order_new' => BusinessBrand.success,
    'courier_assigned' || 'order_assigned' => const Color(0xFF397ACA),
    'library_order' || 'library_assigned' => const Color(0xFF8057B4),
    'order_update' => BusinessBrand.warning,
    _ => BusinessBrand.teal,
  };

  static IconData _icon(String type) => switch (type) {
    'new_order' || 'order_new' => Icons.shopping_bag_rounded,
    'courier_assigned' || 'order_assigned' => Icons.delivery_dining_rounded,
    'library_order' || 'library_assigned' => Icons.storefront_rounded,
    'order_update' => Icons.sync_alt_rounded,
    _ => Icons.notifications_rounded,
  };

  static String _dateTime(dynamic value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed == null) return '';
    final local = parsed.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${p(local.month)}/${p(local.day)} ${p(local.hour)}:${p(local.minute)}';
  }
}
