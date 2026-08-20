import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_config.dart';
import '../widgets/alin_network_image.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final coupon = TextEditingController();
  Map<String, dynamic>? quote;
  bool quoteBusy = false;
  String? quoteError;

  @override
  void dispose() {
    coupon.dispose();
    super.dispose();
  }

  num _num(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;

  Future<void> applyCoupon() async {
    final c = AppScope.of(context);
    final code = coupon.text.trim();
    if (code.isEmpty) {
      setState(() {
        quote = null;
        quoteError = null;
      });
      c.pendingCouponCode = null;
      return;
    }
    setState(() {
      quoteBusy = true;
      quoteError = null;
    });
    try {
      final result = await c.quoteCart(couponCode: code);
      if (!mounted) return;
      setState(() => quote = result);
      c.useCoupon(code);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        quote = null;
        quoteError = '$e'.replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => quoteBusy = false);
    }
  }

  Future<void> checkout() async {
    final c = AppScope.of(context);
    final code = coupon.text.trim();
    if (code.isNotEmpty) {
      await applyCoupon();
      if (!mounted || quote == null) return;
      c.useCoupon(code);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final subtotal = quote == null ? c.cartTotal : _num(quote!['subtotal']);
    final discount = quote == null ? 0 : _num(quote!['discount']);
    final afterDiscount = quote == null ? c.cartTotal : _num(quote!['total']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المشتريات'),
        actions: [if (c.cart.isNotEmpty) TextButton(onPressed: c.clearCart, child: const Text('تفريغ السلة'))],
      ),
      body: c.cart.isEmpty
          ? const Center(child: Text('السلة فارغة'))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(tablet ? 24 : 14),
                    children: [
                      ...List.generate(c.cart.length, (index) {
                        final line = c.cart[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: tablet ? 110 : 82,
                                    height: tablet ? 110 : 82,
                                    child: AlinNetworkImage(
                                      path: line.variant?.imagePath.isNotEmpty == true ? line.variant!.imagePath : line.item.imagePath,
                                      fit: BoxFit.contain,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(line.item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                                        if (line.variant != null) Text('التصميم: ${line.variant!.name}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        if (line.purchaseType == 'pack') Text('باكيت ${line.item.packSize}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                        const SizedBox(height: 6),
                                        Text('${line.total.toStringAsFixed(0)} ${AlinConfig.currency}', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    children: [
                                      IconButton(onPressed: () => c.setCartQty(index, line.qty + 1), icon: const Icon(Icons.add_circle_outline)),
                                      Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                      IconButton(onPressed: () => c.setCartQty(index, line.qty - 1), icon: Icon(line.qty == 1 ? Icons.delete_outline : Icons.remove_circle_outline, color: line.qty == 1 ? Colors.red : null)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('كود الخصم', style: TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: coupon,
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: const InputDecoration(hintText: 'اكتب كود الخصم'),
                                      onSubmitted: (_) => applyCoupon(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: quoteBusy ? null : applyCoupon,
                                    child: quoteBusy
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('تطبيق'),
                                  ),
                                ],
                              ),
                              if (quoteError != null) ...[
                                const SizedBox(height: 8),
                                Text(quoteError!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w700)),
                              ],
                              if (quote != null) ...[
                                const SizedBox(height: 12),
                                _PriceLine(title: 'المبلغ قبل الخصم', value: subtotal),
                                _PriceLine(title: 'قيمة الخصم', value: -discount, emphasis: true),
                                const Divider(),
                                _PriceLine(title: 'المبلغ بعد الخصم', value: afterDiscount, strong: true),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
                    padding: EdgeInsets.fromLTRB(tablet ? 28 : 16, 14, tablet ? 28 : 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(quote == null ? 'الإجمالي' : 'بعد الخصم', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${afterDiscount.toStringAsFixed(0)} ${AlinConfig.currency}', style: TextStyle(fontSize: tablet ? 22 : 19, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: tablet ? 240 : 170,
                          child: ElevatedButton(
                            onPressed: quoteBusy ? null : checkout,
                            child: const Text('إكمال الطلب', style: TextStyle(fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String title;
  final num value;
  final bool strong;
  final bool emphasis;
  const _PriceLine({required this.title, required this.value, this.strong = false, this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    final abs = value.abs();
    final prefix = value < 0 ? '- ' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700))),
          Text('$prefix${abs.toStringAsFixed(0)} ${AlinConfig.currency}', style: TextStyle(fontSize: strong ? 18 : 14, fontWeight: FontWeight.w900, color: emphasis ? Colors.green.shade700 : null)),
        ],
      ),
    );
  }
}
