import 'package:flutter/material.dart';
import '../core/alin_theme.dart';
import '../core/app_scope.dart';
import '../models/catalog.dart';
import '../screens/details_screen.dart';
import 'alin_network_image.dart';

class ProductCard extends StatelessWidget {
  final StoreItem item;
  const ProductCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final favorite = c.isFavorite(item);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(item: item))),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF102F4D) : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(10),
                      child: AlinNetworkImage(path: item.imagePath, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => c.toggleFavorite(item),
                        icon: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.red : AlinTheme.navy, size: 20),
                      ),
                    ),
                  ),
                  if (item.oldPrice != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: AlinTheme.gold, borderRadius: BorderRadius.circular(99)),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('عرض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text(item.priceText, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 15))),
                      if (item.oldPrice != null)
                        Text(item.oldPrice!.toStringAsFixed(0), style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(item: item))),
                      child: Text(c.tr('تفاصيل', ku: 'وردەکاری', en: 'Details'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
