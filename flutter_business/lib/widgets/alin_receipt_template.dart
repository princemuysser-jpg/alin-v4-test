import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'business_brand.dart';

num _receiptNum(dynamic value) => num.tryParse('$value') ?? 0;
String _receiptMoney(dynamic value) => '${_receiptNum(value).round()} د.ع';

String _receiptDate(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  final parsed = DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return raw.isEmpty ? '—' : raw;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)} ${two(parsed.hour)}:${two(parsed.minute)}';
}

String _roleLabel(String role) => switch (role.toLowerCase()) {
  'teacher' => 'مدرس',
  'library' => 'مكتبة',
  'courier' || 'delegate' => 'مندوب',
  'printer' => 'مطبعة',
  'admin' => 'إدارة',
  _ => role.trim().isEmpty ? 'جهة مالية' : role,
};

String _paymentMethodLabel(dynamic value) =>
    switch ('${value ?? ''}'.toLowerCase()) {
      'cash' => 'نقدي',
      'transfer' || 'bank_transfer' => 'تحويل',
      'zaincash' => 'زين كاش',
      'qi' || 'qi_card' => 'كي كارد',
      final value when value.trim().isEmpty => '—',
      final value => value,
    };

String _statusLabel(dynamic value) => switch ('${value ?? ''}'.toLowerCase()) {
  'paid' || 'received' || 'settled' || 'completed' || 'delivered' => 'مكتمل',
  'pending' => 'قيد الانتظار',
  'reversed' => 'معكوس',
  'cancelled' || 'canceled' => 'ملغي',
  final value when value.trim().isEmpty => 'مكتمل',
  final value => value,
};

class AlinReceiptMetric {
  final String label;
  final String value;

  const AlinReceiptMetric(this.label, this.value);
}

class AlinReceiptField {
  final String label;
  final String value;

  const AlinReceiptField(this.label, this.value);
}

class AlinReceiptItem {
  final String title;
  final num quantity;
  final num unitPrice;
  final num total;

  const AlinReceiptItem({
    required this.title,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

class AlinReceiptTotal {
  final String label;
  final num value;
  final bool strong;
  final bool highlight;

  const AlinReceiptTotal(
    this.label,
    this.value, {
    this.strong = false,
    this.highlight = false,
  });
}

class AlinReceiptTemplate extends StatelessWidget {
  final String receiptNumber;
  final String documentLabel;
  final String brandSubtitle;
  final List<AlinReceiptMetric> metrics;
  final String infoTitle;
  final List<AlinReceiptField> infoFields;
  final String itemsTitle;
  final List<AlinReceiptItem> items;
  final List<AlinReceiptTotal> totals;
  final String notes;
  final String footerText;

  const AlinReceiptTemplate({
    super.key,
    required this.receiptNumber,
    required this.documentLabel,
    this.brandSubtitle = 'ملازم • قرطاسية • هدايا',
    required this.metrics,
    required this.infoTitle,
    required this.infoFields,
    this.itemsTitle = 'مواد الطلب',
    this.items = const [],
    required this.totals,
    this.notes = '',
    this.footerText = 'شكراً لاستخدام منصة آلين',
  });

  factory AlinReceiptTemplate.order({
    Key? key,
    required Map<String, dynamic> order,
    String? courierName,
    bool courierView = false,
    String viewerRole = '',
  }) {
    final rawItems =
        (order['_items'] as List?)?.cast<Map<String, dynamic>>() ??
        <Map<String, dynamic>>[order];

    num rowDelivery(Map<String, dynamic> row) =>
        _receiptNum(row['delivery_fee'] ?? row['shipping_fee']);
    num rowDiscount(Map<String, dynamic> row) =>
        _receiptNum(row['discount'] ?? row['discount_amount']);
    num rowTotal(Map<String, dynamic> row) =>
        _receiptNum(row['total'] ?? row['total_amount'] ?? row['amount']);
    num rowQty(Map<String, dynamic> row) {
      final value = _receiptNum(row['qty'] ?? row['quantity']);
      return value <= 0 ? 1 : value;
    }

    num rowSubtotal(Map<String, dynamic> row) {
      final explicit = _receiptNum(row['subtotal'] ?? row['items_total']);
      if (explicit > 0) return explicit;
      return (rowTotal(row) + rowDiscount(row) - rowDelivery(row)).clamp(
        0,
        double.infinity,
      );
    }

    num rowUnit(Map<String, dynamic> row) {
      final explicit = _receiptNum(row['unit_price'] ?? row['price']);
      return explicit > 0 ? explicit : rowSubtotal(row) / rowQty(row);
    }

    final items = rawItems
        .map(
          (row) => AlinReceiptItem(
            title:
                '${row['title'] ?? row['product_name'] ?? row['item_name'] ?? 'مادة'}',
            quantity: rowQty(row),
            unitPrice: rowUnit(row),
            total: rowSubtotal(row),
          ),
        )
        .toList();

    final subtotal = rawItems.fold<num>(
      0,
      (sum, row) => sum + rowSubtotal(row),
    );
    final delivery = _receiptNum(order['_delivery_fee']) > 0
        ? _receiptNum(order['_delivery_fee'])
        : rawItems.fold<num>(0, (sum, row) => sum + rowDelivery(row));
    final discount = _receiptNum(order['_discount']) > 0
        ? _receiptNum(order['_discount'])
        : rawItems.fold<num>(0, (sum, row) => sum + rowDiscount(row));
    final total = _receiptNum(order['_group_total']) > 0
        ? _receiptNum(order['_group_total'])
        : rawItems.fold<num>(0, (sum, row) => sum + rowTotal(row));
    final courierFee = _receiptNum(order['_courier_fee']) > 0
        ? _receiptNum(order['_courier_fee'])
        : rawItems.fold<num>(
            0,
            (sum, row) =>
                sum +
                _receiptNum(
                  row['courier_fee'] ??
                      row['courier_profit'] ??
                      row['delegate_profit'],
                ),
          );

    final orderNumber = '${order['order_number'] ?? order['id'] ?? '—'}';
    final explicitReceipt =
        '${order['receipt_number'] ?? order['voucher_number'] ?? ''}'.trim();
    final cleanOrder = orderNumber.replaceFirst(
      RegExp(r'^AL-', caseSensitive: false),
      '',
    );
    final receiptNumber = explicitReceipt.isNotEmpty
        ? explicitReceipt
        : 'RC-$cleanOrder';
    final quantityCount = rawItems
        .fold<num>(0, (sum, row) => sum + rowQty(row))
        .round();
    final deliveryMethod =
        '${order['delivery_method'] ?? order['fulfillment_method'] ?? ''}'
            .toLowerCase();
    final deliveryText =
        deliveryMethod.contains('courier') ||
            deliveryMethod.contains('delegate')
        ? 'توصيل بواسطة المندوب'
        : deliveryMethod.contains('library') ||
              deliveryMethod.contains('pickup')
        ? 'استلام من المكتبة'
        : (courierName ?? '').trim().isNotEmpty
        ? 'توصيل بواسطة المندوب'
        : '—';

    final fields = <AlinReceiptField>[
      AlinReceiptField('اسم الطالب', '${order['student_name'] ?? '—'}'),
      AlinReceiptField('رقم الهاتف', '${order['student_phone'] ?? '—'}'),
      AlinReceiptField('طريقة الاستلام', deliveryText),
      if ('${order['delivery_area'] ?? ''}'.trim().isNotEmpty)
        AlinReceiptField('المنطقة', '${order['delivery_area']}'),
      if ('${order['delivery_landmark'] ?? ''}'.trim().isNotEmpty)
        AlinReceiptField('نقطة دالة', '${order['delivery_landmark']}'),
      if ((courierName ?? '').trim().isNotEmpty)
        AlinReceiptField('المندوب', courierName!.trim()),
    ];

    final totals = <AlinReceiptTotal>[
      AlinReceiptTotal('مجموع المواد', subtotal),
      if (delivery > 0)
        AlinReceiptTotal(
          courierView ? 'توصيل الطالب' : 'أجرة التوصيل',
          delivery,
        ),
      if (discount > 0) AlinReceiptTotal('الخصم', -discount),
      if (courierView && courierFee > 0)
        AlinReceiptTotal('أجرة التوصيل', courierFee),
      AlinReceiptTotal('الإجمالي الكلي', total, strong: true, highlight: true),
    ];

    final role = viewerRole.toLowerCase();
    if (role == 'teacher') {
      final teacherProfit = rawItems.fold<num>(
        0,
        (sum, row) => sum + _receiptNum(row['teacher_profit']),
      );
      if (teacherProfit > 0)
        totals.insert(
          totals.length - 1,
          AlinReceiptTotal('ربح المدرس', teacherProfit),
        );
    }
    if (role == 'library') {
      final libraryProfit = rawItems.fold<num>(
        0,
        (sum, row) => sum + _receiptNum(row['library_profit']),
      );
      if (libraryProfit > 0)
        totals.insert(
          totals.length - 1,
          AlinReceiptTotal('ربح المكتبة', libraryProfit),
        );
    }

    final notes =
        [
              order['notes'],
              order['student_note'],
              order['library_note'],
              order['courier_note'],
            ]
            .map((value) => '${value ?? ''}'.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return AlinReceiptTemplate(
      key: key,
      receiptNumber: receiptNumber,
      documentLabel: 'وصل طلب كامل',
      metrics: [
        AlinReceiptMetric('رقم الطلب', orderNumber),
        AlinReceiptMetric(
          'التاريخ',
          _receiptDate(
            order['completed_at'] ??
                order['delivered_at'] ??
                order['updated_at'] ??
                order['created_at'],
          ),
        ),
        AlinReceiptMetric(
          'عدد المواد',
          '${items.length} مواد • $quantityCount قطعة/نسخة',
        ),
      ],
      infoTitle: 'بيانات الطالب',
      infoFields: fields,
      items: items,
      totals: totals,
      notes: notes,
    );
  }

  factory AlinReceiptTemplate.settlement({
    Key? key,
    required Map<String, dynamic> settlement,
    String? partyName,
    String? partyRole,
  }) {
    final role =
        (partyRole ?? '${settlement['party_role'] ?? settlement['role'] ?? ''}')
            .trim();
    final name =
        (partyName ??
                '${settlement['party_name'] ?? settlement['name'] ?? settlement['teacher_name'] ?? settlement['library_name'] ?? settlement['courier_name'] ?? ''}')
            .trim();
    final receipt =
        '${settlement['receipt_number'] ?? settlement['voucher_number'] ?? settlement['id'] ?? '—'}';
    final amount = _receiptNum(settlement['amount'] ?? settlement['total']);
    final note = '${settlement['note'] ?? settlement['notes'] ?? ''}'.trim();

    return AlinReceiptTemplate(
      key: key,
      receiptNumber: receipt,
      documentLabel: 'وصل تسوية مالية',
      metrics: [
        AlinReceiptMetric('رقم الوصل', receipt),
        AlinReceiptMetric(
          'التاريخ',
          _receiptDate(settlement['created_at'] ?? settlement['updated_at']),
        ),
        const AlinReceiptMetric('النوع', 'تسوية مالية'),
      ],
      infoTitle: 'بيانات التسوية',
      infoFields: [
        AlinReceiptField('الجهة', name.isEmpty ? '—' : name),
        AlinReceiptField('الصفة', _roleLabel(role)),
        AlinReceiptField(
          'طريقة الدفع',
          _paymentMethodLabel(
            settlement['payment_method'] ?? settlement['method'],
          ),
        ),
        AlinReceiptField('الحالة', _statusLabel(settlement['status'])),
      ],
      totals: [
        AlinReceiptTotal('مبلغ التسوية', amount, strong: true, highlight: true),
      ],
      notes: note,
      footerText: 'تم إصدار هذا الوصل من منصة آلين',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BusinessBrand.border),
        boxShadow: [
          BoxShadow(
            color: BusinessBrand.navy.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: BusinessBrand.navy),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AlinBrandMark(size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'منصة آلين',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        brandSubtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: BusinessBrand.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      documentLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: BusinessBrand.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        receiptNumber,
                        textAlign: TextAlign.left,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: BusinessBrand.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: BusinessBrand.orange.withValues(alpha: .85),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _metricGrid(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                infoTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: BusinessBrand.ink,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _infoGrid(),
          ),
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  itemsTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: BusinessBrand.ink,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _itemsTable(),
            ),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(14, items.isEmpty ? 18 : 12, 14, 0),
            child: _totalsBox(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: BusinessBrand.border),
                borderRadius: BorderRadius.circular(9),
                color: const Color(0xFFFCFDFE),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملاحظات',
                    style: TextStyle(fontSize: 11, color: BusinessBrand.muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notes.trim().isEmpty ? 'لا توجد ملاحظات' : notes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BusinessBrand.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            color: BusinessBrand.navy,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                const Text(
                  'منصة آلين',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    footerText,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560
            ? math.min(3, metrics.length)
            : 1;
        final gap = 8.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 78),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: BusinessBrand.border),
                      borderRadius: BorderRadius.circular(9),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.label,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: BusinessBrand.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          metric.value,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: BusinessBrand.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _infoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        final gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: infoFields
              .map(
                (field) => SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: BusinessBrand.border),
                      borderRadius: BorderRadius.circular(9),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.label,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: BusinessBrand.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          field.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: BusinessBrand.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _itemsTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(610.0, constraints.maxWidth);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: BusinessBrand.border),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFFEFF5FA),
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 8,
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              '#',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              'الصنف',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'سعر الوحدة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'الإجمالي',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...items.asMap().entries.map((entry) {
                      final item = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 8,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: BusinessBrand.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.quantity.round()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _receiptMoney(item.unitPrice),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _receiptMoney(item.total),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _totalsBox() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: BusinessBrand.border),
        borderRadius: BorderRadius.circular(9),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: totals.asMap().entries.map((entry) {
          final row = entry.value;
          return Container(
            color: row.highlight ? const Color(0xFFFFF5DE) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              border: entry.key == 0
                  ? null
                  : const Border(top: BorderSide(color: BusinessBrand.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: TextStyle(
                      fontSize: row.strong ? 13 : 11.5,
                      fontWeight: row.strong
                          ? FontWeight.w900
                          : FontWeight.w600,
                      color: BusinessBrand.ink,
                    ),
                  ),
                ),
                Text(
                  _receiptMoney(row.value),
                  style: TextStyle(
                    fontSize: row.strong ? 14 : 12,
                    fontWeight: row.strong ? FontWeight.w900 : FontWeight.w800,
                    color: row.strong ? BusinessBrand.navy : BusinessBrand.ink,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

Future<void> showAlinOrderReceipt(
  BuildContext context,
  Map<String, dynamic> order, {
  String? courierName,
  bool courierView = false,
  String viewerRole = '',
}) {
  return _showReceiptDialog(
    context,
    AlinReceiptTemplate.order(
      order: order,
      courierName: courierName,
      courierView: courierView,
      viewerRole: viewerRole,
    ),
  );
}

Future<void> showAlinSettlementReceipt(
  BuildContext context,
  Map<String, dynamic> settlement, {
  String? partyName,
  String? partyRole,
}) {
  return _showReceiptDialog(
    context,
    AlinReceiptTemplate.settlement(
      settlement: settlement,
      partyName: partyName,
      partyRole: partyRole,
    ),
  );
}

Future<void> _showReceiptDialog(BuildContext context, Widget receipt) async {
  final width = MediaQuery.sizeOf(context).width;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: width < 700 ? 10 : 28,
        vertical: 18,
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 900),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: receipt,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
                label: const Text('إغلاق الوصل'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
