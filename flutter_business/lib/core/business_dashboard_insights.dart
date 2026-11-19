/// Lightweight UI insights from a recent, capped order snapshot.
///
/// This is not an all-time report. Rows are already grouped by checkout to
/// prevent multiple items from being counted as separate customer orders.
class BusinessDashboardInsights {
  static List<int> ordersByDay(
    List<Map<String, dynamic>> groupedOrders, {
    required DateTime today,
  }) {
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);

    for (final order in groupedOrders) {
      final raw = order['created_at'];
      if (raw == null) continue;
      final created = DateTime.tryParse('$raw');
      if (created == null) continue;
      final local = created.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      if (date.isBefore(start) || date.isAfter(end)) continue;
      counts[date.difference(start).inDays]++;
    }
    return counts;
  }

  static String dayLabel(DateTime today, int offset) {
    final end = DateTime(today.year, today.month, today.day);
    final day = end.subtract(Duration(days: 6 - offset));
    return '${day.day}/${day.month}';
  }
}
