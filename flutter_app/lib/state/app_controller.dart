import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../core/device_store.dart';
import '../data/alin_repository.dart';
import '../models/catalog.dart';

class AppController extends ChangeNotifier {
  final AlinRepository repository;
  final DeviceStore store;

  AppController({required this.repository, required this.store});

  BootstrapData? bootstrap;
  bool loading = true;
  String? error;
  String search = '';
  String selectedCategoryId = '';
  String selectedSubcategoryId = '';
  String sort = 'default';
  String? pendingCouponCode;
  String themeMode = 'light';
  String languageCode = 'ar';

  StudentModel? student;
  String? studentToken;
  bool studentVerifying = false;
  bool sessionReady = false;

  final List<CartItem> cart = [];
  final Set<String> favorites = {};
  final Set<String> readNotifications = {};
  DateTime? lastNotificationRefresh;
  DateTime? lastCatalogRefresh;

  Timer? _activityTimer;
  Timer? _notificationTimer;

  Future<void> initialize() async {
    await _restoreLocalState();
    await Future.wait([
      refreshCatalog(),
      restoreStudent(),
    ]);
    loading = false;
    notifyListeners();
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(const Duration(minutes: 5), (_) => touchStudent());
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 45), (_) => refreshNotifications());
  }

  void disposeController() {
    _activityTimer?.cancel();
    _notificationTimer?.cancel();
  }

  Future<void> _restoreLocalState() async {
    themeMode = store.readThemeMode();
    languageCode = store.readLanguageCode();
    favorites
      ..clear()
      ..addAll(store.readFavorites());
    readNotifications
      ..clear()
      ..addAll(store.readReadNotifications());
    final saved = await store.readStudentSession();
    if (saved != null && saved['student'] is Map && '${saved['token'] ?? ''}'.isNotEmpty) {
      student = StudentModel.fromMap(Map<String, dynamic>.from(saved['student'] as Map));
      studentToken = '${saved['token']}';
    }
  }

  Future<void> refreshCatalog() async {
    try {
      error = null;
      bootstrap = await repository.loadBootstrap();
      _restoreCartFromDisk();
      lastNotificationRefresh = DateTime.now();
      lastCatalogRefresh = DateTime.now();
    } catch (e) {
      error = '$e'.replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    try {
      final fresh = await repository.loadBootstrap(includeReviews: false);
      if (bootstrap == null) {
        bootstrap = fresh;
      } else {
        bootstrap = BootstrapData(
          settings: bootstrap!.settings,
          categories: bootstrap!.categories,
          subcategories: bootstrap!.subcategories,
          items: bootstrap!.items,
          banners: bootstrap!.banners,
          notifications: fresh.notifications,
          reviews: bootstrap!.reviews,
          libraries: bootstrap!.libraries,
          deliveryAreas: bootstrap!.deliveryAreas,
        );
      }
      lastNotificationRefresh = DateTime.now();
      notifyListeners();
    } catch (_) {}
  }

  int get unreadNotificationCount => (bootstrap?.notifications ?? const <NotificationModel>[])
      .where((n) => !readNotifications.contains(n.id))
      .length;

  Future<void> markAllNotificationsRead() async {
    final rows = bootstrap?.notifications ?? const <NotificationModel>[];
    readNotifications.addAll(rows.map((e) => e.id));
    await store.writeReadNotifications(readNotifications);
    notifyListeners();
  }


  Future<void> setThemeMode(String value) async {
    final next = value == 'dark' ? 'dark' : 'light';
    if (themeMode == next) return;
    themeMode = next;
    await store.writeThemeMode(next);
    notifyListeners();
  }

  Future<void> setLanguageCode(String value) async {
    final next = const {'ar', 'ku', 'en'}.contains(value) ? value : 'ar';
    if (languageCode == next) return;
    languageCode = next;
    await store.writeLanguageCode(next);
    notifyListeners();
  }

  String tr(String ar, {String? ku, String? en}) {
    if (languageCode == 'en' && en != null) return en;
    if (languageCode == 'ku' && ku != null) return ku;
    return ar;
  }

  void useCoupon(String code) {
    final clean = code.trim();
    if (clean.isEmpty) return;
    pendingCouponCode = clean;
    notifyListeners();
  }

  String? takePendingCoupon() {
    final code = pendingCouponCode;
    pendingCouponCode = null;
    return code;
  }

  List<StoreItem> get visibleItems {
    var rows = bootstrap?.items ?? const <StoreItem>[];
    if (selectedCategoryId == '__deals__') {
      rows = rows.where((e) => e.hasDiscount).toList();
    } else if (selectedCategoryId.isNotEmpty) {
      rows = rows.where((e) => e.categoryId == selectedCategoryId).toList();
    }
    if (selectedSubcategoryId.isNotEmpty) {
      rows = rows.where((e) => e.subcategoryId == selectedSubcategoryId).toList();
    }
    final q = search.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.subtitle.toLowerCase().contains(q) ||
            e.description.toLowerCase().contains(q);
      }).toList();
    } else {
      rows = rows.toList();
    }
    if (sort == 'price_asc') rows.sort((a, b) => a.price.compareTo(b.price));
    if (sort == 'price_desc') rows.sort((a, b) => b.price.compareTo(a.price));
    if (sort == 'name') rows.sort((a, b) => a.title.compareTo(b.title));
    return rows;
  }

  List<SubcategoryModel> subcategoriesFor(String categoryId) =>
      (bootstrap?.subcategories ?? const <SubcategoryModel>[])
          .where((e) => e.parentCategoryId == categoryId)
          .toList();

  void selectCategory(String id) {
    selectedCategoryId = id;
    selectedSubcategoryId = '';
    notifyListeners();
  }

  void selectSubcategory(String id) {
    selectedSubcategoryId = id;
    notifyListeners();
  }

  void setSearch(String value) {
    search = value;
    notifyListeners();
  }

  void setSort(String value) {
    sort = value;
    notifyListeners();
  }

  String mediaUrl(String path) => repository.mediaUrl(path);

  bool isFavorite(StoreItem item) => favorites.contains('${item.kind}:${item.id}');

  Future<void> toggleFavorite(StoreItem item) async {
    final key = '${item.kind}:${item.id}';
    if (!favorites.add(key)) favorites.remove(key);
    await store.writeFavorites(favorites);
    notifyListeners();
  }

  List<StoreItem> get favoriteItems => (bootstrap?.items ?? const <StoreItem>[])
      .where((item) => favorites.contains('${item.kind}:${item.id}'))
      .toList();

  List<ProductReviewModel> reviewsFor(StoreItem item) =>
      (bootstrap?.reviews ?? const <ProductReviewModel>[])
          .where((review) => review.kind == item.reviewKind && review.itemId == item.id)
          .toList();

  double averageRating(StoreItem item) {
    final rows = reviewsFor(item);
    if (rows.isEmpty) return 0;
    return rows.fold<double>(0, (sum, review) => sum + review.rating) / rows.length;
  }

  List<StoreItem> relatedItems(StoreItem item, {int limit = 6}) {
    final candidates = <_RelatedCandidate>[];
    for (final candidate in bootstrap?.items ?? const <StoreItem>[]) {
      if (candidate.id == item.id && candidate.kind == item.kind) continue;
      var score = 0;
      if (item.subject.isNotEmpty && candidate.subject == item.subject) score += 5;
      if (item.grade.isNotEmpty && candidate.grade == item.grade) score += 4;
      if (item.teacherId.isNotEmpty && candidate.teacherId == item.teacherId) score += 3;
      if (item.category.isNotEmpty && candidate.category == item.category) score += 2;
      if (score > 0) candidates.add(_RelatedCandidate(candidate, score));
    }
    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.item.title.compareTo(b.item.title);
    });
    return candidates.take(limit).map((row) => row.item).toList();
  }

  Future<String> submitReview({
    required StoreItem item,
    required String contact,
    required int rating,
    required String comment,
  }) async {
    final result = await repository.submitReview(
      kind: item.reviewKind,
      itemId: item.id,
      contact: contact,
      rating: rating,
      comment: comment,
    );
    return '${result['message'] ?? 'تم إرسال تقييمك للمراجعة قبل النشر.'}';
  }

  void _restoreCartFromDisk() {
    if (cart.isNotEmpty) return;
    final items = bootstrap?.items ?? const <StoreItem>[];
    for (final raw in store.readCart()) {
      final id = '${raw['id'] ?? ''}';
      final kind = '${raw['kind'] ?? ''}';
      final item = items.where((e) => e.id == id && e.kind == kind).firstOrNull;
      if (item == null) continue;
      final variantId = '${raw['variant_id'] ?? ''}';
      VariantModel? variant;
      if (variantId.isNotEmpty) {
        variant = item.variants.where((v) => v.id == variantId).firstOrNull;
      }
      cart.add(CartItem(
        item: item,
        qty: max(1, int.tryParse('${raw['qty'] ?? 1}') ?? 1),
        purchaseType: '${raw['purchase_type'] ?? 'unit'}' == 'pack' ? 'pack' : 'unit',
        variant: variant,
      ));
    }
  }

  Future<void> _saveCart() => store.writeCart(cart.map((e) => e.toLocalMap()).toList());

  Future<void> addToCart(StoreItem item, {String purchaseType = 'unit', VariantModel? variant}) async {
    if (item.hasVariants && variant == null) throw Exception('اختر التصميم أولاً');
    final index = cart.indexWhere((e) =>
        e.item.id == item.id &&
        e.item.kind == item.kind &&
        e.purchaseType == purchaseType &&
        e.variant?.id == variant?.id);
    if (index >= 0) {
      cart[index] = cart[index].copyWith(qty: cart[index].qty + 1);
    } else {
      cart.add(CartItem(item: item, purchaseType: purchaseType, variant: variant));
    }
    await _saveCart();
    notifyListeners();
  }

  Future<void> setCartQty(int index, int qty) async {
    if (index < 0 || index >= cart.length) return;
    if (qty <= 0) {
      cart.removeAt(index);
    } else {
      cart[index] = cart[index].copyWith(qty: min(50, qty));
    }
    await _saveCart();
    notifyListeners();
  }

  Future<void> clearCart() async {
    cart.clear();
    await _saveCart();
    notifyListeners();
  }

  int get cartCount => cart.fold(0, (sum, e) => sum + e.qty);
  num get cartTotal => cart.fold<num>(0, (sum, e) => sum + e.total);

  Future<void> registerStudent({required String name, required String phone, required String pin}) async {
    final result = await repository.studentRegister(
      name: name,
      phone: phone,
      pin: pin,
      deviceId: store.deviceId(),
    );
    await _applyStudentResult(result);
  }

  Future<void> loginStudent({required String phone, required String pin}) async {
    final result = await repository.studentLogin(
      phone: phone,
      pin: pin,
      deviceId: store.deviceId(),
    );
    await _applyStudentResult(result);
  }

  Future<void> _applyStudentResult(Map<String, dynamic> result) async {
    final rawStudent = result['student'];
    final rawToken = '${result['token'] ?? ''}';
    if (rawStudent is! Map || rawToken.isEmpty) throw Exception('بيانات الجلسة غير مكتملة');
    student = StudentModel.fromMap(Map<String, dynamic>.from(rawStudent));
    studentToken = rawToken;
    await store.writeStudentSession({'student': student!.toMap(), 'token': rawToken});
    notifyListeners();
  }

  Future<void> restoreStudent() async {
    sessionReady = true;
    if (student == null || studentToken == null || studentToken!.isEmpty) {
      notifyListeners();
      return;
    }
    studentVerifying = true;
    notifyListeners();
    try {
      final verified = await repository.studentProfile(token: studentToken!, deviceId: store.deviceId());
      if (verified == null) {
        student = null;
        studentToken = null;
        await store.writeStudentSession(null);
      } else {
        student = verified;
        await store.writeStudentSession({'student': verified.toMap(), 'token': studentToken});
      }
    } catch (_) {
      // Keep the locally stored identity on temporary connectivity/startup errors.
    } finally {
      studentVerifying = false;
      notifyListeners();
    }
  }

  Future<void> logoutStudent() async {
    final token = studentToken;
    student = null;
    studentToken = null;
    await store.writeStudentSession(null);
    notifyListeners();
    if (token != null && token.isNotEmpty) {
      try {
        await repository.studentLogout(token: token, deviceId: store.deviceId());
      } catch (_) {}
    }
  }

  Future<String> deleteStudentAccount({required String pin}) async {
    final token = studentToken;
    if (token == null || token.isEmpty || student == null) {
      throw Exception('سجل الدخول أولاً');
    }
    final result = await repository.studentDeleteAccount(
      token: token,
      deviceId: store.deviceId(),
      pin: pin,
    );
    if (result['ok'] != true) {
      throw Exception('${result['message'] ?? 'تعذر حذف الحساب حالياً'}');
    }
    student = null;
    studentToken = null;
    pendingCouponCode = null;
    favorites.clear();
    readNotifications.clear();
    await Future.wait([
      store.writeStudentSession(null),
      store.writeFavorites(favorites),
      store.writeReadNotifications(readNotifications),
    ]);
    notifyListeners();
    return '${result['message'] ?? 'تم حذف الحساب'}';
  }

  Future<List<Map<String, dynamic>>> loadStudentOrders() async {
    if (studentToken == null) return [];
    return repository.studentOrders(token: studentToken!, deviceId: store.deviceId());
  }

  Future<void> touchStudent() async {
    if (studentToken == null) return;
    try {
      await repository.touchStudent(token: studentToken!, deviceId: store.deviceId());
    } catch (_) {}
  }

  Future<dynamic> trackOrder(String code) => repository.trackOrder(code);

  Future<Map<String, dynamic>> placeOrder({
    required String name,
    required String phone,
    required String notes,
    required Map<String, dynamic> fulfillment,
    String? couponCode,
  }) async {
    if (cart.isEmpty) throw Exception('السلة فارغة');
    final requestKey = _requestKey();
    final result = await repository.createOrder(
      cart: cart,
      name: student?.name ?? name,
      phone: student?.phone ?? phone,
      notes: notes,
      fulfillment: fulfillment,
      requestKey: requestKey,
      deviceId: store.deviceId(),
      couponCode: couponCode,
      studentToken: studentToken,
      studentDevice: studentToken == null ? null : store.deviceId(),
    );
    await clearCart();
    await touchStudent();
    return result;
  }

  String _requestKey() {
    final random = Random.secure();
    final hex = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20)}';
  }
}

class _RelatedCandidate {
  final StoreItem item;
  final int score;
  const _RelatedCandidate(this.item, this.score);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
