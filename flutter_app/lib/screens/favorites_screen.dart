import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import '../widgets/product_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = c.favoriteItems;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final width = MediaQuery.sizeOf(context).width;
    final columns = tablet ? (width >= 1050 ? 4 : 3) : 2;
    return Padding(
      padding: EdgeInsets.all(tablet ? 24 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المفضلة', style: TextStyle(fontSize: tablet ? 25 : 21, fontWeight: FontWeight.w900, color: AlinTheme.ink)),
          const SizedBox(height: 5),
          Text('${items.length} عنصر محفوظ', style: const TextStyle(color: AlinTheme.muted)),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('بعد ما ضفت شي للمفضلة'))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: tablet ? 16 : 10,
                      mainAxisSpacing: tablet ? 16 : 10,
                      childAspectRatio: tablet ? .76 : .63,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, index) => ProductCard(item: items[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
