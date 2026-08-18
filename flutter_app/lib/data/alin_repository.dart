import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/alin_config.dart';
import '../models/catalog.dart';

class AlinRepository {
  final SupabaseClient client;
  AlinRepository(this.client);

  Future<dynamic> _rpc(String name, {Map<String, dynamic>? params}) =>
      client.rpc(name, params: params).timeout(const Duration(seconds: 25));

  Future<BootstrapData> loadBootstrap() async {
    final raw = await _rpc('alin_public_store_bootstrap');
    if (raw is! Map) throw Exception('تعذر تحميل بيانات متجر آلين');
    return BootstrapData.fromMap(Map<String, dynamic>.from(raw));
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

  Future<dynamic> trackOrder(String orderNumber) =>
      _rpc('alin_track_order', params: {'p_order_number': orderNumber.trim()});

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
