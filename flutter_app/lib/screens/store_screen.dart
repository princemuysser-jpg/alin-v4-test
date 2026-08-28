import 'dart:async';
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
      final width = MediaQuery.sizeOf(context).width;
      final roomy = width >= 700;
      final title = c.tr(
        'تعذر الاتصال بالإنترنت',
        ku: 'پەیوەندی بە ئینتەرنێتەوە نەکرا',
        en: 'No internet connection',
      );
      final message = c.tr(
        'تحقق من اتصالك بالإنترنت وحاول مرة ثانية.',
        ku: 'پەیوەندی ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵ بدە.',
        en: 'Check your internet connection and try again.',
      );
      final retry = c.tr('إعادة المحاولة', ku: 'دووبارە هەوڵ بدە', en: 'Try again');

      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: roomy ? 40 : 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: roomy ? 108 : 92,
                  height: roomy ? 108 : 92,
                  decoration: BoxDecoration(
                    color: AlinTheme.navy.withValues(alpha: .08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.sentiment_dissatisfied_rounded,
                    size: roomy ? 62 : 54,
                    color: AlinTheme.navy,
                  ),
                ),
                SizedBox(height: roomy ? 24 : 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: roomy ? 24 : 21,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: roomy ? 16 : 14.5,
                    height: 1.65,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: roomy ? 28 : 24),
                SizedBox(
                  width: roomy ? 220 : 205,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: c.refreshCatalog,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(retry, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
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
                      settings: data.settings,
                      hasDeals: data.items.any((e) => e.hasDiscount),
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
                    if (c.selectedCategoryId.isNotEmpty && c.selectedCategoryId != '__deals__') ...[
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
    if (c.selectedCategoryId == '__deals__') return c.tr('العروض', ku: 'داشکاندنەکان', en: 'Offers');
    return data.categories.where((e) => e.id == c.selectedCategoryId).map((e) => e.name).firstOrNull ?? 'القسم';
  }

  List<Widget> _homeSlivers(BuildContext context, BootstrapData data) {
    final all = data.items;
    final offers = all.where((e) => e.hasDiscount).toList();
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
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
  final Map<String, dynamic> settings;
  final bool hasDeals;
  final VoidCallback onAll;
  final ValueChanged<String> onCategory;

  const _HomeCategories({
    required this.categories,
    required this.settings,
    required this.hasDeals,
    required this.onAll,
    required this.onCategory,
  });

  String _type(String value) {
    final type = value.trim().toLowerCase();
    if (type == 'booklets') return 'booklet';
    if (type == 'gifts') return 'gift';
    if (type == 'stationary') return 'stationery';
    return type;
  }

  String _imageFor(CategoryModel item) {
    final type = _type(item.type);
    final key = const {'booklet', 'stationery', 'gift', 'deal'}.contains(type)
        ? 'store_category_icon_$type'
        : 'store_category_icon_category:${item.id}';
    return '${settings[key] ?? ''}'.trim();
  }

  IconData _iconFor(CategoryModel item) {
    final type = _type(item.type);
    if (type == 'booklet') return Icons.menu_book_rounded;
    if (type == 'gift') return Icons.card_giftcard_rounded;
    if (type == 'stationery') return Icons.edit_note_rounded;
    if (type == 'deal') return Icons.local_offer_rounded;
    return Icons.grid_view_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final all = [
      CategoryModel(id: '', name: c.tr('كل المنتجات', ku: 'هەموو بەرهەمەکان', en: 'All products'), type: 'all', sortOrder: -1),
      ...categories,
      if (hasDeals) CategoryModel(id: '__deals__', name: c.tr('عروض', ku: 'داشکاندن', en: 'Offers'), type: 'deal', sortOrder: 999),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(
          title: c.tr('تسوّق حسب الأقسام', ku: 'بەپێی بەشەکان بکڕە', en: 'Shop by category'),
          subtitle: c.tr('اختار القسم المناسب إلك', ku: 'بەشی گونجاو هەڵبژێرە', en: 'Choose what you need'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = all[index];
              final imagePath = item.id.isEmpty ? '' : _imageFor(item);
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: item.id.isEmpty ? onAll : () => onCategory(item.id),
                child: Container(
                  width: 138,
                  padding: const EdgeInsets.fromLTRB(9, 9, 9, 10),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF0E3659) : const Color(0xFF0B3158),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: dark ? const Color(0xFF4B6F8F) : const Color(0xFF315778)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? .12 : .07), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: imagePath.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(3),
                                child: AlinNetworkImage(path: imagePath, fit: BoxFit.contain),
                              )
                            : Icon(_iconFor(item), color: AlinTheme.gold, size: 34),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
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
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsScreen(item: item))),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
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
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF102F4D) : const Color(0xFFF9FBFD),
                        padding: const EdgeInsets.all(10),
                        child: AlinNetworkImage(path: item.imagePath, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
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
                    if (item.hasDiscount)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(color: AlinTheme.gold, borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            'خصم ${item.discountPercent}%',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
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
                    Text(item.subtitle.isEmpty ? (item.isBooklet ? c.tr('ملزمة', ku: 'ملزمە', en: 'Booklet') : c.tr('منتج', ku: 'بەرهەم', en: 'Product')) : item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(item.priceText, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                    if (item.hasDiscount)
                      Text(
                        item.oldPriceText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          decorationThickness: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
              Text(title, style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900)),
              Text('$count عنصر', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
  final controller = PageController();
  Timer? timer;
  int index = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      index = 0;
      _restart();
    }
  }

  void _restart() {
    timer?.cancel();
    if (widget.banners.length <= 1) return;
    timer = Timer.periodic(const Duration(milliseconds: 6500), (_) {
      if (!mounted || widget.banners.isEmpty) return;
      index = (index + 1) % widget.banners.length;
      if (controller.hasClients) {
        controller.animateToPage(index, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final roomy = screenWidth >= 700;
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;
    final horizontalPagePadding = roomy ? 20.0 : 12.0;
    final availableWidth = (screenWidth - (horizontalPagePadding * 2) - 4).clamp(280.0, 1180.0);
    // منصة آلين تعتمد بنرات عريضة (1180×220). نحافظ على الصورة كاملة
    // بدون BoxFit.cover حتى لا ينقص أي جزء من الإعلان على الموبايل أو التابلت.
    final bannerHeight = (availableWidth / (1180 / 220)).clamp(92.0, 220.0).toDouble();

    return SizedBox(
      height: bannerHeight,
      child: PageView.builder(
        controller: controller,
        itemCount: widget.banners.length,
        onPageChanged: (value) {
          index = value;
          _restart();
        },
        itemBuilder: (context, pageIndex) {
          final banner = widget.banners[pageIndex];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(roomy ? 20 : 16),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .07),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: banner.imagePath.isNotEmpty
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF102F4D)
                          : Colors.white,
                      child: AlinNetworkImage(
                        path: banner.imagePath,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/alin_icon.png',
                            width: roomy ? 70 : 54,
                            height: roomy ? 70 : 54,
                          ),
                          if (banner.title.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              banner.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: roomy ? 17 : 14,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ],
                      ),
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
