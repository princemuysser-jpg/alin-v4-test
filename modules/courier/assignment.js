// === courier/assignment.js ===
/* ALIN v4.1.2 — one authoritative admin assignment path. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/assignment.js');
  const {$,escv,moneyv,notify,allOrders,active,done,matchingCouriers,allCouriers,mapLink,hasExactGps,orderState,statusLabel,statusOf,activeLoad,friendlyOrderError,assignOrder,transitionOrder}=core;
  const pending=new Set();

  function deliveryOrders(){return allOrders().filter(o=>o.fulfillment_type==='home_delivery'||o.delivery_type==='courier')}
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
  function variantLabel(o){return o?.product_variant_id?[o.product_variant_code,o.product_variant_name].filter(Boolean).join(' — '):''}
  function deliveryPricingControls(o,locked){
    const mode=String(o?.delivery_pricing_mode||'area');
    const labels={area:'سعر المنطقة',free:'مجاني للطالب',custom:'مبلغ خاص'};
    return `<section class="v126-assign alin-v430-pricing v164-delivery-pricing"><h4>تسعير التوصيل</h4><div class="v126-detail-grid"><div><small>الوضع</small><b>${escv(labels[mode]||mode)}</b></div><div><small>على الطالب</small><b>${moneyv(o.delivery_fee||0)} د.ع</b></div><div><small>أجرة المندوب</small><b>${moneyv(o.courier_fee??0)} د.ع</b></div></div>${locked?'<small>الحساب مقفول بعد إكمال/إلغاء الطلب.</small>':`<div class="v126-detail-actions"><button data-alin-click="alinV430AreaPricing" data-alin-click-arg0="${escv(o.id)}">سعر المنطقة</button><button data-alin-click="alinV430FreePricing" data-alin-click-arg0="${escv(o.id)}">توصيل مجاني</button><button class="secondary" data-alin-click="alinV430CustomPricing" data-alin-click-arg0="${escv(o.id)}">مبلغ خاص</button></div>`}</section>`;
  }
  function setBusy(id,value){const key=String(id);if(value)pending.add(key);else pending.delete(key);document.querySelectorAll(`[data-order-action="${CSS.escape(key)}"]`).forEach(button=>button.disabled=value)}
  function renderDeliveryOrdersAdmin(){
    const rows=groupedDeliveryOrders();
    adminContent.innerHTML=`<section class="v164-admin-couriers"><header class="v164-admin-head"><div><small>توزيع الطلبات</small><h2>طلبات التوصيل</h2><p>اختيار المندوب حسب المنطقة مع تحديث الطلب من الخادم بمسار واحد.</p></div><button data-alin-click="renderCouriersAdmin">إدارة المندوبين</button></header><section class="v164-admin-metrics"><article><small>كل طلبات التوصيل</small><strong>${rows.length}</strong></article><article><small>بانتظار التعيين</small><strong>${rows.filter(o=>!groupAssignedId(o)).length}</strong></article><article><small>قيد التوصيل</small><strong>${rows.filter(o=>groupActive(o)&&groupAssignedId(o)).length}</strong></article><article><small>مكتملة</small><strong>${rows.filter(groupDone).length}</strong></article></section><div class="v164-delivery-admin-list">${rows.map(deliveryAdminCard).join('')||'<div class="empty">لا توجد طلبات توصيل.</div>'}</div></section>`;
  }
  function deliveryAdminCard(o){
    const area=window.alinNormalizeDeliveryArea(o.delivery_area)||'غير محددة';
    const matches=matchingCouriers(area);
    const assignedId=groupAssignedId(o);
    const assigned=allCouriers().find(c=>[c.id,c.account_id,c.courier_row_id].filter(Boolean).map(String).includes(String(assignedId)));
    const map=mapLink(o),exactGps=hasExactGps(o),locked=groupLocked(o);
    return `<article class="v164-delivery-admin-card"><header><div><small>${escv(o.order_number||o.id)}</small><h3>طلب توصيل واحد • ${Number(o._item_count||1)} مواد</h3><small>${Number(o._qty_count||1)} قطعة/نسخة</small></div><span>${escv(area)}</span></header>${o.delivery_note?`<div class="v164-issue">ملاحظة المندوب: ${escv(o.delivery_note)}</div>`:''}<div class="v164-order-grid"><div><small>الطالب</small><b>${escv(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${escv(o.student_phone||'—')}</b></div><div class="wide"><small>أقرب نقطة دالة</small><b>${escv(o.delivery_landmark||'—')}</b></div><div><small>الإجمالي الكلي</small><b>${moneyv(o.total)} د.ع</b></div><div><small>أجرة التوصيل</small><b>${moneyv(o.delivery_fee||0)} د.ع</b></div><div><small>أجرة المندوب</small><b>${moneyv(o.courier_fee||0)} د.ع</b></div><div><small>الحالة</small><b>${o._mixed_status?'حالات متعددة':escv(orderState(o.status))}</b></div></div>${materialsHtml(o)}${map?`<button type="button" class="v164-map-btn" data-alin-click="alinCourierOpenMap" data-alin-click-arg0="${escv(o.id)}">${exactGps?'فتح موقع الطالب GPS':'فتح النقطة الدالة على الخريطة'}</button>`:''}${deliveryPricingControls(o,locked)}<div class="v164-match-list"><h4>تعيين مندوب للطلب كامل (${matches.length} متاح)</h4>${matches.map(c=>`<label><input type="radio" name="v216assign_${escv(o.id)}" value="${escv(c.id)}" ${assigned&&String(assigned.id)===String(c.id)?'checked':''} ${locked?'disabled':''}><span><b>${escv(c.name)}</b><small>${statusLabel(statusOf(c))} • ${groupedCourierLoad(c)} طلب حالي • ${escv(c.phone||'')}</small></span></label>`).join('')||'<p class="warning-text">لا يوجد مندوب مرتبط بهذه المنطقة.</p>'}</div><footer><button data-order-action="${escv(o.id)}" ${locked||!matches.length?'disabled':''} data-alin-click="alinV164Assign" data-alin-click-arg0="${escv(o.id)}">${assigned?'حفظ المندوب للطلب كامل':'تحويل الطلب كامل للمندوب'}</button>${assigned&&!locked?`<button class="secondary" data-order-action="${escv(o.id)}" data-alin-click="alinV410Unassign" data-alin-click-arg0="${escv(o.id)}">إلغاء تعيين الطلب كامل</button>`:''}${assigned?`<span>المندوب الحالي: <b>${escv(assigned.name)}</b></span>`:'<span>لم يتم تعيين مندوب</span>'}</footer></article>`;
  }
  async function runAssignment(id,courierId){
    const key=String(id);if(pending.has(key)){notify('العملية قيد التنفيذ');return false}
    setBusy(key,true);
    try{
      const result=await assignOrder(key,courierId||null,null);
      if(typeof audit==='function')await audit('courier',courierId?`تحويل الطلب ${key} إلى المندوب ${courierId}`:`إلغاء تعيين المندوب عن الطلب ${key}`);
      renderDeliveryOrdersAdmin();
      notify(courierId?'تم تحويل الطلب للمندوب':'تم إلغاء تعيين المندوب');
      return result;
    }catch(error){console.error('[ALIN courier assignment v4.1.2]',error);notify(friendlyOrderError(error));return false}
    finally{setBusy(key,false)}
  }
  window.alinV164Assign=async function(id){
    const selected=document.querySelector(`input[name="v216assign_${CSS.escape(String(id))}"]:checked`)?.value;
    if(!selected){notify('اختر مندوباً أولاً');return false}
    return runAssignment(id,selected);
  };
  window.alinV410Unassign=async function(id){if(!confirm('تأكيد إلغاء تعيين المندوب عن الطلب؟'))return false;return runAssignment(id,null)};
  window.alinV161AssignOrder=window.alinV164Assign;

  async function assignCourier(id){
    const selected=$(`#assign_${CSS.escape(String(id))}`)?.value||null;
    const result=await runAssignment(id,selected);
    if(result&&typeof renderCourierSettlementsAdmin==='function')renderCourierSettlementsAdmin();
    return Boolean(result);
  }
  async function courierOrderStatus(id,status){
    const key=String(id);if(pending.has(key)){notify('العملية قيد التنفيذ');return false}
    setBusy(key,true);
    try{
      await transitionOrder(key,status);
      if(typeof renderCourierSettlementsAdmin==='function')renderCourierSettlementsAdmin();
      notify('تم تحديث حالة الطلب');
      return true;
    }catch(error){console.error('[ALIN courier status admin v4.1.2]',error);notify(friendlyOrderError(error));return false}
    finally{setBusy(key,false)}
  }

  window.renderDeliveryOrdersAdmin=renderDeliveryOrdersAdmin;
  window.assignCourier=assignCourier;
  window.courierOrderStatus=courierOrderStatus;
  Object.assign(window.AlinCourierModules,{assignCourier,courierOrderStatus,renderDeliveryOrdersAdmin});
  window.AlinAdminModules?.register?.('deliveryOrders',renderDeliveryOrdersAdmin);
})();

;
