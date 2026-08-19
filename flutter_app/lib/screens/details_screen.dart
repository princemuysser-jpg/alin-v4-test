import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/alin_theme.dart';
import '../models/catalog.dart';
import '../state/app_controller.dart';
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

  String _money(num value) => '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} د.ع';

  String _stars(double value) {
    final rounded = value.round().clamp(0, 5).toInt();
    return '${List.filled(rounded, '★').join()}${List.filled(5 - rounded, '☆').join()}';
  }

  Future<void> _showReviewForm(AppController c, StoreItem item) async {
    final contactController = TextEditingController(text: c.student?.phone ?? '');
    final commentController = TextEditingController();
    var rating = 5;
    var sending = false;
    var success = false;
    String message = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            final contact = contactController.text.trim();
            final comment = commentController.text.trim();
            if (contact.isEmpty || comment.isEmpty) {
              setDialogState(() {
                success = false;
                message = 'أكمل رقم الهاتف والتعليق.';
              });
              return;
            }
            setDialogState(() {
              sending = true;
              message = '';
            });
            try {
              final result = await c.submitReview(
                item: item,
                contact: contact,
                rating: rating,
                comment: comment,
              );
              if (!dialogContext.mounted) return;
              setDialogState(() {
                sending = false;
                success = true;
                message = result;
              });
            } catch (e) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                sending = false;
                success = false;
                message = '$e'.replaceFirst('Exception: ', '');
              });
            }
          }

          return AlertDialog(
            title: Text(c.tr('أضف تقييمك', ku: 'هەڵسەنگاندنت زیاد بکە', en: 'Add your review')),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: contactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: c.tr('رقم الهاتف', ku: 'ژمارەی مۆبایل', en: 'Phone number'),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: rating,
                      decoration: InputDecoration(
                        labelText: c.tr('التقييم', ku: 'هەڵسەنگاندن', en: 'Rating'),
                      ),
                      items: List.generate(
                        5,
                        (index) {
                          final value = 5 - index;
                          return DropdownMenuItem(
                            value: value,
                            child: Text('${List.filled(value, '★').join()}${List.filled(5 - value, '☆').join()}'),
                          );
                        },
                      ),
                      onChanged: sending ? null : (value) => setDialogState(() => rating = value ?? 5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 800,
                      decoration: InputDecoration(
                        labelText: c.tr('اكتب رأيك', ku: 'بۆچوونەکەت بنووسە', en: 'Write your review'),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: success
                              ? Colors.green.withValues(alpha: .10)
                              : Colors.red.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: success ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => Navigator.of(dialogContext).pop(),
                child: Text(c.tr('إغلاق', ku: 'داخستن', en: 'Close')),
              ),
              FilledButton.icon(
                onPressed: sending || success ? null : submit,
                icon: sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.star_rounded),
                label: Text(c.tr('إرسال التقييم', ku: 'ناردنی هەڵسەنگاندن', en: 'Submit review')),
              ),
            ],
          );
        },
      ),
    );

    contactController.dispose();
    commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final item = widget.item;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    final images = item.images.isEmpty ? [item.imagePath] : item.images;
    final safeImages = images.where((path) => path.isNotEmpty).toList();
    final currentPath = selectedVariant?.imagePath.isNotEmpty == true
        ? selectedVariant!.imagePath
        : safeImages.isEmpty
            ? item.imagePath
            : safeImages[(imageIndex >= 0 && imageIndex < safeImages.length) ? imageIndex : 0];
    final reviews = c.reviewsFor(item);
    final average = c.averageRating(item);
    final related = c.relatedItems(item);

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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AlinNetworkImage(
                      path: currentPath,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  if (item.hasDiscount)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: AlinTheme.gold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'خصم ${item.discountPercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (safeImages.length > 1)
            SizedBox(
              height: 78,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: safeImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => InkWell(
                  onTap: () => setState(() => imageIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 62,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: imageIndex == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
                        width: imageIndex == index ? 2 : 1,
                      ),
                    ),
                    child: AlinNetworkImage(path: safeImages[index], fit: BoxFit.contain),
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
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: tablet ? 28 : 22,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => c.toggleFavorite(item),
                icon: Icon(
                  c.isFavorite(item) ? Icons.favorite : Icons.favorite_border,
                  color: c.isFavorite(item) ? Colors.red : AlinTheme.navy,
                ),
              ),
            ],
          ),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              item.subtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showReviewForm(c, item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _stars(average),
                    style: const TextStyle(color: AlinTheme.gold, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    reviews.isEmpty ? 'جديد' : average.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reviews.isEmpty ? 'لا توجد تقييمات بعد' : '${reviews.length} تقييم',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .42),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  item.priceText,
                  style: TextStyle(
                    fontSize: tablet ? 25 : 22,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (item.hasDiscount)
                  Text(
                    item.oldPriceText,
                    style: const TextStyle(
                      color: Colors.grey,
                      decoration: TextDecoration.lineThrough,
                      decorationThickness: 2,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (item.hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AlinTheme.gold.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'خصم ${item.discountPercent}% • وفرت ${_money(item.savings)}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AlinTheme.navy, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              c.tr('التفاصيل', ku: 'وردەکاری', en: 'Details'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              item.description,
              style: TextStyle(height: 1.7, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
          if (item.hasVariants) ...[
            const SizedBox(height: 22),
            Text(
              c.tr('اختر التصميم', ku: 'دیزاین هەڵبژێرە', en: 'Choose design'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
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
                      : SizedBox(
                          width: 28,
                          height: 28,
                          child: AlinNetworkImage(path: variant.imagePath, fit: BoxFit.contain),
                        ),
                );
              }).toList(),
            ),
          ],
          if (item.hasPack) ...[
            const SizedBox(height: 22),
            Text(
              c.tr('طريقة الشراء', ku: 'شێوازی کڕین', en: 'Purchase type'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'unit', label: Text('مفرد • ${_money(item.price)}')),
                ButtonSegment(value: 'pack', label: Text('باكيت ${item.packSize} • ${_money(item.packPrice!)}')),
              ],
              selected: {purchaseType},
              onSelectionChanged: (value) => setState(() => purchaseType = value.first),
            ),
          ],
          if (item.isProduct) ...[
            const SizedBox(height: 16),
            Text(
              item.stock > 0 ? 'متوفر بالمخزون: ${item.stock}' : 'نفد من المخزون',
              style: TextStyle(
                color: item.stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: item.isProduct && item.stock <= 0 ? null : add,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                c.tr('إضافة إلى السلة', ku: 'زیادکردن بۆ سەبەتە', en: 'Add to cart'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );

    final reviewSection = _ReviewsSection(
      reviews: reviews,
      average: average,
      onAdd: () => _showReviewForm(c, item),
    );

    final relatedSection = related.isEmpty
        ? const SizedBox.shrink()
        : _RelatedSection(items: related);

    final main = tablet
        ? Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 11, child: gallery),
                const SizedBox(width: 1),
                Expanded(flex: 10, child: info),
              ],
            ),
          )
        : Column(children: [gallery, info]);

    return Scaffold(
      appBar: AppBar(title: Text(c.tr('تفاصيل المنتج', ku: 'وردەکاری بەرهەم', en: 'Product details'))),
      body: ListView(
        children: [
          main,
          reviewSection,
          relatedSection,
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  final List<ProductReviewModel> reviews;
  final double average;
  final VoidCallback onAdd;

  const _ReviewsSection({
    required this.reviews,
    required this.average,
    required this.onAdd,
  });

  String _stars(double value) {
    final rounded = value.round().clamp(0, 5).toInt();
    return '${List.filled(rounded, '★').join()}${List.filled(5 - rounded, '☆').join()}';
  }

  @override
  Widget build(BuildContext context) {
    final counts = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
    for (final review in reviews) {
      counts[review.rating] = (counts[review.rating] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('آراء العملاء', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('التقييمات بالنجوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.star_border_rounded),
                  label: const Text('أضف تقييمك'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 92,
                  child: Column(
                    children: [
                      Text(
                        reviews.isEmpty ? '—' : average.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _stars(average),
                        maxLines: 1,
                        style: const TextStyle(color: AlinTheme.gold, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reviews.isEmpty ? 'لا توجد تقييمات' : '${reviews.length} تقييم منشور',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: [
                      for (var star = 5; star >= 1; star--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(width: 28, child: Text('$star ★', style: const TextStyle(fontSize: 10.5))),
                              const SizedBox(width: 6),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: reviews.isEmpty ? 0 : (counts[star] ?? 0) / reviews.length,
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                width: 22,
                                child: Text(
                                  '${counts[star] ?? 0}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 10.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (reviews.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Text('لا توجد تقييمات منشورة بعد', style: TextStyle(fontWeight: FontWeight.w900)),
                    SizedBox(height: 4),
                    Text('يمكنك إضافة تقييمك وسيظهر بعد مراجعته.', textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ...reviews.take(8).map(
                    (review) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .32),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stars(review.rating.toDouble()),
                            style: const TextStyle(color: AlinTheme.gold, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            review.comment.isEmpty ? 'تقييم بدون تعليق' : review.comment,
                            style: const TextStyle(height: 1.55, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'تقييم موثّق في منصة آلين',
                            style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _RelatedSection extends StatelessWidget {
  final List<StoreItem> items;
  const _RelatedSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = width >= 700 ? 190.0 : 164.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('مواد مرتبطة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(
            'اقتراحات من نفس المادة أو المرحلة',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: width >= 700 ? 276 : 244,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => SizedBox(
                width: cardWidth,
                child: _RelatedCard(item: items[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedCard extends StatelessWidget {
  final StoreItem item;
  const _RelatedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailsScreen(item: item)),
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF102F4D)
                            : const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.all(9),
                        child: AlinNetworkImage(path: item.imagePath, fit: BoxFit.contain),
                      ),
                    ),
                    if (item.hasDiscount)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(color: AlinTheme.gold, borderRadius: BorderRadius.circular(99)),
                          child: Text(
                            'خصم ${item.discountPercent}%',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(item.priceText, style: TextStyle(fontSize: 13.5, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                    if (item.hasDiscount)
                      Text(
                        item.oldPriceText,
                        style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough),
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
