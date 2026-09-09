import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/business_account.dart';

class BusinessRepository {
  final SupabaseClient client;
  BusinessRepository(this.client);

  Future<BusinessAccount> login({required String username, required String password}) async {
    final result = await client.functions.invoke('secure-login', body: {
      'username': username.trim(),
      'password': password,
    }).timeout(const Duration(seconds: 25));

    if (result.status != 200) {
      final data = result.data;
      if (data is Map && data['error'] != null) throw Exception('${data['error']}');
      throw Exception('تعذر تسجيل الدخول حالياً');
    }
    if (result.data is! Map) throw Exception('تعذر تسجيل الدخول حالياً');
    final payload = Map<String, dynamic>.from(result.data as Map);
    if (payload['ok'] != true) throw Exception('${payload['error'] ?? 'تعذر تسجيل الدخول'}');
    final session = payload['session'];
    final user = payload['user'];
    if (session is! Map || user is! Map) throw Exception('جلسة الدخول غير مكتملة');
    final accessToken = '${session['access_token'] ?? ''}';
    final refreshToken = '${session['refresh_token'] ?? ''}';
    final userId = '${user['id'] ?? ''}';
    if (accessToken.isEmpty || refreshToken.isEmpty || userId.isEmpty) {
      throw Exception('جلسة الدخول غير مكتملة');
    }
    final set = await client.auth.setSession(
      refreshToken,
      accessToken: accessToken,
    );
    if (set.session == null || set.user == null || set.user!.id != userId) {
      throw Exception('تعذر تثبيت جلسة الدخول');
    }
    final account = await accountForUser(set.user!.id);
    if (!account.isBusinessRole) {
      await client.auth.signOut();
      throw Exception('هذا الحساب غير مخصص لتطبيق آلين للأعمال');
    }
    return account;
  }

  Future<BusinessAccount> accountForUser(String authUserId) async {
    final raw = await client
        .from('accounts')
        .select('id,role,name,username,status,auth_user_id,area,phone,landmark,admin_level,deleted_at')
        .eq('auth_user_id', authUserId)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (raw == null) throw Exception('الحساب غير مربوط');
    final map = Map<String, dynamic>.from(raw);
    if ('${map['status']}' != 'active' || map['deleted_at'] != null) {
      throw Exception('الحساب غير فعال');
    }
    return BusinessAccount.fromMap(map);
  }

  Future<BusinessAccount?> restoreAccount() async {
    final session = client.auth.currentSession;
    final user = session?.user;
    if (user == null) return null;
    try {
      final account = await accountForUser(user.id);
      return account.isBusinessRole ? account : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() => client.auth.signOut();

  Future<Map<String, dynamic>> dashboardSummary(BusinessAccount account) async {
    switch (account.role) {
      case 'printer':
        final data = await client.rpc('alin_printer_finance_summary');
        return data is Map ? Map<String, dynamic>.from(data) : {};
      case 'admin':
      case 'accountant':
        return _adminSummary();
      case 'courier':
        return _courierSummary(account.id);
      case 'library':
        return _librarySummary(account.id);
      case 'teacher':
        return _teacherSummary(account.id);
      default:
        return {};
    }
  }

  Future<List<Map<String, dynamic>>> courierOrders(String courierId) async {
    final raw = await client
        .from('orders')
        .select('id,order_number,title,kind,status,student_name,student_phone,qty,total,delivery_fee,courier_fee,delegate_profit,courier_profit,delivery_area,delivery_landmark,delivery_latitude,delivery_longitude,delivery_location_url,delivery_note,notes,pickup_source_label,pickup_source_type,library_id,pickup_library_id,product_variant_code,product_variant_name,created_at,updated_at,delivered_at,completed_at,courier_id,delegate_id')
        .or('courier_id.eq.$courierId,delegate_id.eq.$courierId')
        .order('created_at', ascending: false)
        .limit(300);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> courierTransition(String orderId, String status, {String reason = ''}) async {
    final raw = await client.rpc('alin_order_transition_atomic', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_reason': reason.trim().isEmpty ? null : reason.trim(),
    });
    if (raw is! Map) throw Exception('تعذر تحديث الطلب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحديث الطلب'}');
    return map;
  }

  Future<void> courierSetNote(String orderId, String note) async {
    final text = note.trim();
    if (text.length < 2) throw Exception('اكتب ملاحظة واضحة');
    final raw = await client.rpc('alin_courier_set_order_note', params: {
      'p_order_id': orderId,
      'p_note': text,
    });
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر إرسال الملاحظة');
  }

  Future<void> courierSetAvailability(String value) async {
    final raw = await client.rpc('alin_courier_set_availability', params: {'p_value': value});
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر تحديث حالة المندوب');
  }

  Future<List<Map<String, dynamic>>> libraryOrders(String libraryId) async {
    final raw = await client
        .from('orders')
        .select('id,order_number,title,kind,status,student_name,student_phone,qty,unit_price,total,library_profit,library_cash_collected,payment_status,payment_method,fulfillment_type,delivery_type,library_id,pickup_library_id,notes,library_note,created_at,updated_at,processing_at,ready_at,completed_at,delivered_at,cancellation_reason')
        .or('library_id.eq.$libraryId,pickup_library_id.eq.$libraryId')
        .order('created_at', ascending: false)
        .limit(400);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> libraryProfile(String libraryId) async {
    final raw = await client
        .from('accounts')
        .select('id,name,phone,area,landmark,is_open,open_status,status')
        .eq('id', libraryId)
        .maybeSingle();
    if (raw == null) throw Exception('تعذر قراءة بيانات المكتبة');
    return Map<String, dynamic>.from(raw);
  }

  Future<void> librarySetOpen(bool open) async {
    final raw = await client.rpc('alin_set_library_open', params: {'p_open': open});
    if (raw is Map && raw['ok'] == true) return;
    throw Exception('تعذر تحديث حالة المكتبة');
  }

  Future<Map<String, dynamic>> libraryTransition(String orderId, String status, {String reason = ''}) async {
    final raw = await client.rpc('alin_library_set_order_status', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_reason': reason.trim().isEmpty ? null : reason.trim(),
    });
    if (raw is! Map) throw Exception('تعذر تحديث الطلب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحديث الطلب'}');
    return map;
  }

  Future<List<Map<String, dynamic>>> librarySettlements(String libraryId) async {
    final raw = await client
        .from('settlements')
        .select('id,receipt_number,party_role,party_id,amount,payment_method,status,note,created_at,updated_at')
        .eq('party_id', libraryId)
        .order('created_at', ascending: false)
        .limit(200);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _adminSummary() async {
    final results = await Future.wait([
      client.from('orders').select('id,status,total').limit(500),
      client.from('accounts').select('id,role,status').isFilter('deleted_at', null).limit(500),
    ]);
    final orders = (results[0] as List).cast<Map<String, dynamic>>();
    final accounts = (results[1] as List).cast<Map<String, dynamic>>();
    return {
      'orders': orders.length,
      'new_orders': orders.where((e) => ['new', 'pending', 'pending_admin'].contains('${e['status']}')).length,
      'total_sales': orders.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['total']}') ?? 0)),
      'couriers': accounts.where((e) => ['courier', 'delegate'].contains('${e['role']}')).length,
      'libraries': accounts.where((e) => '${e['role']}' == 'library').length,
      'printers': accounts.where((e) => '${e['role']}' == 'printer').length,
      'teachers': accounts.where((e) => '${e['role']}' == 'teacher').length,
    };
  }

  Future<Map<String, dynamic>> _courierSummary(String id) async {
    final list = await courierOrders(id);
    return {
      'orders': list.length,
      'active': list.where((e) => !['completed', 'delivered', 'cancelled', 'rejected'].contains('${e['status']}')).length,
      'completed': list.where((e) => ['completed', 'delivered'].contains('${e['status']}')).length,
      'profit': list.fold<num>(0, (sum, e) {
        final v = e['courier_fee'] ?? e['courier_profit'] ?? e['delegate_profit'];
        return sum + (num.tryParse('$v') ?? 0);
      }),
    };
  }

  Future<Map<String, dynamic>> _librarySummary(String id) async {
    final list = await libraryOrders(id);
    return {
      'orders': list.length,
      'new_orders': list.where((e) => ['new', 'pending', 'pending_admin', 'accepted', 'processing', 'printing'].contains('${e['status']}')).length,
      'completed': list.where((e) => ['ready', 'completed', 'delivered'].contains('${e['status']}')).length,
      'profit': list.where((e) => ['completed', 'delivered'].contains('${e['status']}')).fold<num>(0, (sum, e) => sum + (num.tryParse('${e['library_profit']}') ?? 0)),
    };
  }

  Future<Map<String, dynamic>> _teacherSummary(String id) async {
    final data = await client
        .from('orders')
        .select('id,status,total,teacher_id')
        .eq('teacher_id', id)
        .limit(300);
    final list = data.cast<Map<String, dynamic>>();
    return {
      'orders': list.length,
      'completed': list.where((e) => ['completed', 'delivered'].contains('${e['status']}')).length,
      'sales': list.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['total']}') ?? 0)),
    };
  }
}
