/// Date-only filtering used by the business party statement and its PDF.
///
/// Without a date filter, preserve all rows (including legacy undated rows).
/// With a filter, undated or malformed timestamps must not appear in a
/// date-bounded financial report.
bool statementDateWithinRange(
  Object? raw, {
  DateTime? fromDate,
  DateTime? toDate,
}) {
  if (fromDate == null && toDate == null) return true;

  final parsed = DateTime.tryParse('${raw ?? ''}')?.toLocal();
  if (parsed == null) return false;

  final day = DateTime(parsed.year, parsed.month, parsed.day);
  if (fromDate != null) {
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    if (day.isBefore(from)) return false;
  }
  if (toDate != null) {
    final to = DateTime(toDate.year, toDate.month, toDate.day);
    if (day.isAfter(to)) return false;
  }
  return true;
}
