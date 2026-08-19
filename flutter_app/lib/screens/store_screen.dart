import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import '../models/catalog.dart';
import '../widgets/alin_network_image.dart';
import '../widgets/product_card.dart';
import 'details_screen.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  bool catalogMode = false;
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _openHome(dynamic c) {
    c.setSearch('');
    c.selectCategory('');
    searchController.clear();
    setState(() => catalogMode = false);
  }

  void _openAll(dynamic c) {
    c.setSearch('');
    c.selectCategory('');
    searchController.clear();
    setState(() => catalogMode = true);
  }

  void _openCategory(dynamic c, String id) {
    c.setSearch('');
    searchController.clear();
    c.selectCategory(id);
    setState(() => catalogMode = true);
  }

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
    final roomy = width >= 700;
    final showCatalog = catalogMode || c.search.trim().isNotEmpty || c.selectedCategoryId.isNotEmpty;

    return RefreshIndicator(
      onRefresh: c.refreshCatalog,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(roomy ? 20 : 12, 12, roomy ? 20 : 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SearchBox(
                    controller: searchController,
                    onChanged: (value) {
                      c.setSearch(value);
                      setState(() {
                        if (value.trim().isNotEmpty) catalogMode = true;
                      });
                    },
                    onClear: () {
                      searchController.clear();
                      c.setSearch('');
                      if (c.selectedCategoryId.isEmpty) setState(() => catalogMode = false);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (data.banners.isNotEmpty) ...[
                    _BannerCarousel(banners: data.banners.take(4).toList()),
                    const SizedBox(height: 12),
                  ],
                  if (!showCatalog) ...[
                    _HomeCategories(
                      categories: data.categories,
                      onAll: () => _openAll(c),
                      onCategory: (id) => _openCategory(c, id),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _CatalogTopBar(
                      title: _catalogTitle(c, data),
                      count: c.visibleItems.length,
                      onBack: () => _openHome(c),
                    ),
                    if (c.selectedCategoryId.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SubcategoryStrip(items: c.subcategoriesFor(c.selectedCategoryId)),
                    ],
                    const SizedBox(height: 10),
                    _SortRow(),
                  ],
                ],
              ),
            ),
          ),
          if (!showCatalog) ..._homeSlivers(context, data) else ..._catalogSlivers(context, c),
        ],
      ),
    );
  }

  String _catalogTitle(dynamic c, BootstrapData data) {
    if (c.search.trim().isNotEmpty) return 'نتائج البحث';
    if (c.selectedCategoryId.isEmpty) return 'كل المنتجات والملازم';
    return data.categories.where((e) => e.id == c.selectedCategoryId).map((e) => e.name).firstOrNull ?? 'القسم';
  }

  List<Widget> _homeSlivers(BuildContext context, BootstrapData data) {
    final all = data.items;
    final offers = all.where((e) => e.oldPrice != null).toList();
    final booklets = all.where((e) => e.isBooklet).take(10).toList();
    final products = all.where((e) => e.isProduct).take(10).toList();
    final mixed = all.take(10).toList();

    final sections = <Widget>[];
    if (offers.isNotEmpty) {
      sections.add(_ShelfSection(title: 'عروض الآن', subtitle: 'خصومات مختارة من منصة آلين', items: offers.take(10).toList()));
    }
    if (mixed.isNotEmpty) {
      sections.add(_ShelfSection(title: 'مختارات آلين', subtitle: 'منتجات وملازم نقترحها إلك', items: mixed));
    }
    if (booklets.isNotEmpty) {
      sections.add(_ShelfSection(title: 'ملازم للطلاب', subtitle: 'أحدث الملازم المتوفرة', items: booklets));
    }
    if (products.isNotEmpty) {
      sections.add(_ShelfSection(title: 'وصل حديثاً', subtitle: 'قرطاسية وهدايا ومنتجات جديدة', items: products));
    }

    return [
      for (final section in sections)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: section,
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
    ];
  }

  List<Widget> _catalogSlivers(BuildContext context, dynamic c) {
    final items = c.visibleItems as List<StoreItem>;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1120 ? 4 : width >= 700 ? 3 : 2;
    final ratio = width >= 700 ? .78 : .64;
    final side = width >= 700 ? 20.0 : 12.0;

    if (items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('ماكو نتائج مطابقة حالياً')),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(side, 2, side, 22),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: width >= 700 ? 14 : 9,
            mainAxisSpacing: width >= 700 ? 14 : 9,
            childAspectRatio: ratio,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => ProductCard(item: items[index]),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBox({required this.controller, required this.onChanged, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AlinTheme.line),
        boxShadow: [BoxShadow(color: AlinTheme.navy.withValues(alpha: .04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'ابحث عن ملزمة، مادة، مدرس أو منتج',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty ? null : IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded)),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
        ),
      ),
    );
  }
}

class _HomeCategories extends StatelessWidget {
  final List<CategoryModel> categories;
  final VoidCallback onAll;
  final ValueChanged<String> onCategory;

  const _HomeCategories({required this.categories, required this.onAll, required this.onCategory});

  @override
  Widget build(BuildContext context) {
    final all = [CategoryModel(id: '', name: 'كل المنتجات', type: 'all', sortOrder: -1), ...categories];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(title: 'تسوق حسب القسم', subtitle: 'اختار القسم المناسب إلك'),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final item = all[index];
              final icon = item.type == 'booklet'
                  ? Icons.menu_book_rounded
                  : item.type == 'gift'
                      ? Icons.card_giftcard_rounded
                      : item.type == 'stationery'
                          ? Icons.edit_note_rounded
                          : Icons.grid_view_rounded;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: item.id.isEmpty ? onAll : () => onCategory(item.id),
                child: Container(
                  width: 132,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AlinTheme.line),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFEAF2FB), borderRadius: BorderRadius.circular(13)),
                        child: Icon(icon, color: AlinTheme.navy, size: 22),
                      ),
                      const SizedBox(height: 5),
                      Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShelfSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<StoreItem> items;

  const _ShelfSection({required this.title, required this.subtitle, required this.items});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final roomy = width >= 700;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: roomy ? 20 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeading(title: title, subtitle: subtitle),
          const SizedBox(height: 10),
          SizedBox(
            height: roomy ? 270 : 238,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: roomy ? 190 : 164,
                child: _ShelfCard(item: items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final StoreItem item;
  const _ShelfCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final favorite = c.isFavorite(item);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(item: item))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AlinTheme.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFFF9FBFD),
                        padding: const EdgeInsets.all(10),
                        child: AlinNetworkImage(path: item.imagePath, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Material(
                        color: Colors.white.withValues(alpha: .94),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => c.toggleFavorite(item),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(favorite ? Icons.favorite : Icons.favorite_border, color: favorite ? Colors.red : AlinTheme.navy, size: 19),
                          ),
                        ),
                      ),
                    ),
                    if (item.oldPrice != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(color: AlinTheme.gold, borderRadius: BorderRadius.circular(99)),
                          child: const Text('عرض', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(item.subtitle.isEmpty ? (item.isBooklet ? 'ملزمة' : 'منتج') : item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: AlinTheme.muted)),
                    const SizedBox(height: 6),
                    Text(item.priceText, style: const TextStyle(fontSize: 14, color: AlinTheme.navy, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, color: AlinTheme.ink, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AlinTheme.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CatalogTopBar extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onBack;

  const _CatalogTopBar({required this.title, required this.count, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(onPressed: onBack, icon: const Icon(Icons.arrow_forward_rounded), tooltip: 'الرئيسية'),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, color: AlinTheme.ink, fontWeight: FontWeight.w900)),
              Text('$count عنصر', style: const TextStyle(fontSize: 11, color: AlinTheme.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 180,
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
    );
  }
}

class _SubcategoryStrip extends StatelessWidget {
  final List<SubcategoryModel> items;
  const _SubcategoryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
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
  final controller = PageController(viewportFraction: .97);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = width >= 700 ? 220.0 : 162.0;
    return SizedBox(
      height: height,
      child: PageView.builder(
        controller: controller,
        itemCount: widget.banners.length,
        itemBuilder: (context, index) {
          final banner = widget.banners[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (banner.imagePath.isNotEmpty)
                    AlinNetworkImage(path: banner.imagePath, fit: BoxFit.cover)
                  else
                    Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [AlinTheme.navy, Color(0xFF1468A8)]))),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: .62)],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            banner.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: width >= 700 ? 21 : 16, fontWeight: FontWeight.w900),
                          ),
                          if (banner.subtitle.isNotEmpty)
                            Text(banner.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
