import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_config.dart';
import '../core/alin_theme.dart';
import '../models/catalog.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final notes = TextEditingController();
  final coupon = TextEditingController();
  final landmark = TextEditingController();
  String fulfillmentType = 'pickup';
  LibraryModel? library;
  DeliveryAreaModel? area;
  bool busy = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final student = AppScope.of(context).student;
    if (student != null) {
      if (name.text.isEmpty) name.text = student.name;
      if (phone.text.isEmpty) phone.text = student.phone;
    }
    if (coupon.text.isEmpty) {
      final pending = AppScope.of(context).takePendingCoupon();
      if (pending != null && pending.isNotEmpty) coupon.text = pending;
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    notes.dispose();
    coupon.dispose();
    landmark.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final c = AppScope.of(context);
    final customerName = c.student?.name ?? name.text.trim();
    final customerPhone = c.student?.phone ?? phone.text.trim();
    if (customerName.length < 2) return _setError('اكتب اسم الطالب بصورة صحيحة');
    if (!RegExp(r'^\+?[0-9٠-٩]{7,15}$').hasMatch(customerPhone.replaceAll(' ', ''))) return _setError('اكتب رقم هاتف صحيح');

    final hasPhysical = c.cart.any((line) => line.item.isProduct);
    if (hasPhysical && fulfillmentType == 'pickup') {
      fulfillmentType = 'home_delivery';
    }

    Map<String, dynamic> fulfillment;
    if (fulfillmentType == 'pickup') {
      if (library == null) return _setError('اختر مكتبة الاستلام');
      fulfillment = {
        'fulfillment_type': 'pickup',
        'library_id': library!.id,
        'pickup_library_id': library!.id,
        'library_name': library!.name,
        'pickup_library_name': library!.name,
      };
    } else {
      if (area == null) return _setError('اختر منطقة التوصيل');
      if (landmark.text.trim().isEmpty) return _setError('اكتب أقرب نقطة دالة');
      fulfillment = {
        'fulfillment_type': 'home_delivery',
        'delivery_area': area!.name,
        'delivery_landmark': landmark.text.trim(),
        'delivery_latitude': null,
        'delivery_longitude': null,
        'delivery_location_accuracy': null,
      };
    }

    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await c.placeOrder(
        name: customerName,
        phone: customerPhone,
        notes: notes.text,
        fulfillment: fulfillment,
        couponCode: coupon.text,
      );
      if (!mounted) return;
      final number = '${result['order_number'] ?? result['order_id'] ?? 'تم إنشاء الطلب'}';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 54),
          title: const Text('تم إرسال طلبك'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('احتفظ برقم الطلب حتى تگدر تتابعه.'),
              const SizedBox(height: 12),
              SelectableText(number, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AlinTheme.navy)),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('تم'))],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      _setError('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _setError(String value) {
    if (!mounted) return;
    setState(() => error = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final data = c.bootstrap;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final hasPhysical = c.cart.any((line) => line.item.isProduct);
    if (hasPhysical && fulfillmentType == 'pickup') fulfillmentType = 'home_delivery';
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الطلب')),
      body: ListView(
        padding: EdgeInsets.all(tablet ? 28 : 16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Section(
                    title: 'بيانات الطالب',
                    child: Column(
                      children: [
                        TextField(controller: name, readOnly: c.student != null, decoration: const InputDecoration(labelText: 'الاسم')),
                        const SizedBox(height: 12),
                        TextField(controller: phone, readOnly: c.student != null, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                        if (c.student != null) ...[
                          const SizedBox(height: 8),
                          Text('الطلب مربوط بحساب ${c.student!.name}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'طريقة الاستلام',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'pickup', icon: Icon(Icons.store_mall_directory_outlined), label: Text('استلام من مكتبة')),
                            ButtonSegment(value: 'home_delivery', icon: Icon(Icons.delivery_dining), label: Text('توصيل')),
                          ],
                          selected: {fulfillmentType},
                          onSelectionChanged: busy ? null : (value) {
                            final next = value.first;
                            if (hasPhysical && next == 'pickup') return;
                            setState(() => fulfillmentType = next);
                          },
                        ),
                        if (hasPhysical) ...[
                          const SizedBox(height: 8),
                          const Text('القرطاسية والهدايا متاحة بالتوصيل فقط.', style: TextStyle(color: AlinTheme.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 14),
                        if (fulfillmentType == 'pickup')
                          DropdownButtonFormField<LibraryModel>(
                            initialValue: library,
                            decoration: const InputDecoration(labelText: 'اختر المكتبة'),
                            items: data.libraries
                                .where((e) => e.isOpen)
                                .map((e) => DropdownMenuItem(value: e, child: Text('${e.name}${e.area.isEmpty ? '' : ' — ${e.area}'}', overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: busy ? null : (value) => setState(() => library = value),
                          )
                        else ...[
                          DropdownButtonFormField<DeliveryAreaModel>(
                            initialValue: area,
                            decoration: const InputDecoration(labelText: 'منطقة التوصيل'),
                            items: data.deliveryAreas.map((e) => DropdownMenuItem(value: e, child: Text(e.deliveryFee > 0 ? '${e.name} — ${e.deliveryFee.toStringAsFixed(0)} د.ع' : e.name))).toList(),
                            onChanged: busy ? null : (value) => setState(() => area = value),
                          ),
                          const SizedBox(height: 12),
                          TextField(controller: landmark, maxLength: 300, decoration: const InputDecoration(labelText: 'أقرب نقطة دالة')),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'إضافات',
                    child: Column(
                      children: [
                        TextField(controller: coupon, decoration: const InputDecoration(labelText: 'كود الخصم — اختياري')),
                        const SizedBox(height: 12),
                        TextField(controller: notes, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'ملاحظات الطلب — اختياري')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(child: Text(fulfillmentType == 'home_delivery' && area != null ? 'الإجمالي التقريبي' : 'إجمالي السلة', style: const TextStyle(fontWeight: FontWeight.w800))),
                          Text('${(c.cartTotal + (fulfillmentType == 'home_delivery' ? (area?.deliveryFee ?? 0) : 0)).toStringAsFixed(0)} ${AlinConfig.currency}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AlinTheme.navy)),
                        ],
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                      child: Text(error!, style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: busy ? null : submit,
                    icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline),
                    label: Text(busy ? 'جارٍ إرسال الطلب...' : 'تأكيد الطلب'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}
