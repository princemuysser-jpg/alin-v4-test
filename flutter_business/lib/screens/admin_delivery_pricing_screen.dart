import 'package:flutter/material.dart';

import '../data/admin_delivery_pricing_repository.dart';
import '../data/business_repository.dart';

class AdminDeliveryPricingScreen extends StatefulWidget {
  final BusinessRepository repository;

  const AdminDeliveryPricingScreen({super.key, required this.repository});

  @override
  State<AdminDeliveryPricingScreen> createState() => _AdminDeliveryPricingScreenState();
}

class _AdminDeliveryPricingScreenState extends State<AdminDeliveryPricingScreen> {
  bool loading = true;
  bool busy = false;
  String? error;
  String tab = 'areas';
  List<Map<String, dynamic>> areas = [];
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  bool closed(Map<String, dynamic> order) => const {'completed', 'delivered', 'cancelled', 'rejected'}.contains('${order['status']}'.toLowerCase());

  bool delivery(Map<String, dynamic> order) {
    final fulfillment = '${order['fulfillment_type']}'.toLowerCase();
    final type = '${order['delivery_type']}'.toLowerCase();
    return fulfillment == 'home_delivery' || fulfillment == 'courier' || fulfillment == 'delivery' || type == 'courier';
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.adminDeliveryAreas(),
        widget.repository.adminOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        areas = (results[0] as List).cast<Map<String, dynamic>>();
        orders = (results[1] as List).cast<Map<String, dynamic>>().where((o) => delivery(o) && !closed(o)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  num n(dynamic v) => num.tryParse('$v') ?? 0;
  String money(dynamic v) => '${n(v).round()} د.ع';

  Future<void> editArea([Map<String, dynamic>? area]) async {
    final name = TextEditingController(text: '${area?['name'] ?? ''}');
    final deliveryFee = TextEditingController(text: area == null ? '' : '${n(area['delivery_fee']).round()}');
    final courierFee = TextEditingController(text: area == null ? '' : '${n(area['courier_fee']).round()}');
    bool active = area?['active'] != false && '${area?['status'] ?? 'active'}' != 'inactive';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(area == null ? 'إضافة منطقة' : 'تعديل المنطقة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنطقة')),
              const SizedBox(height: 8),
              TextField(controller: deliveryFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر على الطالب')),
              const SizedBox(height: 8),
              TextField(controller: courierFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أجرة المندوب')),
              const SizedBox(height: 8),
              SwitchListTile(
                value: active,
                contentPadding: EdgeInsets.zero,
                title: const Text('المنطقة فعّالة'),
                onChanged: (v) => setLocal(() => active = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final nm = name.text.trim();
                final df = num.tryParse(deliveryFee.text.trim());
                final cf = num.tryParse(courierFee.text.trim());
                if (nm.length < 2 || df == null || cf == null || df < 0 || cf < 0) return;
                Navigator.pop(dialogContext, {'name': nm, 'delivery_fee': df, 'courier_fee': cf, 'active': active});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    deliveryFee.dispose();
    courierFee.dispose();
    if (result == null) return;

    setState(() => busy = true);
    try {
      await widget.repository.adminUpsertDeliveryArea(
        id: area?['id']?.toString(),
        name: '${result['name']}',
        deliveryFee: result['delivery_fee'] as num,
        courierFee: result['courier_fee'] as num,
        active: result['active'] == true,
      );
      await load();
      _snack('تم حفظ المنطقة');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> priceOrder(Map<String, dynamic> order) async {
    String mode = 'area';
    final deliveryFee = TextEditingController(text: '${n(order['delivery_fee']).round()}');
    final courierFee = TextEditingController(text: '${n(order['courier_fee']).round()}');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('تسعير الطلب ${order['order_number'] ?? order['id']}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'نوع التسعير'),
                items: const [
                  DropdownMenuItem(value: 'area', child: Text('سعر المنطقة')),
                  DropdownMenuItem(value: 'free', child: Text('توصيل مجاني')),
                  DropdownMenuItem(value: 'custom', child: Text('مبلغ خاص')),
                ],
                onChanged: (v) {
                  if (v != null) setLocal(() => mode = v);
                },
              ),
              if (mode == 'custom') ...[
                const SizedBox(height: 10),
                TextField(controller: deliveryFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'على الطالب')),
                const SizedBox(height: 10),
                TextField(controller: courierFee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أجرة المندوب')),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final df = num.tryParse(deliveryFee.text.trim()) ?? 0;
                final cf = num.tryParse(courierFee.text.trim()) ?? 0;
                if (mode == 'custom' && (df < 0 || cf < 0)) return;
                Navigator.pop(dialogContext, {'mode': mode, 'delivery_fee': df, 'courier_fee': cf});
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );

    deliveryFee.dispose();
    courierFee.dispose();
    if (result == null) return;

    setState(() => busy = true);
    try {
      await widget.repository.adminSetOrderDeliveryPricing(
        orderId: '${order['id']}',
        mode: '${result['mode']}',
        deliveryFee: result['mode'] == 'custom' ? result['delivery_fee'] as num : null,
        courierFee: result['mode'] == 'custom' ? result['courier_fee'] as num : null,
      );
      await load();
      _snack('تم تحديث تسعير الطلب');
    } catch (e) {
      _snack('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التوصيل والمناطق'),
        actions: [IconButton(onPressed: busy ? null : load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'areas', label: Text('المناطق'), icon: Icon(Icons.location_on_rounded)),
                        ButtonSegment(value: 'orders', label: Text('تسعير الطلبات'), icon: Icon(Icons.local_shipping_rounded)),
                      ],
                      selected: {tab},
                      onSelectionChanged: (v) => setState(() => tab = v.first),
                    ),
                  ),
                  Expanded(child: tab == 'areas' ? _areas() : _orders()),
                ]),
      floatingActionButton: tab == 'areas'
          ? FloatingActionButton.extended(onPressed: busy ? null : () => editArea(), icon: const Icon(Icons.add_location_alt_rounded), label: const Text('إضافة منطقة'))
          : null,
    );
  }

  Widget _areas() {
    if (areas.isEmpty) return const Center(child: Text('لا توجد مناطق توصيل'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
      itemCount: areas.length,
      itemBuilder: (_, i) {
        final a = areas[i];
        final active = a['active'] != false && '${a['status']}' != 'inactive';
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(active ? Icons.location_on_rounded : Icons.location_off_rounded)),
            title: Text('${a['name'] ?? 'منطقة'}', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('على الطالب: ${money(a['delivery_fee'])}\nأجرة المندوب: ${money(a['courier_fee'])}'),
            isThreeLine: true,
            trailing: Chip(label: Text(active ? 'فعّالة' : 'موقوفة')),
            onTap: busy ? null : () => editArea(a),
          ),
        );
      },
    );
  }

  Widget _orders() {
    if (orders.isEmpty) return const Center(child: Text('لا توجد طلبات توصيل حالية'));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final o = orders[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.delivery_dining_rounded)),
            title: Text('${o['order_number'] ?? o['id']} — ${o['title'] ?? 'طلب'}', style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${o['delivery_area'] ?? 'بدون منطقة'}\nعلى الطالب: ${money(o['delivery_fee'])} • المندوب: ${money(o['courier_fee'])}'),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: busy ? null : () => priceOrder(o),
          ),
        );
      },
    );
  }
}
