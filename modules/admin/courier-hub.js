// === admin/courier-hub.js ===
/* ALIN — one courier administration hub inside the admin panel. */
(function(){
  'use strict';
  if(window.__ALIN_COURIER_ADMIN_HUB__)return;
  window.__ALIN_COURIER_ADMIN_HUB__=true;

  const VALID=new Set(['couriers','areas','orders','settlements']);
  const LEGACY_TO_SECTION={courierAreas:'areas',deliveryOrders:'orders',courierSettlements:'settlements'};
  const state={section:'couriers',scheduled:false,observer:null};
  const original={
    couriers:typeof window.renderCouriersAdmin==='function'?window.renderCouriersAdmin:null,
    areas:typeof window.renderCourierAreasAdmin==='function'?window.renderCourierAreasAdmin:null,
    orders:typeof window.renderDeliveryOrdersAdmin==='function'?window.renderDeliveryOrdersAdmin:null,
    settlements:typeof window.renderCourierSettlementsAdmin==='function'?window.renderCourierSettlementsAdmin:null
  };

  function root(){return document.getElementById('adminContent')}
  function adminPage(){return document.getElementById('adminPage')}
  function isAdminVisible(){const page=adminPage();return Boolean(page&&!page.classList.contains('hidden'))}

  function ensureStyle(){
    if(document.getElementById('alinCourierAdminHubCss'))return;
    const link=document.createElement('link');
    link.id='alinCourierAdminHubCss';
    link.rel='stylesheet';
    const version=window.ALIN_CONFIG?.assetVersion||window.ALIN_CONFIG?.version||'4.2.0';
    link.href=`./styles/alin-admin-courier-hub.css?v=${encodeURIComponent(version)}`;
    document.head.appendChild(link);
  }

  function removeLegacyMainTabs(){
    ['courierAreas','deliveryOrders','courierSettlements'].forEach(tab=>{
      document.querySelectorAll(`#adminPage .admin-tabs [data-admin-tab="${tab}"]`).forEach(button=>button.remove());
    });
  }

  function markCourierMainTab(){
    const page=adminPage();
    if(page)page.dataset.activeAdminTab='couriers';
    window.activeAdminTab='couriers';
    document.querySelectorAll('#adminPage .admin-tabs [data-admin-tab]').forEach(button=>{
      button.classList.toggle('active-admin-tab',button.dataset.adminTab==='couriers');
    });
    const host=root();
    if(host)host.dataset.adminModule='couriers';
  }

  function navMarkup(section){
    const items=[
      ['couriers','المندوبون'],
      ['areas','إدارة المناطق'],
      ['orders','طلبات التوصيل'],
      ['settlements','تسويات المندوبين']
    ];
    return `<section class="alin-courier-admin-hub" data-courier-hub-section="${section}">
      <div class="alin-courier-admin-hub-title"><div><small>قسم موحد</small><strong>إدارة المندوبين</strong></div><span>منصة آلين</span></div>
      <nav aria-label="أقسام إدارة المندوبين">${items.map(([key,label])=>`<button type="button" class="${key===section?'active':''}" data-alin-click="alinCourierHubOpen" data-alin-click-arg0="${key}">${label}</button>`).join('')}</nav>
    </section>`;
  }

  function removeCourierCreateButton(){
    const host=root();if(!host)return;
    host.querySelectorAll('.v164-admin-head button[data-alin-click="alinV161CourierForm"]:not([data-alin-click-arg0])').forEach(button=>button.remove());
  }

  function decorateHub(section=state.section){
    if(!VALID.has(section))section='couriers';
    const host=root();if(!host)return;
    state.section=section;
    removeLegacyMainTabs();
    removeCourierCreateButton();
    const current=host.querySelector(':scope > .alin-courier-admin-hub');
    if(!current){host.insertAdjacentHTML('afterbegin',navMarkup(section));}
    else if(current.dataset.courierHubSection!==section){current.outerHTML=navMarkup(section);}
    markCourierMainTab();
  }

  function invoke(section){
    section=VALID.has(section)?section:'couriers';
    state.section=section;
    const renderer=original[section];
    if(typeof renderer!=='function'){
      const host=root();
      if(host)host.innerHTML='<section class="notice"><b>القسم غير جاهز</b><div>تعذر تحميل قسم إدارة المندوبين. حدّث الصفحة مرة واحدة.</div></section>';
      decorateHub(section);
      return false;
    }
    try{
      const result=renderer();
      Promise.resolve(result).finally(()=>decorateHub(section));
      decorateHub(section);
      return result;
    }catch(error){
      console.error('[ALIN courier admin hub]',error);
      decorateHub(section);
      return false;
    }
  }

  function decorateAccounts(){
    const host=root();
    if(!host||window.activeAdminTab!=='accounts')return;
    const head=host.querySelector('.v131-accounts-head');
    if(!head||document.getElementById('alinAccountsAddCourierButton'))return;
    const general=head.querySelector('.v131-add-account');
    const button=document.createElement('button');
    button.id='alinAccountsAddCourierButton';
    button.type='button';
    button.className='v131-add-account alin-add-courier-account';
    button.dataset.alinClick='alinOpenCourierFromAccounts';
    button.textContent='+ إضافة مندوب';
    if(general)general.insertAdjacentElement('beforebegin',button);else head.appendChild(button);
  }

  function openCourierFromAccounts(){
    const open=()=>{
      const role=document.getElementById('aRole');
      if(!role)return false;
      role.value='courier';
      window.v131ToggleAccountForm?.(true);
      window.v131SyncAccountRole?.();
      document.getElementById('v131AccountForm')?.scrollIntoView?.({behavior:'smooth',block:'start'});
      return true;
    };
    if(window.activeAdminTab!=='accounts'){
      window.adminTab?.('accounts');
      setTimeout(open,80);
      setTimeout(open,260);
      return true;
    }
    return open();
  }

  function schedule(){
    if(state.scheduled)return;
    state.scheduled=true;
    requestAnimationFrame(()=>{
      state.scheduled=false;
      ensureStyle();
      removeLegacyMainTabs();
      if(!isAdminVisible())return;
      if(window.activeAdminTab==='accounts'){decorateAccounts();return;}
      if(window.activeAdminTab==='couriers')decorateHub(state.section);
    });
  }

  window.alinCourierHubOpen=invoke;
  window.alinOpenCourierFromAccounts=openCourierFromAccounts;
  window.AlinCourierAdminHub=Object.freeze({open:invoke,decorate:decorateHub,section:()=>state.section});

  ensureStyle();
  removeLegacyMainTabs();

  // Keep old deep links/routes working, but render them inside the one courier hub.
  window.AlinAdminModules?.register?.('couriers',()=>invoke('couriers'));
  window.AlinAdminModules?.register?.('courierAreas',()=>invoke('areas'));
  window.AlinAdminModules?.register?.('deliveryOrders',()=>invoke('orders'));
  window.AlinAdminModules?.register?.('courierSettlements',()=>invoke('settlements'));

  window.addEventListener('alin:admin-tab',event=>{
    const tab=String(event.detail?.tab||'');
    if(tab==='accounts'){schedule();return;}
    if(tab==='couriers')state.section='couriers';
    else if(LEGACY_TO_SECTION[tab])state.section=LEGACY_TO_SECTION[tab];
    schedule();
  });
  window.addEventListener('alin:page-open',schedule);
  window.addEventListener('alin:data-refreshed',schedule);

  const host=root();
  if(host){
    state.observer=new MutationObserver(schedule);
    state.observer.observe(host,{childList:true,subtree:true});
  }
  schedule();
})();

;
