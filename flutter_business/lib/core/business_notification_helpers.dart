/// Safe display helpers for the business notification inbox.
/// Order detail access remains protected by the existing repository.
class BusinessNotificationHelpers {
  static String? orderId(Map<String, dynamic> item) {
    for (final field in ['order_id', 'orderId']) {
      final raw = item[field];
      final value = raw == null ? '' : '$raw'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    final data = item['data'];
    if (data is Map) {
      final nested = orderId(Map<String, dynamic>.from(data));
      if (nested != null) return nested;
    }
    final link = '${item['link'] ?? item['url'] ?? ''}'.trim();
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      for (final name in ['order', 'order_id']) {
        final value = uri?.queryParameters[name]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
      if (uri != null) {
        final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
        for (var i = 0; i + 1 < parts.length; i++) {
          if (parts[i] == 'orders' || parts[i] == 'order') {
            return Uri.decodeComponent(parts[i + 1]);
          }
        }
      }
    }
    // Legacy notifications may contain only an order code in the message.
    final message = '${item['message'] ?? ''}';
    return RegExp(r'\b(O[0-9A-Za-z]+)\b').firstMatch(message)?.group(1);
  }

  static List<Map<String, dynamic>> distinctById(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = '${row['id'] ?? ''}'.trim();
      // Do not collapse distinct events sharing a title or an order.
      if (id.isNotEmpty && !seen.add(id)) continue;
      result.add(row);
    }
    return result;
  }
}
