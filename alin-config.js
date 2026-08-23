// منصة آلين v4.2.0 Stable — Alin Platform.
window.ALIN_CONFIG=Object.freeze({
  version:'4.2.0',
  assetVersion:'4.2.0-delivery-pricing-ui-20260823-1121',
  desktopPage:'./store-desktop.html',
  mobilePage:'./store-mobile.html',
  tabletPage:'./store-tablet.html',
  currency:'د.ع',
  locale:'ar-IQ',
  locales:{ar:'ar-IQ',ku:'ckb-IQ',en:'en-IQ'},
  authEnabled:true,
  authEmailDomain:'users.alin.local',
  teacherCoursesEnabled:true,
  supabaseUrl:'https://dgaikazhbtyjmswpyvrl.supabase.co',
  supabaseAnonKey:'sb_publishable_HjVoise8mRYVeMeBaM9pxw_oxf_mLp3'
});

/* ALIN v4.3.0 courier-fee compatibility.
   The backend snapshots courier_fee independently from the customer delivery fee.
   Keep legacy orders on the legacy calculation, but make new orders display the
   persisted courier fee even when customer delivery is free. */
(function installCourierFeeDisplayCompatibility(){
  'use strict';

  function patchFinance(){
    const base=window.AlinFinance;
    if(!base||typeof base.shares!=='function'||base.__alinCourierFeeCompatV430)return;

    const legacyShares=base.shares;
    const shares=function(order){
      const split=legacyShares(order);
      if(!split||split.delivery!=='delegate')return split;

      const raw=order?.courier_fee;
      const hasCourierFee=raw!==null&&raw!==undefined&&String(raw).trim()!=='';
      if(!hasCourierFee)return split;

      const parsed=Number(raw);
      if(!Number.isFinite(parsed))return split;

      const delegate=Math.max(0,Math.round(parsed));
      const total=Math.max(0,Number(split.total)||0);
      const teacher=Math.max(0,Number(split.teacher)||0);
      const library=Math.max(0,Number(split.library)||0);
      return {
        ...split,
        delegate,
        admin:Math.max(0,total-teacher-library-delegate),
        debt:Math.max(0,total-delegate)
      };
    };

    const patched=Object.freeze({...base,shares,__alinCourierFeeCompatV430:true});
    window.AlinFinance=patched;
    window.AlinFinanceV207=patched;
  }

  window.addEventListener('alin:role-runtime-ready',patchFinance);
  if(typeof queueMicrotask==='function')queueMicrotask(patchFinance);
  else setTimeout(patchFinance,0);
})();

/* ALIN v4.3.0 delivery pricing UI bridge.
   Load the admin pricing source after the staff runtime is ready when the current
   role bundle does not contain it yet. A future rebuilt bundle makes this a no-op. */
(function installDeliveryPricingUiBridge(){
  'use strict';
  let state='idle';
  let promise=null;

  function ready(){
    return typeof window.alinV430FreePricing==='function'&&
      typeof window.alinV430CustomPricing==='function'&&
      typeof window.alinV430AreaPricing==='function';
  }

  function ensure(){
    if(ready())return Promise.resolve(true);
    if(state==='loading'&&promise)return promise;
    if(!window.AlinCourierCore)return Promise.resolve(false);

    const existing=document.getElementById('alinDeliveryPricingRuntimeScript');
    if(existing){
      if(ready())return Promise.resolve(true);
      return new Promise(resolve=>{
        existing.addEventListener('load',()=>resolve(ready()),{once:true});
        existing.addEventListener('error',()=>resolve(false),{once:true});
      });
    }

    state='loading';
    promise=new Promise(resolve=>{
      const script=document.createElement('script');
      script.id='alinDeliveryPricingRuntimeScript';
      script.src=`./modules/admin/delivery-pricing.js?v=${encodeURIComponent(window.ALIN_CONFIG?.assetVersion||'4.3.0')}`;
      script.async=false;
      script.addEventListener('load',()=>{
        state=ready()?'ready':'error';
        if(state==='ready'){
          window.dispatchEvent(new CustomEvent('alin:delivery-pricing-ready'));
          if(window.activeAdminTab==='courierAreas'&&typeof window.renderCourierAreasAdmin==='function'){
            setTimeout(()=>window.renderCourierAreasAdmin(),0);
          }
        }
        resolve(state==='ready');
      },{once:true});
      script.addEventListener('error',()=>{state='error';promise=null;resolve(false)},{once:true});
      document.head.appendChild(script);
    });
    return promise;
  }

  window.addEventListener('alin:role-runtime-ready',ensure);
  if(window.AlinRoleRuntime?.ready?.())ensure();
})();
