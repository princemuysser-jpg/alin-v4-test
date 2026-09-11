from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label}: expected source block not found')
    return text.replace(old, new, 1)


# WEB: one receipt per checkout, all materials in one receipt.
p = Path('modules/core/receipts-center.js')
t = p.read_text(encoding='utf-8')
t = t.replace(
    '/* ALIN v4.1.5 — isolated receipts center (orders + settlements). */',
    '/* ALIN v4.2.2 — grouped checkout receipts center (orders + settlements). */',
    1,
)

old = """  function orderNumber(row){return String(row.order_number||row.tracking_code||row.order_id||row.id||'—')}
  function receiptNumber(row){
    if(row.receipt_number||row.voucher_number)return String(row.receipt_number||row.voucher_number);
    const base=orderNumber(row).replace(/^AL-/i,'');
    return `RC-${base}`;
  }
"""
new = """  function checkoutKey(row){
    const group=String(row?.checkout_group_id||'').trim();if(group)return `group:${group}`;
    const request=String(row?.checkout_request_key||'').trim();if(request)return `request:${request}`;
    return `single:${String(row?.id||row?.order_id||row?.order_number||'')}`;
  }
  function groupedOrderReceipts(role){
    const groups=new Map();
    scopedOrders(role).forEach(row=>{const key=checkoutKey(row);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(row)});
    const result=[];
    for(const [key,items] of groups){
      items.sort((a,b)=>String(a.created_at||'').localeCompare(String(b.created_at||'')));
      const anchor=items.find(row=>num(row.delivery_fee||row.shipping_fee)>0||num(row.courier_fee||row.courier_profit||row.delegate_profit)>0)||items[0];
      result.push({...anchor,_receipt_group_key:key,_items:items,_item_count:items.length,_qty_count:items.reduce((s,row)=>s+Math.max(1,num(row.qty||row.quantity||1)),0),_group_total:items.reduce((s,row)=>s+num(row.total||row.total_amount||row.amount),0),_delivery_fee:items.reduce((s,row)=>s+num(row.delivery_fee||row.shipping_fee),0),_discount:items.reduce((s,row)=>s+num(row.discount||row.discount_amount),0),_courier_fee:items.reduce((s,row)=>s+num(row.courier_fee||row.courier_profit||row.delegate_profit),0)});
    }
    return result;
  }
  function itemRows(row){return Array.isArray(row?._items)&&row._items.length?row._items:[row]}
  function orderNumber(row){return String(row.order_number||row.tracking_code||row.order_id||row.id||'—')}
  function receiptNumber(row){
    if(row.receipt_number||row.voucher_number)return String(row.receipt_number||row.voucher_number);
    const base=orderNumber(row).replace(/^AL-/i,'');
    return `RC-${base}`;
  }
"""
t = replace_once(t, old, new, 'web grouping helpers')

old = """  function orderKey(row){return encodeURIComponent(String(row.id||row.order_id||row.order_number||row.tracking_code||''))}
  function settlementKey(row){return encodeURIComponent(settlementIdentity(row))}
  function findOrder(key,role){
    const value=decodeURIComponent(String(key||''));
    return scopedOrders(role).find(row=>[row.id,row.order_id,row.order_number,row.tracking_code].some(item=>same(item,value)))||null;
  }
"""
new = """  function orderKey(row){return encodeURIComponent(String(row._receipt_group_key||checkoutKey(row)))}
  function settlementKey(row){return encodeURIComponent(settlementIdentity(row))}
  function findOrder(key,role){
    const value=decodeURIComponent(String(key||''));
    return groupedOrderReceipts(role).find(row=>String(row._receipt_group_key||checkoutKey(row))===value)||null;
  }
"""
t = replace_once(t, old, new, 'web grouped receipt lookup')

old = """  function orderAmounts(row){
    const quantity=Math.max(1,num(row.qty||row.quantity||1));
    const delivery=Math.max(0,num(row.delivery_fee||row.shipping_fee));
    const discount=Math.max(0,num(row.discount||row.discount_amount));
    const total=Math.max(0,num(row.total||row.total_amount||row.amount));
    const subtotal=Math.max(0,num(row.subtotal||row.items_total)||(total+discount-delivery));
    const unit=Math.max(0,num(row.unit_price||row.price)||(subtotal/quantity));
    return {quantity,delivery,discount,total,subtotal,unit};
  }
"""
new = """  function rowAmounts(row){
    const quantity=Math.max(1,num(row.qty||row.quantity||1));
    const delivery=Math.max(0,num(row.delivery_fee||row.shipping_fee));
    const discount=Math.max(0,num(row.discount||row.discount_amount));
    const total=Math.max(0,num(row.total||row.total_amount||row.amount));
    const subtotal=Math.max(0,num(row.subtotal||row.items_total)||(total+discount-delivery));
    const unit=Math.max(0,num(row.unit_price||row.price)||(subtotal/quantity));
    return {quantity,delivery,discount,total,subtotal,unit};
  }
  function orderAmounts(row){
    const items=itemRows(row),delivery=row._delivery_fee!=null?num(row._delivery_fee):items.reduce((s,item)=>s+rowAmounts(item).delivery,0),discount=row._discount!=null?num(row._discount):items.reduce((s,item)=>s+rowAmounts(item).discount,0),total=row._group_total!=null?num(row._group_total):items.reduce((s,item)=>s+rowAmounts(item).total,0),subtotal=items.reduce((s,item)=>s+rowAmounts(item).subtotal,0),quantity=items.reduce((s,item)=>s+rowAmounts(item).quantity,0);
    return {quantity,delivery,discount,total,subtotal,unit:quantity?subtotal/quantity:0};
  }
"""
t = replace_once(t, old, new, 'web grouped amounts')

old = """  function orderRow(row,role){
    const key=orderKey(row);
    const search=[receiptNumber(row),orderNumber(row),title(row),studentName(row),money(orderAmounts(row).total)].join(' ').toLowerCase();
"""
new = """  function orderRow(row,role){
    const key=orderKey(row),items=itemRows(row);
    const search=[receiptNumber(row),orderNumber(row),...items.map(title),studentName(row),money(orderAmounts(row).total)].join(' ').toLowerCase();
"""
t = replace_once(t, old, new, 'web receipt row search')
t = t.replace(
    '<span class="alin415r-type">وصل طلب</span>',
    '<span class="alin415r-type">وصل طلب • ${items.length} مواد</span>',
    1,
)

start = t.index('  function orderReceipt(row){')
end = t.index('  function settlementReceipt(row,role){', start)
replacement = r'''  function orderReceipt(row){
    const items=itemRows(row),amount=orderAmounts(row),number=receiptNumber(row);
    const itemLines=items.map((item,index)=>{const a=rowAmounts(item);return `<tr><td>${index+1}</td><td>${esc(title(item))}</td><td>${a.quantity}</td><td>${money(a.unit)} د.ع</td><td>${money(a.subtotal)} د.ع</td></tr>`}).join('');
    const note=items.map(item=>item.notes||item.note||item.delivery_note||'').filter(Boolean).join(' • ')||'لا توجد ملاحظات';
    return `<article class="alin415r-paper" dir="rtl" data-alin415r-printable>
      <header class="alin415r-paper-head"><div class="alin415r-paper-brand"><span>آ</span><div><h2>منصة آلين</h2><p>ملازم • قرطاسية • هدايا</p></div></div><div class="alin415r-paper-title"><small>وصل طلب كامل</small><b dir="ltr">${esc(number)}</b></div></header>
      <div class="alin415r-paper-meta"><div><small>رقم الطلب</small><b dir="ltr">${esc(orderNumber(row))}</b></div><div><small>التاريخ</small><b>${esc(dateTime(row.completed_at||row.delivered_at||row.updated_at||row.created_at))}</b></div><div><small>عدد المواد</small><b>${items.length} مواد • ${amount.quantity} قطعة/نسخة</b></div></div>
      <section class="alin415r-paper-section"><h3>بيانات الطالب</h3><div class="alin415r-student"><div><small>اسم الطالب</small><b>${esc(studentName(row))}</b></div><div><small>رقم الهاتف</small><b dir="ltr">${esc(studentPhone(row))}</b></div><div><small>طريقة الاستلام</small><b>${esc(fulfillment(row))}</b></div></div></section>
      <section class="alin415r-paper-section"><h3>مواد الطلب</h3><table><thead><tr><th>#</th><th>الصنف</th><th>الكمية</th><th>سعر الوحدة</th><th>الإجمالي</th></tr></thead><tbody>${itemLines}</tbody></table>
      <div class="alin415r-totals"><div><span>مجموع المواد</span><b>${money(amount.subtotal)} د.ع</b></div>${amount.delivery?`<div><span>أجرة التوصيل</span><b>${money(amount.delivery)} د.ع</b></div>`:''}${amount.discount?`<div><span>الخصم</span><b>${money(amount.discount)} د.ع</b></div>`:''}<div class="final"><span>الإجمالي الكلي</span><strong>${money(amount.total)} د.ع</strong></div></div></section>
      <section class="alin415r-paper-note"><small>ملاحظات</small><p>${esc(note)}</p></section>
      <footer><b>منصة آلين</b><small>شكراً لاستخدام منصة آلين</small></footer>
    </article>`;
  }

'''
t = t[:start] + replacement + t[end:]

t = replace_once(
    t,
    """  function centerHtml(role){
    const orders=[...scopedOrders(role)].sort((a,b)=>String(b.completed_at||b.updated_at||b.created_at||'').localeCompare(String(a.completed_at||a.updated_at||a.created_at||'')));
""",
    """  function centerHtml(role){
    const orders=groupedOrderReceipts(role).sort((a,b)=>String(b.completed_at||b.updated_at||b.created_at||'').localeCompare(String(a.completed_at||a.updated_at||a.created_at||'')));
""",
    'web grouped center',
)
t = t.replace('orders:scopedOrders,settlements:scopedSettlements', 'orders:groupedOrderReceipts,settlements:scopedSettlements', 1)
p.write_text(t, encoding='utf-8')

# Flutter courier: add receipts tab based on already grouped orders.
p = Path('flutter_business/lib/screens/courier_dashboard_screen.dart')
t = p.read_text(encoding='utf-8')
imp = "import '../models/business_account.dart';\n"
if 'grouped_order_receipt_card.dart' not in t:
    t = replace_once(t, imp, imp + "import '../widgets/grouped_order_receipt_card.dart';\n", 'courier receipt import')
if "value: 'receipts'" not in t:
    t = replace_once(
        t,
        "ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),",
        "ButtonSegment(value: 'all', label: Text('الكل'), icon: Icon(Icons.list_alt_rounded)),\n                ButtonSegment(value: 'receipts', label: Text('الوصولات'), icon: Icon(Icons.receipt_long_rounded)),",
        'courier receipts segment',
    )
old = """            else if (visibleOrders.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات حالياً'))))
            else
              ...visibleOrders.map(orderCard),
"""
if "وصولات الطلبات المكتملة" not in t:
    new = """            else if (filter == 'receipts') ...[
              const Text('وصولات الطلبات المكتملة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (grouped.where(isDone).isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد وصولات مكتملة بعد'))))
              else
                ...grouped.where(isDone).map((order) => GroupedOrderReceiptCard(order: order, courierName: widget.account.name, courierView: true)),
            ] else if (visibleOrders.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد طلبات حالياً'))))
            else
              ...visibleOrders.map(orderCard),
"""
    t = replace_once(t, old, new, 'courier receipts body')
p.write_text(t, encoding='utf-8')

# Flutter admin mobile/tablet: receipts destination.
p = Path('flutter_business/lib/screens/admin_dashboard_screen.dart')
t = p.read_text(encoding='utf-8')
imp = "import '../models/business_account.dart';\n"
if 'grouped_order_receipt_card.dart' not in t:
    t = replace_once(t, imp, imp + "import '../widgets/grouped_order_receipt_card.dart';\n", 'admin receipt import')
if '_receipts()' not in t.split('Widget build', 1)[1].split('];', 1)[0]:
    t = replace_once(t, 'final pages = [_home(), _orders(), _accounts(), _finance(), _catalog()];', 'final pages = [_home(), _orders(), _accounts(), _finance(), _catalog(), _receipts()];', 'admin pages')
nav = "NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'المحتوى'),"
if "label: 'الوصولات'" not in t:
    t = replace_once(t, nav, nav + "\n          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'الوصولات'),", 'admin receipts nav')
if 'Widget _receipts()' not in t:
    marker = '  String _courierName(String id) {'
    receipts = r'''  Widget _receipts() {
    final completed = groupedOrders.where((order) {
      final items = (order['_items'] as List).cast<Map<String, dynamic>>();
      return items.every((row) => const {'completed', 'delivered', 'done'}.contains('${row['status']}'));
    }).toList();
    return _scroll([
      const Text('الوصولات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('وصل واحد لكل طلب كامل ويعرض جميع المواد.'),
      const SizedBox(height: 12),
      if (completed.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(22), child: Center(child: Text('لا توجد وصولات مكتملة'))))
      else
        ...completed.map((order) => GroupedOrderReceiptCard(order: order, courierName: _courierName('${order['courier_id'] ?? order['delegate_id'] ?? ''}'))),
    ]);
  }

'''
    t = replace_once(t, marker, receipts + marker, 'admin receipts page')
p.write_text(t, encoding='utf-8')

# Flutter desktop admin: grouped orders and receipts section.
p = Path('flutter_business/lib/screens/admin_desktop_dashboard_screen.dart')
t = p.read_text(encoding='utf-8')
imp = "import '../models/business_account.dart';\n"
if 'grouped_order_receipt_card.dart' not in t:
    t = replace_once(t, imp, imp + "import '../widgets/grouped_order_receipt_card.dart';\n", 'desktop receipt import')
if 'List<Map<String, dynamic>> get groupedOrders' not in t:
    old = """  List<Map<String, dynamic>> get visibleOrders {
    if (orderFilter == 'all') return orders;
    if (orderFilter == 'done') return orders.where((e) => const ['completed', 'delivered'].contains('${e['status']}')).toList();
    if (orderFilter == 'cancelled') return orders.where((e) => const ['cancelled', 'rejected'].contains('${e['status']}')).toList();
    return orders.where((e) => !_closed(e)).toList();
  }
"""
    new = """  List<Map<String, dynamic>> get groupedOrders => groupOrdersForReceipts(orders);

  bool _groupClosed(Map<String, dynamic> order) {
    final items = (order['_items'] as List).cast<Map<String, dynamic>>();
    return items.every((row) => const ['completed', 'delivered', 'cancelled', 'rejected'].contains('${row['status']}'));
  }

  List<Map<String, dynamic>> get visibleOrders {
    final grouped = groupedOrders;
    if (orderFilter == 'all') return grouped;
    if (orderFilter == 'done') return grouped.where(receiptGroupCompleted).toList();
    if (orderFilter == 'cancelled') return grouped.where((e) => ((e['_items'] as List).cast<Map<String, dynamic>>()).every((row) => const ['cancelled', 'rejected'].contains('${row['status']}'))).toList();
    return grouped.where((e) => !_groupClosed(e)).toList();
  }
"""
    t = replace_once(t, old, new, 'desktop grouped orders')
if "(Icons.receipt_long_rounded, 'الوصولات')" not in t:
    t = replace_once(t, "(Icons.inventory_2_rounded, 'المحتوى'),", "(Icons.inventory_2_rounded, 'المحتوى'),\n      (Icons.receipt_long_rounded, 'الوصولات'),", 'desktop receipts nav')
if 'case 5:' not in t:
    t = replace_once(t, "      case 4:\n        return _catalogPage();\n      default:", "      case 4:\n        return _catalogPage();\n      case 5:\n        return _receiptsPage();\n      default:", 'desktop receipt case')
t = t.replace("String _titleForSection() => const ['الرئيسية', 'إدارة الطلبات', 'إدارة الحسابات', 'المالية والتسويات', 'المحتوى'][section];", "String _titleForSection() => const ['الرئيسية', 'إدارة الطلبات', 'إدارة الحسابات', 'المالية والتسويات', 'المحتوى', 'الوصولات'][section];", 1)
t = t.replace('_ordersTable(orders.take(8).toList()),', '_ordersTable(groupedOrders.take(8).toList()),', 1)
if 'Widget _receiptsPage()' not in t:
    marker = '  Widget _accountsPage() => _page(['
    receipts = r'''  Widget _receiptsPage() {
    final completed = groupedOrders.where(receiptGroupCompleted).toList();
    return _page([
      _sectionHeader('الوصولات (${completed.length})'),
      const SizedBox(height: 6),
      const Text('وصل واحد لكل طلب مكتمل مع جميع المواد والتوصيل والإجمالي.'),
      const SizedBox(height: 14),
      if (completed.isEmpty)
        _empty('لا توجد وصولات مكتملة')
      else
        ...completed.map((order) => GroupedOrderReceiptCard(order: order, courierName: _courierName('${order['courier_id'] ?? order['delegate_id'] ?? ''}'))),
    ]);
  }

  String _courierName(String id) {
    if (id.trim().isEmpty) return '';
    for (final courier in couriers) {
      if ('${courier['id']}' == id) return '${courier['name'] ?? id}';
    }
    return id;
  }

'''
    t = replace_once(t, marker, receipts + marker, 'desktop receipts page')
p.write_text(t, encoding='utf-8')

# Business app build + cache bust.
p = Path('flutter_business/pubspec.yaml')
t = p.read_text(encoding='utf-8')
t = re.sub(r'^version:\s*1\.0\.1\+\d+\s*$', 'version: 1.0.1+9', t, flags=re.M)
p.write_text(t, encoding='utf-8')

p = Path('alin-config.js')
t = p.read_text(encoding='utf-8')
t = re.sub(r"assetVersion:'[^']+'", "assetVersion:'4.2.2-grouped-receipts-20260911'", t, count=1)
p.write_text(t, encoding='utf-8')
