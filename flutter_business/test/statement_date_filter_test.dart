import 'package:flutter_test/flutter_test.dart';
import 'package:alin_business/core/statement_date_filter.dart';

void main() {
  final start = DateTime(2026, 11, 10);
  final end = DateTime(2026, 11, 17);

  test('unfiltered statements retain legacy rows with missing dates', () {
    expect(statementDateWithinRange(null), isTrue);
    expect(statementDateWithinRange('invalid'), isTrue);
  });

  test('from and to dates are inclusive, regardless of timestamp time', () {
    expect(
      statementDateWithinRange(
        '2026-11-10T00:00:00',
        fromDate: start,
        toDate: end,
      ),
      isTrue,
    );
    expect(
      statementDateWithinRange(
        '2026-11-17T23:59:59',
        fromDate: start,
        toDate: end,
      ),
      isTrue,
    );
  });

  test('dates outside the selected period are excluded', () {
    expect(
      statementDateWithinRange(
        '2026-11-09',
        fromDate: start,
        toDate: end,
      ),
      isFalse,
    );
    expect(
      statementDateWithinRange(
        '2026-11-18',
        fromDate: start,
        toDate: end,
      ),
      isFalse,
    );
  });

  test('undated and invalid rows are excluded from filtered reports', () {
    expect(
      statementDateWithinRange(null, fromDate: start),
      isFalse,
    );
    expect(
      statementDateWithinRange('', toDate: end),
      isFalse,
    );
    expect(
      statementDateWithinRange(
        'not-a-date',
        fromDate: start,
        toDate: end,
      ),
      isFalse,
    );
  });

  test('open-ended date filters work', () {
    expect(
      statementDateWithinRange('2026-11-20', fromDate: start),
      isTrue,
    );
    expect(
      statementDateWithinRange('2026-11-20', toDate: end),
      isFalse,
    );
  });
}
