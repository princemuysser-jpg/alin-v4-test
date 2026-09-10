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
}
