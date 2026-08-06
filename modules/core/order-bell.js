// === core/order-bell.js ===
/* ALIN v4.1.6 prepublish 1o — audible new-order alerts for admin, library and courier while their page is open. */
(function(){
  'use strict';
  if(window.__ALIN_ORDER_BELL__)return;
  window.__ALIN_ORDER_BELL__=true;

  const VERSION='4.1.6-prepublish-1o';
  const ROLE_PAGES={admin:'adminPage',library:'libraryPage',courier:'courierPage'};
  const roleState=new Map();
  const sessionSeen=new Set();
  let audioContext=null;
  let realtimeChannel=null;
  let toastTimer=null;

  const text=value=>String(value??'').trim();
  const same=(a,b)=>text(a)!==''&&text(a)===text(b);
  const orders=()=>Array.isArray(window.db?.orders)?window.db.orders:[];

  function role(){
    const value=text(window.current?.role).toLowerCase();
    return value==='admin'||value==='library'||value==='courier'?value:'';
  }

  function pageIsOpen(currentRole=role()){
    if(!currentRole||document.visibilityState!=='visible')return false;
    const page=document.getElementById(ROLE_PAGES[currentRole]);
    if(!page||page.hidden)return false;
    const style=getComputedStyle(page);
    return style.display!=='none'&&style.visibility!=='hidden'&&page.getClientRects().length>0;
  }

  function accountIds(currentRole=role()){
    const current=window.current||{};
    const ids=new Set([
      current.id,current.account_id,current.library_id,current.courier_id,current.delegate_id,
      current.auth_user_id,current.username
    ].filter(Boolean).map(text));

    if(currentRole==='courier'){
      const sources=[
        ...(Array.isArray(window.db?.accounts?.couriers)?window.db.accounts.couriers:[]),
        ...(Array.isArray(window.db?.couriers)?window.db.couriers:[]),
        ...(Array.isArray(window.couriers)?window.couriers:[])
      ];
      for(const item of sources){
        const related=[item?.id,item?.account_id,item?.courier_row_id,item?.user_id,item?.auth_user_id,item?.username].filter(Boolean).map(text);
        if(related.some(id=>ids.has(id)))related.forEach(id=>ids.add(id));
      }
    }
    return ids;
  }

  function libraryOrderIds(order){
    return [order?.library_id,order?.pickup_library_id,order?.assigned_library_id].filter(Boolean).map(text);
  }

  function courierOrderIds(order){
    return [order?.courier_id,order?.delegate_id,order?.courier_account_id,order?.assigned_courier_id].filter(Boolean).map(text);
  }

  function relevant(order,currentRole=role()){
    if(!order||!currentRole)return false;
    if(currentRole==='admin')return true;
    const ids=accountIds(currentRole);
    if(currentRole==='library')return libraryOrderIds(order).some(id=>ids.has(id));
    if(currentRole==='courier')return courierOrderIds(order).some(id=>ids.has(id));
    return false;
  }

  function orderId(order){return text(order?.id||order?.order_id||order?.order_number||order?.tracking_code)}
  function signature(order,currentRole=role()){
    const assignment=currentRole==='library'?libraryOrderIds(order).join('|'):currentRole==='courier'?courierOrderIds(order).join('|'):text(order?.created_at||order?.id);
    return `${currentRole}:${orderId(order)}:${assignment}`;
  }

  function markSeen(key){
    if(!key)return;
    sessionSeen.add(key);
    try{sessionStorage.setItem(`alin_order_bell_seen_${key}`,'1')}catch(_){ }
  }
  function wasSeen(key){
    if(!key)return true;
    if(sessionSeen.has(key))return true;
    try{return sessionStorage.getItem(`alin_order_bell_seen_${key}`)==='1'}catch(_){return false}
  }

  function unlockAudio(){
    try{
      const AudioCtx=window.AudioContext||window.webkitAudioContext;
      if(!AudioCtx)return false;
      if(!audioContext)audioContext=new AudioCtx();
      if(audioContext.state==='suspended')audioContext.resume().catch(()=>{});
      return true;
    }catch(_){return false}
  }

  function bell(){
    if(!unlockAudio()||!audioContext)return false;
    try{
      const now=audioContext.currentTime;
      const master=audioContext.createGain();
      master.gain.setValueAtTime(0.0001,now);
      master.gain.exponentialRampToValueAtTime(0.28,now+0.015);
      master.gain.exponentialRampToValueAtTime(0.0001,now+1.05);
      master.connect(audioContext.destination);

      const notes=[880,1174.66];
      notes.forEach((frequency,index)=>{
        const oscillator=audioContext.createOscillator();
        const gain=audioContext.createGain();
        const start=now+(index*0.18);
        oscillator.type='sine';
        oscillator.frequency.setValueAtTime(frequency,start);
        gain.gain.setValueAtTime(0.0001,start);
        gain.gain.exponentialRampToValueAtTime(index?0.52:0.7,start+0.012);
        gain.gain.exponentialRampToValueAtTime(0.0001,start+0.72);
        oscillator.connect(gain);gain.connect(master);
        oscillator.start(start);oscillator.stop(start+0.75);
      });
      return true;
    }catch(error){console.warn('[ALIN order bell] audio',error);return false}
  }

  function message(order,currentRole){
    const number=text(order?.order_number||order?.tracking_code||order?.id)||'—';
    const title=text(order?.title||order?.item_name||order?.product_name||order?.booklet_name);
    const suffix=title?` — ${title}`:'';
    if(currentRole==='library')return {title:'طلب طباعة جديد',body:`وصل طلب جديد إلى مكتبتك: ${number}${suffix}`};
    if(currentRole==='courier')return {title:'طلب توصيل جديد',body:`تم تعيين طلب جديد إلك: ${number}${suffix}`};
    return {title:'طلب جديد',body:`وصل طلب طالب جديد إلى الإدارة: ${number}${suffix}`};
  }

  function showToast(order,currentRole){
    let node=document.getElementById('alinOrderBellToast');
    if(!node){
      node=document.createElement('div');
      node.id='alinOrderBellToast';
      node.className='alin-order-bell-toast';
      node.setAttribute('role','status');
      node.setAttribute('aria-live','assertive');
      node.innerHTML='<span class="alin-order-bell-icon" aria-hidden="true">🔔</span><div><strong></strong><p></p></div><button type="button" aria-label="إغلاق">×</button>';
      node.querySelector('button').addEventListener('click',()=>node.classList.remove('show'));
      document.body.appendChild(node);
    }
    const content=message(order,currentRole);
    node.querySelector('strong').textContent=content.title;
    node.querySelector('p').textContent=content.body;
    node.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer=setTimeout(()=>node.classList.remove('show'),6500);
  }

  function notify(order,currentRole=role()){
    if(!relevant(order,currentRole))return false;
    const key=signature(order,currentRole);
    if(wasSeen(key))return false;
    markSeen(key);
    if(!pageIsOpen(currentRole))return false;
    bell();
    showToast(order,currentRole);
    try{navigator.vibrate?.([90,70,130])}catch(_){ }
    window.dispatchEvent(new CustomEvent('alin:new-order-bell',{detail:{role:currentRole,order,at:new Date().toISOString()}}));
    return true;
  }

  function assignmentBecameRelevant(next,previous,currentRole){
    if(currentRole==='admin')return false;
    return relevant(next,currentRole)&&!relevant(previous,currentRole);
  }

  function handleRealtime(payload){
    const currentRole=role();
    if(!currentRole)return;
    const event=text(payload?.eventType||payload?.event).toUpperCase();
    const next=payload?.new||payload?.record||null;
    const previous=payload?.old||payload?.old_record||null;
    if(event==='INSERT')notify(next,currentRole);
    else if(event==='UPDATE'&&assignmentBecameRelevant(next,previous,currentRole))notify(next,currentRole);
  }

  function snapshotRelevant(currentRole){
    const map=new Map();
    for(const order of orders())if(relevant(order,currentRole))map.set(orderId(order),signature(order,currentRole));
    return map;
  }

  function compareSnapshot(){
    const currentRole=role();
    if(!currentRole)return;
    const current=snapshotRelevant(currentRole);
    const previous=roleState.get(currentRole);
    if(!previous){roleState.set(currentRole,current);return}
    for(const order of orders()){
      if(!relevant(order,currentRole))continue;
      const id=orderId(order),sig=signature(order,currentRole);
      if(!previous.has(id)||previous.get(id)!==sig)notify(order,currentRole);
    }
    roleState.set(currentRole,current);
  }

  function startRealtime(){
    const client=window.sb||window.AlinCloud?.client?.()||null;
    if(!client?.channel||realtimeChannel)return;
    try{
      realtimeChannel=client.channel(`alin-order-bell-${Math.random().toString(36).slice(2,8)}`)
        .on('postgres_changes',{event:'INSERT',schema:'public',table:'orders'},handleRealtime)
        .on('postgres_changes',{event:'UPDATE',schema:'public',table:'orders'},handleRealtime)
        .subscribe();
    }catch(error){console.warn('[ALIN order bell] realtime',error)}
  }

  function resetRoleState(){
    const currentRole=role();
    if(currentRole)roleState.set(currentRole,snapshotRelevant(currentRole));
  }

  ['pointerdown','touchstart','keydown'].forEach(type=>document.addEventListener(type,unlockAudio,{capture:true,once:true,passive:true}));
  window.addEventListener('alin:data-refreshed',compareSnapshot);
  window.addEventListener('alin:cloud-mutation',event=>{if(text(event?.detail?.table)==='orders')setTimeout(compareSnapshot,30)});
  window.addEventListener('alin:logout',()=>{roleState.clear();sessionSeen.clear()});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')resetRoleState()});
  document.addEventListener('DOMContentLoaded',()=>{setTimeout(()=>{resetRoleState();startRealtime()},900)},{once:true});
  setInterval(()=>{if(role()){startRealtime();compareSnapshot()}},5000);

  window.AlinOrderBell=Object.freeze({version:VERSION,ring:bell,check:compareSnapshot,notify,enabled:()=>Boolean(role())});
})();
