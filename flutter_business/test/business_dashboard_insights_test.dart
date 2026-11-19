import 'package:flutter_test/flutter_test.dart';
import 'package:alin_business/core/business_dashboard_insights.dart';

void main() {
  test('activity includes only last seven calendar days and ignores unknown dates', () {
    final today = DateTime(2026, 11, 19);
    String isoFor(int daysAgo) =>
        DateTime(2026, 11, 19).subtract(Duration(days: daysAgo)).toUtc().toIso8601String();

    final grouped = <Map<String, dynamic>>[
      {'created_at': isoFor(6)},
      {'created_at': isoFor(0)},
      {'created_at': isoFor(0)},
      {'created_at': isoFor(7)},
      {'created_at': 'bad-value'},
      {'created_at': null},
    ];
    expect(BusinessDashboardInsights.ordersByDay(grouped, today: today),
      [1, 0, 0, 0, 0, 0, 2]);
    expect(BusinessDashboardInsights.dayLabel(today, 0), '13/11');
    expect(BusinessDashboardInsights.dayLabel(today, 6), '19/11');
  });

  test('empty recent snapshot renders all zero chart values', () {
    expect(BusinessDashboardInsights.ordersByDay(
      <Map<String, dynamic>>[], today: DateTime(2026, 11, 19)),
      List<int>.filled(7, 0));
  });
}
