import 'package:flutter_test/flutter_test.dart';
import 'package:alin_business/core/business_notification_helpers.dart';

void main() {
  test('uses direct order id before link and message', () {
    expect(BusinessNotificationHelpers.orderId({
      'order_id': 'order-123',
      'link': 'alinbusiness://orders?order=other',
    }), 'order-123');
  });

  test('supports query links and nested order metadata', () {
    expect(BusinessNotificationHelpers.orderId({
      'link': 'https://alinplatform.com/business/?order_id=abc-123',
    }), 'abc-123');
    expect(BusinessNotificationHelpers.orderId({
      'data': {'order_id': 'nested-1'},
    }), 'nested-1');
  });

  test('legacy order number still works and missing order stays absent', () {
    expect(BusinessNotificationHelpers.orderId({
      'message': 'تم تجهيز الطلب OAB123',
    }), 'OAB123');
    expect(BusinessNotificationHelpers.orderId({
      'message': 'طلب جديد يحتاج متابعة',
    }), isNull);
  });

  test('deduplicates only identical notification ids', () {
    final rows = [
      {'id': 'n1', 'title': 'طلب جديد'},
      {'id': 'n1', 'title': 'طلب جديد'},
      {'id': 'n2', 'title': 'طلب جديد'},
      {'title': 'طلب جديد'},
      {'title': 'طلب جديد'},
    ];
    final result = BusinessNotificationHelpers.distinctById(rows);
    expect(result.length, 4);
    expect(result[0]['id'], 'n1');
    expect(result[1]['id'], 'n2');
  });
}
