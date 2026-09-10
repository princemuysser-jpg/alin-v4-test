import 'business_repository.dart';

extension AdminDeliveryPricingRepository on BusinessRepository {
  Future<List<Map<String, dynamic>>> adminDeliveryAreas() async {
    final raw = await client
        .from('delivery_areas')
        .select('id,name,city,delivery_fee,courier_fee,status,active,sort_order,landmark,latitude,longitude,created_at,updated_at')
        .order('sort_order')
        .order('name');
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> adminUpsertDeliveryArea({
    String? id,
    required String name,
    required num deliveryFee,
    required num courierFee,
    bool active = true,
    String city = 'كركوك',
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'city': city.trim().isEmpty ? 'كركوك' : city.trim(),
      'delivery_fee': deliveryFee,
      'courier_fee': courierFee,
      'active': active,
      'status': active ? 'active' : 'inactive',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null || id.trim().isEmpty) {
      payload['id'] = 'DA-${DateTime.now().microsecondsSinceEpoch}';
      payload['created_at'] = DateTime.now().toUtc().toIso8601String();
      await client.from('delivery_areas').insert(payload);
    } else {
      await client.from('delivery_areas').update(payload).eq('id', id);
    }
  }

  Future<Map<String, dynamic>> adminSetOrderDeliveryPricing({
    required String orderId,
    required String mode,
    num? deliveryFee,
    num? courierFee,
  }) async {
    final raw = await client.rpc('alin_admin_set_order_delivery_pricing', params: {
      'p_order_id': orderId,
      'p_mode': mode,
      'p_delivery_fee': deliveryFee,
      'p_courier_fee': courierFee,
    });
    if (raw is! Map) throw Exception('تعذر تحديث تسعير التوصيل');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحديث تسعير التوصيل'}');
    return map;
  }
}
