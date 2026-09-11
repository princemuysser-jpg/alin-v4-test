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
      (order['_items'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[order];

  num _rowDelivery(Map<String, dynamic> row) => _n(row['delivery_fee'] ?? row['shipping_fee']);
  num _rowDiscount(Map<String, dynamic> row) => _n(row['discount'] ?? row['discount_amount']);
  num _rowTotal(Map<String, dynamic> row) => _n(row['total'] ?? row['total_amount'] ?? row['amount']);
  num _rowQty(Map<String, dynamic> row) => _n(row['qty'] ?? row['quantity']) <= 0 ? 1 : _n(row['qty'] ?? row['quantity']);
  num _rowSubtotal(Map<String, dynamic> row) {
    final explicit = _n(row['subtotal'] ?? row['items_total']);
    if (explicit > 0) return explicit;
    return (_rowTotal(row) + _rowDiscount(row) - _rowDelivery(row)).clamp(0, double.infinity);
  }
  num _rowUnit(Map<String, dynamic> row) {
    final explicit = _n(row['unit_price'] ?? row['price']);
    return explicit > 0 ? explicit : _rowSubtotal(row) / _rowQty(row);
  }

  String _dateText() {
    final raw = '${order['completed_at'] ?? order['delivered_at'] ?? order['updated_at'] ?? order['created_at'] ?? ''}';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '—';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)}  ${two(parsed.hour)}:${two(parsed.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final delivery = _n(order['_delivery_fee']) > 0 ? _n(order['_delivery_fee']) : items.fold<num>(0, (s, r) => s + _rowDelivery(r));
    final discount = _n(order['_discount']) > 0 ? _n(order['_discount']) : items.fold<num>(0, (s, r) => s + _rowDiscount(r));
    final total = _n(order['_group_total']) > 0 ? _n(order['_group_total']) : items.fold<num>(0, (s, r) => s + _rowTotal(r));
    final subtotal = items.fold<num>(0, (s, r) => s + _rowSubtotal(r));
    final courierFee = _n(order['_courier_fee']) > 0
        ? _n(order['_courier_fee'])
        : items.fold<num>(0, (s, r) => s + _n(r['courier_fee'] ?? r['courier_profit'] ?? r['delegate_profit']));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0xFFEAF2FB), borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF143B68)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('وصل طلب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF143B68))),
              Text('${order['order_number'] ?? order['id'] ?? '—'} • ${items.length} مواد', style: TextStyle(color: Colors.grey.shade700)),
            ])),
            Text(_dateText(), textAlign: TextAlign.left, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
          ]),
          const Divider(height: 24),
          _info('الطالب', '${order['student_name'] ?? '—'}'),
          _info('الهاتف', '${order['student_phone'] ?? '—'}'),
          if ('${order['delivery_area'] ?? ''}'.trim().isNotEmpty) _info('المنطقة', '${order['delivery_area']}'),
          if (courierName != null && courierName!.trim().isNotEmpty) _info('المندوب', courierName!),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF7F9FC), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مواد الطلب', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              ...items.asMap().entries.map((entry) {
                final row = entry.value;
                final qty = _rowQty(row).round();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${row['title'] ?? row['product_name'] ?? row['item_name'] ?? 'مادة'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('$qty × ${_money(_rowUnit(row))}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ])),
                    Text(_money(_rowSubtotal(row)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                );
              }),
            ]),
          ),
          const SizedBox(height: 10),
          _total('مجموع المواد', _money(subtotal)),
          if (delivery > 0) _total('أجرة التوصيل', _money(delivery)),
          if (discount > 0) _total('الخصم', _money(discount)),
          if (courierView) _total('أجرة المندوب', _money(courierFee)),
          const Divider(),
          Row(children: [
            const Expanded(child: Text('الإجمالي الكلي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            Text(_money(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF143B68))),
          ]),
        ]),
      ),
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 92, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _total(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
