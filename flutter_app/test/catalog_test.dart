import 'package:flutter_test/flutter_test.dart';
import 'package:alin_flutter/models/catalog.dart';

void main() {
  test('product price and variants parse correctly', () {
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
      'price': 3000,
      'unit_price': 2500,
      'sale_price': null,
      'pack_price': 25000,
      'pack_size': 12,
      'stock': 10,
      'image_path': 'products/a.png',
      'category_id': 'CAT-STATIONERY',
    }, variants);
    expect(item.price, 2500);
    expect(item.oldPrice, 3000);
    expect(item.hasVariants, isTrue);
    expect(item.hasPack, isTrue);
  });
}
