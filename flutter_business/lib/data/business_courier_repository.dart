import 'business_repository.dart';

extension BusinessCourierRepository on BusinessRepository {
  Future<Map<String, dynamic>> courierProfile() async {
    final raw = await client.rpc('alin_courier_profile');
    if (raw is! Map) throw Exception('تعذر قراءة حالة المندوب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true || map['courier'] is! Map) {
      throw Exception('${map['error'] ?? 'تعذر قراءة حالة المندوب'}');
    }
    return Map<String, dynamic>.from(map['courier'] as Map);
  }

  Future<List<Map<String, dynamic>>> courierGroupedOrderRows(String courierId) async {
    final raw = await client
        .from('orders')
        .select('id,order_number,title,kind,status,student_name,student_phone,qty,unit_price,discount,total,delivery_fee,courier_fee,delegate_profit,courier_profit,delivery_area,delivery_landmark,delivery_latitude,delivery_longitude,delivery_location_url,delivery_note,notes,pickup_source_label,pickup_source_type,library_id,pickup_library_id,product_variant_code,product_variant_name,checkout_group_id,checkout_request_key,created_at,updated_at,delivered_at,completed_at,courier_id,delegate_id')
        .or('courier_id.eq.$courierId,delegate_id.eq.$courierId')
        .order('created_at', ascending: false)
        .limit(500);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> courierTransitionGroup(
    String orderId,
    String status, {
    String reason = '',
  }) async {
    final raw = await client.rpc('alin_order_transition_group', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_reason': reason.trim().isEmpty ? null : reason.trim(),
    });
    if (raw is! Map) throw Exception('تعذر تحديث الطلب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحديث الطلب'}');
    return map;
  }

  Future<void> courierSetNoteGroup(String orderId, String note) async {
    final text = note.trim();
    if (text.length < 2) throw Exception('اكتب ملاحظة واضحة');
    final raw = await client.rpc('alin_courier_set_order_note_group', params: {
      'p_order_id': orderId,
      'p_note': text,
    });
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر إرسال الملاحظة');
  }
}
