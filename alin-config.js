// منصة آلين v4.2.0 Stable — Alin Platform.
window.ALIN_CONFIG=Object.freeze({
  version:'4.2.0',
  assetVersion:'4.2.0-stable-report-settlement-lookup-20260825-1440',
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

/* Keep authenticated staff on the same role/page/tab across refreshes. */
(function loadAlinSessionBootGuard(){
  'use strict';
  if(document.getElementById('alinSessionBootGuardScript'))return;
  const script=document.createElement('script');
  script.id='alinSessionBootGuardScript';
  script.src=`./core/alin-session-boot-guard.js?v=${encodeURIComponent(window.ALIN_CONFIG.assetVersion)}`;
  script.async=false;
  document.head.appendChild(script);
})();

/* ALIN 2026-08-23 stability batch loader. */
(function loadAlinStabilityBatch(){
  'use strict';
  if(document.getElementById('alinStabilityBatchScript'))return;
  const script=document.createElement('script');
  script.id='alinStabilityBatchScript';
  script.src=`./core/alin-stability-batch.js?v=${encodeURIComponent(window.ALIN_CONFIG.assetVersion)}`;
  script.async=false;
  document.head.appendChild(script);
})();

/* True shared shell for teacher/library/courier. */
(function loadAlinRoleShellV2(){
  'use strict';
  if(!document.getElementById('alinRoleShellV2CompatCss')){
    const link=document.createElement('link');
    link.id='alinRoleShellV2CompatCss';
    link.rel='stylesheet';
    link.href=`./styles/alin-role-shell-v2-compat.css?v=${encodeURIComponent(window.ALIN_CONFIG.assetVersion)}`;
    document.head.appendChild(link);
  }
  if(document.getElementById('alinRoleShellV2Script'))return;
  const script=document.createElement('script');
  script.id='alinRoleShellV2Script';
  script.src=`./core/alin-role-shell-v2.js?v=${encodeURIComponent(window.ALIN_CONFIG.assetVersion)}`;
  script.async=false;
  document.head.appendChild(script);
})();

/* One admin courier hub: couriers + areas + delivery orders + settlements. */
(function loadAlinCourierAdminHub(){
  'use strict';
  let loading=false;
  function ensure(){
    if(window.__ALIN_COURIER_ADMIN_HUB__||loading)return;
    if(!window.AlinAdminModules||typeof window.renderCouriersAdmin!=='function')return;
    loading=true;
    const script=document.createElement('script');
    script.id='alinCourierAdminHubScript';
    script.src=`./modules/admin/courier-hub.js?v=${encodeURIComponent(window.ALIN_CONFIG.assetVersion)}`;
    script.async=false;
    script.addEventListener('load',()=>{loading=false},{once:true});
    script.addEventListener('error',()=>{loading=false;script.remove()},{once:true});
    document.head.appendChild(script);
  }
  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(ensure,0));
  window.addEventListener('alin:page-open',()=>setTimeout(ensure,0));
  if(window.AlinRoleRuntime?.ready?.())setTimeout(ensure,0);
})();

/* Teacher orders: show the real delivery method (courier/library) in the orders tab. */
(function loadTeacherOrderDeliveryFix(){
  'use strict';
  let loading=false;
  function ensure(){
    if(window.__ALIN_TEACHER_ORDER_DELIVERY_FIX__||loading)return;
    if(!window.TeacherApp)return;
    loading=true;
    const script=document.createElement('script');
    script.id='alinTeacherOrderDeliveryFixScript';
    script.src=`./modules/teacher/order-delivery-label-fix.js?v=${encodeURIComponent(window.ALIN_CONFIG.assetVersion)}`;
    script.async=false;
    script.addEventListener('load',()=>{loading=false},{once:true});
    script.addEventListener('error',()=>{loading=false;script.remove()},{once:true});
    document.head.appendChild(script);
  }
  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(ensure,0));
  window.addEventListener('alin:page-open',()=>setTimeout(ensure,0));
  if(window.AlinRoleRuntime?.ready?.())setTimeout(ensure,0);
})();

/* ALIN v4.3.0 courier-fee compatibility. */
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
      return {...split,delegate,admin:Math.max(0,total-teacher-library-delegate),debt:Math.max(0,total-delegate)};
    };
    const patched=Object.freeze({...base,shares,__alinCourierFeeCompatV430:true});
    window.AlinFinance=patched;
    window.AlinFinanceV207=patched;
  }
  window.addEventListener('alin:role-runtime-ready',patchFinance);
  if(typeof queueMicrotask==='function')queueMicrotask(patchFinance);else setTimeout(patchFinance,0);
})();

/* ALIN v4.3.0 delivery pricing UI bridge. */
(function installDeliveryPricingUiBridge(){
  'use strict';
  let state='idle',promise=null;
  function ready(){return typeof window.alinV430FreePricing==='function'&&typeof window.alinV430CustomPricing==='function'&&typeof window.alinV430AreaPricing==='function'}
  function ensure(){
    if(ready())return Promise.resolve(true);
    if(state==='loading'&&promise)return promise;
    if(!window.AlinCourierCore)return Promise.resolve(false);
    const existing=document.getElementById('alinDeliveryPricingRuntimeScript');
    if(existing){if(ready())return Promise.resolve(true);return new Promise(resolve=>{existing.addEventListener('load',()=>resolve(ready()),{once:true});existing.addEventListener('error',()=>resolve(false),{once:true})})}
    state='loading';
    promise=new Promise(resolve=>{
      const script=document.createElement('script');
      script.id='alinDeliveryPricingRuntimeScript';
      script.src=`./modules/admin/delivery-pricing.js?v=${encodeURIComponent(window.ALIN_CONFIG?.assetVersion||'4.3.0')}`;
      script.async=false;
      script.addEventListener('load',()=>{state=ready()?'ready':'error';if(state==='ready'){window.dispatchEvent(new CustomEvent('alin:delivery-pricing-ready'));if(window.activeAdminTab==='courierAreas'&&typeof window.renderCourierAreasAdmin==='function')setTimeout(()=>window.renderCourierAreasAdmin(),0)}resolve(state==='ready')},{once:true});
      script.addEventListener('error',()=>{state='error';promise=null;resolve(false)},{once:true});
      document.head.appendChild(script);
    });
    return promise;
  }
  window.addEventListener('alin:role-runtime-ready',ensure);
  if(window.AlinRoleRuntime?.ready?.())ensure();
})();
