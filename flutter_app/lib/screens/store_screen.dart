import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import '../models/catalog.dart';
import '../widgets/alin_network_image.dart';
import '../widgets/product_card.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final data = c.bootstrap;
    if (c.loading && data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 54, color: AlinTheme.muted),
              const SizedBox(height: 12),
              Text(c.error ?? 'تعذر تحميل المتجر', textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton(onPressed: c.refreshCatalog, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final columns = tablet ? (width >= 1050 ? 4 : 3) : 2;
    final ratio = tablet ? .76 : .63;
    final items = c.visibleItems;
    final selectedSubcategories = c.selectedCategoryId.isEmpty ? const <SubcategoryModel>[] : c.subcategoriesFor(c.selectedCategoryId);

    return RefreshIndicator(
      onRefresh: c.refreshCatalog,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(tablet ? 24 : 14, 18, tablet ? 24 : 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data.banners.isNotEmpty) _BannerCarousel(banners: data.banners.take(4).toList()),
                  if (data.banners.isNotEmpty) const SizedBox(height: 16),
                  TextField(
                    onChanged: c.setSearch,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن ملزمة، مادة، مدرس أو منتج',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: c.search.isEmpty
                          ? null
                          : IconButton(onPressed: () => c.setSearch(''), icon: const Icon(Icons.close)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CategoryStrip(categories: data.categories),
                  if (selectedSubcategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SubcategoryStrip(items: selectedSubcategories),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.selectedCategoryId.isEmpty ? 'كل المنتجات والملازم' : data.categories.where((e) => e.id == c.selectedCategoryId).map((e) => e.name).firstOrNull ?? 'القسم',
                          style: TextStyle(fontSize: tablet ? 22 : 18, fontWeight: FontWeight.w900, color: AlinTheme.ink),
                        ),
                      ),
                      SizedBox(
                        width: tablet ? 210 : 150,
                        child: DropdownButtonFormField<String>(
                          initialValue: c.sort,
                          isDense: true,
                          decoration: const InputDecoration(labelText: 'الترتيب'),
                          items: const [
                            DropdownMenuItem(value: 'default', child: Text('افتراضي')),
                            DropdownMenuItem(value: 'price_asc', child: Text('السعر الأقل')),
                            DropdownMenuItem(value: 'price_desc', child: Text('السعر الأعلى')),
                            DropdownMenuItem(value: 'name', child: Text('الاسم')),
                          ],
                          onChanged: (value) => c.setSort(value ?? 'default'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${items.length} عنصر', style: const TextStyle(color: AlinTheme.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('ماكو نتائج مطابقة حالياً')),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(tablet ? 24 : 14, 8, tablet ? 24 : 14, tablet ? 28 : 20),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: tablet ? 16 : 10,
                  mainAxisSpacing: tablet ? 16 : 10,
                  childAspectRatio: ratio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(item: items[index]),
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  final List<CategoryModel> categories;
  const _CategoryStrip({required this.categories});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final all = [CategoryModel(id: '', name: 'الكل', type: 'all', sortOrder: -1), ...categories];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = all[index];
          final selected = c.selectedCategoryId == item.id;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => c.selectCategory(item.id),
            label: Text(item.name, maxLines: 1),
            avatar: Icon(
              item.type == 'booklet' ? Icons.menu_book_outlined : item.type == 'gift' ? Icons.card_giftcard : item.type == 'stationery' ? Icons.edit_note : Icons.grid_view_rounded,
              size: 18,
            ),
          );
        },
      ),
    );
  }
}

class _SubcategoryStrip extends StatelessWidget {
  final List<SubcategoryModel> items;
  const _SubcategoryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final all = [SubcategoryModel(id: '', name: 'كل القسم', parentCategoryId: c.selectedCategoryId, sortOrder: -1), ...items];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final item = all[index];
          return ChoiceChip(
            selected: c.selectedSubcategoryId == item.id,
            onSelected: (_) => c.selectSubcategory(item.id),
            label: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        },
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List<BannerModel> banners;
  const _BannerCarousel({required this.banners});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final controller = PageController(viewportFraction: .96);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return SizedBox(
      height: tablet ? 220 : 150,
      child: PageView.builder(
        controller: controller,
        itemCount: widget.banners.length,
        itemBuilder: (context, index) {
          final banner = widget.banners[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner.imagePath.isNotEmpty)
                    AlinNetworkImage(path: banner.imagePath, fit: BoxFit.cover)
                  else
                    Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AlinTheme.navy, Color(0xFF1468A8)]))),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .68)]))),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(banner.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: tablet ? 22 : 17, fontWeight: FontWeight.w900)),
                          if (banner.subtitle.isNotEmpty) Text(banner.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
