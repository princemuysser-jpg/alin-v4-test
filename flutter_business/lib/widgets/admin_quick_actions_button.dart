import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../screens/admin_delivery_pricing_screen.dart';
import '../screens/admin_finance_v2_screen.dart';

class AdminQuickActionsButton extends StatefulWidget {
  final BusinessRepository repository;
  final Future<void> Function()? onChanged;

  const AdminQuickActionsButton({super.key, required this.repository, this.onChanged});

  @override
  State<AdminQuickActionsButton> createState() => _AdminQuickActionsButtonState();
}

class _AdminQuickActionsButtonState extends State<AdminQuickActionsButton> {
  bool busy = false;

  void snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> changed() async {
    final callback = widget.onChanged;
    if (callback != null) await callback();
  }

  Future<void> openFinance() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminFinanceV2Screen(repository: widget.repository)),
    );
    await changed();
  }

  Future<void> openDeliveryPricing() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminDeliveryPricingScreen(repository: widget.repository)),
    );
    await changed();
  }

  Future<void> openActions() async {
    if (busy) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('إجراءات سريعة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _tile(sheetContext, Icons.person_add_alt_1_rounded, 'إضافة حساب', 'مدرس، مكتبة، مندوب، مطبعة أو حسابات', createAccount),
              _tile(sheetContext, Icons.delivery_dining_rounded, 'تعيين مندوب', 'تعيين مندوب لطلبات التوصيل فقط', assignCourier),
              _tile(sheetContext, Icons.local_shipping_rounded, 'التوصيل والمناطق', 'أسعار المناطق، أجرة المندوب وتسعير طلبات التوصيل', openDeliveryPricing),
              _tile(sheetContext, Icons.account_balance_wallet_rounded, 'المالية والتسويات', 'الأرصدة الرسمية، التسويات، العكس ومستحقات المطابع', openFinance),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext sheetContext, IconData icon, String title, String subtitle, Future<void> Function() action) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () async {
          Navigator.pop(sheetContext);
          await action();
        },
      ),
    );
  }

  Future<void> createAccount() async {
    final name = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final phone = TextEditingController();
    final area = TextEditingController();
    String role = 'teacher';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('إضافة حساب'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
              const SizedBox(height: 8),
              TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم الدخول')),
              const SizedBox(height: 8),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'نوع الحساب'),
                items: const [
                  DropdownMenuItem(value: 'teacher', child: Text('مدرس')),
                  DropdownMenuItem(value: 'library', child: Text('مكتبة')),
                  DropdownMenuItem(value: 'courier', child: Text('مندوب')),
                  DropdownMenuItem(value: 'printer', child: Text('مطبعة')),
                  DropdownMenuItem(value: 'accountant', child: Text('حسابات')),
                ],
                onChanged: (value) {
                  if (value != null) setLocal(() => role = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'الهاتف (اختياري)')),
              const SizedBox(height: 8),
              TextField(controller: area, decoration: const InputDecoration(labelText: 'المنطقة (اختياري)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final n = name.text.trim();
                final u = username.text.trim();
                final p = password.text;
                if (n.length < 2 || u.length < 3 || p.length < 6) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('تأكد من الاسم واسم الدخول وكلمة مرور لا تقل عن 6 أحرف')));
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': n,
                  'username': u,
                  'password': p,
                  'role': role,
                  'phone': phone.text.trim(),
                  'area': area.text.trim(),
                  'status': 'active',
                });
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    username.dispose();
    password.dispose();
    phone.dispose();
    area.dispose();
    if (payload == null) return;

    setState(() => busy = true);
    try {
      await widget.repository.adminCreateAccount(payload);
      await changed();
      snack('تم إنشاء الحساب بنجاح');
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool closed(Map<String, dynamic> order) => const {'completed', 'delivered', 'cancelled', 'rejected'}.contains('${order['status']}'.toLowerCase());

  bool delivery(Map<String, dynamic> order) {
    final fulfillment = '${order['fulfillment_type']}'.toLowerCase();
    final deliveryType = '${order['delivery_type']}'.toLowerCase();
    return fulfillment == 'home_delivery' || fulfillment == 'courier' || fulfillment == 'delivery' || deliveryType == 'courier';
  }

  Future<void> assignCourier() async {
    setState(() => busy = true);
    try {
      final values = await Future.wait([
        widget.repository.adminOrders(),
        widget.repository.adminCouriers(),
      ]);
      if (!mounted) return;
      final orders = (values[0] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => !closed(e) && delivery(e))
          .toList();
      final couriers = (values[1] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => '${e['status']}' == 'active')
          .toList();
      setState(() => busy = false);
      if (orders.isEmpty) {
        snack('لا توجد طلبات توصيل حالية تحتاج مندوب');
        return;
      }
      if (couriers.isEmpty) {
        snack('لا يوجد مندوب فعّال حالياً');
        return;
      }
      await chooseCourier(orders, couriers);
    } catch (e) {
      if (mounted) setState(() => busy = false);
      snack('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> chooseCourier(List<Map<String, dynamic>> orders, List<Map<String, dynamic>> couriers) async {
    String orderId = '${orders.first['id']}';
    String? courierId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('تعيين مندوب'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: orderId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'طلب التوصيل'),
                items: orders
                    .map((e) => DropdownMenuItem(
                          value: '${e['id']}',
                          child: Text('${e['order_number'] ?? e['id']} — ${e['title'] ?? 'طلب'}', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocal(() {
                      orderId = value;
                      courierId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: courierId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المندوب'),
                items: couriers
                    .map((e) => DropdownMenuItem(
                          value: '${e['id']}',
                          child: Text('${e['name'] ?? e['id']}', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setLocal(() => courierId = value),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: courierId == null ? null : () => Navigator.pop(dialogContext, true), child: const Text('تعيين')),
          ],
        ),
      ),
    );

    if (ok != true || courierId == null) return;
    setState(() => busy = true);
    try {
      await widget.repository.adminAssignOrder(orderId, courierId: courierId);
      await changed();
      snack('تم تعيين المندوب');
    } catch (e) {
      snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'admin-quick-actions',
      onPressed: busy ? null : openActions,
      icon: busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.bolt_rounded),
      label: Text(busy ? 'جارٍ التنفيذ' : 'إجراء سريع'),
    );
  }
}
