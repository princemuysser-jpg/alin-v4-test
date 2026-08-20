import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/alin_config.dart';
import '../models/catalog.dart';

class AlinRepository {
  final SupabaseClient client;
  AlinRepository(this.client);

  Future<dynamic> _rpc(String name, {Map<String, dynamic>? params}) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 25));

  Future<BootstrapData> loadBootstrap({bool includeReviews = true}) async {
    final raw = await _rpc('alin_public_store_bootstrap');
    if (raw is! Map) throw Exception('تعذر تحميل بيانات متجر آلين');
    final data = Map<String, dynamic>.from(raw);
    if (includeReviews) {
      data['productReviews'] = await _loadPublishedReviews();
    }
    return BootstrapData.fromMap(data);
  }

  Future<List<Map<String, dynamic>>> _loadPublishedReviews() async {
    try {
      final raw = await client
          .from('product_reviews')
          .select('id,kind,item_id,rating,comment,status,created_at')
          .eq('status', 'approved')
          .order('created_at', ascending: false)
          .limit(500)
          .timeout(const Duration(seconds: 20));
      return raw.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (_) {
      // Reviews are optional storefront content; never block the store if they fail.
      return [];
    }
  }

  Future<Map<String, dynamic>> submitReview({
    required String kind,
    required String itemId,
    required String contact,
    required int rating,
    required String comment,
    required String deviceId,
    String? studentToken,
    String? studentDevice,
  }) async {
    final raw = await _rpc('alin_flutter_submit_review', params: {
      'p_kind': kind,
      'p_item_id': itemId,
      'p_contact': contact.trim(),
      'p_rating': rating.clamp(1, 5),
      'p_comment': comment.trim(),
      'p_device': deviceId,
      'p_student_token': studentToken,
      'p_student_device': studentDevice,
    });
    if (raw is! Map) throw Exception('تعذر نشر التقييم حالياً');
    final data = Map<String, dynamic>.from(raw);
    if (data['ok'] != true) {
      throw Exception('${data['message'] ?? 'تعذر نشر التقييم حالياً'}');
    }
    return data;
  }

  Future<Map<String, dynamic>> quoteCart({
    required List<CartItem> cart,
    required String deviceId,
    String? couponCode,
    String? studentToken,
    String? studentDevice,
  }) async {
    final items = cart
        .map((line) => {
              'kind': line.item.kind,
              'id': line.item.id,
              'qty': line.qty,
              'purchase_type': line.purchaseType,
              'variant_id': line.variant?.id,
            })
        .toList();
    final raw = await _rpc('alin_flutter_cart_quote', params: {
      'p_items': items,
      'p_coupon_code': couponCode?.trim().isEmpty == true ? null : couponCode?.trim(),
      'p_student_token': studentToken,
      'p_student_device': studentDevice,
    });
    if (raw is! Map) throw Exception('تعذر احتساب الخصم حالياً');
    return Map<String, dynamic>.from(raw);
  }

  String mediaUrl(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    final normalized = clean
        .replaceFirst('private://', '')
        .replaceFirst('${AlinConfig.publicBucket}/', '');
    if (normalized.startsWith('booklets/') || normalized.startsWith('teacher-requests/')) return '';
    return client.storage.from(AlinConfig.publicBucket).getPublicUrl(normalized);
  }

  Future<Map<String, dynamic>> studentRegister({
    required String name,
    required String phone,
    required String pin,
    required String deviceId,
  }) async {
    final raw = await _rpc('alin_student_register', params: {
      'p_name': name,
      'p_phone': phone,
      'p_pin': pin,
      'p_device': deviceId,
    });
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<Map<String, dynamic>> studentLogin({
    required String phone,
    required String pin,
    required String deviceId,
  }) async {
    final raw = await _rpc('alin_student_login', params: {
      'p_phone': phone,
      'p_pin': pin,
      'p_device': deviceId,
    });
    return Map<String, dynamic>.from(raw as Map);
  }

  Future<StudentModel?> studentProfile({
    required String token,
    required String deviceId,
  }) async {
    final raw = await _rpc('alin_student_profile', params: {
      'p_token': token,
      'p_device': deviceId,
    });
    if (raw == null || raw is! Map) return null;
    return StudentModel.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<void> studentLogout({required String token, required String deviceId}) async {
    await _rpc('alin_student_logout', params: {
      'p_token': token,
      'p_device': deviceId,
    });
  }

  Future<Map<String, dynamic>> studentDeleteAccount({
    required String token,
    required String deviceId,
    required String pin,
  }) async {
    final raw = await _rpc('alin_student_delete_account', params: {
      'p_token': token,
      'p_device': deviceId,
      'p_pin': pin,
    });
    if (raw is! Map) throw Exception('تعذر حذف الحساب حالياً');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> studentOrders({
    required String token,
    required String deviceId,
  }) async {
    final raw = await _rpc('alin_student_orders', params: {
      'p_token': token,
      'p_device': deviceId,
    });
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> trackOrder(String orderNumber) async {
    final clean = orderNumber.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (clean.isEmpty) throw Exception('اكتب رقم الطلب');
    final raw = await _rpc('alin_track_order', params: {'p_order_number': clean});
    if (raw is List) {
      if (raw.isEmpty) throw Exception('رقم الطلب غير موجود');
      final first = raw.first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw Exception('رقم الطلب غير موجود');
  }

  Future<List<Map<String, dynamic>>> personalOffers({
    required String token,
    required String deviceId,
  }) async {
    final raw = await _rpc('alin_student_personal_offers', params: {
      'p_token': token,
      'p_device': deviceId,
    });
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> touchStudent({required String token, required String deviceId}) async {
    await _rpc('alin_student_touch_activity', params: {
      'p_token': token,
      'p_device': deviceId,
    });
  }

  Future<Map<String, dynamic>> createOrder({
    required List<CartItem> cart,
    required String name,
    required String phone,
    required String notes,
    required Map<String, dynamic> fulfillment,
    required String requestKey,
    required String deviceId,
    String? couponCode,
    String? studentToken,
    String? studentDevice,
  }) async {
    final items = cart
        .map((line) => {
              'kind': line.item.kind,
              'id': line.item.id,
              'qty': line.qty,
              'purchase_type': line.purchaseType,
              'variant_id': line.variant?.id,
            })
        .toList();
    final customer = {'name': name.trim(), 'phone': phone.trim(), 'notes': notes.trim()};
    final base = <String, dynamic>{
      'p_items': items,
      'p_customer': customer,
      'p_fulfillment': fulfillment,
      'p_coupon_code': couponCode?.trim().isEmpty == true ? null : couponCode?.trim(),
      'p_request_key': requestKey,
      'p_device_id': deviceId,
    };
    if (studentToken != null && studentToken.isNotEmpty && studentDevice != null) {
      base['p_student_token'] = studentToken;
      base['p_student_device'] = studentDevice;
    }
    final raw = await _rpc('alin_create_store_orders_guarded', params: base);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw Exception('تم إرسال الطلب لكن تعذر قراءة رقم الطلب');
  }
}
