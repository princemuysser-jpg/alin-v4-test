import 'package:flutter_test/flutter_test.dart';
import 'package:alin_business/core/business_order_list.dart';

void main() {
  final now = DateTime(2026, 11, 19, 12);
  Map<String, dynamic> order(String id, String status, {
    String? reason, int amount = 0, DateTime? date,
    String? student,
  }) => {
    'id': id, 'order_number': id, 'status': status,
    'cancellation_reason': reason ?? '',
    'student_name': student ?? '',
    'total': amount,
    'created_at': (date ?? now).toIso8601String(),
  };

  test('grouped checkout status checks any item and all terminal items', () {
    final grouped = {
      ...order('g1', 'new'),
      '_items': [
        order('a', 'completed'),
        order('b', 'new'),
      ],
    };
    expect(BusinessOrderList.anyStatus(grouped, BusinessOrderList.newStatuses), isTrue);
    expect(BusinessOrderList.isClosed(grouped), isFalse);
    expect(BusinessOrderList.select([grouped], filter: 'new').length, 1);
    expect(BusinessOrderList.select([grouped], filter: 'active').length, 1);
  });

  test('cancellation reason filter includes only cancelled orders', () {
    final rows = [
      order('1', 'cancelled', reason: 'لم يستجب'),
      order('2', 'canceled'),
      order('3', 'completed', reason: 'لم يستجب'),
    ];
    expect(BusinessOrderList.select(rows,
      filter: 'cancelled', cancellationReasonFilter: 'لم يستجب',
    ).map((x) => x['id']), ['1']);
    expect(BusinessOrderList.select(rows,
      filter: 'cancelled', cancellationReasonFilter: '__without_reason__',
    ).map((x) => x['id']), ['2']);
  });

  test('search, date range and amount sorting are deterministic', () {
    final rows = [
      order('1', 'new', amount: 50, student: 'مصطفى'),
      order('2', 'ready', amount: 400,
        date: DateTime(2026, 11, 17, 12), student: 'أحمد'),
      order('3', 'ready', amount: 800,
        date: DateTime(2026, 10, 1, 12), student: 'مصطفى'),
    ];
    expect(BusinessOrderList.select(rows,
      query: 'مصطفى', dateFilter: 'month', today: now,
    ).map((e) => e['id']), ['1']);
    expect(BusinessOrderList.select(rows,
      dateFilter: 'week', sort: 'highest', today: now,
    ).map((e) => e['id']), ['2', '1']);
    expect(BusinessOrderList.select(rows, sort: 'oldest',
      today: now).map((e) => e['id']), ['3', '2', '1']);
  });

  test('missing date excluded from bounded periods and input is unchanged', () {
    final rows = [
      {'id': 'bad', 'status': 'new', 'created_at': null},
      order('recent', 'new'),
    ];
    final result = BusinessOrderList.select(rows,
      dateFilter: 'today', today: now);
    expect(result.map((x) => x['id']), ['recent']);
    expect(rows.first['id'], 'bad');
  });
}
