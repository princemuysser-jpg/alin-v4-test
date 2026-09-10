import 'business_repository.dart';

extension AdminGrowthRepository on BusinessRepository {
  Future<Map<String, dynamic>> adminOrderingSettings() async {
    final raw = await client.rpc('alin_admin_ordering_settings');
    if (raw is! Map) throw Exception('تعذر تحميل حالة الطلبات');
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> adminSetOrderingEnabled({
    required bool enabled,
    String? reason,
  }) async {
    final raw = await client.rpc('alin_admin_set_ordering_enabled', params: {
      'p_enabled': enabled,
      'p_reason': reason,
    });
    if (raw is! Map) throw Exception('تعذر تحديث حالة الطلبات');
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> adminStudentCustomers({
    int days = 30,
    String mode = 'all',
    String? search,
  }) async {
    final raw = await client.rpc('alin_admin_student_customers', params: {
      'p_days': days,
      'p_mode': mode,
      'p_search': search,
    });
    if (raw is! Map) throw Exception('تعذر تحميل العملاء');
    return Map<String, dynamic>.from(raw);
  }

  Future<Map<String, dynamic>> adminCreateStudentOffer({
    required String studentId,
    required String discountType,
    required num discountValue,
    int daysValid = 3,
    String appliesTo = 'all',
    String? title,
    String? message,
  }) async {
    final raw = await client.rpc('alin_admin_create_student_offer', params: {
      'p_student_id': studentId,
      'p_discount_type': discountType,
      'p_discount_value': discountValue,
      'p_days_valid': daysValid,
      'p_applies_to': appliesTo,
      'p_title': title,
      'p_message': message,
    });
    if (raw is! Map) throw Exception('تعذر إنشاء العرض الخاص');
    return Map<String, dynamic>.from(raw);
  }
}
