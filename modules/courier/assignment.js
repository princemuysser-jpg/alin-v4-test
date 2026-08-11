// === courier/assignment.js ===
/* ALIN v4.1.2 — one authoritative admin assignment path. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/assignment.js');
  const {$,escv,moneyv,notify,allOrders,active,done,matchingCouriers,allCouriers,mapLink,hasExactGps,orderState,statusLabel,statusOf,activeLoad,friendlyOrderError,assignOrder,transitionOrder}=core;
  const pending=new Set();

  function deliveryOrders(){return allOrders().filter(o=>o.fulfillment_type==='home_delivery'||o.delivery_type==='courier')}
  function setBusy(id,value){const key=String(id);if(value)pending.add(key);else pending.delete(key);document.querySelectorAll(`[data-order-action="${CSS.escape(key)}"]`).forEach(button=>button.disabled=value)}
  function renderDeliveryOrdersAdmin(){
    const rows=deliveryOrders();
    adminContent.innerHTML=`<section class="v164-admin-couriers"><header class="v164-admin-head"><div><small>توزيع الطلبات</small><h2>طلبات التوصيل</h2><p>اختيار المندوب حسب المنطقة مع تحديث الطلب من الخادم بمسار واحد.</p></div><button data-alin-click="renderCouriersAdmin">إدارة المندوبين</button></header><section class="v164-admin-metrics"><article><small>كل طلبات التوصيل</small><strong>${rows.length}</strong></article><article><small>بانتظار التعيين</small><strong>${rows.filter(o=>!o.courier_id&&!o.delegate_id).length}</strong></article><article><small>قيد التوصيل</small><strong>${rows.filter(o=>active(o)&&(o.courier_id||o.delegate_id)).length}</strong></article><article><small>مكتملة</small><strong>${rows.filter(done).length}</strong></article></section><div class="v164-delivery-admin-list">${rows.map(deliveryAdminCard).join('')||'<div class="empty">لا توجد طلبات توصيل.</div>'}</div></section>`;
  }
  function deliveryAdminCard(o){
    const area=window.alinNormalizeDeliveryArea(o.delivery_area)||'غير محددة';
    const matches=matchingCouriers(area);
    const assigned=allCouriers().find(c=>String(c.id)===String(o.courier_id||o.delegate_id||''));
    const map=mapLink(o),exactGps=hasExactGps(o),locked=done(o)||['cancelled','rejected'].includes(String(o.status||''));
    return `<article class="v164-delivery-admin-card"><header><div><small>${escv(o.order_number||o.id)}</small><h3>${escv(o.title||'طلب توصيل')}</h3></div><span>${escv(area)}</span></header>${o.delivery_note?`<div class="v164-issue">ملاحظة المندوب: ${escv(o.delivery_note)}</div>`:''}<div class="v164-order-grid"><div><small>الطالب</small><b>${escv(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${escv(o.student_phone||'—')}</b></div><div class="wide"><small>أقرب نقطة دالة</small><b>${escv(o.delivery_landmark||'—')}</b></div><div><small>المبلغ</small><b>${moneyv(o.total)} د.ع</b></div><div><small>الحالة</small><b>${escv(orderState(o.status))}</b></div></div>${map?`<button type="button" class="v164-map-btn" data-alin-click="alinCourierOpenMap" data-alin-click-arg0="${escv(o.id)}">${exactGps?'فتح موقع الطالب GPS':'فتح النقطة الدالة على الخريطة'}</button>`:''}<div class="v164-match-list"><h4>المندوبون المطابقون للمنطقة (${matches.length})</h4>${matches.map(c=>`<label><input type="radio" name="v216assign_${escv(o.id)}" value="${escv(c.id)}" ${assigned&&String(assigned.id)===String(c.id)?'checked':''} ${locked?'disabled':''}><span><b>${escv(c.name)}</b><small>${statusLabel(statusOf(c))} • ${activeLoad(c)} طلب حالي • ${escv(c.phone||'')}</small></span></label>`).join('')||'<p class="warning-text">لا يوجد مندوب مرتبط بهذه المنطقة.</p>'}</div><footer><button data-order-action="${escv(o.id)}" ${locked||!matches.length?'disabled':''} data-alin-click="alinV164Assign" data-alin-click-arg0="${escv(o.id)}">${assigned?'حفظ المندوب':'تحويل للمندوب'}</button>${assigned&&!locked?`<button class="secondary" data-order-action="${escv(o.id)}" data-alin-click="alinV410Unassign" data-alin-click-arg0="${escv(o.id)}">إلغاء التعيين</button>`:''}${assigned?`<span>المندوب الحالي: <b>${escv(assigned.name)}</b></span>`:'<span>لم يتم تعيين مندوب</span>'}</footer></article>`;
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
