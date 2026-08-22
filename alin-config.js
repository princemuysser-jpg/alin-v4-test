// منصة آلين v4.2.0 Stable — Alin Platform.
window.ALIN_CONFIG=Object.freeze({
  version:'4.2.0',
  assetVersion:'4.2.0-courier-fee-compat-20260823',
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
