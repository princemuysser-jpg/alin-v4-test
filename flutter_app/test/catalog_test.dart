import 'package:flutter_test/flutter_test.dart';
import 'package:alin_flutter/models/catalog.dart';

void main() {
  test('product discount and variants parse correctly', () {
    final variants = [
      VariantModel.fromMap({
        'id': 'V1',
        'product_id': 'P1',
        'name': 'أزرق',
        'code': 'B',
        'stock': 4,
        'sort_order': 1,
      }),
    ];
    final item = StoreItem.product({
      'id': 'P1',
      'name': 'دفتر',
      'type': 'stationery',
      'category': 'قرطاسية',
      'price': 3000,
      'unit_price': 2500,
      'sale_price': 2500,
      'pack_price': 25000,
      'pack_size': 12,
      'stock': 10,
      'image_path': 'products/a.png',
      'category_id': 'CAT-STATIONERY',
    }, variants);
    expect(item.price, 2500);
    expect(item.oldPrice, 3000);
    expect(item.discountPercent, 17);
    expect(item.reviewKind, 'stationery');
    expect(item.hasVariants, isTrue);
    expect(item.hasPack, isTrue);
  });

  test('approved review model keeps rating in valid range', () {
    final review = ProductReviewModel.fromMap({
      'id': 'R1',
      'kind': 'stationery',
      'item_id': 'P1',
      'rating': 7,
      'comment': 'ممتاز',
    });
    expect(review.rating, 5);
    expect(review.itemId, 'P1');
  });
}
