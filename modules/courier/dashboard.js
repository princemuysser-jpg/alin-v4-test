// === courier/dashboard.js ===
/* ALIN v4.2.1 — courier dashboard with checkout-level delivery grouping. */
(function(){
  'use strict';
  const core=window.AlinCourierCore;if(!core)throw new Error('AlinCourierCore is required before courier/dashboard.js');
  const {$,$$,arr,escv,moneyv,now,notify,currentAccount,dbx,areasOf,statusOf,statusLabel,resolveCourier,allOrders,myOrders,done,active,today,financials,orderState,friendlyOrderError,mapLink,hasExactGps,phoneLink,waLink,fmtDate,transitionOrder,refreshCourierData,resetRefresh}=core;
  let renderSerial=0;
  const pendingOrders=new Set();

  const number=v=>{const n=Number(v);return Number.isFinite(n)?n:0};
  function groupKey(o){
    const group=String(o?.checkout_group_id||'').trim();
    if(group)return `group:${group}`;
    const request=String(o?.checkout_request_key||'').trim();
    if(request)return `request:${request}`;
    return `single:${String(o?.id||'')}`;
  }
  function itemRows(o){return Array.isArray(o?._items)&&o._items.length?o._items:[o]}
  function groupedOrders(rows){
    const groups=new Map();
    for(const row of arr(rows)){
      const key=groupKey(row);
      if(!groups.has(key))groups.set(key,[]);
      groups.get(key).push(row);
    }
    const result=[];
    for(const [key,items] of groups){
      items.sort((a,b)=>String(a.created_at||'').localeCompare(String(b.created_at||'')));
      const anchor=items.find(row=>number(row.delivery_fee)>0||number(row.courier_fee)>0||number(row.courier_profit)>0||number(row.delegate_profit)>0)||items[0];
      const statuses=new Set(items.map(row=>String(row.status||'assigned')));
      const combined={...anchor};
      combined._group_key=key;
      combined._items=items;
      combined._item_count=items.length;
      combined._qty_count=items.reduce((sum,row)=>sum+number(row.qty||1),0);
      combined._group_total=items.reduce((sum,row)=>sum+number(row.total),0);
      combined._delivery_fee=items.reduce((sum,row)=>sum+number(row.delivery_fee),0);
      combined._courier_fee=items.reduce((sum,row)=>{
        const value=row.courier_fee??row.courier_profit??row.delegate_profit??0;
        return sum+number(value);
      },0);
      combined._mixed_status=statuses.size>1;
      result.push(combined);
    }
    return result;
  }
  function isGrouped(o){return itemRows(o).length>1||String(o?.checkout_group_id||'').trim()||String(o?.checkout_request_key||'').trim()}
  function groupDone(o){return itemRows(o).every(done)}
  function groupActive(o){return itemRows(o).some(active)}
  function groupToday(o){return itemRows(o).some(row=>done(row)&&today(row))}
  function groupStatus(o){return String(o?.status||'assigned')}
  function groupTotal(o){return o?._group_total!=null?number(o._group_total):number(o?.total)}
  function groupCourierFee(o){
    if(o?._courier_fee!=null)return number(o._courier_fee);
    return number(o?.delegate_profit||o?.courier_profit||window.AlinFinance?.shares?.(o)?.delegate||0);
  }
  function groupDeliveryFee(o){return o?._delivery_fee!=null?number(o._delivery_fee):number(o?.delivery_fee)}

  function ensureTabs(){const nav=$('.courier-v161-tabs');if(!nav)return;const wanted=[['home','الرئيسية'],['current','طلبات التوصيل'],['completed','المكتملة'],['finance','الحسابات'],['receipts','الوصولات'],['notifications','الإشعارات'],['profile','حسابي']];nav.innerHTML=wanted.map(([key,label])=>key==='receipts'?`<button type="button" id="courierReceiptsTab" data-courier-tab="receipts" data-alin415-receipts-role="courier">${label}</button>`:`<button type="button" data-courier-tab="${key}" data-alin-click="renderCourierDashboard" data-alin-click-arg0="${key}">${label}${key==='current'?'<span id="courierCurrentBadge" hidden>0</span>':''}${key==='notifications'?'<span id="courierNotifyBadge" hidden>0</span>':''}</button>`).join('')}
  function notificationsFor(c){return window.AlinNotifications?.visible?.({role:'courier',id:String(c?.id||'')})||arr(dbx().notifications).filter(n=>String(n.courier_id||n.user_id||n.recipient_id||n.target_id||'')===String(c?.id)||['courier','delegate','all'].includes(String(n.target_role||n.role||n.audience||''))).sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')))}
  function setHeader(c,tab){
    const name=$('#courierV161Name'),areas=$('#courierV161Areas');
    if(name)name.textContent=c?.name||currentAccount()?.name||'المندوب';
    if(areas)areas.textContent=areasOf(c).join('، ')||'غير محددة';
    $$('.courier-v161-tabs [data-courier-tab]').forEach(b=>b.classList.toggle('active',b.dataset.courierTab===tab));
    const cb=$('#courierCurrentBadge'),nb=$('#courierNotifyBadge');
    const activeCount=groupedOrders(myOrders(c)).filter(groupActive).length;
    const unread=window.AlinNotifications?.unreadCount?.({role:'courier',id:String(c?.id||'')})??notificationsFor(c).filter(n=>!(n.read_at||n.is_read)).length;
    if(cb){cb.textContent=activeCount;cb.hidden=!activeCount}
    if(nb){nb.textContent=unread;nb.hidden=!unread}
  }
  function summary(c,rows){
    const f=financials(c);
    return `<section class="v174-metrics"><article><small>طلبات جديدة</small><strong>${rows.filter(o=>['assigned','new','pending_admin'].includes(groupStatus(o))).length}</strong></article><article><small>قيد التوصيل</small><strong>${rows.filter(o=>['accepted','picked_up','out_for_delivery','processing'].includes(groupStatus(o))).length}</strong></article><article><small>تم التسليم اليوم</small><strong>${rows.filter(groupToday).length}</strong></article><article><small>كل المكتملة</small><strong>${rows.filter(groupDone).length}</strong></article><article><small>أرباح التوصيل</small><strong>${moneyv(f.earnings)} د.ع</strong></article><article class="debt"><small>ذمتك للإدارة</small><strong>${moneyv(f.debt)} د.ع</strong></article></section>`
  }
  function homeHtml(c,rows){
    const currentRows=rows.filter(groupActive).slice(0,5),notes=notificationsFor(c).slice(0,4);
    return `${summary(c,rows)}<section class="v174-home-grid"><article class="v174-panel"><header><div><small>حالة العمل</small><h2>${statusLabel(statusOf(c))}</h2></div><span class="v174-status ${statusOf(c)}"></span></header><div class="v174-status-actions"><button data-alin-click="alinV174QuickStatus" data-alin-click-arg0="available">متاح</button><button data-alin-click="alinV174QuickStatus" data-alin-click-arg0="busy">مشغول</button><button data-alin-click="alinV174QuickStatus" data-alin-click-arg0="offline">خارج الخدمة</button></div><p>مناطق العمل: ${escv(areasOf(c).join('، ')||'غير محددة')}</p></article><article class="v174-panel"><header><div><small>طلبات تحتاج متابعة</small><h2>طلباتك الحالية</h2></div><button data-alin-click="renderCourierDashboard" data-alin-click-arg0="current">عرض الكل</button></header><div class="v174-mini-list">${currentRows.map(o=>`<button data-alin-click="renderCourierDashboard" data-alin-click-arg0="current"><b>${escv(o.order_number||o.id)}</b><span>${escv(window.alinNormalizeDeliveryArea(o.delivery_area)||'—')} • ${Number(o._item_count||1)} مادة</span><small>${escv(orderState(groupStatus(o)))}</small></button>`).join('')||'<p class="empty">لا توجد طلبات حالياً.</p>'}</div></article><article class="v174-panel wide"><header><div><small>آخر الإشعارات</small><h2>تنبيهات المندوب</h2></div><button data-alin-click="renderCourierDashboard" data-alin-click-arg0="notifications">عرض الإشعارات</button></header><div class="v174-mini-list">${notes.map(n=>`<div><b>${escv(n.title||'إشعار')}</b><span>${escv(n.message||n.body||'')}</span><small>${escv(fmtDate(n.created_at))}</small></div>`).join('')||'<p class="empty">لا توجد إشعارات جديدة.</p>'}</div></article></section>`
  }
  function variantLabel(o){return o?.product_variant_id?[o.product_variant_code,o.product_variant_name].filter(Boolean).join(' — '):[o?.product_variant_code,o?.product_variant_name].filter(Boolean).join(' — ')}
  function itemLabel(row){return String(row?.title||row?.product_name||row?.booklet_title||row?.kind||'مادة')}
  function itemsHtml(o){
    const items=itemRows(o);
    return `<div class="wide" style="grid-column:1/-1"><small>المواد (${items.length})</small><div style="display:grid;gap:6px;margin-top:7px">${items.map(row=>{const qty=Math.max(1,number(row.qty||1));const variant=variantLabel(row);const unit=number(row.unit_price);return `<div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start;padding:8px 10px;border-radius:10px;background:rgba(0,0,0,.035)"><span><b>${escv(itemLabel(row))}</b>${variant?`<small style="display:block;margin-top:3px">${escv(variant)}</small>`:''}</span><span style="white-space:nowrap">× ${qty}${unit>0?` • ${moneyv(unit)} د.ع`:''}</span></div>`}).join('')}</div></div>`
  }
  function orderCard(o,actions=true){
    const st=groupStatus(o),phone=o.student_phone||'',map=mapLink(o),exactGps=hasExactGps(o),first=['assigned','new','pending_admin'].includes(st),accepted=st==='accepted',picked=st==='picked_up',moving=st==='out_for_delivery';
    const itemCount=Number(o._item_count||1),qtyCount=number(o._qty_count||o.qty||1),deliveryFee=groupDeliveryFee(o),courierFee=groupCourierFee(o);
    return `<article class="v174-order" data-courier-order="${escv(o.id)}"><header><div><small>${escv(o.order_number||o.id)}</small><h3>طلب توصيل • ${itemCount} مادة • ${qtyCount} قطعة</h3>${o._mixed_status?'<small style="display:block;margin-top:4px">تتم معالجة حالة الطلب كاملة كمجموعة واحدة</small>':''}</div><span class="v174-order-state ${escv(st)}">${escv(orderState(st))}</span></header><div class="v174-order-data"><div><small>الطالب</small><b>${escv(o.student_name||'—')}</b></div><div><small>الهاتف</small><b>${escv(phone||'—')}</b></div><div><small>المنطقة</small><b>${escv(window.alinNormalizeDeliveryArea(o.delivery_area)||'—')}</b></div>${itemsHtml(o)}<div><small>المبلغ المطلوب</small><b>${moneyv(groupTotal(o))} د.ع</b></div>${deliveryFee>0?`<div><small>أجرة التوصيل على الطلب</small><b>${moneyv(deliveryFee)} د.ع</b></div>`:''}<div><small>ربح التوصيل</small><b>${moneyv(courierFee)} د.ع</b></div><div class="wide"><small>أقرب نقطة دالة</small><b>${escv(o.delivery_landmark||'—')}</b></div></div><div class="v174-links">${phone?`<a href="${phoneLink(phone)}">اتصال</a><a href="${waLink(phone)}" target="_blank" rel="noopener">واتساب</a>`:''}${map?`<button type="button" class="map" data-alin-click="alinCourierOpenMap" data-alin-click-arg0="${escv(o.id)}">${exactGps?'فتح الموقع GPS':'فتح النقطة على الخريطة'}</button>`:''}</div>${actions?`<div class="v174-actions">${first?`<button data-alin-click="alinV164CourierStep" data-alin-click-arg0="${escv(o.id)}" data-alin-click-arg1="accepted">قبول الطلب بالكامل</button><button class="reject" data-alin-click="alinV174Reject" data-alin-click-arg0="${escv(o.id)}">رفض الطلب بالكامل</button>`:''}${accepted?`<button data-alin-click="alinV164CourierStep" data-alin-click-arg0="${escv(o.id)}" data-alin-click-arg1="picked_up">استلمت الطلب بالكامل</button>`:''}${picked?`<button data-alin-click="alinV164CourierStep" data-alin-click-arg0="${escv(o.id)}" data-alin-click-arg1="out_for_delivery">بدء التوصيل</button>`:''}${moving?`<button class="success" data-alin-click="alinV164CourierComplete" data-alin-click-arg0="${escv(o.id)}">تم التسليم واستلام المبلغ</button>`:''}<button class="secondary" data-alin-click="alinV164ReportIssue" data-alin-click-arg0="${escv(o.id)}">إرسال ملاحظة للإدارة</button></div>`:`<footer>تم التسليم: ${escv(fmtDate(o.delivered_at||o.completed_at||o.updated_at))}</footer>`}</article>`
  }
  function ordersHtml(c,rows,completed=false){
    const list=rows.filter(completed?groupDone:groupActive);
    return `${summary(c,rows)}<section class="v174-head"><div><small>${completed?'سجل الإنجاز':'طلبات التوصيل'}</small><h2>${completed?'الطلبات المكتملة':'طلباتك الحالية'}</h2></div><span>${list.length}</span></section><div class="v174-orders">${list.map(o=>orderCard(o,!completed)).join('')||`<div class="empty">${completed?'لا توجد طلبات مكتملة بعد.':'لا توجد طلبات مسندة إليك حالياً.'}</div>`}</div>`
  }
  function financeHtml(c,rows){
    const f=financials(c),doneRows=rows.filter(groupDone);
    return `${summary(c,rows)}<section class="v164-finance-grid"><article><small>المبالغ المستلمة</small><strong>${moneyv(f.collected)} د.ع</strong></article><article><small>أرباح التوصيل</small><strong>${moneyv(f.earnings)} د.ع</strong></article><article><small>المسدّد للإدارة</small><strong>${moneyv(f.paid)} د.ع</strong></article><article class="debt"><small>المبلغ بذمتك</small><strong>${moneyv(f.debt)} د.ع</strong></article></section><section class="v164-table-card"><h2>كشف الطلبات المالية</h2><div class="v164-finance-list">${doneRows.map(o=>`<div><span>${escv(o.order_number||o.id)} • ${Number(o._item_count||1)} مادة</span><span>${moneyv(groupTotal(o))} د.ع</span><span>ربح التوصيل ${moneyv(groupCourierFee(o))} د.ع</span><span>${escv(fmtDate(o.delivered_at||o.updated_at))}</span></div>`).join('')||'<p class="empty">لا توجد حركات مالية بعد.</p>'}</div></section>`
  }
  function notificationsHtml(c,rows){const notes=notificationsFor(c);return `${summary(c,rows)}<section class="v164-section-head"><div><h2>إشعارات المندوب</h2><p>الطلبات الجديدة ورسائل الإدارة والتسويات.</p></div><button data-alin-click="alinV164CourierReadAll">تحديد الكل كمقروء</button></section><div class="v164-notifications">${notes.map(n=>{const read=window.AlinNotifications?.isRead?.(n,{role:'courier',id:String(c?.id||'')})??Boolean(n.read_at||n.is_read);return `<article class="${read?'read':''}"><div><h3>${escv(n.title||'إشعار')}</h3><p>${escv(n.message||n.body||'')}</p><small>${escv(fmtDate(n.created_at))}</small></div>${read?'':`<button data-alin-click="alinV164CourierRead" data-alin-click-arg0="${escv(n.id)}">مقروء</button>`}</article>`}).join('')||'<div class="empty">لا توجد إشعارات.</div>'}</div>`}
  function profileHtml(c,rows){return `${summary(c,rows)}<section class="v164-profile"><div class="v164-profile-head"><div class="v161-avatar">${escv((c.name||'م').slice(0,1))}</div><div><h2>${escv(c.name||'مندوب')}</h2><p>${escv(c.phone||currentAccount()?.phone||'بدون هاتف')}</p></div><span class="v161-status ${statusOf(c)}">${statusLabel(statusOf(c))}</span></div><div class="v164-profile-fields"><label>حالة العمل<select id="v161MyAvailability"><option value="available" ${statusOf(c)==='available'?'selected':''}>متاح</option><option value="busy" ${statusOf(c)==='busy'?'selected':''}>مشغول</option><option value="offline" ${statusOf(c)==='offline'?'selected':''}>خارج الخدمة</option></select></label><div><small>مناطق العمل</small><div class="v161-area-chips">${areasOf(c).map(a=>`<span>${escv(a)}</span>`).join('')||'<span>غير محددة</span>'}</div></div></div><button data-alin-click="alinV161SaveMyStatus">حفظ الحالة</button></section>`}
  function unavailableHtml(){return `<section class="v174-panel"><h2>تعذر ربط صفحة المندوب بالحساب</h2><p>اضغط إعادة المحاولة. إذا استمرت الحالة افتح حساب المندوب من لوحة المدير واحفظه مرة واحدة.</p><button data-alin-click="alinRefreshCourierPage">إعادة تحميل بيانات المندوب</button></section>`}
  async function renderCourierDashboard(tab='home',options={}){
    const serial=++renderSerial,box=$('#courierV161Content');if(!box)return false;
    ensureTabs();let c=resolveCourier();setHeader(c,tab);if(!c){box.innerHTML=unavailableHtml();return false}
    let rows=groupedOrders(myOrders(c));
    const paint=()=>{if(serial!==renderSerial)return;setHeader(c,tab);if(tab==='home')box.innerHTML=homeHtml(c,rows);else if(tab==='current')box.innerHTML=ordersHtml(c,rows,false);else if(tab==='completed')box.innerHTML=ordersHtml(c,rows,true);else if(tab==='finance')box.innerHTML=financeHtml(c,rows);else if(tab==='notifications')box.innerHTML=notificationsHtml(c,rows);else box.innerHTML=profileHtml(c,rows)};
    paint();
    if(options.refresh!==false){c=await refreshCourierData(Boolean(options.force));if(serial!==renderSerial)return true;if(!c){box.innerHTML=unavailableHtml();return false}rows=groupedOrders(myOrders(c));paint()}
    return true
  }

  function rawOrderById(id){return allOrders().find(row=>String(row.id)===String(id)||String(row.order_number)===String(id))||null}
  function rawGroupForId(id){
    const anchor=rawOrderById(id);if(!anchor)return[];
    const key=groupKey(anchor);return allOrders().filter(row=>groupKey(row)===key);
  }
  async function transitionCourierOrder(id,status,reason=''){
    const key=String(id);
    if(pendingOrders.has(key)){notify('العملية قيد التنفيذ');return false}
    pendingOrders.add(key);
    document.querySelectorAll(`[data-courier-order="${CSS.escape(key)}"] button`).forEach(button=>button.disabled=true);
    try{
      const rows=rawGroupForId(key),grouped=rows.length>1||rows.some(isGrouped);
      if(grouped){
        const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة تحديث الطلب غير متاحة');
        const {data,error}=await client.rpc('alin_order_transition_group',{p_order_id:key,p_status:String(status),p_reason:String(reason||'').trim()||null});
        if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم تحديث الطلب بالكامل');
      }else{
        await transitionOrder(key,status,reason);
      }
      await refreshCourierData(true);
      await renderCourierDashboard('current',{refresh:false});
      notify(status==='completed'?'تم تسجيل تسليم الطلب بالكامل والحسابات':'تم تحديث الطلب بالكامل');
      return true;
    }catch(error){console.error('[ALIN courier group transition]',error);notify(friendlyOrderError(error));return false}
    finally{pendingOrders.delete(key)}
  }
  window.alinV164CourierStep=async function(id,status){return transitionCourierOrder(id,status)};
  window.alinV164CourierComplete=async function(id){if(!confirm('تأكيد تسليم الطلب بالكامل واستلام المبلغ من الطالب؟'))return false;return transitionCourierOrder(id,'completed')};
  window.alinV164ReportIssue=async function(id){
    const note=(prompt('اكتب الملاحظة أو المشكلة لإرسالها إلى الإدارة')||'').trim();if(!note)return false;
    try{
      const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة إرسال الملاحظة غير متاحة');
      const rows=rawGroupForId(id),grouped=rows.length>1||rows.some(isGrouped);
      const rpcName=grouped?'alin_courier_set_order_note_group':'alin_courier_set_order_note';
      const {data,error}=await client.rpc(rpcName,{p_order_id:String(id),p_note:note});
      if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم حفظ الملاحظة');
      await refreshCourierData(true);await renderCourierDashboard('current',{refresh:false});notify(grouped?'تم إرسال الملاحظة لكل الطلب':'تم إرسال الملاحظة للإدارة');return true;
    }catch(error){console.error('[ALIN courier note]',error);notify(friendlyOrderError(error));return false}
  };
  window.alinV174Reject=async function(id){const reason=(prompt('اكتب سبب رفض الطلب بالكامل')||'').trim();if(!reason)return false;if(!confirm('تأكيد رفض الطلب بالكامل؟'))return false;return transitionCourierOrder(id,'rejected',reason)};
  window.alinV174QuickStatus=async function(value){const c=resolveCourier();if(!c)return false;try{const client=window.sb||window.AlinCloud?.client?.();if(!client?.rpc)throw new Error('خدمة تحديث حالة المندوب غير متاحة');const {data,error}=await client.rpc('alin_courier_set_availability',{p_value:String(value||'')});if(error)throw error;if(!data?.ok)throw new Error(data?.error||'لم يؤكد الخادم تحديث الحالة');if(data.courier)Object.assign(c,data.courier);else c.availability=value;await refreshCourierData(true);await renderCourierDashboard('home',{refresh:false});notify('تم تحديث حالة المندوب');return true}catch(error){alert(error.message||'تعذر تحديث الحالة');return false}};
  window.alinV161SaveMyStatus=async function(){return window.alinV174QuickStatus($('#v161MyAvailability')?.value||'available')};
  window.alinV161CourierStatus=window.alinV164CourierStep;
  window.alinV164CourierRead=async function(id){try{const c=resolveCourier();if(window.AlinNotifications?.markRead)await window.AlinNotifications.markRead(id,{role:'courier',id:String(c?.id||'')});else await update('notifications',{is_read:true,read_at:now()},{id});await renderCourierDashboard('notifications',{refresh:false})}catch(error){alert(error.message||'تعذر تحديث الإشعار')}};
  window.alinV164CourierReadAll=async function(){const c=resolveCourier();if(window.AlinNotifications?.markAll)await window.AlinNotifications.markAll({role:'courier',id:String(c?.id||'')});await renderCourierDashboard('notifications',{refresh:false})};
  window.alinRefreshCourierPage=async function(){resetRefresh();const box=$('#courierV161Content');if(box)box.innerHTML='<div class="empty">جاري تحميل بيانات المندوب والطلبات...</div>';await refreshCourierData(true);return renderCourierDashboard('home',{refresh:false})};

  window.renderCourierDashboard=renderCourierDashboard;
  window.AlinCourierDashboard=Object.freeze({version:window.ALIN_CONFIG?.version||'4.2.1',resolveCourier,myOrders,groupedOrders,refreshCourierData,render:renderCourierDashboard});

  window.addEventListener('alin:page-open',event=>{if(event.detail?.page==='courier')renderCourierDashboard('home',{force:true})});
  window.addEventListener('alin:data-refreshed',()=>{if($('#courierPage:not(.hidden)'))renderCourierDashboard($('.courier-v161-tabs .active')?.dataset.courierTab||'home',{refresh:false})});
  window.addEventListener('alin:auth-login',event=>{if(event.detail?.account?.role==='courier')setTimeout(()=>renderCourierDashboard('home',{force:true}),0)});
  window.addEventListener('alin:auth-restored',event=>{if(event.detail?.account?.role==='courier')setTimeout(()=>renderCourierDashboard('home',{force:true}),0)});
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ensureTabs,{once:true});else ensureTabs();
})();

;
