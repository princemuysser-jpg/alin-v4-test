import '../core/alin_config.dart';

num _num(dynamic value) => value is num ? value : num.tryParse('${value ?? 0}') ?? 0;
String _str(dynamic value) => '${value ?? ''}'.trim();
bool _bool(dynamic value) => value == true || value == 1 || _str(value).toLowerCase() == 'true';

class CategoryModel {
  final String id;
  final String name;
  final String type;
  final int sortOrder;
  CategoryModel({required this.id, required this.name, required this.type, required this.sortOrder});
  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: _str(map['id']),
        name: _str(map['name']),
        type: _str(map['type']),
        sortOrder: _num(map['sort_order']).toInt(),
      );
}

class SubcategoryModel {
  final String id;
  final String name;
  final String parentCategoryId;
  final int sortOrder;
  SubcategoryModel({required this.id, required this.name, required this.parentCategoryId, required this.sortOrder});
  factory SubcategoryModel.fromMap(Map<String, dynamic> map) => SubcategoryModel(
        id: _str(map['id']),
        name: _str(map['name']),
        parentCategoryId: _str(map['parent_category_id']),
        sortOrder: _num(map['sort_order']).toInt(),
      );
}

class VariantModel {
  final String id;
  final String productId;
  final String name;
  final String code;
  final String imagePath;
  final int stock;
  final int sortOrder;
  VariantModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.code,
    required this.imagePath,
    required this.stock,
    required this.sortOrder,
  });
  factory VariantModel.fromMap(Map<String, dynamic> map) => VariantModel(
        id: _str(map['id']),
        productId: _str(map['product_id']),
        name: _str(map['name']),
        code: _str(map['code']),
        imagePath: _str(map['image_path']),
        stock: _num(map['stock']).toInt(),
        sortOrder: _num(map['sort_order']).toInt(),
      );
}

class StoreItem {
  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String description;
  final String categoryId;
  final String subcategoryId;
  final String imagePath;
  final List<String> images;
  final num price;
  final num? oldPrice;
  final num? packPrice;
  final int packSize;
  final int stock;
  final String teacherId;
  final List<VariantModel> variants;

  const StoreItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.categoryId,
    required this.subcategoryId,
    required this.imagePath,
    required this.images,
    required this.price,
    required this.oldPrice,
    required this.packPrice,
    required this.packSize,
    required this.stock,
    required this.teacherId,
    required this.variants,
  });

  factory StoreItem.product(Map<String, dynamic> map, List<VariantModel> allVariants) {
    final unit = _num(map['unit_price']);
    final sale = _num(map['sale_price']);
    final base = _num(map['price']);
    final current = sale > 0 ? sale : (unit > 0 ? unit : base);
    final imageList = (map['images'] is List)
        ? (map['images'] as List).map(_str).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final image = _str(map['image_path']);
    if (imageList.isEmpty && image.isNotEmpty) imageList.add(image);
    final id = _str(map['id']);
    return StoreItem(
      id: id,
      kind: 'product',
      title: _str(map['name']).isNotEmpty ? _str(map['name']) : _str(map['title']),
      subtitle: _str(map['category']),
      description: _str(map['description']).isNotEmpty ? _str(map['description']) : _str(map['details']),
      categoryId: _str(map['category_id']),
      subcategoryId: _str(map['subcategory_id']),
      imagePath: image,
      images: imageList,
      price: current,
      oldPrice: base > current ? base : null,
      packPrice: _num(map['pack_price']) > 0 ? _num(map['pack_price']) : null,
      packSize: _num(map['pack_size']).toInt(),
      stock: _num(map['stock']).toInt(),
      teacherId: '',
      variants: allVariants.where((v) => v.productId == id).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  factory StoreItem.booklet(Map<String, dynamic> map) => StoreItem(
        id: _str(map['id']),
        kind: 'booklet',
        title: _str(map['title']),
        subtitle: [_str(map['subject']), _str(map['grade']), _str(map['year'])].where((e) => e.isNotEmpty).join(' • '),
        description: _str(map['description']),
        categoryId: 'CAT-BOOKLETS',
        subcategoryId: '',
        imagePath: _str(map['cover_path']),
        images: _str(map['cover_path']).isEmpty ? const [] : [_str(map['cover_path'])],
        price: _num(map['price']),
        oldPrice: null,
        packPrice: null,
        packSize: 0,
        stock: 999999,
        teacherId: _str(map['teacher_id']),
        variants: const [],
      );

  bool get isProduct => kind == 'product';
  bool get isBooklet => kind == 'booklet';
  bool get hasPack => isProduct && packPrice != null && packSize > 1;
  bool get hasVariants => variants.isNotEmpty;
  String get priceText => '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ${AlinConfig.currency}';
}

class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imagePath;
  final String linkUrl;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  BannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.linkUrl,
    required this.active,
    required this.startsAt,
    required this.endsAt,
  });
  factory BannerModel.fromMap(Map<String, dynamic> map) => BannerModel(
        id: _str(map['id']),
        title: _str(map['title']),
        subtitle: _str(map['subtitle']),
        imagePath: _str(map['image_path']).isNotEmpty ? _str(map['image_path']) : _str(map['image_url']),
        linkUrl: _str(map['link_url']),
        active: map['active'] == null ? _str(map['status']) != 'inactive' : _bool(map['active']),
        startsAt: DateTime.tryParse(_str(map['starts_at'])),
        endsAt: DateTime.tryParse(_str(map['ends_at'])),
      );

  bool get isVisible {
    final now = DateTime.now().toUtc();
    if (!active) return false;
    if (startsAt != null && startsAt!.toUtc().isAfter(now)) return false;
    if (endsAt != null && endsAt!.toUtc().isBefore(now)) return false;
    return true;
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  NotificationModel({required this.id, required this.title, required this.message, required this.createdAt});
  factory NotificationModel.fromMap(Map<String, dynamic> map) => NotificationModel(
        id: _str(map['id']),
        title: _str(map['title']),
        message: _str(map['message']),
        createdAt: DateTime.tryParse(_str(map['created_at'])),
      );
}

class LibraryModel {
  final String id;
  final String name;
  final String area;
  final String landmark;
  final bool isOpen;
  LibraryModel({required this.id, required this.name, required this.area, required this.landmark, required this.isOpen});
  factory LibraryModel.fromMap(Map<String, dynamic> map) => LibraryModel(
        id: _str(map['id']),
        name: _str(map['name']),
        area: _str(map['area']),
        landmark: _str(map['landmark']),
        isOpen: _bool(map['is_open']) || _str(map['open_status']) == 'open',
      );
}

class DeliveryAreaModel {
  final String id;
  final String name;
  final num deliveryFee;
  DeliveryAreaModel({required this.id, required this.name, required this.deliveryFee});
  factory DeliveryAreaModel.fromMap(Map<String, dynamic> map) => DeliveryAreaModel(
        id: _str(map['id']),
        name: _str(map['name']),
        deliveryFee: _num(map['delivery_fee']),
      );
}

class CartItem {
  final StoreItem item;
  final int qty;
  final String purchaseType;
  final VariantModel? variant;

  const CartItem({required this.item, this.qty = 1, this.purchaseType = 'unit', this.variant});

  num get unitPrice => purchaseType == 'pack' && item.packPrice != null ? item.packPrice! : item.price;
  num get total => unitPrice * qty;

  CartItem copyWith({int? qty, String? purchaseType, VariantModel? variant, bool clearVariant = false}) => CartItem(
        item: item,
        qty: qty ?? this.qty,
        purchaseType: purchaseType ?? this.purchaseType,
        variant: clearVariant ? null : (variant ?? this.variant),
      );

  Map<String, dynamic> toLocalMap() => {
        'id': item.id,
        'kind': item.kind,
        'qty': qty,
        'purchase_type': purchaseType,
        'variant_id': variant?.id,
      };
}

class StudentModel {
  final String id;
  final String name;
  final String phone;
  final String grade;
  const StudentModel({required this.id, required this.name, required this.phone, required this.grade});
  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
        id: _str(map['id']),
        name: _str(map['name']),
        phone: _str(map['phone']),
        grade: _str(map['grade']),
      );
  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'phone': phone, 'grade': grade};
}

class BootstrapData {
  final List<CategoryModel> categories;
  final List<SubcategoryModel> subcategories;
  final List<StoreItem> items;
  final List<BannerModel> banners;
  final List<NotificationModel> notifications;
  final List<LibraryModel> libraries;
  final List<DeliveryAreaModel> deliveryAreas;

  const BootstrapData({
    required this.categories,
    required this.subcategories,
    required this.items,
    required this.banners,
    required this.notifications,
    required this.libraries,
    required this.deliveryAreas,
  });

  factory BootstrapData.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> maps(dynamic value) => value is List
        ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final variants = maps(map['productVariants']).map(VariantModel.fromMap).toList();
    final products = maps(map['products']).map((e) => StoreItem.product(e, variants));
    final booklets = maps(map['booklets']).map(StoreItem.booklet);
    final accountMap = map['accounts'] is Map ? Map<String, dynamic>.from(map['accounts'] as Map) : <String, dynamic>{};
    return BootstrapData(
      categories: maps(map['categories']).map(CategoryModel.fromMap).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      subcategories: maps(map['productSubcategories']).map(SubcategoryModel.fromMap).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      items: [...booklets, ...products],
      banners: maps(map['banners']).map(BannerModel.fromMap).where((e) => e.isVisible).toList(),
      notifications: maps(map['notifications']).map(NotificationModel.fromMap).toList(),
      libraries: maps(accountMap['libraries']).map(LibraryModel.fromMap).toList(),
      deliveryAreas: maps(map['deliveryAreas']).map(DeliveryAreaModel.fromMap).toList(),
    );
  }
}
