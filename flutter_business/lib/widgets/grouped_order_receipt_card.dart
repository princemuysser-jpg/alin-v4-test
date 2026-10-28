import 'package:flutter/material.dart';

num receiptNumberValue(dynamic value) => num.tryParse('$value') ?? 0;

String receiptCheckoutKey(Map<String, dynamic> row) {
  final group = '${row['checkout_group_id'] ?? ''}'.trim();
  if (group.isNotEmpty) return 'group:$group';
  final request = '${row['checkout_request_key'] ?? ''}'.trim();
  if (request.isNotEmpty) return 'request:$request';
  return 'single:${row['id'] ?? row['order_number']}';
}

List<Map<String, dynamic>> groupOrdersForReceipts(List<Map<String, dynamic>> source) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final row in source) {
    groups.putIfAbsent(receiptCheckoutKey(row), () => <Map<String, dynamic>>[]).add(row);
  }
  final result = <Map<String, dynamic>>[];
  for (final entry in groups.entries) {
    final items = entry.value;
    items.sort((a, b) => '${a['created_at'] ?? ''}'.compareTo('${b['created_at'] ?? ''}'));
    final anchor = items.firstWhere(
      (row) => receiptNumberValue(row['delivery_fee']) > 0 || receiptNumberValue(row['courier_fee']) > 0,
      orElse: () => items.first,
    );
    result.add({
      ...anchor,
      '_receipt_group_key': entry.key,
      '_items': items,
      '_item_count': items.length,
      '_qty_count': items.fold<num>(0, (sum, row) => sum + (receiptNumberValue(row['qty']) <= 0 ? 1 : receiptNumberValue(row['qty']))),
      '_group_total': items.fold<num>(0, (sum, row) => sum + receiptNumberValue(row['total'] ?? row['total_amount'])),
      '_delivery_fee': items.fold<num>(0, (sum, row) => sum + receiptNumberValue(row['delivery_fee'] ?? row['shipping_fee'])),
      '_discount': items.fold<num>(0, (sum, row) => sum + receiptNumberValue(row['discount'] ?? row['discount_amount'])),
      '_courier_fee': items.fold<num>(0, (sum, row) => sum + receiptNumberValue(row['courier_fee'] ?? row['courier_profit'] ?? row['delegate_profit'])),
    });
  }
  result.sort((a, b) => '${b['completed_at'] ?? b['delivered_at'] ?? b['updated_at'] ?? b['created_at'] ?? ''}'
      .compareTo('${a['completed_at'] ?? a['delivered_at'] ?? a['updated_at'] ?? a['created_at'] ?? ''}'));
  return result;
}

bool receiptGroupCompleted(Map<String, dynamic> order) {
  final items = (order['_items'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[order];
  return items.isNotEmpty && items.every((row) => const {'completed', 'delivered', 'done'}.contains('${row['status'] ?? row['order_status']}'));
}

class GroupedOrderReceiptCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String? courierName;
  final bool courierView;

  const GroupedOrderReceiptCard({
    super.key,
    required this.order,
    this.courierName,
    this.courierView = false,
  });

  num _n(dynamic value) => receiptNumberValue(value);
  String _money(dynamic value) => '${_n(value).round()} د.ع';

  List<Map<String, dynamic>> get _items =>
      (order['_items'] as List?)?.cast<Map<String, dynamic>>() ??
      <Map<String, dynamic>>[order];

  num _rowDelivery(Map<String, dynamic> row) =>
      _n(row['delivery_fee'] ?? row['shipping_fee']);

  num _rowDiscount(Map<String, dynamic> row) =>
      _n(row['discount'] ?? row['discount_amount']);

  num _rowTotal(Map<String, dynamic> row) =>
      _n(row['total'] ?? row['total_amount'] ?? row['amount']);

  num _rowQty(Map<String, dynamic> row) =>
      _n(row['qty'] ?? row['quantity']) <= 0
          ? 1
          : _n(row['qty'] ?? row['quantity']);

  num _rowSubtotal(Map<String, dynamic> row) {
    final explicit = _n(row['subtotal'] ?? row['items_total']);
    if (explicit > 0) return explicit;
    return (_rowTotal(row) + _rowDiscount(row) - _rowDelivery(row))
        .clamp(0, double.infinity);
  }

  num _rowUnit(Map<String, dynamic> row) {
    final explicit = _n(row['unit_price'] ?? row['price']);
    return explicit > 0 ? explicit : _rowSubtotal(row) / _rowQty(row);
  }

  String _dateText() {
    final raw =
        '${order['completed_at'] ?? order['delivered_at'] ?? order['updated_at'] ?? order['created_at'] ?? ''}';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)}  '
        '${two(parsed.hour)}:${two(parsed.minute)}';
  }

  bool get _isDelivery {
    final fulfillment = '${order['fulfillment_type'] ?? ''}'.toLowerCase();
    final deliveryType = '${order['delivery_type'] ?? ''}'.toLowerCase();
    return fulfillment == 'home_delivery' ||
        fulfillment == 'courier' ||
        fulfillment == 'delivery' ||
        deliveryType == 'courier';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final delivery = _n(order['_delivery_fee']) > 0
        ? _n(order['_delivery_fee'])
        : items.fold<num>(0, (s, r) => s + _rowDelivery(r));
    final discount = _n(order['_discount']) > 0
        ? _n(order['_discount'])
        : items.fold<num>(0, (s, r) => s + _rowDiscount(r));
    final total = _n(order['_group_total']) > 0
        ? _n(order['_group_total'])
        : items.fold<num>(0, (s, r) => s + _rowTotal(r));
    final subtotal = items.fold<num>(0, (s, r) => s + _rowSubtotal(r));
    final courierFee = _n(order['_courier_fee']) > 0
        ? _n(order['_courier_fee'])
        : items.fold<num>(
            0,
            (s, r) =>
                s +
                _n(
                  r['courier_fee'] ??
                      r['courier_profit'] ??
                      r['delegate_profit'],
                ),
          );

    final accent =
        _isDelivery ? const Color(0xFF0088FF) : const Color(0xFF16A34A);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .07),
              border: Border(
                right: BorderSide(color: accent, width: 4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: accent,
                    size: 23,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'وصل طلب',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF143B68),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '#${order['order_number'] ?? order['id'] ?? '—'} • '
                        '${items.length} مواد',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(alpha: .14),
                    ),
                  ),
                  child: Text(
                    _isDelivery ? '🚚 توصيل' : '🏪 مكتبة',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 620;
                    final student = _summaryBox(
                      Icons.person_rounded,
                      'الطالب',
                      '${order['student_name'] ?? '—'}',
                      '${order['student_phone'] ?? '—'}',
                      const Color(0xFF7C3AED),
                    );
                    final place = _summaryBox(
                      _isDelivery
                          ? Icons.local_shipping_rounded
                          : Icons.storefront_rounded,
                      _isDelivery ? 'التوصيل' : 'الاستلام',
                      _isDelivery
                          ? '${order['delivery_area'] ?? '—'}'
                          : 'استلام من مكتبة',
                      courierName == null || courierName!.trim().isEmpty
                          ? _dateText()
                          : courierName!,
                      accent,
                    );
                    final amount = _summaryBox(
                      Icons.payments_rounded,
                      'الإجمالي',
                      _money(total),
                      _dateText(),
                      const Color(0xFFFF7A00),
                    );
                    if (!wide) {
                      return Column(
                        children: [
                          student,
                          const SizedBox(height: 8),
                          place,
                          const SizedBox(height: 8),
                          amount,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: student),
                        const SizedBox(width: 8),
                        Expanded(child: place),
                        const SizedBox(width: 8),
                        Expanded(child: amount),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 11),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEF2F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 17,
                            color: Color(0xFF143B68),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'مواد الطلب',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF143B68),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...items.asMap().entries.map((entry) {
                        final row = entry.value;
                        final qty = _rowQty(row).round();
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: entry.key == items.length - 1
                                ? null
                                : const Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFEEF2F6),
                                    ),
                                  ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${row['title'] ?? row['product_name'] ?? row['item_name'] ?? 'مادة'}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF344054),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$qty × ${_money(_rowUnit(row))}',
                                      style: const TextStyle(
                                        color: Color(0xFF667085),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _money(_rowSubtotal(row)),
                                style: const TextStyle(
                                  color: Color(0xFF143B68),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _totalRow('مجموع المواد', _money(subtotal)),
                if (delivery > 0)
                  _totalRow('أجرة التوصيل', _money(delivery)),
                if (discount > 0)
                  _totalRow(
                    'الخصم',
                    '- ${_money(discount)}',
                    valueColor: const Color(0xFFE11D48),
                  ),
                if (courierView)
                  _totalRow('أجرة المندوب', _money(courierFee)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF143B68),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الإجمالي الكلي',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        _money(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(
    IconData icon,
    String label,
    String value,
    String subtitle,
    Color accent,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: .12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF143B68),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    String label,
    String value, {
    Color valueColor = const Color(0xFF143B68),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
