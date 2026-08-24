/* ALIN teacher order delivery label fix — display only; no finance/order mutation. */
(function(){
  'use strict';
  if(window.__ALIN_TEACHER_ORDER_DELIVERY_FIX__)return;
  window.__ALIN_TEACHER_ORDER_DELIVERY_FIX__=true;

  const arr=v=>Array.isArray(v)?v:[];
  const same=(a,b)=>String(a??'')===String(b??'');
  const escText=v=>String(v??'').trim();

  function teacherData(){
    try{return window.TeacherApp?.data?.()||null}catch(_){return null}
  }

  function courierRows(){return arr(window.db?.accounts?.couriers||window.db?.couriers)}
  function libraryRows(){return arr(window.db?.accounts?.libraries)}

  function isCourier(order){
    const fulfillment=String(order?.fulfillment_type||'').toLowerCase();
    const deliveryType=String(order?.delivery_type||'').toLowerCase();
    return fulfillment==='home_delivery'||deliveryType==='courier'||Boolean(order?.courier_id||order?.delegate_id);
  }

  function deliveryLabel(order){
    if(isCourier(order)){
      const courierId=order?.courier_id||order?.delegate_id||'';
      const courier=courierRows().find(row=>same(row.id,courierId));
      return courier?.name?`التوصيل: مندوب — ${escText(courier.name)}`:'التوصيل: مندوب';
    }
    const library=libraryRows().find(row=>same(row.id,order?.library_id));
    return `الاستلام: مكتبة — ${escText(library?.name||'-')}`;
  }

  function orderForCard(card,orders){
    const title=card.querySelector('h4')?.textContent||'';
    const number=title.split('—')[0]?.trim()||'';
    return orders.find(order=>same(order.order_number||order.id,number));
  }

  function fixCards(){
    const page=document.getElementById('teacherPage');
    if(!page||page.classList.contains('hidden'))return;
    const host=document.getElementById('teacherV154Orders');
    if(!host)return;
    const data=teacherData();
    const orders=arr(data?.orders);
    if(!orders.length)return;

    host.querySelectorAll('.teacher-v154-order').forEach(card=>{
      const order=orderForCard(card,orders);
      if(!order)return;
      const small=card.querySelector('div > small');
      if(!small)return;
      const qty=Number(order.qty)||1;
      const date=String(order.created_at||'').slice(0,10)||'-';
      const label=deliveryLabel(order);
      const next=`النسخ: ${qty} • ${label} • ${date}`;
      if(small.textContent!==next)small.textContent=next;
      card.dataset.delivery=isCourier(order)?'courier':'library';
    });
  }

  let scheduled=false;
  function schedule(){
    if(scheduled)return;
    scheduled=true;
    requestAnimationFrame(()=>{scheduled=false;fixCards()});
  }

  function start(){
    const target=document.getElementById('teacherContent');
    if(target){new MutationObserver(schedule).observe(target,{childList:true,subtree:true})}
    schedule();
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
  ['alin:role-runtime-ready','alin:data-refreshed','alin:page-open','alin:teacher-rendered'].forEach(type=>window.addEventListener(type,schedule));
  window.AlinTeacherOrderDeliveryFix=Object.freeze({apply:fixCards});
})();
