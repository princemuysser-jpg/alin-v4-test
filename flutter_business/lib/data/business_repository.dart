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
    final set = await client.auth.setSession(accessToken, refreshToken);
    if (set.session == null || set.user == null) throw Exception('تعذر تثبيت جلسة الدخول');
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
    final data = await client
        .from('orders')
        .select('id,status,total,delivery_fee,courier_fee')
        .or('courier_id.eq.$id,delegate_id.eq.$id')
        .limit(300);
    final list = data.cast<Map<String, dynamic>>();
    return {
      'orders': list.length,
      'active': list.where((e) => !['completed', 'delivered', 'cancelled'].contains('${e['status']}')).length,
      'completed': list.where((e) => ['completed', 'delivered'].contains('${e['status']}')).length,
      'profit': list.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['courier_fee']}') ?? 0)),
    };
  }

  Future<Map<String, dynamic>> _librarySummary(String id) async {
    final data = await client
        .from('orders')
        .select('id,status,total,library_id')
        .eq('library_id', id)
        .limit(300);
    final list = data.cast<Map<String, dynamic>>();
    return {
      'orders': list.length,
      'new_orders': list.where((e) => ['new', 'pending', 'processing', 'printing'].contains('${e['status']}')).length,
      'completed': list.where((e) => ['ready', 'completed', 'delivered'].contains('${e['status']}')).length,
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
