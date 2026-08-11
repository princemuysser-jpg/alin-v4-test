/* ALIN v4.1.5 — receipt preview lifecycle guard for every role and device. */
(function(){
  'use strict';
  if(window.__ALIN_RECEIPTS_NAV_GUARD__)return;
  window.__ALIN_RECEIPTS_NAV_GUARD__=true;

  const navigationSelector=[
    '#adminPage .admin-tabs button',
    '#teacherPage .teacher-tabs button',
    '#libraryPage .library-v116-tabs button',
    '#courierPage .courier-v161-tabs button',
    '[data-admin-tab]',
    '[data-teacher-tab]',
    '[data-library-tab]',
    '[data-courier-tab]',
    ''
  ].join(',');

  function isReceiptsNavigation(node){
    if(!node)return false;
    if(node.matches?.('[data-alin415-receipts-role]'))return true;
    if(String(node.dataset?.adminTab||'')==='receipts')return true;
    if(String(node.dataset?.teacherTab||'')==='receipts')return true;
    if(String(node.dataset?.libraryTab||'')==='receipts')return true;
    if(String(node.dataset?.courierTab||'')==='receipts')return true;
    return false;
  }

  function leaveReceipts(){
    try{window.Alin415Receipts?.closePreview?.()}catch(error){console.warn('[ALIN receipts] close preview',error)}
    try{delete document.body.dataset.alin415ReceiptsRole}catch(_){document.body.removeAttribute('data-alin415-receipts-role')}
    document.body.classList.remove('alin415r-modal-open');
    const modal=document.getElementById('alin415rPreviewModal');
    if(modal){
      modal.hidden=true;
      const body=modal.querySelector('.alin415r-modal-body');
      if(body)body.innerHTML='';
    }
  }

  function receiptCenterIsActive(){
    const role=String(document.body.dataset.alin415ReceiptsRole||'');
    if(!role)return false;
    const hostId=role==='admin'||role==='accountant'?'adminContent':role==='teacher'?'teacherContent':role==='library'?'libraryV116Content':'courierV161Content';
    const host=document.getElementById(hostId);
    if(!host||host.closest('.hidden')||host.hidden)return false;
    const center=host.querySelector(`.alin415r-center[data-alin415r-role="${role}"]`);
    return Boolean(center&&!center.closest('.hidden')&&!center.hidden);
  }

  document.addEventListener('click',event=>{
    const navigation=event.target.closest?.(navigationSelector);
    if(!navigation||navigation.closest('#alin415rPreviewModal')||isReceiptsNavigation(navigation))return;
    leaveReceipts();
  },true);

  function wrapNavigation(name,shouldLeave){
    const original=window[name];
    if(typeof original!=='function'||original.__alinReceiptsGuarded)return false;
    function guarded(...args){
      if(shouldLeave(...args))leaveReceipts();
      return original.apply(this,args);
    }
    Object.defineProperty(guarded,'__alinReceiptsGuarded',{value:true});
    window[name]=guarded;
    return true;
  }

  function installWrappers(){
    wrapNavigation('adminTab',tab=>String(tab||'')!=='receipts');
    wrapNavigation('teacherTab',tab=>String(tab||'')!=='receipts');
    wrapNavigation('renderCourierDashboard',tab=>String(tab||'')!=='receipts');
    wrapNavigation('logout',()=>true);
    wrapNavigation('openPage',()=>true);
    wrapNavigation('showPage',()=>true);
  }

  let scheduled=false;
  const verify=()=>{
    if(scheduled)return;
    scheduled=true;
    requestAnimationFrame(()=>{
      scheduled=false;
      installWrappers();
      if((document.body.classList.contains('alin415r-modal-open')||document.body.dataset.alin415ReceiptsRole)&&!receiptCenterIsActive())leaveReceipts();
    });
  };

  const observer=new MutationObserver(verify);
  const start=()=>{
    installWrappers();
    observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['class','hidden','style']});
    [120,500,1200,2600].forEach(delay=>setTimeout(installWrappers,delay));
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();

  ['popstate','hashchange','pagehide'].forEach(type=>window.addEventListener(type,leaveReceipts));
  ['alin:admin-tab','alin:teacher-tab','alin:library-tab','alin:courier-tab','alin:page-changed'].forEach(type=>window.addEventListener(type,verify));
  window.AlinReceiptsNavigationGuard=Object.freeze({leave:leaveReceipts,verify,isActive:receiptCenterIsActive});
})();
