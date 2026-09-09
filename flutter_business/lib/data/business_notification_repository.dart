import 'business_repository.dart';

extension BusinessNotificationRepository on BusinessRepository {
  Future<List<Map<String, dynamic>>> businessNotifications({int limit = 100}) async {
    final raw = await client.rpc('alin_business_notifications', params: {'p_limit': limit});
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<int> businessNotificationUnreadCount() async {
    final raw = await client.rpc('alin_business_notification_unread_count');
    return int.tryParse('$raw') ?? 0;
  }

  Future<bool> businessNotificationMarkRead(String notificationId) async {
    final raw = await client.rpc(
      'alin_business_notification_mark_read',
      params: {'p_notification_id': notificationId},
    );
    return raw == true;
  }

  Future<int> businessNotificationsMarkAll() async {
    final raw = await client.rpc('alin_business_notifications_mark_all');
    return int.tryParse('$raw') ?? 0;
  }

  Future<Map<String, dynamic>> businessOrder(String orderId) async {
    final raw = await client
        .from('orders')
        .select(
          'id,order_number,title,kind,status,student_name,student_phone,qty,unit_price,total,payment_status,payment_method,fulfillment_type,delivery_type,library_id,pickup_library_id,courier_id,delegate_id,delivery_area,delivery_landmark,delivery_fee,courier_fee,notes,library_note,delivery_note,created_at,updated_at,assigned_at,accepted_at,picked_up_at,out_for_delivery_at,processing_at,ready_at,completed_at,delivered_at,cancelled_at,rejected_at,cancellation_reason',
        )
        .eq('id', orderId)
        .maybeSingle();
    if (raw == null) throw Exception('الطلب غير موجود أو غير مسموح بعرضه');
    return Map<String, dynamic>.from(raw);
  }

  Future<List<Map<String, dynamic>>> businessOrderTimeline(String orderId) async {
    final raw = await client.rpc(
      'alin_business_order_timeline',
      params: {'p_order_id': orderId},
    );
    return (raw as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
