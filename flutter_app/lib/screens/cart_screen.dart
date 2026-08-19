import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_config.dart';
import '../core/alin_theme.dart';
import '../widgets/alin_network_image.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
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
                  child: ListView.separated(
                    padding: EdgeInsets.all(tablet ? 24 : 14),
                    itemCount: c.cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final line = c.cart[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: tablet ? 110 : 82,
                                height: tablet ? 110 : 82,
                                child: AlinNetworkImage(path: line.variant?.imagePath.isNotEmpty == true ? line.variant!.imagePath : line.item.imagePath, fit: BoxFit.contain, borderRadius: BorderRadius.circular(12)),
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
                      );
                    },
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
                              Text('الإجمالي', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                              Text('${c.cartTotal.toStringAsFixed(0)} ${AlinConfig.currency}', style: TextStyle(fontSize: tablet ? 22 : 19, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: tablet ? 240 : 170,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckoutScreen())),
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
