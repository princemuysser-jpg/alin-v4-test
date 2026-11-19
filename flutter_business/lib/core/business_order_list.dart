/// Presentation-only filters for the administrator's recently loaded orders.
///
/// Input rows are already grouped by checkout; no database writes are involved.
class BusinessOrderList {
  static const newStatuses = {'new', 'pending', 'pending_admin'};
  static const processingStatuses = {
    'assigned', 'accepted', 'processing', 'printing',
    'picked_up', 'out_for_delivery',
  };
  static const terminalStatuses = {
    'completed', 'delivered', 'done',
    'cancelled', 'canceled', 'rejected',
  };

  static List<Map<String, dynamic>> items(Map<String, dynamic> order) {
    final nested = order['_items'];
    if (nested is! List) return [order];
    final rows = nested
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return rows.isEmpty ? [order] : rows;
  }

  static bool anyStatus(Map<String, dynamic> order, Set<String> statuses) =>
      items(order).any((row) => statuses.contains('${row['status']}'));

  static bool allStatus(Map<String, dynamic> order, Set<String> statuses) =>
      items(order).every((row) => statuses.contains('${row['status']}'));

  static bool isClosed(Map<String, dynamic> order) =>
      allStatus(order, terminalStatuses);

  static String cancellationReason(Map<String, dynamic> order) {
    final grouped = '${order['_cancellation_reason'] ?? ''}'.trim();
    if (grouped.isNotEmpty) return grouped;
    final direct = '${order['cancellation_reason'] ?? ''}'.trim();
    if (direct.isNotEmpty) return direct;
    for (final row in items(order)) {
      final reason = '${row['cancellation_reason'] ?? ''}'.trim();
      if (reason.isNotEmpty) return reason;
    }
    return '';
  }

  static bool _hasStatus(Map<String, dynamic> order, String filter) =>
      switch (filter) {
        'new' => anyStatus(order, newStatuses),
        'processing' => anyStatus(order, processingStatuses),
        'ready' => anyStatus(order, {'ready'}),
        'done' => allStatus(order, {'completed', 'delivered', 'done'}),
        'cancelled' => allStatus(order, {'cancelled', 'canceled', 'rejected'}),
        'active' => !isClosed(order),
        _ => true,
      };

  static DateTime? createdLocal(Map<String, dynamic> order) {
    final raw = order['created_at'];
    return raw == null ? null : DateTime.tryParse('${raw}')?.toLocal();
  }

  static bool _withinDate(Map<String, dynamic> order, String filter, DateTime today) {
    if (filter == 'all') return true;
    final created = createdLocal(order);
    if (created == null) return false;
    final day = DateTime(created.year, created.month, created.day);
    final end = DateTime(today.year, today.month, today.day);
    if (day.isAfter(end)) return false;
    if (filter == 'today') return day == end;
    if (filter == 'week') return !day.isBefore(end.subtract(const Duration(days: 6)));
    if (filter == 'month') return day.year == end.year && day.month == end.month;
    return true;
  }

  static String _searchText(Map<String, dynamic> order) => [
    order['order_number'], order['id'], order['student_name'],
    order['student_phone'], order['delivery_area'], order['delivery_landmark'],
    order['title'], cancellationReason(order),
    ...items(order).map((e) => e['title']),
  ].where((v) => v != null).join(' ').toLowerCase();

  static num _total(Map<String, dynamic> order) =>
      num.tryParse('${order['total'] ?? 0}') ?? 0;

  static List<Map<String, dynamic>> select(
    List<Map<String, dynamic>> grouped, {
    String filter = 'all',
    String query = '',
    String cancellationReasonFilter = 'all',
    String dateFilter = 'all',
    String sort = 'newest',
    DateTime? today,
  }) {
    final search = query.trim().toLowerCase();
    final now = today ?? DateTime.now();
    final rows = grouped.where((order) {
      if (!_hasStatus(order, filter)) return false;
      if (!_withinDate(order, dateFilter, now)) return false;
      if (filter == 'cancelled' && cancellationReasonFilter != 'all') {
        final reason = cancellationReason(order);
        if (cancellationReasonFilter == '__without_reason__') {
          if (reason.isNotEmpty) return false;
        } else if (reason != cancellationReasonFilter) {
          return false;
        }
      }
      return search.isEmpty || _searchText(order).contains(search);
    }).toList();

    // Always sort a copy: the grouped input also feeds finance and receipts.
    rows.sort((a, b) {
      if (sort == 'highest') {
        final byAmount = _total(b).compareTo(_total(a));
        if (byAmount != 0) return byAmount;
      }
      final one = createdLocal(a) ?? DateTime(1970);
      final two = createdLocal(b) ?? DateTime(1970);
      return sort == 'oldest' ? one.compareTo(two) : two.compareTo(one);
    });
    return rows;
  }
}
