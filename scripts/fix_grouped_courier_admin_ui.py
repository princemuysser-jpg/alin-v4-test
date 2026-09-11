from pathlib import Path
import re


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


# Legacy web: delivery assignment page becomes checkout-group based.
p = Path('modules/courier/assignment.js')
text = p.read_text(encoding='utf-8')
old = "  function deliveryOrders(){return allOrders().filter(o=>o.fulfillment_type==='home_delivery'||o.delivery_type==='courier')}\n"
new = '''  function deliveryOrders(){return allOrders().filter(o=>o.fulfillment_type==='home_delivery'||o.delivery_type==='courier')}
  function checkoutKey(o){const group=String(o?.checkout_group_id||'').trim();if(group)return `group:${group}`;const request=String(o?.checkout_request_key||'').trim();if(request)return `request:${request}`;return `single:${String(o?.id||o?.order_number||'')}`}
  function groupedDeliveryOrders(){
    const map=new Map();
    deliveryOrders().forEach(row=>{const key=checkoutKey(row);if(!map.has(key))map.set(key,[]);map.get(key).push(row)});
    return [...map.entries()].map(([key,items])=>{
      items.sort((a,b)=>String(a.created_at||'').localeCompare(String(b.created_at||'')));
      const anchor=items.find(row=>Number(row.delivery_fee||0)>0||Number(row.courier_fee||0)>0)||items[0];
      const statuses=new Set(items.map(row=>String(row.status||'')));
      return {...anchor,_checkout_key:key,_items:items,_item_count:items.length,_qty_count:items.reduce((s,row)=>s+Math.max(1,Number(row.qty||row.quantity||1)||1),0),total:items.reduce((s,row)=>s+Number(row.total||0),0),delivery_fee:items.reduce((s,row)=>s+Number(row.delivery_fee||0),0),courier_fee:items.reduce((s,row)=>s+Number(row.courier_fee||row.courier_profit||row.delegate_profit||0),0),_mixed_status:statuses.size>1};
    }).sort((a,b)=>String(b.created_at||b.updated_at||'').localeCompare(String(a.created_at||a.updated_at||'')));
  }
  function groupDone(o){return (o._items||[o]).every(done)}
  function groupActive(o){return (o._items||[o]).some(active)}
  function groupLocked(o){return (o._items||[o]).every(row=>done(row)||['cancelled','rejected'].includes(String(row.status||'')))}
  function groupAssignedId(o){const ids=(o._items||[o]).map(row=>row.courier_id||row.delegate_id).filter(Boolean).map(String);return ids[0]||''}
  function groupedCourierLoad(c){if(!c)return 0;const ids=new Set([c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String));const keys=new Set();allOrders().filter(active).forEach(row=>{if([row.courier_id,row.delegate_id].filter(Boolean).map(String).some(id=>ids.has(id)))keys.add(checkoutKey(row))});return keys.size}
  function materialsHtml(o){return `<div class="v164-group-materials"><h4>مواد الطلب (${Number(o._item_count||1)})</h4>${(o._items||[o]).map((row,i)=>`<div class="v164-group-material"><span><b>${i+1}. ${escv(row.title||'مادة')}</b>${variantLabel(row)?`<small>${escv(variantLabel(row))}</small>`:''}</span><span>× ${Math.max(1,Number(row.qty||row.quantity||1)||1)} • ${moneyv(row.total||0)} د.ع</span></div>`).join('')}</div>`}
'''
if old not in text:
    raise SystemExit('assignment helper insertion point not found')
text = text.replace(old, new, 1)
text = text.replace('    const rows=deliveryOrders();', '    const rows=groupedDeliveryOrders();', 1)
text = text.replace("${rows.filter(o=>!o.courier_id&&!o.delegate_id).length}", "${rows.filter(o=>!groupAssignedId(o)).length}", 1)
text = text.replace("${rows.filter(o=>active(o)&&(o.courier_id||o.delegate_id)).length}", "${rows.filter(o=>groupActive(o)&&groupAssignedId(o)).length}", 1)
text = text.replace("${rows.filter(done).length}", "${rows.filter(groupDone).length}", 1)
start = text.index('  function deliveryAdminCard(o){')
end = text.index('  async function runAssignment', start)
text = text[:start] + '''  function deliveryAdminCard(o){
    const area=window.alinNormalizeDeliveryArea(o.delivery_area)||'غير محددة';
    const matches=matchingCouriers(area);
    const assignedId=groupAssignedId(o);
    const assigned=allCouriers().find(c=>[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(String(assignedId)));
    const map=mapLink(o),exactGps=hasExactGps(o),locked=groupLocked(o);
    return `<article class="v164-delivery-admin-card"><header><div><small>${escv(o.order_number||o.id)}</small><h3>طلب توصيل واحد • ${Number(o._item_count||1)} مواد</h3><small>${Number(o._qty_count||1)} قطعة/نسخة</small></div><span>${escv(area)}</span></header>${o.delivery_note?`<div class="v164-issue">ملاحظة المندوب: ${escv(o.delivery_note)}</div>`:''}<div class="v164-order-grid"><div><small>الطالب</small><b>${escv(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${escv(o.student_phone||'—')}</b></div><div class="wide"><small>أقرب نقطة دالة</small><b>${escv(o.delivery_landmark||'—')}</b></div><div><small>الإجمالي الكلي</small><b>${moneyv(o.total)} د.ع</b></div><div><small>أجرة التوصيل</small><b>${moneyv(o.delivery_fee||0)} د.ع</b></div><div><small>أجرة المندوب</small><b>${moneyv(o.courier_fee||0)} د.ع</b></div><div><small>الحالة</small><b>${o._mixed_status?'حالات متعددة':escv(orderState(o.status))}</b></div></div>${materialsHtml(o)}${map?`<button type="button" class="v164-map-btn" data-alin-click="alinCourierOpenMap" data-alin-click-arg0="${escv(o.id)}">${exactGps?'فتح موقع الطالب GPS':'فتح النقطة الدالة على الخريطة'}</button>`:''}${deliveryPricingControls(o,locked)}<div class="v164-match-list"><h4>تعيين مندوب للطلب كامل (${matches.length} متاح)</h4>${matches.map(c=>`<label><input type="radio" name="v216assign_${escv(o.id)}" value="${escv(c.id)}" ${assigned&&String(assigned.id)===String(c.id)?'checked':''} ${locked?'disabled':''}><span><b>${escv(c.name)}</b><small>${statusLabel(statusOf(c))} • ${groupedCourierLoad(c)} طلب حالي • ${escv(c.phone||'')}</small></span></label>`).join('')||'<p class="warning-text">لا يوجد مندوب مرتبط بهذه المنطقة.</p>'}</div><footer><button data-order-action="${escv(o.id)}" ${locked||!matches.length?'disabled':''} data-alin-click="alinV164Assign" data-alin-click-arg0="${escv(o.id)}">${assigned?'حفظ المندوب للطلب كامل':'تحويل الطلب كامل للمندوب'}</button>${assigned&&!locked?`<button class="secondary" data-order-action="${escv(o.id)}" data-alin-click="alinV410Unassign" data-alin-click-arg0="${escv(o.id)}">إلغاء تعيين الطلب كامل</button>`:''}${assigned?`<span>المندوب الحالي: <b>${escv(assigned.name)}</b></span>`:'<span>لم يتم تعيين مندوب</span>'}</footer></article>`;
  }
''' + text[end:]
p.write_text(text, encoding='utf-8')

# Legacy web: add courier assignment to grouped order materials modal.
p = Path('modules/admin/orders-grouped.js')
text = p.read_text(encoding='utf-8')
needle = '.alin-order-prep-actions{padding:0 20px 20px}'
if needle not in text:
    raise SystemExit('grouped orders CSS point not found')
text = text.replace(needle, '.alin-order-group-courier{margin:0 20px 18px;padding:14px;border:1px solid #d9e3ee;border-radius:14px;background:#f8fbff}.alin-order-group-courier h3{margin:0 0 8px;font-size:15px}.alin-order-group-courier-row{display:flex;gap:8px;align-items:end;flex-wrap:wrap}.alin-order-group-courier label{flex:1;min-width:220px;font-size:12px;color:#64748b}.alin-order-group-courier select{display:block;width:100%;margin-top:5px;padding:10px;border:1px solid #cbd5e1;border-radius:10px;background:white}.alin-order-group-courier button{border:0;border-radius:10px;padding:10px 14px;background:#173b67;color:white;font-weight:800;cursor:pointer}.alin-order-prep-actions{padding:0 20px 20px}', 1)
marker = "function fulfillmentText(first){const home=['home_delivery','delivery','courier'].includes(String(first?.fulfillment_type||first?.delivery_type||''));return home?(first.delivery_area||'توصيل للمنزل'):libraryName(first.library_id||first.pickup_library_id)}\n"
if marker not in text:
    raise SystemExit('grouped orders helper point not found')
helpers = marker + '''function isHomeDelivery(first){return ['home_delivery','delivery','courier'].includes(String(first?.fulfillment_type||first?.delivery_type||''))}
function groupCourierId(list){return String(list.map(o=>o.courier_id||o.delegate_id).find(Boolean)||'')}
function courierAssignmentHtml(g){
 const first=g.rows[0];if(!isHomeDelivery(first))return'';
 const core=window.AlinCourierCore;if(!core)return '<section class="alin-order-group-courier">خدمة المندوب غير جاهزة.</section>';
 const area=window.alinNormalizeDeliveryArea?.(first.delivery_area)||first.delivery_area||'';
 let options=core.matchingCouriers?.(area)||core.activeCouriers?.()||[];
 const current=groupCourierId(g.rows),all=core.allCouriers?.()||[];
 const currentCourier=all.find(c=>[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(current));
 if(currentCourier&&!options.some(c=>String(c.id)===String(currentCourier.id)))options=[currentCourier,...options];
 return `<section class="alin-order-group-courier"><h3>تعيين مندوب للطلب كامل</h3><div class="alin-order-group-courier-row"><label>المندوب<select class="alin-order-group-courier-select"><option value="">بدون مندوب</option>${options.map(c=>`<option value="${esc(c.id)}" ${current&&String(c.id)===current?'selected':''}>${esc(c.name||c.username||'مندوب')} • ${esc(c.phone||'')}</option>`).join('')}</select></label><button type="button" class="alin-order-group-assign-btn" data-group-key="${esc(g.key)}">${current?'حفظ المندوب':'تعيين المندوب'}</button></div><small>التعيين يطبق على كل مواد هذا الطلب دفعة واحدة.</small></section>`
}
'''
text = text.replace(marker, helpers, 1)
summary_line = '   <section class="alin-order-prep-summary"><span>مجموع المواد<b>${money(total-delivery)} د.ع</b></span><span>أجرة التوصيل<b>${money(delivery)} د.ع</b></span><span>مجموع الخصم<b>${money(discount)} د.ع</b></span><span>الإجمالي الكلي<b>${money(total)} د.ع</b></span></section>\n'
if summary_line not in text:
    raise SystemExit('grouped orders summary point not found')
text = text.replace(summary_line, summary_line + '   ${courierAssignmentHtml(g)}\n', 1)
old_event = "document.addEventListener('click',e=>{const b=e.target.closest?.('.alin-order-list-btn');if(b)prepModal(b.dataset.groupKey)});"
if old_event not in text:
    raise SystemExit('grouped orders event handler not found')
new_event = '''document.addEventListener('click',async e=>{
 const listBtn=e.target.closest?.('.alin-order-list-btn');if(listBtn){prepModal(listBtn.dataset.groupKey);return}
 const assignBtn=e.target.closest?.('.alin-order-group-assign-btn');if(!assignBtn)return;
 const g=groupsByKey.get(String(assignBtn.dataset.groupKey));if(!g?.rows?.length)return;
 const select=assignBtn.closest('.alin-order-group-courier')?.querySelector('.alin-order-group-courier-select');
 const courierId=String(select?.value||'').trim()||null,core=window.AlinCourierCore;
 if(!core?.assignOrder){window.toast?.('خدمة تعيين المندوب غير جاهزة');return}
 assignBtn.disabled=true;
 try{
   await core.assignOrder(String(g.rows[0].id),courierId,null);
   document.querySelector('.alin-order-prep-backdrop')?.remove();
   await Promise.resolve(window.renderOrdersAdmin?.());
   window.toast?.(courierId?'تم تعيين المندوب للطلب كامل':'تم إلغاء تعيين المندوب عن الطلب كامل');
 }catch(error){console.error('[ALIN grouped order courier assignment]',error);window.toast?.(core.friendlyOrderError?.(error)||error?.message||'تعذر تعيين المندوب')}
 finally{assignBtn.disabled=false}
});'''
text = text.replace(old_event, new_event, 1)
p.write_text(text, encoding='utf-8')

# Flutter Business repository: fetch grouping keys and make admin status change group-level.
p = Path('flutter_business/lib/data/business_repository.dart')
text = p.read_text(encoding='utf-8')
old_select = 'id,order_number,kind,item_id,title,student_name,student_phone,qty,unit_price,discount,total,status,assignment_status,payment_status,payment_method,fulfillment_type,delivery_type,library_id,pickup_library_id,courier_id,delegate_id,delivery_area,delivery_landmark,delivery_fee,courier_fee,notes,library_note,delivery_note,platform_profit,teacher_profit,library_profit,courier_profit,delegate_profit,book_supplier_profit,created_at,updated_at,completed_at,delivered_at,cancellation_reason'
new_select = 'id,order_number,kind,item_id,title,student_name,student_phone,qty,unit_price,discount,total,status,assignment_status,payment_status,payment_method,fulfillment_type,delivery_type,library_id,pickup_library_id,courier_id,delegate_id,checkout_group_id,checkout_request_key,delivery_area,delivery_landmark,delivery_fee,courier_fee,notes,library_note,delivery_note,platform_profit,teacher_profit,library_profit,courier_profit,delegate_profit,book_supplier_profit,created_at,updated_at,completed_at,delivered_at,cancellation_reason'
if old_select not in text:
    raise SystemExit('Flutter adminOrders select point not found')
text = text.replace(old_select, new_select, 1)
old_transition = "  Future<Map<String, dynamic>> adminTransitionOrder(String orderId, String status, {String reason = ''}) {\n    return _orderTransition(orderId, status, reason: reason);\n  }"
new_transition = "  Future<Map<String, dynamic>> adminTransitionOrder(String orderId, String status, {String reason = ''}) async {\n    final raw = await client.rpc('alin_order_transition_group', params: {\n      'p_order_id': orderId,\n      'p_status': status,\n      'p_reason': reason.trim().isEmpty ? null : reason.trim(),\n    });\n    if (raw is! Map) throw Exception('تعذر تحديث الطلب');\n    final map = Map<String, dynamic>.from(raw);\n    if (map['ok'] != true) throw Exception('${map['error'] ?? 'تعذر تحديث الطلب'}');\n    return map;\n  }"
if old_transition not in text:
    raise SystemExit('Flutter admin transition point not found')
text = text.replace(old_transition, new_transition, 1)
p.write_text(text, encoding='utf-8')

# Flutter Business admin UI: group checkout rows in Orders section and show materials + group courier assignment.
p = Path('flutter_business/lib/screens/admin_dashboard_screen.dart')
text = p.read_text(encoding='utf-8')
old_closed = "  bool isClosed(Map<String, dynamic> o) => ['completed', 'delivered', 'cancelled', 'rejected'].contains('${o['status']}');\n"
if old_closed not in text:
    raise SystemExit('Flutter isClosed point not found')
new_closed = '''  bool isClosed(Map<String, dynamic> o) {
    final items = (o['_items'] as List?)?.cast<Map<String, dynamic>>() ?? [o];
    return items.every((row) => ['completed', 'delivered', 'cancelled', 'rejected'].contains('${row['status']}'));
  }

  String checkoutKey(Map<String, dynamic> o) {
    final group = '${o['checkout_group_id'] ?? ''}'.trim();
    if (group.isNotEmpty) return 'group:$group';
    final request = '${o['checkout_request_key'] ?? ''}'.trim();
    if (request.isNotEmpty) return 'request:$request';
    return 'single:${o['id'] ?? o['order_number']}';
  }

  List<Map<String, dynamic>> groupOrders(List<Map<String, dynamic>> source) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in source) {
      groups.putIfAbsent(checkoutKey(row), () => []).add(row);
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in groups.entries) {
      final items = entry.value;
      final anchor = items.firstWhere((row) => number(row['delivery_fee']) > 0 || number(row['courier_fee']) > 0, orElse: () => items.first);
      final statuses = items.map((row) => '${row['status']}').toSet();
      result.add({...anchor, '_checkout_key': entry.key, '_items': items, '_item_count': items.length, '_qty_count': items.fold<num>(0, (sum, row) => sum + (number(row['qty']) <= 0 ? 1 : number(row['qty']))), 'total': items.fold<num>(0, (sum, row) => sum + number(row['total'])), 'delivery_fee': items.fold<num>(0, (sum, row) => sum + number(row['delivery_fee'])), 'courier_fee': items.fold<num>(0, (sum, row) => sum + number(row['courier_fee'] ?? row['courier_profit'] ?? row['delegate_profit'])), '_mixed_status': statuses.length > 1});
    }
    result.sort((a, b) => '${b['created_at'] ?? b['updated_at'] ?? ''}'.compareTo('${a['created_at'] ?? a['updated_at'] ?? ''}'));
    return result;
  }
'''
text = text.replace(old_closed, new_closed, 1)
old_visible = '''  List<Map<String, dynamic>> get visibleOrders {
    if (orderFilter == 'all') return orders;
    if (orderFilter == 'done') return orders.where((e) => ['completed', 'delivered'].contains('${e['status']}')).toList();
    if (orderFilter == 'cancelled') return orders.where((e) => ['cancelled', 'rejected'].contains('${e['status']}')).toList();
    return orders.where((e) => !isClosed(e)).toList();
  }
'''
if old_visible not in text:
    raise SystemExit('Flutter visibleOrders point not found')
new_visible = '''  List<Map<String, dynamic>> get groupedOrders => groupOrders(orders);

  List<Map<String, dynamic>> get visibleOrders {
    final grouped = groupedOrders;
    if (orderFilter == 'all') return grouped;
    if (orderFilter == 'done') return grouped.where((e) => ((e['_items'] as List).cast<Map<String, dynamic>>()).every((row) => ['completed', 'delivered'].contains('${row['status']}'))).toList();
    if (orderFilter == 'cancelled') return grouped.where((e) => ((e['_items'] as List).cast<Map<String, dynamic>>()).every((row) => ['cancelled', 'rejected'].contains('${row['status']}'))).toList();
    return grouped.where((e) => !isClosed(e)).toList();
  }
'''
text = text.replace(old_visible, new_visible, 1)
text = text.replace('      ...orders.take(5).map(_orderCard),', '      ...groupedOrders.take(5).map(_orderCard),', 1)
old_title = "              Text('${o['title'] ?? 'طلب'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),"
new_title = "              Text(number(o['_item_count']) > 1 ? 'طلب واحد • ${number(o['_item_count']).round()} مواد' : '${o['title'] ?? 'طلب'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),"
if old_title not in text:
    raise SystemExit('Flutter title point not found')
text = text.replace(old_title, new_title, 1)
old_divider = "          const Divider(),\n          _line('الطالب', '${o['student_name'] ?? '—'}'),"
new_divider = '''          const Divider(),
          if (number(o['_item_count']) > 1) ...[
            const Text('مواد الطلب', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF143B68))),
            const SizedBox(height: 6),
            ...((o['_items'] as List).cast<Map<String, dynamic>>()).asMap().entries.map((entry) {
              final item = entry.value;
              final qty = number(item['qty']) <= 0 ? 1 : number(item['qty']);
              return Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [Expanded(child: Text('${entry.key + 1}. ${item['title'] ?? 'مادة'}', style: const TextStyle(fontWeight: FontWeight.w700))), Text('× ${qty.round()} • ${money(item['total'])}', style: const TextStyle(fontWeight: FontWeight.w700))]));
            }),
            const Divider(),
          ],
          _line('الطالب', '${o['student_name'] ?? '—'}'),'''
if old_divider not in text:
    raise SystemExit('Flutter materials point not found')
text = text.replace(old_divider, new_divider, 1)
old_courier = "          if ('${o['courier_id'] ?? o['delegate_id'] ?? ''}'.isNotEmpty) _line('المندوب', '${o['courier_id'] ?? o['delegate_id']}'),"
new_courier = "          if ('${o['courier_id'] ?? o['delegate_id'] ?? ''}'.isNotEmpty) _line('المندوب', _courierName('${o['courier_id'] ?? o['delegate_id']}'))," 
if old_courier not in text:
    raise SystemExit('Flutter courier label point not found')
text = text.replace(old_courier, new_courier, 1)
insert = '  Widget _accounts() {'
if insert not in text:
    raise SystemExit('Flutter helper insertion point not found')
text = text.replace(insert, "  String _courierName(String id) {\n    for (final courier in couriers) {\n      if ('${courier['id']}' == id) return '${courier['name'] ?? id}';\n    }\n    return id;\n  }\n\n" + insert, 1)
text = text.replace("        title: const Text('تعيين مندوب'),", "        title: Text(number(order['_item_count']) > 1 ? 'تعيين مندوب للطلب كامل' : 'تعيين مندوب'),", 1)
text = text.replace("      _snack('تم تعيين المندوب');", "      _snack(number(order['_item_count']) > 1 ? 'تم تعيين المندوب لكل مواد الطلب' : 'تم تعيين المندوب');", 1)
p.write_text(text, encoding='utf-8')

# Bump Business app build.
p = Path('flutter_business/pubspec.yaml')
text = p.read_text(encoding='utf-8')
text, count = re.subn(r'^version:\s*1\.0\.1\+7\s*$', 'version: 1.0.1+8', text, flags=re.M)
if count == 0 and 'version: 1.0.1+8' not in text:
    raise SystemExit('Business version point not found')
p.write_text(text, encoding='utf-8')

print('Grouped courier admin UI patch applied.')
