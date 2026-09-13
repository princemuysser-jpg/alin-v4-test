from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding='utf-8')
    print(f'PATCHED {path}')


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'PATCH FAILED: marker not found for {label}')
    return text.replace(old, new, 1)


# 1) Receipt detail card: keep the business value, but use one public label only.
card_path = 'flutter_business/lib/widgets/grouped_order_receipt_card.dart'
card = read(card_path)
card = card.replace("if (courierView) _total('أجرة المندوب', _money(courierFee)),", "if (courierView) _total('أجرة التوصيل', _money(courierFee)),")
write(card_path, card)


# 2) Receipt list + PDF: desktop rows mirror the old web receipts center.
list_path = 'flutter_business/lib/widgets/grouped_order_receipt_list.dart'
receipt_list = read(list_path)
receipt_list = receipt_list.replace("if (widget.courierView) totalRow('أجرة المندوب', courierFee),", "if (widget.courierView) totalRow('أجرة التوصيل', courierFee),")
receipt_list = receipt_list.replace("Text('أجرتك ${_money(widget.order['_courier_fee'])}'", "Text('أجرة التوصيل ${_money(widget.order['_courier_fee'])}'")

build_marker = "  @override\n  Widget build(BuildContext context) {"
idx = receipt_list.rfind(build_marker)
if idx < 0:
    raise SystemExit('PATCH FAILED: receipt list build marker not found')

prefix = receipt_list[:idx]
new_build = r'''  String _receiptNumber() {
    final explicit = '${widget.order['receipt_number'] ?? widget.order['voucher_number'] ?? ''}'.trim();
    if (explicit.isNotEmpty) return explicit;
    final orderNumber = '${widget.order['order_number'] ?? widget.order['id'] ?? ''}'.replaceFirst(RegExp(r'^AL-', caseSensitive: false), '');
    return 'RC-$orderNumber';
  }

  Widget _desktopRow() {
    final items = _items;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showReceipt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 178,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_receiptNumber(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: BusinessBrand.navy)),
                    const SizedBox(height: 3),
                    Text('${widget.order['order_number'] ?? widget.order['id'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BusinessBrand.muted, fontSize: 12)),
                  ],
                ),
              ),
              SizedBox(
                width: 150,
                child: Text('وصل طلب • ${items.length} مواد', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: BusinessBrand.ink)),
              ),
              Expanded(child: Text(_dateText(), style: const TextStyle(color: BusinessBrand.muted, fontSize: 12))),
              SizedBox(width: 118, child: Text(_money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: BusinessBrand.navy))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: BusinessBrand.softTeal, borderRadius: BorderRadius.circular(99)),
                child: const Text('مكتمل', style: TextStyle(color: BusinessBrand.teal, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 250,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showReceipt,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('معاينة'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: printing ? null : _printReceipt,
                        icon: printing
                            ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print_rounded, size: 18),
                        label: Text(printing ? 'جاري...' : 'طباعة / PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileCard() {
    final items = _items;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showReceipt,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: BusinessBrand.softTeal, borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.receipt_long_rounded, color: BusinessBrand.teal, size: 28),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_receiptNumber(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: BusinessBrand.navy)),
                        const SizedBox(height: 3),
                        Text('${widget.order['order_number'] ?? widget.order['id'] ?? '—'} • ${items.length} مواد', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: BusinessBrand.ink, fontSize: 13)),
                        const SizedBox(height: 3),
                        Text('${widget.order['student_name'] ?? 'طالب'} • ${_dateText()}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BusinessBrand.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_money(_total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: BusinessBrand.navy)),
                      if (widget.courierView)
                        Text('أجرة التوصيل ${_money(widget.order['_courier_fee'])}', style: const TextStyle(color: BusinessBrand.teal, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _showReceipt, icon: const Icon(Icons.visibility_outlined, size: 19), label: const Text('معاينة'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: printing ? null : _printReceipt,
                      icon: printing
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.print_rounded, size: 19),
                      label: Text(printing ? 'جاري...' : 'طباعة / PDF'),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 980 ? _desktopRow() : _mobileCard(),
    );
  }
}
'''
receipt_list = prefix + new_build
write(list_path, receipt_list)


# 3) Courier dashboard: clearer typography, stronger work metrics, web-like receipts center.
dashboard_path = 'flutter_business/lib/screens/courier_dashboard_screen.dart'
dashboard = read(dashboard_path)

dashboard = replace_required(
    dashboard,
    "  String filter = 'active';\n",
    "  String filter = 'active';\n  String receiptSearch = '';\n",
    'receipt search state',
)

dashboard = dashboard.replace("const Text('آلين للمندوب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))", "const Text('آلين للمندوب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20))")
dashboard = dashboard.replace("Text(widget.account.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400))", "Text(widget.account.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))")
dashboard = dashboard.replace("fontSize: 21)),", "fontSize: 25)),", 1)
dashboard = dashboard.replace("const Text('طلباتك وتوصيلاتك ووصولاتك بمكان واحد', style: TextStyle(color: Colors.white70, fontSize: 12))", "const Text('طلباتك وتوصيلاتك ووصولاتك بمكان واحد', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600))")
dashboard = dashboard.replace("fontWeight: FontWeight.w700, fontSize: 12))", "fontWeight: FontWeight.w800, fontSize: 13))", 1)
dashboard = dashboard.replace("_line(Icons.account_balance_wallet_outlined, 'أجرة المندوب', money(order['_courier_fee']))", "_line(Icons.account_balance_wallet_outlined, 'أجرة التوصيل', money(order['_courier_fee']))")

dashboard = dashboard.replace("constraints: const BoxConstraints(minHeight: 116)", "constraints: const BoxConstraints(minHeight: 128)")
dashboard = dashboard.replace("width: 39,\n                height: 39,", "width: 44,\n                height: 44,")
dashboard = dashboard.replace("child: Icon(icon, color: accent, size: 23)", "child: Icon(icon, color: accent, size: 26)")
dashboard = dashboard.replace("fontWeight: FontWeight.w900, fontSize: 17, color: BusinessBrand.ink", "fontWeight: FontWeight.w900, fontSize: 22, color: BusinessBrand.ink")
dashboard = dashboard.replace("color: BusinessBrand.muted, fontSize: 11, fontWeight: FontWeight.w700", "color: BusinessBrand.muted, fontSize: 13, fontWeight: FontWeight.w800")

dashboard = dashboard.replace("Text('${order['order_number'] ?? id}', style: const TextStyle(fontWeight: FontWeight.w900))", "Text('${order['order_number'] ?? id}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: BusinessBrand.navy))")
dashboard = dashboard.replace("style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))", "style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))", 1)
dashboard = dashboard.replace("SizedBox(width: 95, child: Text(label, style: TextStyle(color: Colors.grey.shade600)))", "SizedBox(width: 105, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w700)))")
dashboard = dashboard.replace("Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)))", "Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))")

old_receipts_block = """            else if (filter == 'receipts') ...[\n              const Row(children: [Icon(Icons.receipt_long_rounded, color: BusinessBrand.navy), SizedBox(width: 8), Text('وصولات الطلبات المكتملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BusinessBrand.navy))]),\n              const SizedBox(height: 10),\n              if (grouped.where(isDone).isEmpty)\n                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد وصولات مكتملة بعد'))))\n              else\n                ...grouped.where(isDone).map((order) => GroupedOrderReceiptListTile(order: order, courierName: widget.account.name, courierView: true)),\n            ] else if (visibleOrders.isEmpty)\n"""
new_receipts_block = """            else if (filter == 'receipts')\n              _receiptCenter(grouped)\n            else if (visibleOrders.isEmpty)\n"""
dashboard = replace_required(dashboard, old_receipts_block, new_receipts_block, 'receipts center block')

order_card_marker = "  Widget orderCard(Map<String, dynamic> order) {\n"
receipt_center = r'''  Widget _receiptCenter(List<Map<String, dynamic>> grouped) {
    final completed = grouped.where(isDone).toList();
    final query = receiptSearch.trim().toLowerCase();
    final visible = completed.where((order) {
      if (query.isEmpty) return true;
      final items = (order['_items'] as List? ?? const <dynamic>[]).cast<Map<String, dynamic>>();
      final haystack = [
        order['order_number'],
        order['id'],
        order['student_name'],
        order['student_phone'],
        ...items.map((item) => item['title'] ?? item['product_name'] ?? item['item_name']),
      ].map((value) => '${value ?? ''}'.toLowerCase()).join(' ');
      return haystack.contains(query);
    }).toList();
    final totalAmounts = completed.fold<num>(0, (sum, order) => sum + number(order['_group_total']));
    final totalDelivery = completed.fold<num>(0, (sum, order) => sum + number(order['_courier_fee']));

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: BusinessBrand.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: BusinessBrand.softBlue, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.receipt_long_rounded, color: BusinessBrand.navy, size: 29),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الوصولات', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: BusinessBrand.navy)),
                        SizedBox(height: 3),
                        Text('وصولات الطلبات المكتملة بصورة مرتبة مثل صفحة الويب القديمة.', style: TextStyle(fontSize: 13, color: BusinessBrand.muted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(color: BusinessBrand.navy, borderRadius: BorderRadius.circular(99)),
                    child: Text('${completed.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(width: desktop ? (constraints.maxWidth - 30) / 4 : (constraints.maxWidth - 10) / 2, child: _Metric(label: 'جميع الوصولات', value: '${completed.length}', icon: Icons.receipt_long_rounded, accent: BusinessBrand.navy)),
                SizedBox(width: desktop ? (constraints.maxWidth - 30) / 4 : (constraints.maxWidth - 10) / 2, child: _Metric(label: 'الطلبات المكتملة', value: '${completed.length}', icon: Icons.task_alt_rounded, accent: BusinessBrand.teal)),
                SizedBox(width: desktop ? (constraints.maxWidth - 30) / 4 : (constraints.maxWidth - 10) / 2, child: _Metric(label: 'إجمالي مبالغ الطلبات', value: money(totalAmounts), icon: Icons.payments_rounded, accent: BusinessBrand.orange)),
                SizedBox(width: desktop ? (constraints.maxWidth - 30) / 4 : (constraints.maxWidth - 10) / 2, child: _Metric(label: 'أجرة التوصيل', value: money(totalDelivery), icon: Icons.account_balance_wallet_rounded, accent: BusinessBrand.navy2)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => receiptSearch = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'بحث في الوصولات',
                hintText: 'رقم الوصول أو الطلب أو اسم الطالب أو المادة',
              ),
            ),
            const SizedBox(height: 12),
            if (desktop)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: BusinessBrand.softBlue, borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  children: [
                    SizedBox(width: 178, child: Text('رقم الوصول / الطلب', style: TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy))),
                    SizedBox(width: 150, child: Text('النوع', style: TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy))),
                    Expanded(child: Text('التاريخ', style: TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy))),
                    SizedBox(width: 118, child: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy))),
                    SizedBox(width: 76, child: Text('الحالة', style: TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy))),
                    SizedBox(width: 262, child: Text('الإجراءات', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: BusinessBrand.navy))),
                  ],
                ),
              ),
            if (desktop) const SizedBox(height: 8),
            if (completed.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد وصولات مكتملة بعد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))))
            else if (visible.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: Text('لا توجد نتائج مطابقة للبحث', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))))
            else
              ...visible.map((order) => GroupedOrderReceiptListTile(order: order, courierName: widget.account.name, courierView: true)),
          ],
        );
      },
    );
  }

'''
if order_card_marker not in dashboard:
    raise SystemExit('PATCH FAILED: order card marker not found')
dashboard = dashboard.replace(order_card_marker, receipt_center + order_card_marker, 1)
write(dashboard_path, dashboard)


# 4) Release marker so Android/web builds cannot be confused with the previous UI.
pubspec_path = 'flutter_business/pubspec.yaml'
pubspec = read(pubspec_path)
pubspec = re.sub(r'^version:\s*[^\n]+$', 'version: 1.0.3+11', pubspec, count=1, flags=re.MULTILINE)
pubspec = re.sub(r'^# Build[^\n]*$', '# Build 11: courier receipts mirror old web layout + clearer courier dashboard typography.', pubspec, count=1, flags=re.MULTILINE)
write(pubspec_path, pubspec)

print('Courier receipt/web-layout refinement complete.')
