// === admin/retention.js ===
/* ALIN v4.2.0 UI9 — unified customer directory: all / active / inactive + private offers. */
(function(){
  'use strict';
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const client=()=>window.sb||window.AlinCloud?.client?.()||null;
  const state={days:30,mode:'all',search:'',rows:[],stats:{registered:0,active:0,inactive:0},loading:false};
  async function rpc(name,args={}){const c=client();if(!c?.rpc)throw new Error('الاتصال بقاعدة البيانات غير متاح');const {data,error}=await c.rpc(name,args);if(error)throw error;return data}
  const fmtDate=v=>v?new Date(v).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ'):'—';
  const offerLabel=row=>row.active_offer_code?`<span class="alin-retention-offer-live">عرض فعال: <b>${esc(row.active_offer_code)}</b></span>`:'<span class="alin-retention-offer-none">لا يوجد عرض فعال</span>';
  const activityLabel=row=>row.is_active?'<span class="alin-retention-state is-active">نشط</span>':'<span class="alin-retention-state is-inactive">غير نشط</span>';
  function card(row){
    const days=Math.max(0,Number(row.days_inactive||0));
    const activityText=row.is_active?(days===0?'نشط اليوم':`آخر نشاط قبل ${days} يوم`):`${days} يوم بدون نشاط`;
    return `<article class="alin-retention-card"><div class="alin-retention-person"><div class="alin-retention-avatar">${esc((row.name||'ط').trim().slice(0,1))}</div><div><div class="alin-retention-name-line"><h3>${esc(row.name||'طالب')}</h3>${activityLabel(row)}</div><p>${esc(row.phone||'')}</p><small>${row.grade?`المرحلة: ${esc(row.grade)} • `:''}الطلبات: ${Number(row.order_count||0)}</small></div></div><div class="alin-retention-meta"><span class="alin-retention-days">${esc(activityText)}</span><small>آخر نشاط: ${esc(fmtDate(row.last_active_at||row.last_login_at||row.created_at))}</small>${offerLabel(row)}</div><div class="alin-retention-actions"><button type="button" data-alin-click="AlinRetentionAdmin.offer" data-alin-click-arg0="${esc(row.id)}" data-alin-click-arg1="${encodeURIComponent(String(row.name||'طالب'))}">${row.active_offer_code?'إرسال عرض جديد':'إرسال عرض خاص'}</button></div></article>`
  }
  function modeButton(mode,label,count){return `<button type="button" class="${state.mode===mode?'active':''}" data-alin-click="AlinRetentionAdmin.changeMode" data-alin-click-arg0="${mode}">${label}<b>${Number(count||0)}</b></button>`}
  function render(host=document.getElementById('adminContent')){
    if(!host)return;
    const title=state.mode==='active'?'العملاء النشطون':state.mode==='inactive'?'العملاء غير النشطين':'جميع العملاء';
    host.innerHTML=`<section class="alin-retention-admin"><header class="alin-retention-head"><div><small>إدارة العملاء والعروض</small><h2>${title}</h2><p>يعتمد التصنيف على آخر نشاط فعلي للحساب خلال الفترة المحددة.</p></div><button type="button" class="secondary" data-alin-click="AlinRetentionAdmin.reload">تحديث</button></header><section class="alin-retention-stats"><article><small>إجمالي الحسابات المسجلة</small><b>${Number(state.stats.registered||0)}</b></article><article><small>العملاء النشطون</small><b>${Number(state.stats.active||0)}</b></article><article><small>العملاء غير النشطين</small><b>${Number(state.stats.inactive||0)}</b></article></section><div class="alin-retention-mode-tabs">${modeButton('all','الكل',state.stats.registered)}${modeButton('active','النشطون',state.stats.active)}${modeButton('inactive','غير النشطين',state.stats.inactive)}</div><div class="alin-retention-tools"><select id="alinRetentionDays" data-alin-change="AlinRetentionAdmin.changeDays" data-alin-change-arg0-source="value"><option value="7" ${state.days===7?'selected':''}>آخر 7 أيام</option><option value="15" ${state.days===15?'selected':''}>آخر 15 يوم</option><option value="30" ${state.days===30?'selected':''}>آخر 30 يوم</option><option value="60" ${state.days===60?'selected':''}>آخر 60 يوم</option><option value="90" ${state.days===90?'selected':''}>آخر 90 يوم</option></select><input id="alinRetentionSearch" value="${esc(state.search)}" placeholder="بحث بالاسم أو رقم الهاتف"><button type="button" data-alin-click="AlinRetentionAdmin.search">بحث</button></div><div id="alinRetentionList" class="alin-retention-list">${state.loading?'<div class="empty">جاري تحميل الحسابات...</div>':state.rows.length?state.rows.map(card).join(''):'<div class="empty">لا توجد حسابات مطابقة لهذا الفلتر حالياً.</div>'}</div></section>`;
  }
  async function load(){state.loading=true;render();try{const data=await rpc('alin_admin_student_customers',{p_days:state.days,p_mode:state.mode,p_search:state.search||null});state.rows=Array.isArray(data?.rows)?data.rows:[];state.stats=data?.stats||{registered:0,active:0,inactive:0}}catch(error){window.toast?.(error.message||'تعذر تحميل العملاء');state.rows=[]}finally{state.loading=false;render()}}
  function closeOffer(){document.getElementById('alinRetentionOfferModal')?.remove()}
  function offer(id,encodedName){
    const name=decodeURIComponent(String(encodedName||''));closeOffer();
    const modal=document.createElement('div');modal.id='alinRetentionOfferModal';modal.className='alin-retention-modal';
    modal.innerHTML=`<button class="alin-retention-backdrop" type="button" data-alin-click="AlinRetentionAdmin.closeOffer" aria-label="إغلاق"></button><section class="alin-retention-dialog" role="dialog" aria-modal="true"><header><div><small>عرض خاص للعميل</small><h3>${esc(name)}</h3><p>سيصل للعميل بعنوان واضح «عرض خاص لك»، والكود يعمل لهذا الحساب فقط ولمرة واحدة.</p></div><button type="button" class="secondary" data-alin-click="AlinRetentionAdmin.closeOffer">×</button></header><div class="alin-retention-offer-form"><label><span>نوع الخصم</span><select id="alinRetentionOfferType"><option value="percent">نسبة مئوية %</option><option value="fixed">مبلغ ثابت د.ع</option></select></label><label><span>قيمة الخصم</span><input id="alinRetentionOfferValue" type="number" min="1" value="10"></label><label><span>الصلاحية</span><select id="alinRetentionOfferDays"><option value="1">يوم واحد</option><option value="3" selected>3 أيام</option><option value="7">7 أيام</option><option value="14">14 يوم</option></select></label><label><span>يشمل</span><select id="alinRetentionOfferScope"><option value="all">كل المتجر</option><option value="booklet">الملازم</option><option value="stationery">القرطاسية</option><option value="gift">الهدايا</option></select></label></div><div class="alin-retention-special-note"><b>ما سيشاهده العميل:</b><span>عرض خاص لك من منصة آلين 🎁 — خصم مخصص لحسابك فقط.</span></div><div id="alinRetentionOfferMsg"></div><footer><button type="button" class="secondary" data-alin-click="AlinRetentionAdmin.closeOffer">إلغاء</button><button type="button" data-alin-click="AlinRetentionAdmin.sendOffer" data-alin-click-arg0="${esc(id)}">إرسال العرض</button></footer></section>`;
    document.body.appendChild(modal);
  }
  async function sendOffer(id){
    const msg=document.getElementById('alinRetentionOfferMsg'),type=document.getElementById('alinRetentionOfferType')?.value||'percent',value=Number(document.getElementById('alinRetentionOfferValue')?.value||0),days=Number(document.getElementById('alinRetentionOfferDays')?.value||3),applies=document.getElementById('alinRetentionOfferScope')?.value||'all';
    if(value<=0){if(msg)msg.textContent='اكتب قيمة خصم صحيحة';return}if(type==='percent'&&value>100){if(msg)msg.textContent='النسبة لا تتجاوز 100%';return}
    try{
      if(msg)msg.textContent='جاري إنشاء العرض...';
      const discountText=type==='percent'?`${value}%`:`${value.toLocaleString('ar-IQ')} د.ع`;
      const offerTitle='عرض خاص لك من منصة آلين 🎁';
      const offerMessage=`هذا عرض خاص مخصص لحسابك فقط: خصم ${discountText} صالح لمدة ${days} ${days===1?'يوم':'أيام'}. افتح منصة آلين واستخدم العرض قبل انتهاء الصلاحية.`;
      const data=await rpc('alin_admin_create_student_offer',{p_student_id:id,p_discount_type:type,p_discount_value:value,p_days_valid:days,p_applies_to:applies,p_title:offerTitle,p_message:offerMessage});
      let push=null;
      try{
        const invoke=window.ALINAuthRuntime?.invokeAdmin;
        if(typeof invoke==='function')push=await invoke('admin-send-push',{title:data?.coupon?.offer_title||'عرض خاص لك من منصة آلين 🎁',message:data?.coupon?.offer_message||`عندك خصم خاص. الكود ${data?.coupon?.code||''}`,role:'student',target_id:id,url:'./store-mobile.html'});
      }catch(pushError){console.warn('[ALIN retention push]',pushError)}
      closeOffer();
      window.toast?.(`تم إرسال العرض — الكود ${data?.coupon?.code||''}${push?.sent?` — Push إلى ${push.sent} جهاز`:''}`);
      await load();
    }catch(error){if(msg)msg.textContent=error.message||'تعذر إرسال العرض'}
  }
  function ensureTab(){document.querySelectorAll('#adminPage .admin-tabs').forEach(tabs=>{if(tabs.querySelector('[data-admin-tab="retention"]'))return;const b=document.createElement('button');b.type='button';b.dataset.adminTab='retention';b.setAttribute('data-alin-click','adminTab');b.setAttribute('data-alin-click-arg0','retention');b.textContent='العملاء';const coupons=tabs.querySelector('[data-admin-tab="coupons"]');tabs.insertBefore(b,coupons||null)})}
  const api={render,load,reload:load,offer,sendOffer,closeOffer,changeDays(v){state.days=Math.max(1,Number(v)||30);load()},changeMode(v){state.mode=['all','active','inactive'].includes(String(v))?String(v):'all';load()},search(){state.search=document.getElementById('alinRetentionSearch')?.value.trim()||'';load()}};
  window.AlinRetentionAdmin=api;
  function boot(){ensureTab();if(window.AlinAdminModules?.register)window.AlinAdminModules.register('retention',()=>load())}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();
