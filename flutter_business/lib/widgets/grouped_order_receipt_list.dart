import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'business_brand.dart';
import 'grouped_order_receipt_card.dart';

class GroupedOrderReceiptListTile extends StatefulWidget {
  final Map<String, dynamic> order;
  final String? courierName;
  final bool courierView;

  const GroupedOrderReceiptListTile({
    super.key,
    required this.order,
    this.courierName,
    this.courierView = false,
  });

  @override
  State<GroupedOrderReceiptListTile> createState() => _GroupedOrderReceiptListTileState();
}

class _GroupedOrderReceiptListTileState extends State<GroupedOrderReceiptListTile> {
  bool printing = false;

  num _n(dynamic value) => receiptNumberValue(value);
  String _money(dynamic value) => '${_n(value).round()} د.ع';

  List<Map<String, dynamic>> get _items =>
      (widget.order['_items'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[widget.order];

  num _rowDelivery(Map<String, dynamic> row) => _n(row['delivery_fee'] ?? row['shipping_fee']);
  num _rowDiscount(Map<String, dynamic> row) => _n(row['discount'] ?? row['discount_amount']);
  num _rowTotal(Map<String, dynamic> row) => _n(row['total'] ?? row['total_amount'] ?? row['amount']);
  num _rowQty(Map<String, dynamic> row) {
    final value = _n(row['qty'] ?? row['quantity']);
    return value <= 0 ? 1 : value;
  }

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
    final raw = '${widget.order['completed_at'] ?? widget.order['delivered_at'] ?? widget.order['updated_at'] ?? widget.order['created_at'] ?? ''}';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return '—';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${parsed.year}/${two(parsed.month)}/${two(parsed.day)} • ${two(parsed.hour)}:${two(parsed.minute)}';
  }

  num get _total {
    final grouped = _n(widget.order['_group_total']);
    if (grouped > 0) return grouped;
    return _items.fold<num>(0, (sum, row) => sum + _rowTotal(row));
  }

  Future<void> _showReceipt() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final width = MediaQuery.sizeOf(dialogContext).width;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: width < 600 ? 12 : 28, vertical: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      const AlinBrandMark(size: 38),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('وصل منصة آلين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: BusinessBrand.navy)),
                            Text('تفاصيل الطلب الكامل', style: TextStyle(color: BusinessBrand.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(dialogContext), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: GroupedOrderReceiptCard(
                      order: widget.order,
                      courierName: widget.courierName,
                      courierView: widget.courierView,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: printing ? null : _printReceipt,
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('طباعة الوصل'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _printReceipt() async {
    if (printing) return;
    setState(() => printing = true);
    try {
      await Printing.layoutPdf(
        onLayout: (format) => _buildPdf(format),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر طباعة الوصل: ${'$e'.replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final regular = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final items = _items;
    final delivery = _n(widget.order['_delivery_fee']) > 0
        ? _n(widget.order['_delivery_fee'])
        : items.fold<num>(0, (sum, row) => sum + _rowDelivery(row));
    final discount = _n(widget.order['_discount']) > 0
        ? _n(widget.order['_discount'])
        : items.fold<num>(0, (sum, row) => sum + _rowDiscount(row));
    final subtotal = items.fold<num>(0, (sum, row) => sum + _rowSubtotal(row));
    final courierFee = _n(widget.order['_courier_fee']) > 0
        ? _n(widget.order['_courier_fee'])
        : items.fold<num>(0, (sum, row) => sum + _n(row['courier_fee'] ?? row['courier_profit'] ?? row['delegate_profit']));

    pw.Widget info(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(width: 90, child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 10))),
              pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: regular, fontSize: 10))),
            ],
          ),
        );

    pw.Widget totalRow(String label, num value, {bool strong = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            children: [
              pw.Expanded(child: pw.Text(label, style: pw.TextStyle(font: strong ? bold : regular, fontSize: strong ? 12 : 10))),
              pw.Text(_money(value), style: pw.TextStyle(font: strong ? bold : regular, fontSize: strong ? 13 : 10)),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#143B68'),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 38,
                        height: 38,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(9),
                        ),
                        child: pw.Text('A', style: pw.TextStyle(font: bold, fontSize: 22, color: PdfColor.fromHex('#143B68'))),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('منصة آلين للأعمال', style: pw.TextStyle(font: bold, fontSize: 17, color: PdfColors.white)),
                            pw.Text('وصل توصيل الطلب', style: pw.TextStyle(font: regular, fontSize: 10, color: PdfColors.white)),
                          ],
                        ),
                      ),
                      pw.Text(_dateText(), style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.white)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text('رقم الطلب: ${widget.order['order_number'] ?? widget.order['id'] ?? '—'}', style: pw.TextStyle(font: bold, fontSize: 12)),
                pw.SizedBox(height: 6),
                info('الطالب', '${widget.order['student_name'] ?? '—'}'),
                info('الهاتف', '${widget.order['student_phone'] ?? '—'}'),
                if ('${widget.order['delivery_area'] ?? ''}'.trim().isNotEmpty) info('المنطقة', '${widget.order['delivery_area']}'),
                if ('${widget.order['delivery_landmark'] ?? ''}'.trim().isNotEmpty) info('نقطة دالة', '${widget.order['delivery_landmark']}'),
                if ((widget.courierName ?? '').trim().isNotEmpty) info('المندوب', widget.courierName!.trim()),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: PdfColor.fromHex('#F0F6FC'),
                  child: pw.Text('مواد الطلب • ${items.length}', style: pw.TextStyle(font: bold, fontSize: 12, color: PdfColor.fromHex('#143B68'))),
                ),
                ...items.asMap().entries.map((entry) {
                  final row = entry.value;
                  return pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(width: 24, child: pw.Text('${entry.key + 1}.', style: pw.TextStyle(font: bold, fontSize: 10))),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('${row['title'] ?? row['product_name'] ?? row['item_name'] ?? 'مادة'}', style: pw.TextStyle(font: bold, fontSize: 10)),
                              pw.Text('${_rowQty(row).round()} × ${_money(_rowUnit(row))}', style: pw.TextStyle(font: regular, fontSize: 9, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Text(_money(_rowSubtotal(row)), style: pw.TextStyle(font: bold, fontSize: 10)),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 10),
                totalRow('مجموع المواد', subtotal),
                if (delivery > 0) totalRow('أجرة التوصيل على الطالب', delivery),
                if (discount > 0) totalRow('الخصم', discount),
                if (widget.courierView) totalRow('أجرة المندوب', courierFee),
                pw.Divider(),
                totalRow('الإجمالي الكلي', _total, strong: true),
                pw.SizedBox(height: 18),
                pw.Center(
                  child: pw.Text('شكراً لاستخدام منصة آلين', style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColor.fromHex('#143B68'))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showReceipt,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: BusinessBrand.softTeal,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: BusinessBrand.teal, size: 27),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.order['order_number'] ?? widget.order['id'] ?? 'وصل طلب'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${items.length} مواد • ${widget.order['student_name'] ?? 'طالب'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: BusinessBrand.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 3),
                        Text(_dateText(), style: const TextStyle(color: BusinessBrand.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(_total), style: const TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy)),
                      if (widget.courierView)
                        Text('أجرتك ${_money(widget.order['_courier_fee'])}', style: const TextStyle(color: BusinessBrand.teal, fontSize: 11, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showReceipt,
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                      label: const Text('عرض الوصل'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: printing ? null : _printReceipt,
                      icon: printing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.print_rounded, size: 19),
                      label: Text(printing ? 'جاري...' : 'طباعة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
