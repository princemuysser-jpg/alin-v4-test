// === core/order-attention.js ===
/* ALIN v4.2 Stable — unified new-order attention for admin, library and courier. */
(function(){
  'use strict';
  if(window.__ALIN_ORDER_ATTENTION__)return;
  window.__ALIN_ORDER_ATTENTION__=true;

  const VERSION='4.2.0';
  const POLL_MS=6000;
  const READ_PREFIX='alin_order_attention_read_v1';
  let pollBusy=false;
  let lastSignature='';
  let uiQueued=false;

  const text=value=>String(value??'').trim();
  const arr=value=>Array.isArray(value)?value:[];
  const role=()=>{
    const value=text(window.current?.role).toLowerCase();
    return ['admin','library','courier'].includes(value)?value:'';
  };
  const orderId=order=>text(order?.id||order?.order_id||order?.order_number||order?.tracking_code);
  const status=order=>text(order?.status||'new').toLowerCase();

  function loadStyle(){
    if(document.getElementById('alinOrderAttentionCss'))return;
    const link=document.createElement('link');
    link.id='alinOrderAttentionCss';
    link.rel='stylesheet';
    link.href=`./styles/alin-order-attention.css?v=${encodeURIComponent(window.ALIN_CONFIG?.assetVersion||VERSION)}`;
    document.head.appendChild(link);
  }
  loadStyle();

  function accountIds(currentRole=role()){
    const current=window.current||{};
    const ids=new Set([
      current.id,current.account_id,current.library_id,current.courier_id,current.delegate_id,
      current.auth_user_id,current.user_id,current.username
    ].filter(Boolean).map(text));
    const sources=currentRole==='library'?
      [...arr(window.db?.accounts?.libraries),...arr(window.db?.libraries)]:
      currentRole==='courier'?
      [...arr(window.db?.accounts?.couriers),...arr(window.db?.couriers),...arr(window.couriers)]:[];
    for(const item of sources){
      const related=[item?.id,item?.account_id,item?.library_id,item?.library_row_id,item?.courier_id,item?.courier_row_id,item?.user_id,item?.auth_user_id,item?.username].filter(Boolean).map(text);
      if(related.some(id=>ids.has(id)))related.forEach(id=>ids.add(id));
    }
    return ids;
  }

  function relevant(order,currentRole=role()){
    if(!order||!currentRole)return false;
    if(currentRole==='admin')return true;
    const ids=accountIds(currentRole);
    if(currentRole==='library')return [order.library_id,order.pickup_library_id,order.assigned_library_id].filter(Boolean).map(text).some(id=>ids.has(id));
    return [order.courier_id,order.delegate_id,order.courier_account_id,order.assigned_courier_id].filter(Boolean).map(text).some(id=>ids.has(id));
  }

  function needsAttention(order,currentRole=role()){
    if(!relevant(order,currentRole))return false;
    const s=status(order);
    if(currentRole==='admin')return ['new','pending','pending_admin','payment_pending'].includes(s);
    if(currentRole==='library')return ['new','pending','pending_admin','accepted'].includes(s);
    return ['assigned','new','pending_admin'].includes(s);
  }

  function accountKey(currentRole=role()){
    const current=window.current||{};
    if(currentRole==='library')return text(current.id||current.library_id||current.account_id||current.username||'session');
    if(currentRole==='courier')return text(current.id||current.courier_id||current.delegate_id||current.account_id||current.username||'session');
    return text(current.id||current.account_id||current.username||'session');
  }
  function storageKey(currentRole=role()){return `${READ_PREFIX}:${currentRole}:${accountKey(currentRole)}`}
  function readSet(currentRole=role()){
    try{return new Set(JSON.parse(localStorage.getItem(storageKey(currentRole))||'[]').map(text).filter(Boolean))}catch(_){return new Set()}
  }
  function writeSet(set,currentRole=role()){
    try{localStorage.setItem(storageKey(currentRole),JSON.stringify([...set].slice(-1000)))}catch(_){ }
  }
  function markRead(id,currentRole=role()){
    const key=text(id);if(!key||!currentRole)return false;
    const seen=readSet(currentRole);seen.add(key);writeSet(seen,currentRole);refreshUI();return true;
  }
  function isUnread(order,currentRole=role()){
    if(!needsAttention(order,currentRole))return false;
    return !readSet(currentRole).has(orderId(order));
  }
  function unreadOrders(currentRole=role()){
    return arr(window.db?.orders).filter(order=>isUnread(order,currentRole));
  }
  function unreadCount(currentRole=role()){return unreadOrders(currentRole).length}

  function ensureBadge(button,className='alin-order-attention-badge'){
    if(!button)return null;
    let badge=button.querySelector(`.${className}`);
    if(!badge){badge=document.createElement('span');badge.className=className;badge.hidden=true;button.appendChild(badge)}
    return badge;
  }
  function paintBadge(badge,count){if(!badge)return;badge.textContent=count>99?'99+':String(count);badge.hidden=count===0}

  function cardId(card){
    if(!card)return '';
    if(card.dataset?.courierOrder)return text(card.dataset.courierOrder);
    const button=card.querySelector('[data-alin-click-arg0]');
    return text(button?.dataset?.alinClickArg0||'');
  }
  function decorateCard(card,currentRole){
    const id=cardId(card);if(!id)return;
    const order=arr(window.db?.orders).find(row=>orderId(row)===id);
    const unread=Boolean(order&&isUnread(order,currentRole));
    card.classList.toggle('alin-order-attention-unread',unread);
    let badge=card.querySelector('.alin-order-attention-new');
    if(unread&&!badge){
      badge=document.createElement('span');badge.className='alin-order-attention-new';badge.textContent='جديد';
      const target=card.querySelector('.admin-order-v126-title,.library-v116-status,.v174-order-state')||card.firstElementChild;
      target?.appendChild(badge);
    }else if(!unread&&badge)badge.remove();
  }

  function refreshUI(){
    if(uiQueued)return;uiQueued=true;
    requestAnimationFrame(()=>{
      uiQueued=false;
      const currentRole=role();if(!currentRole)return;
      const count=unreadCount(currentRole);
      if(currentRole==='admin'){
        document.querySelectorAll('#adminPage [data-admin-tab="orders"]').forEach(button=>paintBadge(ensureBadge(button),count));
        document.querySelectorAll('#adminContent .admin-order-v126').forEach(card=>decorateCard(card,currentRole));
      }else if(currentRole==='library'){
        paintBadge(document.getElementById('libraryV116OrdersBadge'),count);
        document.querySelectorAll('#libraryPage .library-v116-order').forEach(card=>decorateCard(card,currentRole));
      }else if(currentRole==='courier'){
        paintBadge(document.getElementById('courierCurrentBadge'),count);
        document.querySelectorAll('#courierPage .v174-order').forEach(card=>decorateCard(card,currentRole));
      }
    });
  }

  function orderSignature(rows){
    return arr(rows).map(row=>[
      orderId(row),text(row?.updated_at||row?.created_at),status(row),
      text(row?.library_id||row?.pickup_library_id||row?.assigned_library_id),
      text(row?.courier_id||row?.delegate_id||row?.assigned_courier_id)
    ].join(':')).sort().join('|');
  }

  async function pollOrders(force=false){
    const currentRole=role();
    if(!currentRole||pollBusy||!navigator.onLine)return false;
    if(!force&&document.visibilityState&&document.visibilityState!=='visible')return false;
    if(typeof window.query!=='function')return false;
    pollBusy=true;
    try{
      const rows=await window.query('orders',{orderBy:'created_at',ascending:false,limit:1000});
      const next=arr(rows);
      const signature=orderSignature(next);
      if(signature!==lastSignature){
        lastSignature=signature;
        if(!window.db||typeof window.db!=='object')window.db={};
        window.db.orders=next;
        window.dispatchEvent(new CustomEvent('alin:data-refreshed',{detail:{reason:'staff-order-attention',tables:['orders'],at:new Date().toISOString()}}));
      }else refreshUI();
      return true;
    }catch(error){
      console.warn('[ALIN order attention] poll',error);
      return false;
    }finally{pollBusy=false}
  }

  function openRelevantPage(currentRole=role()){
    if(currentRole==='admin')window.adminTab?.('orders');
    else if(currentRole==='library')document.querySelector('#libraryPage [data-library-tab="orders"]')?.click();
    else if(currentRole==='courier')window.renderCourierDashboard?.('current',{force:true});
  }

  function onCardInteraction(event){
    const currentRole=role();if(!currentRole)return;
    const selector=currentRole==='admin'?'.admin-order-v126':currentRole==='library'?'.library-v116-order':'.v174-order';
    const card=event.target?.closest?.(selector);if(!card)return;
    const id=cardId(card);if(id)markRead(id,currentRole);
  }

  function onNewOrder(event){
    const detail=event?.detail||{};
    if(detail.role&&detail.role!==role())return;
    refreshUI();
    setTimeout(()=>pollOrders(true),120);
  }

  function boot(){
    const currentRole=role();if(!currentRole)return;
    lastSignature=orderSignature(window.db?.orders||[]);
    refreshUI();
    setTimeout(()=>pollOrders(true),700);
  }

  document.addEventListener('click',onCardInteraction,true);
  window.addEventListener('alin:new-order-bell',onNewOrder);
  window.addEventListener('alin:data-refreshed',()=>setTimeout(refreshUI,0));
  window.addEventListener('alin:realtime-change',event=>{if(text(event?.detail?.table).toLowerCase()==='orders')setTimeout(()=>pollOrders(true),120)});
  window.addEventListener('alin:admin-tab',()=>refreshUI());
  window.addEventListener('alin:page-open',()=>refreshUI());
  window.addEventListener('focus',()=>pollOrders(true),{passive:true});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')pollOrders(true)});
  window.addEventListener('alin:auth-login',()=>setTimeout(boot,200));
  window.addEventListener('alin:auth-restored',()=>setTimeout(boot,200));
  window.addEventListener('alin:logout',()=>{lastSignature='';pollBusy=false});
  setInterval(()=>pollOrders(false),POLL_MS);
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(boot,600),{once:true});else setTimeout(boot,600);

  window.AlinOrderAttention=Object.freeze({version:VERSION,count:unreadCount,unread:unreadOrders,isUnread,markRead,refresh:pollOrders,paint:refreshUI,open:openRelevantPage});
})();
