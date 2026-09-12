from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')
    print(f'WROTE {path}')


def replace_once(path: str, old: str, new: str) -> None:
    target = ROOT / path
    text = target.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'PATCH FAILED: marker not found in {path}: {old[:100]!r}')
    target.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'PATCHED {path}')


brand = r'''import 'package:flutter/material.dart';

class BusinessBrand {
  static const navy = Color(0xFF143B68);
  static const navy2 = Color(0xFF255B91);
  static const teal = Color(0xFF19B8A8);
  static const orange = Color(0xFFFF9F43);
  static const ink = Color(0xFF172B4D);
  static const muted = Color(0xFF667085);
  static const background = Color(0xFFF4F7FB);
  static const softBlue = Color(0xFFF0F6FC);
  static const softTeal = Color(0xFFE9F9F6);
  static const border = Color(0xFFE3EAF2);

  static const heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy, navy2],
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: navy,
      secondary: teal,
      tertiary: orange,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: navy, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: softBlue,
        selectedColor: softTeal,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: softTeal,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: teal,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class AlinBrandMark extends StatelessWidget {
  final double size;
  final bool light;

  const AlinBrandMark({super.key, this.size = 46, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: light
            ? const LinearGradient(colors: [Colors.white, Color(0xFFEAF3FC)])
            : BusinessBrand.heroGradient,
        borderRadius: BorderRadius.circular(size * .30),
        boxShadow: [
          BoxShadow(
            color: BusinessBrand.navy.withValues(alpha: .16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: Icon(
              Icons.auto_awesome_mosaic_rounded,
              size: size * .52,
              color: light ? BusinessBrand.navy : Colors.white,
            ),
          ),
          Positioned(
            right: size * .10,
            bottom: size * .10,
            child: Container(
              width: size * .20,
              height: size * .20,
              decoration: const BoxDecoration(color: BusinessBrand.orange, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: size * .10,
            top: size * .12,
            child: Container(
              width: size * .18,
              height: size * .07,
              decoration: BoxDecoration(
                color: BusinessBrand.teal,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'''

receipt_list = r'''import 'dart:typed_data';

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
'''

write('flutter_business/lib/widgets/business_brand.dart', brand)
write('flutter_business/lib/widgets/grouped_order_receipt_list.dart', receipt_list)

# pubspec: printing already exists; add the direct pdf dependency used by the receipt printer.
pubspec = ROOT / 'flutter_business/pubspec.yaml'
pub = pubspec.read_text(encoding='utf-8')
if '  pdf:' not in pub:
    if '  printing: ^5.14.3\n' not in pub:
        raise SystemExit('PATCH FAILED: printing dependency marker missing')
    pub = pub.replace('  printing: ^5.14.3\n', '  printing: ^5.14.3\n  pdf: ^3.11.3\n', 1)
pubspec.write_text(pub, encoding='utf-8')
print('PATCHED flutter_business/pubspec.yaml')

# Global visual identity.
replace_once(
    'flutter_business/lib/main.dart',
    "import 'widgets/admin_quick_actions_button.dart';\nimport 'widgets/business_notification_bell.dart';",
    "import 'widgets/admin_quick_actions_button.dart';\nimport 'widgets/business_brand.dart';\nimport 'widgets/business_notification_bell.dart';",
)
replace_once(
    'flutter_business/lib/main.dart',
    "  @override\n  Widget build(BuildContext context) {\n    const navy = Color(0xFF143B68);\n    return MaterialApp(",
    "  @override\n  Widget build(BuildContext context) {\n    return MaterialApp(",
)
old_theme = '''      theme: ThemeData(\n        useMaterial3: true,\n        colorScheme: ColorScheme.fromSeed(seedColor: navy),\n        scaffoldBackgroundColor: const Color(0xFFF5F8FC),\n        appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white, elevation: 0),\n        inputDecorationTheme: InputDecorationTheme(\n          filled: true,\n          fillColor: Colors.white,\n          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),\n        ),\n        cardTheme: CardThemeData(\n          elevation: 0,\n          color: Colors.white,\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),\n        ),\n      ),'''
replace_once('flutter_business/lib/main.dart', old_theme, '      theme: BusinessBrand.theme(),')
replace_once(
    'flutter_business/lib/main.dart',
    "            color: const Color(0xFF143B68),",
    "            color: BusinessBrand.navy,",
)
old_login_mark = '''                Container(\n                  width: 94,\n                  height: 94,\n                  decoration: BoxDecoration(color: const Color(0xFF143B68), borderRadius: BorderRadius.circular(28)),\n                  child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 50),\n                ),'''
replace_once('flutter_business/lib/main.dart', old_login_mark, "                const AlinBrandMark(size: 94),")
replace_once(
    'flutter_business/lib/main.dart',
    "Text(BusinessConfig.appName, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Color(0xFF143B68))),",
    "Text(BusinessConfig.appName, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: BusinessBrand.navy)),",
)

# Courier web + mobile: brand, responsive boxes, compact receipt list with printing.
replace_once(
    'flutter_business/lib/screens/courier_dashboard_screen.dart',
    "import '../widgets/grouped_order_receipt_card.dart';",
    "import '../widgets/business_brand.dart';\nimport '../widgets/grouped_order_receipt_card.dart';\nimport '../widgets/grouped_order_receipt_list.dart';",
)
replace_once(
    'flutter_business/lib/screens/courier_dashboard_screen.dart',
    "        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n          const Text('لوحة المندوب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),\n          Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),\n        ]),",
    "        title: Row(children: [\n          const AlinBrandMark(size: 36, light: true),\n          const SizedBox(width: 10),\n          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n            const Text('آلين للمندوب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),\n            Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),\n          ])),\n        ]),",
)
replace_once(
    'flutter_business/lib/screens/courier_dashboard_screen.dart',
    "          padding: const EdgeInsets.all(16),",
    "          padding: EdgeInsets.symmetric(\n            horizontal: MediaQuery.sizeOf(context).width > 1180\n                ? (MediaQuery.sizeOf(context).width - 1120) / 2\n                : 16,\n            vertical: 16,\n          ),",
)
old_hero = '''            Container(\n              padding: const EdgeInsets.all(18),\n              decoration: BoxDecoration(\n                gradient: const LinearGradient(colors: [Color(0xFF143B68), Color(0xFF255B91)]),\n                borderRadius: BorderRadius.circular(22),\n              ),\n              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),\n                if (courierArea.isNotEmpty || courierAreas.isNotEmpty) ...[\n                  const SizedBox(height: 5),\n                  Text('مناطقك: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}', style: const TextStyle(color: Colors.white70)),\n                ],\n                const SizedBox(height: 10),\n                Wrap(spacing: 8, runSpacing: 8, children: [\n                  ChoiceChip(label: const Text('متاح'), selected: availability == 'available', onSelected: (_) => setAvailability('available')),\n                  ChoiceChip(label: const Text('مشغول'), selected: availability == 'busy', onSelected: (_) => setAvailability('busy')),\n                  ChoiceChip(label: const Text('خارج الخدمة'), selected: availability == 'offline', onSelected: (_) => setAvailability('offline')),\n                ]),\n              ]),\n            ),'''
new_hero = '''            Container(\n              clipBehavior: Clip.antiAlias,\n              decoration: BoxDecoration(\n                gradient: BusinessBrand.heroGradient,\n                borderRadius: BorderRadius.circular(26),\n                boxShadow: [BoxShadow(color: BusinessBrand.navy.withValues(alpha: .16), blurRadius: 24, offset: const Offset(0, 10))],\n              ),\n              child: Stack(children: [\n                Positioned(left: -26, top: -34, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .06)))),\n                Positioned(right: -18, bottom: -45, child: Container(width: 145, height: 145, decoration: BoxDecoration(shape: BoxShape.circle, color: BusinessBrand.teal.withValues(alpha: .18)))),\n                Padding(\n                  padding: const EdgeInsets.all(20),\n                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                    Container(\n                      width: 54,\n                      height: 54,\n                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(17)),\n                      child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 31),\n                    ),\n                    const SizedBox(width: 13),\n                    Expanded(\n                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                        Text('مرحباً ${widget.account.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21)),\n                        const SizedBox(height: 3),\n                        const Text('طلباتك وتوصيلاتك ووصولاتك بمكان واحد', style: TextStyle(color: Colors.white70, fontSize: 12)),\n                        if (courierArea.isNotEmpty || courierAreas.isNotEmpty) ...[\n                          const SizedBox(height: 6),\n                          Text('مناطقك: ${[courierArea, ...courierAreas].where((e) => e.isNotEmpty).toSet().join('، ')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),\n                        ],\n                        const SizedBox(height: 11),\n                        Wrap(spacing: 8, runSpacing: 8, children: [\n                          ChoiceChip(label: const Text('متاح'), selected: availability == 'available', onSelected: (_) => setAvailability('available')),\n                          ChoiceChip(label: const Text('مشغول'), selected: availability == 'busy', onSelected: (_) => setAvailability('busy')),\n                          ChoiceChip(label: const Text('خارج الخدمة'), selected: availability == 'offline', onSelected: (_) => setAvailability('offline')),\n                        ]),\n                      ]),\n                    ),\n                  ]),\n                ),\n              ]),\n            ),'''
replace_once('flutter_business/lib/screens/courier_dashboard_screen.dart', old_hero, new_hero)
old_metrics = '''            Row(children: [\n              Expanded(child: _Metric(label: 'قيد التنفيذ', value: '$active', icon: Icons.delivery_dining_rounded)),\n              const SizedBox(width: 8),\n              Expanded(child: _Metric(label: 'مكتملة', value: '$completed', icon: Icons.check_circle_rounded)),\n              const SizedBox(width: 8),\n              Expanded(child: _Metric(label: 'أجور التوصيل', value: money(profit), icon: Icons.payments_rounded)),\n            ]),'''
new_metrics = '''            LayoutBuilder(builder: (context, constraints) {\n              final columns = constraints.maxWidth >= 900 ? 4 : 2;\n              final gap = 10.0;\n              final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;\n              return Wrap(spacing: gap, runSpacing: gap, children: [\n                SizedBox(width: width, child: _Metric(label: 'قيد التنفيذ', value: '$active', icon: Icons.delivery_dining_rounded, accent: BusinessBrand.orange)),\n                SizedBox(width: width, child: _Metric(label: 'مكتملة', value: '$completed', icon: Icons.task_alt_rounded, accent: BusinessBrand.teal)),\n                SizedBox(width: width, child: _Metric(label: 'كل الطلبات', value: '${grouped.length}', icon: Icons.inventory_2_rounded, accent: BusinessBrand.navy2)),\n                SizedBox(width: width, child: _Metric(label: 'أجور التوصيل', value: money(profit), icon: Icons.account_balance_wallet_rounded, accent: BusinessBrand.navy)),\n              ]);\n            }),'''
replace_once('flutter_business/lib/screens/courier_dashboard_screen.dart', old_metrics, new_metrics)
old_segments = '''            SegmentedButton<String>(\n              segments: const [\n                ButtonSegment(value: 'active', label: Text('الحالية'), icon: Icon(Icons.local_shipping_rounded)),\n                ButtonSegment(value: 'completed', label: Text('المكتملة'), icon: Icon(Icons.check_circle_outline)),\n                ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),\n                ButtonSegment(value: 'receipts', label: Text('الوصولات'), icon: Icon(Icons.receipt_long_rounded)),\n              ],\n              selected: {filter},\n              onSelectionChanged: (value) => setState(() => filter = value.first),\n            ),'''
new_segments = '''            SingleChildScrollView(\n              scrollDirection: Axis.horizontal,\n              child: SegmentedButton<String>(\n                segments: const [\n                  ButtonSegment(value: 'active', label: Text('الحالية'), icon: Icon(Icons.local_shipping_rounded)),\n                  ButtonSegment(value: 'completed', label: Text('المكتملة'), icon: Icon(Icons.check_circle_outline)),\n                  ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),\n                  ButtonSegment(value: 'receipts', label: Text('الوصولات'), icon: Icon(Icons.receipt_long_rounded)),\n                ],\n                selected: {filter},\n                onSelectionChanged: (value) => setState(() => filter = value.first),\n              ),\n            ),'''
replace_once('flutter_business/lib/screens/courier_dashboard_screen.dart', old_segments, new_segments)
replace_once(
    'flutter_business/lib/screens/courier_dashboard_screen.dart',
    "              const Text('وصولات الطلبات المكتملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),",
    "              const Row(children: [Icon(Icons.receipt_long_rounded, color: BusinessBrand.navy), SizedBox(width: 8), Text('وصولات الطلبات المكتملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BusinessBrand.navy))]),",
)
replace_once(
    'flutter_business/lib/screens/courier_dashboard_screen.dart',
    "                ...grouped.where(isDone).map((order) => GroupedOrderReceiptCard(order: order, courierName: widget.account.name, courierView: true)),",
    "                ...grouped.where(isDone).map((order) => GroupedOrderReceiptListTile(order: order, courierName: widget.account.name, courierView: true)),",
)
old_metric_class = '''class _Metric extends StatelessWidget {\n  final String label;\n  final String value;\n  final IconData icon;\n  const _Metric({required this.label, required this.value, required this.icon});\n\n  @override\n  Widget build(BuildContext context) {\n    return Container(\n      padding: const EdgeInsets.all(12),\n      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),\n      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n        Icon(icon, color: const Color(0xFF143B68)),\n        const SizedBox(height: 8),\n        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),\n        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),\n      ]),\n    );\n  }\n}'''
new_metric_class = '''class _Metric extends StatelessWidget {\n  final String label;\n  final String value;\n  final IconData icon;\n  final Color accent;\n  const _Metric({required this.label, required this.value, required this.icon, required this.accent});\n\n  @override\n  Widget build(BuildContext context) {\n    return Container(\n      constraints: const BoxConstraints(minHeight: 116),\n      decoration: BoxDecoration(\n        color: Colors.white,\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: BusinessBrand.border),\n        boxShadow: [BoxShadow(color: BusinessBrand.navy.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 7))],\n      ),\n      child: Stack(\n        clipBehavior: Clip.antiAlias,\n        children: [\n          Positioned(left: -20, top: -25, child: Container(width: 74, height: 74, decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: .08)))),\n          Padding(\n            padding: const EdgeInsets.all(13),\n            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n              Container(\n                width: 39,\n                height: 39,\n                decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),\n                child: Icon(icon, color: accent, size: 23),\n              ),\n              const SizedBox(height: 9),\n              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: BusinessBrand.ink)),\n              const SizedBox(height: 2),\n              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BusinessBrand.muted, fontSize: 11, fontWeight: FontWeight.w700)),\n            ]),\n          ),\n        ],\n      ),\n    );\n  }\n}'''
replace_once('flutter_business/lib/screens/courier_dashboard_screen.dart', old_metric_class, new_metric_class)

print('ALIN Business courier UI/receipts visual refresh patch completed.')
