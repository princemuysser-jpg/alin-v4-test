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
    final set = await client.auth.setSession(refreshToken, accessToken: accessToken);
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
    if ('${map['status']}' != 'active' || map['deleted_at'] != null) throw Exception('الحساب غير فعال');
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
    return _orderTransition(orderId, status, reason: reason);
  }

  Future<void> courierSetNote(String orderId, String note) async {
    final text = note.trim();
    if (text.length < 2) throw Exception('اكتب ملاحظة واضحة');
    final raw = await client.rpc('alin_courier_set_order_note', params: {'p_order_id': orderId, 'p_note': text});
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
    final raw = await client.from('accounts').select('id,name,phone,area,landmark,is_open,open_status,status').eq('id', libraryId).maybeSingle();
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
    final raw = await client.from('settlements').select('id,receipt_number,party_role,party_id,amount,payment_method,status,note,created_at,updated_at').eq('party_id', libraryId).order('created_at', ascending: false).limit(200);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminOrders() async {
    final raw = await client
        .from('orders')
        .select('id,order_number,kind,item_id,title,student_name,student_phone,qty,unit_price,discount,total,status,assignment_status,payment_status,payment_method,fulfillment_type,delivery_type,library_id,pickup_library_id,courier_id,delegate_id,delivery_area,delivery_landmark,delivery_fee,courier_fee,notes,library_note,delivery_note,platform_profit,teacher_profit,library_profit,courier_profit,delegate_profit,book_supplier_profit,created_at,updated_at,completed_at,delivered_at,cancellation_reason')
        .order('created_at', ascending: false)
        .limit(600);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminAccounts() async {
    final raw = await client
        .from('accounts')
        .select('id,role,name,username,status,admin_level,phone,area,landmark,is_open,open_status,notes,deleted_at,created_at,updated_at')
        .order('created_at', ascending: false)
        .limit(800);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminCouriers() async {
    final raw = await client
        .from('couriers')
        .select('id,name,username,phone,area,areas,availability,status,created_at,updated_at')
        .order('name')
        .limit(300);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminBooklets() async {
    final raw = await client
        .from('booklets')
        .select('id,title,teacher_id,subject,grade,term,edition,year,price,teacher_share_percent,library_share_percent,platform_share_percent,status,publish_status,published,is_published,teacher_approved,admin_note,description,cover_path,file_name,deleted_at,created_at,updated_at')
        .order('created_at', ascending: false)
        .limit(500);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminProducts() async {
    final raw = await client
        .from('products')
        .select('id,name,title,type,category,price,sale_price,stock,low_stock_limit,status,supplier_type,supplier_name,deleted_at,created_at,updated_at')
        .order('created_at', ascending: false)
        .limit(500);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminSettlements() async {
    final raw = await client
        .from('settlements')
        .select('id,receipt_number,party_role,party_id,amount,payment_method,status,note,reversed_from,created_at,updated_at')
        .order('created_at', ascending: false)
        .limit(400);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> adminLedger() async {
    final raw = await client
        .from('ledger')
        .select('id,order_id,order_number,title,total,merchandise_total,delivery_fee,alin,admin,teacher,teacher_id,library,library_id,courier,courier_id,delegate,delegate_id,collector_role,collector_id,collector_debt,status,settlement_status,supplier,supplier_id,supplier_type,supplier_name,supplier_settlement_status,created_at,settled_at')
        .eq('is_current', true)
        .order('created_at', ascending: false)
        .limit(600);
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> adminCreateAccount(Map<String, dynamic> payload) async {
    final result = await client.functions.invoke('admin-create-account', body: payload).timeout(const Duration(seconds: 30));
    if (result.data is! Map) throw Exception('تعذر إنشاء الحساب');
    final map = Map<String, dynamic>.from(result.data as Map);
    if (result.status != 200 || map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر إنشاء الحساب'}');
    return map;
  }

  Future<Map<String, dynamic>> adminUpdateAccount(String accountId, Map<String, dynamic> changes) async {
    final result = await client.functions.invoke('admin-update-account', body: {'account_id': accountId, ...changes}).timeout(const Duration(seconds: 30));
    if (result.data is! Map) throw Exception('تعذر تحديث الحساب');
    final map = Map<String, dynamic>.from(result.data as Map);
    if (result.status != 200 || map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحديث الحساب'}');
    return map;
  }

  Future<Map<String, dynamic>> adminAssignOrder(String orderId, {String? courierId, String? libraryId}) async {
    final raw = await client.rpc('alin_admin_assign_order_group', params: {
      'p_order_id': orderId,
      'p_courier_id': courierId?.trim().isEmpty == true ? null : courierId,
      'p_library_id': libraryId?.trim().isEmpty == true ? null : libraryId,
    });
    if (raw is! Map) throw Exception('تعذر تعيين الطلب');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تعيين الطلب'}');
    return map;
  }

  Future<Map<String, dynamic>> adminTransitionOrder(String orderId, String status, {String reason = ''}) {
    return _orderTransition(orderId, status, reason: reason);
  }

  Future<Map<String, dynamic>> adminRecordSettlement({required String role, required String partyId, required num amount, required String method, String note = ''}) async {
    final raw = await client.rpc('alin_finance_record_settlement', params: {
      'p_role': role,
      'p_party_id': partyId,
      'p_amount': amount,
      'p_method': method,
      'p_note': note.trim().isEmpty ? null : note.trim(),
    });
    if (raw is! Map) throw Exception('تعذر تثبيت التسوية');
    final map = Map<String, dynamic>.from(raw);
    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تثبيت التسوية'}');
    return map;
  }

  Future<Map<String, dynamic>> _orderTransition(String orderId, String status, {String reason = ''}) async {
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

  Future<Map<String, dynamic>> _adminSummary() async {
    final results = await Future.wait([
      client.from('orders').select('id,status,total,platform_profit').limit(800),
      client.from('accounts').select('id,role,status,deleted_at').limit(800),
    ]);
    final orders = (results[0] as List).cast<Map<String, dynamic>>();
    final accounts = (results[1] as List).cast<Map<String, dynamic>>();
    final validAccounts = accounts.where((e) => e['deleted_at'] == null).toList();
    return {
      'orders': orders.length,
      'new_orders': orders.where((e) => ['new', 'pending', 'pending_admin', 'assigned'].contains('${e['status']}')).length,
      'total_sales': orders.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['total']}') ?? 0)),
      'platform_profit': orders.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['platform_profit']}') ?? 0)),
      'couriers': validAccounts.where((e) => ['courier', 'delegate'].contains('${e['role']}')).length,
      'libraries': validAccounts.where((e) => '${e['role']}' == 'library').length,
      'printers': validAccounts.where((e) => '${e['role']}' == 'printer').length,
      'teachers': validAccounts.where((e) => '${e['role']}' == 'teacher').length,
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
    final raw = await client
        .from('alin_teacher_orders')
        .select('id,status,total,teacher_profit,teacher_id')
        .eq('teacher_id', id)
        .limit(400);
    final list = (raw as List).cast<Map<String, dynamic>>();
    return {
      'orders': list.length,
      'completed': list.where((e) => ['completed', 'delivered', 'done'].contains('${e['status']}')).length,
      'sales': list.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['total']}') ?? 0)),
      'profit': list.fold<num>(0, (sum, e) => sum + (num.tryParse('${e['teacher_profit']}') ?? 0)),
    };
  }
}
