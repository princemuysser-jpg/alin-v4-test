import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/alin_theme.dart';

/// An order acknowledgement exists from successful checkout; it is never a
/// settlement receipt or proof that money was collected or goods delivered.
String orderReceiptStatus(dynamic value) {
  final status = '${value ?? 'new'}'.toLowerCase();
  if (const {'completed', 'delivered', 'done', 'settled'}.contains(status)) {
    return 'مكتمل';
  }
  if (const {'cancelled', 'canceled', 'rejected'}.contains(status)) {
    return 'ملغي';
  }
  if (const {'ready'}.contains(status)) return 'جاهز للاستلام';
  if (const {'out_for_delivery', 'picked_up'}.contains(status)) return 'قيد التوصيل';
  if (const {'printing', 'processing'}.contains(status)) return 'قيد التجهيز';
  return 'تم استلام الطلب';
}

num _receiptNum(dynamic value) => num.tryParse('${value ?? 0}') ?? 0;
String _money(dynamic value) => '${_receiptNum(value).round()} د.ع';
String _receiptDate(dynamic value) {
  final parsed = DateTime.tryParse('${value ?? ''}')?.toLocal();
  if (parsed == null) return '—';
  String p(int value) => value.toString().padLeft(2, '0');
  return '${parsed.year}/${p(parsed.month)}/${p(parsed.day)} ${p(parsed.hour)}:${p(parsed.minute)}';
}

List<Map<String, dynamic>> _items(Map<String, dynamic> receipt) {
  final raw = receipt['items'];
  if (raw is List && raw.isNotEmpty) {
    return raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
  }
  final name = '${receipt['item_name'] ?? receipt['title'] ?? ''}'.trim();
  return name.isEmpty ? [] : [
    {'title': name, 'qty': 1, 'total': receipt['total'] ?? 0},
  ];
}

String _receiptText(Map<String, dynamic> receipt) {
  final number = '${receipt['order_number'] ?? '—'}';
  final rows = _items(receipt);
  return [
    'منصة آلين — وصل تأكيد الطلب',
    'رقم الطلب: $number',
    'التاريخ: ${_receiptDate(receipt['created_at'])}',
    'الحالة: ${orderReceiptStatus(receipt['status'])}',
    'الطالب: ${receipt['student_name'] ?? '—'}',
    for (final row in rows)
      '${row['title'] ?? 'مادة'} × ${row['qty'] ?? 1} — ${_money(row['total'])}',
    'الإجمالي: ${_money(receipt['total'])}',
    'وصل تأكيد طلب، وليس إثبات دفع أو تسليم.',
  ].join('\n');
}

Future<void> showStudentOrderReceipt(
  BuildContext context,
  Map<String, dynamic> receipt,
) async {
  final number = '${receipt['order_number'] ?? '—'}';
  final rows = _items(receipt);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 25),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 690),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AlinTheme.navy),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('وصل تأكيد الطلب',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('منصة آلين', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AlinTheme.navy)),
                    const SizedBox(height: 8),
                    SelectableText(number, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 15),
                    _info('تاريخ الطلب', _receiptDate(receipt['created_at'])),
                    _info('حالة الطلب', orderReceiptStatus(receipt['status'])),
                    _info('حالة الدفع', '${receipt['payment_status'] ?? ''}'.toLowerCase() == 'paid'
                        ? 'مدفوع' : 'غير مؤكد الدفع'),
                    if ('${receipt['student_name'] ?? ''}'.trim().isNotEmpty)
                      _info('اسم الطالب', '${receipt['student_name']}'),
                    _info('طريقة الاستلام',
                        '${receipt['fulfillment_type'] ?? ''}' == 'home_delivery'
                        ? 'توصيل مندوب' : 'استلام من مكتبة'),
                    const Divider(height: 24),
                    const Text('المواد', style: TextStyle(fontWeight: FontWeight.w900)),
                    for (final item in rows)
                      _info('${item['title'] ?? 'مادة'} × ${item['qty'] ?? 1}',
                          _money(item['total'])),
                    const Divider(height: 24),
                    if (_receiptNum(receipt['discount']) > 0)
                      _info('الخصم', '- ${_money(receipt['discount'])}'),
                    if (_receiptNum(receipt['delivery_fee']) > 0)
                      _info('أجرة التوصيل', _money(receipt['delivery_fee'])),
                    _info('المبلغ الإجمالي', _money(receipt['total']), strong: true),
                    const SizedBox(height: 14),
                    const Text('هذا الوصل يؤكد تسجيل الطلب فقط، ولا يُعد إثباتاً للدفع أو التسليم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _receiptText(receipt)));
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('تم نسخ تفاصيل الوصل')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('نسخ تفاصيل الوصل'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _info(String label, String value, {bool strong = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label, style: TextStyle(
        fontWeight: strong ? FontWeight.w900 : FontWeight.w600))),
      const SizedBox(width: 9),
      Flexible(child: Text(value, textAlign: TextAlign.end,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: strong ? AlinTheme.navy : null))),
    ],
  ),
);
