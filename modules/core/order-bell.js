// === core/order-bell.js ===
/* ALIN v4.1.6 prepublish 1s — high quality bell + immediate assignment alerts + resilient realtime. */
(function(){
  'use strict';
  if(window.__ALIN_ORDER_BELL__)return;
  window.__ALIN_ORDER_BELL__=true;

  const VERSION='4.2.0-rc.3';
  const SOUND_URL='./assets/audio/alin-order-chime.wav?v=4.2.0-rc.3';
  const ROLE_PAGES={admin:'adminPage',library:'libraryPage',courier:'courierPage'};
  const roleState=new Map();
  const sessionSeen=new Set();
  let audioContext=null;
  let audioBuffer=null;
  let audioLoading=null;
  let realtimeChannel=null;
  let realtimeRetry=null;
  let toastTimer=null;

  const text=value=>String(value??'').trim();
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

    const sources=currentRole==='courier'?
      [
        ...(Array.isArray(window.db?.accounts?.couriers)?window.db.accounts.couriers:[]),
        ...(Array.isArray(window.db?.couriers)?window.db.couriers:[]),
        ...(Array.isArray(window.couriers)?window.couriers:[])
      ]:
      currentRole==='library'?
      [
        ...(Array.isArray(window.db?.accounts?.libraries)?window.db.accounts.libraries:[]),
        ...(Array.isArray(window.db?.libraries)?window.db.libraries:[]),
        ...(Array.isArray(window.libraries)?window.libraries:[])
      ]:[];

    for(const item of sources){
      const related=[item?.id,item?.account_id,item?.library_row_id,item?.courier_row_id,item?.user_id,item?.auth_user_id,item?.username].filter(Boolean).map(text);
      if(related.some(id=>ids.has(id)))related.forEach(id=>ids.add(id));
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
  function unmarkSeen(key){
    if(!key)return;
    sessionSeen.delete(key);
    try{sessionStorage.removeItem(`alin_order_bell_seen_${key}`)}catch(_){ }
  }

  function ensureAudioContext(){
    try{
      const AudioCtx=window.AudioContext||window.webkitAudioContext;
      if(!AudioCtx)return false;
      if(!audioContext){try{audioContext=new AudioCtx({latencyHint:'interactive'})}catch(_){audioContext=new AudioCtx()}}
      if(audioContext.state==='suspended')audioContext.resume().catch(()=>{});
      return true;
    }catch(_){return false}
  }

  async function loadBellAudio(){
    if(audioBuffer)return audioBuffer;
    if(audioLoading)return audioLoading;
    if(!ensureAudioContext()||!audioContext)return null;
    audioLoading=(async()=>{
      try{
        const response=await fetch(SOUND_URL,{cache:'force-cache'});
        if(!response.ok)throw new Error(`sound ${response.status}`);
        const data=await response.arrayBuffer();
        audioBuffer=await audioContext.decodeAudioData(data.slice(0));
        return audioBuffer;
      }catch(error){
        console.warn('[ALIN order bell] sound load',error);
        return null;
      }finally{audioLoading=null}
    })();
    return audioLoading;
  }

  function fallbackBell(){
    if(!ensureAudioContext()||!audioContext)return false;
    try{
      const now=audioContext.currentTime;
      const master=audioContext.createGain();
      const compressor=audioContext.createDynamicsCompressor();
      compressor.threshold.value=-20;compressor.knee.value=16;compressor.ratio.value=3;compressor.attack.value=.003;compressor.release.value=.2;
      master.gain.setValueAtTime(0.0001,now);
      master.gain.exponentialRampToValueAtTime(0.42,now+0.012);
      master.gain.exponentialRampToValueAtTime(0.0001,now+1.25);
      master.connect(compressor);compressor.connect(audioContext.destination);
      [[783.99,0],[1046.5,.30]].forEach(([frequency,delay])=>{
        [1,2.01,3.97].forEach((partial,index)=>{
          const oscillator=audioContext.createOscillator();
          const gain=audioContext.createGain();
          const start=now+delay;
          oscillator.type=index===0?'sine':'triangle';
          oscillator.frequency.setValueAtTime(frequency*partial,start);
          gain.gain.setValueAtTime(0.0001,start);
          gain.gain.exponentialRampToValueAtTime([0.65,0.18,0.07][index],start+0.008);
          gain.gain.exponentialRampToValueAtTime(0.0001,start+[0.9,0.55,0.34][index]);
          oscillator.connect(gain);gain.connect(master);
          oscillator.start(start);oscillator.stop(start+1.0);
        });
      });
      return true;
    }catch(error){console.warn('[ALIN order bell] fallback audio',error);return false}
  }

  function bell(){
    if(!ensureAudioContext()||!audioContext)return false;
    if(audioBuffer){
      try{
        const source=audioContext.createBufferSource();
        const gain=audioContext.createGain();
        const compressor=audioContext.createDynamicsCompressor();
        source.buffer=audioBuffer;
        gain.gain.value=0.92;
        source.connect(gain);gain.connect(compressor);compressor.connect(audioContext.destination);
        source.start(0);
        return true;
      }catch(error){console.warn('[ALIN order bell] buffered audio',error)}
    }
    loadBellAudio().catch(()=>{});
    return fallbackBell();
  }

  function message(order,currentRole,reason='new'){
    const number=text(order?.order_number||order?.tracking_code||order?.id)||'—';
    const title=text(order?.title||order?.item_name||order?.product_name||order?.booklet_name);
    const suffix=title?` — ${title}`:'';
    if(currentRole==='library')return {title:reason==='assigned'?'تم تحويل طلب للمكتبة':'طلب طباعة جديد',body:`وصل طلب إلى مكتبتك: ${number}${suffix}`};
    if(currentRole==='courier')return {title:reason==='assigned'?'تم تحويل طلب للمندوب':'طلب توصيل جديد',body:`وصل طلب توصيل جديد إلك: ${number}${suffix}`};
    return {title:'طلب جديد',body:`وصل طلب طالب جديد إلى الإدارة: ${number}${suffix}`};
  }

  function showToast(order,currentRole,reason){
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
    const content=message(order,currentRole,reason);
    node.querySelector('strong').textContent=content.title;
    node.querySelector('p').textContent=content.body;
    node.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer=setTimeout(()=>node.classList.remove('show'),7000);
  }

  function notify(order,currentRole=role(),reason='new'){
    if(!relevant(order,currentRole))return false;
    const key=signature(order,currentRole);
    if(wasSeen(key))return false;
    markSeen(key);
    if(!pageIsOpen(currentRole))return false;
    bell();
    showToast(order,currentRole,reason);
    try{navigator.vibrate?.([100,55,100,55,150])}catch(_){ }
    window.dispatchEvent(new CustomEvent('alin:new-order-bell',{detail:{role:currentRole,order,reason,at:new Date().toISOString()}}));
    return true;
  }

  function snapshotRelevant(currentRole){
    const map=new Map();
    for(const order of orders())if(relevant(order,currentRole))map.set(orderId(order),signature(order,currentRole));
    return map;
  }

  function rememberRealtimeRow(order,currentRole){
    const id=orderId(order);if(!id)return {changed:false,had:false};
    const state=roleState.get(currentRole)||new Map();
    const had=state.has(id),old=state.get(id),isRelevant=relevant(order,currentRole);
    if(!isRelevant){if(old)unmarkSeen(old);state.delete(id);roleState.set(currentRole,state);return {changed:false,had}}
    const next=signature(order,currentRole);
    state.set(id,next);roleState.set(currentRole,state);
    return {changed:!had||old!==next,had};
  }

  function handleRealtime(payload){
    const currentRole=role();
    if(!currentRole)return;
    const event=text(payload?.eventType||payload?.event).toUpperCase();
    const next=payload?.new||payload?.record||null;
    if(!next)return;

    // Admin rings only for a genuinely new student order.
    if(currentRole==='admin'){
      rememberRealtimeRow(next,currentRole);
      if(event==='INSERT')notify(next,currentRole,'new');
      return;
    }

    // Library/courier: use the live assignment signature rather than relying on payload.old.
    // This makes a transfer ring immediately even when Supabase does not return the old row.
    const change=rememberRealtimeRow(next,currentRole);
    if(relevant(next,currentRole)&&change.changed)notify(next,currentRole,event==='UPDATE'?'assigned':'new');
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
      if(!previous.has(id)||previous.get(id)!==sig)notify(order,currentRole,previous.has(id)?'assigned':'new');
    }
    roleState.set(currentRole,current);
  }

  function scheduleRealtimeRetry(){
    clearTimeout(realtimeRetry);
    realtimeRetry=setTimeout(()=>{realtimeChannel=null;startRealtime()},900);
  }

  function startRealtime(){
    const client=window.sb||window.AlinCloud?.client?.()||null;
    if(!client?.channel||realtimeChannel)return;
    try{
      realtimeChannel=client.channel(`alin-order-bell-${Math.random().toString(36).slice(2,8)}`)
        .on('postgres_changes',{event:'INSERT',schema:'public',table:'orders'},handleRealtime)
        .on('postgres_changes',{event:'UPDATE',schema:'public',table:'orders'},handleRealtime)
        .subscribe(status=>{
          if(status==='CHANNEL_ERROR'||status==='TIMED_OUT'||status==='CLOSED'){
            try{client.removeChannel?.(realtimeChannel)}catch(_){ }
            realtimeChannel=null;
            scheduleRealtimeRetry();
          }
        });
    }catch(error){
      realtimeChannel=null;
      console.warn('[ALIN order bell] realtime',error);
      scheduleRealtimeRetry();
    }
  }

  function resetRoleState(){
    const currentRole=role();
    if(currentRole)roleState.set(currentRole,snapshotRelevant(currentRole));
  }

  function unlockAudio(){
    if(ensureAudioContext())loadBellAudio().catch(()=>{});
  }

  ['pointerdown','touchstart','keydown'].forEach(type=>document.addEventListener(type,unlockAudio,{capture:true,once:true,passive:true}));
  window.addEventListener('alin:data-refreshed',compareSnapshot);
  window.addEventListener('alin:cloud-mutation',event=>{if(text(event?.detail?.table)==='orders')setTimeout(compareSnapshot,0)});
  window.addEventListener('alin:logout',()=>{roleState.clear();sessionSeen.clear()});
  document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'){resetRoleState();startRealtime()}});
  document.addEventListener('DOMContentLoaded',()=>{setTimeout(()=>{resetRoleState();startRealtime()},500)},{once:true});

  // Fast fallback only when realtime/data events are unavailable.
  setInterval(()=>{if(role()){startRealtime();compareSnapshot()}},1500);

  window.AlinOrderBell=Object.freeze({version:VERSION,ring:bell,check:compareSnapshot,notify,enabled:()=>Boolean(role())});
})();
