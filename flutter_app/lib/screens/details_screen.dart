import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import '../models/catalog.dart';
import '../widgets/alin_network_image.dart';

class DetailsScreen extends StatefulWidget {
  final StoreItem item;
  const DetailsScreen({super.key, required this.item});

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  VariantModel? selectedVariant;
  String purchaseType = 'unit';
  int imageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final item = widget.item;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final images = item.images.isEmpty ? [item.imagePath] : item.images;
    final currentPath = selectedVariant?.imagePath.isNotEmpty == true
        ? selectedVariant!.imagePath
        : images[(imageIndex >= 0 && imageIndex < images.length) ? imageIndex : 0];

    Future<void> add() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await c.addToCart(item, purchaseType: purchaseType, variant: selectedVariant);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('تمت الإضافة إلى السلة')));
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
      }
    }

    final gallery = Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: tablet ? 1.25 : 1,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: AlinNetworkImage(path: currentPath, fit: BoxFit.contain, borderRadius: BorderRadius.circular(20)),
            ),
          ),
          if (images.length > 1)
            SizedBox(
              height: 78,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => InkWell(
                  onTap: () => setState(() => imageIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 62,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: imageIndex == index ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: imageIndex == index ? 2 : 1),
                    ),
                    child: AlinNetworkImage(path: images[index], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final info = Padding(
      padding: EdgeInsets.all(tablet ? 28 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.title, style: TextStyle(fontSize: tablet ? 28 : 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface))),
              IconButton(
                onPressed: () => c.toggleFavorite(item),
                icon: Icon(c.isFavorite(item) ? Icons.favorite : Icons.favorite_border, color: c.isFavorite(item) ? Colors.red : AlinTheme.navy),
              ),
            ],
          ),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(item.subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Text(item.priceText, style: TextStyle(fontSize: tablet ? 24 : 21, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
              if (item.oldPrice != null) ...[
                const SizedBox(width: 10),
                Text('${item.oldPrice!.toStringAsFixed(0)} د.ع', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
              ],
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('التفاصيل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(item.description, style: TextStyle(height: 1.7, color: Theme.of(context).colorScheme.onSurface)),
          ],
          if (item.hasVariants) ...[
            const SizedBox(height: 22),
            const Text('اختر التصميم', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: item.variants.map((variant) {
                final selected = selectedVariant?.id == variant.id;
                return ChoiceChip(
                  selected: selected,
                  onSelected: variant.stock <= 0 ? null : (_) => setState(() => selectedVariant = variant),
                  label: Text('${variant.name}${variant.stock <= 0 ? ' — نفذ' : ''}'),
                  avatar: variant.imagePath.isEmpty
                      ? null
                      : SizedBox(width: 28, height: 28, child: AlinNetworkImage(path: variant.imagePath, fit: BoxFit.contain)),
                );
              }).toList(),
            ),
          ],
          if (item.hasPack) ...[
            const SizedBox(height: 22),
            const Text('طريقة الشراء', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'unit', label: Text('مفرد • ${item.price.toStringAsFixed(0)} د.ع')),
                ButtonSegment(value: 'pack', label: Text('باكيت ${item.packSize} • ${item.packPrice!.toStringAsFixed(0)} د.ع')),
              ],
              selected: {purchaseType},
              onSelectionChanged: (value) => setState(() => purchaseType = value.first),
            ),
          ],
          if (item.isProduct) ...[
            const SizedBox(height: 16),
            Text(item.stock > 0 ? 'متوفر بالمخزون: ${item.stock}' : 'نفد من المخزون', style: TextStyle(color: item.stock > 0 ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: item.isProduct && item.stock <= 0 ? null : add,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('إضافة إلى السلة', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المنتج')),
      body: tablet
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: SingleChildScrollView(child: gallery)),
                const VerticalDivider(width: 1),
                Expanded(flex: 10, child: SingleChildScrollView(child: info)),
              ],
            )
          : ListView(children: [gallery, info]),
    );
  }
}
