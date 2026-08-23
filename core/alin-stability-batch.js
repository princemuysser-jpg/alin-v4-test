/* ALIN v4.2.0 — 2026-08-23 stability + unified role UI batch.
   Frontend-only: route persistence, notification read fallback, receipt safety,
   and one visual system for teacher/library/courier on desktop/tablet/mobile.
   No finance/account calculation is changed here. */
(function(){
  'use strict';
  if(window.__ALIN_STABILITY_BATCH_20260823__)return;
  window.__ALIN_STABILITY_BATCH_20260823__=true;

  const VERSION=String(window.ALIN_CONFIG?.assetVersion||'4.2.0-unified-role-ui');
  const text=value=>String(value??'').trim();
  const arr=value=>Array.isArray(value)?value:[];
  const ROLE_TABS={
    admin:new Set(['dashboard','accounts','booklets','teacherRequests','libraryRequests','products','categories','orders','couriers','courierAreas','deliveryOrders','courierSettlements','finance','receipts','ads','coupons','notifications','audit','brandIdentity','backup','settings']),
    accountant:new Set(['finance','receipts']),
    teacher:new Set(['dashboard','booklets','orders','finance','receipts','notifications','requests','review','profile']),
    library:new Set(['home','orders','finance','receipts','notifications','settings']),
    courier:new Set(['home','current','completed','finance','receipts','notifications','profile'])
  };

  function loadResponsiveCss(){
    if(document.getElementById('alinStabilityResponsiveCss'))return;
    const link=document.createElement('link');
    link.id='alinStabilityResponsiveCss';
    link.rel='stylesheet';
    link.href=`./styles/alin-role-responsive-fixes.css?v=${encodeURIComponent(VERSION)}`;
    document.head.appendChild(link);
  }

  function normalizeRole(value){const role=text(value).toLowerCase();return role==='delegate'?'courier':role}
  function currentContext(){const current=window.current||{};return {role:normalizeRole(current.role),id:text(current.id||current.account_id||current.user_id||current.auth_user_id),name:text(current.name||current.username)}}
  function firstLetter(value,fallback){return text(value||fallback).slice(0,1)||fallback}

  function teacherHero(page,context){
    let hero=page.querySelector(':scope > .alin-role-unified-hero');
    if(!hero){
      hero=document.createElement('header');
      hero.className='alin-role-unified-hero alin-role-teacher-hero';
      const heading=page.querySelector(':scope > h2');
      if(heading)heading.insertAdjacentElement('afterend',hero);else page.prepend(hero);
    }
    hero.innerHTML=`<div class="alin-role-hero-main"><div class="alin-role-avatar">${firstLetter(context.name,'م')}</div><div class="alin-role-hero-copy"><small>لوحة المدرس</small><h1>${context.name||'المدرس'}</h1><p>إدارة الملازم والطلبات والأرباح والنشر من مكان واحد</p></div></div><div class="alin-role-platform-badge">منصة آلين</div>`;
  }

  function installUnifiedRoleShell(){
    const context=currentContext();
    for(const role of ['teacher','library','courier']){
      const page=document.getElementById(`${role}Page`);
      if(!page)continue;
      page.classList.add('alin-role-shell',`alin-role-${role}`);
      page.dataset.alinRoleShell=role;
      if(role==='teacher')teacherHero(page,context.role==='teacher'?context:{name:''});
      if(role==='library'){
        const header=page.querySelector('.library-v116-header');
        header?.classList.add('alin-role-unified-hero','alin-role-library-hero');
        const identity=header?.querySelector('.library-v116-identity');
        identity?.classList.add('alin-role-hero-main');
      }
      if(role==='courier'){
        const header=page.querySelector('.courier-v161-hero');
        header?.classList.add('alin-role-unified-hero','alin-role-courier-hero');
      }
    }
    const teacherPage=document.getElementById('teacherPage');
    const legacyTeacherHeading=teacherPage?.querySelector(':scope > h2');
    if(legacyTeacherHeading)legacyTeacherHeading.classList.add('alin-role-legacy-title');
  }

  function installSafeClosest(){
    const proto=window.Element?.prototype;
    const nativeClosest=proto?.closest;
    if(!proto||typeof nativeClosest!=='function'||nativeClosest.__alinTrailingCommaSafe)return;
    function safeClosest(selector){
      try{return nativeClosest.call(this,selector)}
      catch(error){
        if(typeof selector==='string'&&/,\s*$/.test(selector)){
          const cleaned=selector.replace(/(?:,\s*)+$/,'').trim();
          if(cleaned)return nativeClosest.call(this,cleaned);
        }
        throw error;
      }
    }
    Object.defineProperty(safeClosest,'__alinTrailingCommaSafe',{value:true});
    proto.closest=safeClosest;
  }

  function routeKey(context=currentContext()){return context.role&&context.id?`alin_last_staff_route_v1:${context.role}:${context.id}`:''}
  function readRoute(context=currentContext()){
    const key=routeKey(context);if(!key)return '';
    try{const raw=JSON.parse(localStorage.getItem(key)||'null');const tab=text(raw?.tab);return ROLE_TABS[context.role]?.has(tab)?tab:''}catch(_){return ''}
  }
  function saveRoute(role,tab){
    const context=currentContext();role=normalizeRole(role||context.role);tab=text(tab);
    if(role!==context.role||!context.id||!ROLE_TABS[role]?.has(tab))return false;
    try{localStorage.setItem(routeKey(context),JSON.stringify({tab,updated_at:new Date().toISOString()}));return true}catch(_){return false}
  }
  function clickedRoute(node){
    const button=node?.closest?.('button,[data-admin-tab],[data-teacher-tab],[data-library-tab],[data-courier-tab],[data-alin415-receipts-role],[data-alin-click]');
    if(!button)return null;
    if(button.dataset.adminTab)return {role:currentContext().role==='accountant'?'accountant':'admin',tab:button.dataset.adminTab};
    if(button.dataset.teacherTab)return {role:'teacher',tab:button.dataset.teacherTab};
    if(button.dataset.libraryTab)return {role:'library',tab:button.dataset.libraryTab};
    if(button.dataset.courierTab)return {role:'courier',tab:button.dataset.courierTab};
    const receiptRole=normalizeRole(button.dataset.alin415ReceiptsRole);if(receiptRole)return {role:receiptRole,tab:'receipts'};
    const action=text(button.dataset.alinClick),arg=text(button.dataset.alinClickArg0);
    if(action==='adminTab')return {role:currentContext().role==='accountant'?'accountant':'admin',tab:arg};
    if(action==='teacherTab')return {role:'teacher',tab:arg};
    if(action==='renderCourierDashboard')return {role:'courier',tab:arg};
    return null;
  }
  document.addEventListener('click',event=>{const route=clickedRoute(event.target);if(route)saveRoute(route.role,route.tab)},true);

  function pageVisible(id){const page=document.getElementById(id);return Boolean(page&&!page.classList.contains('hidden')&&!page.hidden)}
  function primeRoute(){const context=currentContext(),tab=readRoute(context);if(!tab)return false;if(context.role==='admin'||context.role==='accountant')window.activeAdminTab=tab;else if(context.role==='teacher')window.activeTeacherTab=tab;return true}
  function restoreRoute(){
    const context=currentContext();let tab=readRoute(context);if(!tab)return false;
    if(context.role==='accountant'&&!ROLE_TABS.accountant.has(tab))tab='finance';
    try{
      if((context.role==='admin'||context.role==='accountant')&&pageVisible('adminPage')&&typeof window.adminTab==='function'){if(window.activeAdminTab!==tab)window.adminTab(tab);return true}
      if(context.role==='teacher'&&pageVisible('teacherPage')&&typeof window.teacherTab==='function'){if(String(window.TeacherApp?.active||window.activeTeacherTab||'')!==tab)window.teacherTab(tab);return true}
      if(context.role==='library'&&pageVisible('libraryPage')){const selector=tab==='receipts'?'#libraryReceiptsTab':`.library-v116-tabs [data-library-tab="${CSS.escape(tab)}"]`;const button=document.querySelector(selector);if(button&&!button.classList.contains('active'))button.click();return Boolean(button)}
      if(context.role==='courier'&&pageVisible('courierPage')){if(tab==='receipts'){const button=document.getElementById('courierReceiptsTab');if(button&&!button.classList.contains('active'))button.click();return Boolean(button)}const active=document.querySelector('.courier-v161-tabs [data-courier-tab].active')?.dataset.courierTab||'';if(active!==tab&&typeof window.renderCourierDashboard==='function')window.renderCourierDashboard(tab,{refresh:false});return true}
    }catch(error){console.warn('[ALIN stability] restore route',error)}
    return false;
  }
  let restoreTimer=0;
  function scheduleRestore(){primeRoute();clearTimeout(restoreTimer);restoreTimer=setTimeout(restoreRoute,140);setTimeout(restoreRoute,420)}

  function seenKey(input={}){const context=window.AlinNotifications?.context?.(input)||{role:normalizeRole(input.role||window.current?.role||'student'),id:text(input.id||window.current?.id||'guest')};return `alin_notifications_ui_seen_v1:${normalizeRole(context.role)||'student'}:${text(context.id)||'guest'}`}
  function seen(input={}){try{return new Set(arr(JSON.parse(localStorage.getItem(seenKey(input))||'[]')).map(String))}catch(_){return new Set()}}
  function saveSeen(values,input={}){try{localStorage.setItem(seenKey(input),JSON.stringify([...values].slice(-1000)))}catch(_){}}
  function notificationKey(row,index=0){return text(row?.id)||`${text(row?.created_at)}:${text(row?.title)}:${index}`}
  function installNotificationFallback(){
    const base=window.AlinNotifications;if(!base||base.__alinReadFallbackV1)return false;
    const originalIsRead=typeof base.isRead==='function'?base.isRead.bind(base):()=>false;
    const originalMarkRead=typeof base.markRead==='function'?base.markRead.bind(base):async()=>true;
    const originalMarkAll=typeof base.markAll==='function'?base.markAll.bind(base):async()=>true;
    const originalUnread=typeof base.unreadCount==='function'?base.unreadCount.bind(base):()=>0;
    function isRead(row,input={}){if(!row)return true;if(seen(input).has(notificationKey(row)))return true;return Boolean(originalIsRead(row,input))}
    async function markRead(id,input={}){const values=seen(input);values.add(String(id));saveSeen(values,input);try{return await originalMarkRead(id,input)}catch(error){console.warn('[ALIN stability] notification read remote fallback',error);return true}}
    async function markAll(input={}){const visible=typeof base.visible==='function'?arr(base.visible(input)):[];const values=seen(input);visible.forEach((row,index)=>values.add(notificationKey(row,index)));saveSeen(values,input);try{return await originalMarkAll(input)}catch(error){console.warn('[ALIN stability] notification read-all remote fallback',error);return true}}
    function unreadCount(input={}){if(typeof base.visible!=='function')return originalUnread(input);return arr(base.visible(input)).filter(row=>!isRead(row,input)).length}
    window.AlinNotifications=Object.freeze({...base,isRead,markRead,markAll,unreadCount,__alinReadFallbackV1:true});
    window.dispatchEvent(new CustomEvent('alin:notifications-updated',{detail:{reason:'read-fallback-ready'}}));
    return true;
  }

  function ensureFixes(){installSafeClosest();installNotificationFallback();installUnifiedRoleShell()}
  loadResponsiveCss();ensureFixes();
  let attempts=0;const timer=setInterval(()=>{ensureFixes();attempts+=1;if(attempts>=40)clearInterval(timer)},500);
  window.addEventListener('alin:role-runtime-ready',()=>{ensureFixes();scheduleRestore()});
  window.addEventListener('alin:auth-login',()=>{installUnifiedRoleShell();scheduleRestore()});
  window.addEventListener('alin:auth-restored',()=>{installUnifiedRoleShell();scheduleRestore()});
  window.addEventListener('alin:data-refreshed',installUnifiedRoleShell);
  window.addEventListener('alin:page-open',event=>{installUnifiedRoleShell();const role=currentContext().role,page=text(event.detail?.page);if((role==='admin'||role==='accountant')&&page==='admin')scheduleRestore();else if(role===page)scheduleRestore()});
  window.addEventListener('alin:logout',()=>clearTimeout(restoreTimer));
  window.addEventListener('alin:notifications-updated',()=>installNotificationFallback());
  window.AlinStabilityBatch=Object.freeze({version:VERSION,restoreRoute,saveRoute,installNotificationFallback,installUnifiedRoleShell});
})();
