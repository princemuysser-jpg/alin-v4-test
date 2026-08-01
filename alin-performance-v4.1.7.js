/*
 * ALIN v4.1.7 — Public-store performance and student-session isolation.
 * Safe additive layer: does not replace order, finance, login, or role logic.
 */
(function(){
  'use strict';

  const VERSION='4.1.7-performance-student-isolation';
  const PUBLIC_REFRESH_MS=90*1000;
  const AUTH_DEDUPE_MS=2500;
  const LAST_PUBLIC_REFRESH_KEY='alin_public_refresh_v417';
  const DEVICE_V1='alin_device_id_v1';
  const DEVICE_V3='alin_device_id_v3';
  const PUBLIC_CORE_TABLES=['settings','accounts','categories','booklets','products'];
  const PUBLIC_DEFERRED_TABLES=['delivery_areas','banners','coupons','notifications'];

  let publicPromise=null;
  let deferredTimer=0;
  let authenticatedPromise=null;
  let lastAuthenticatedStart=0;
  let installed=false;

  function randomId(){
    try{return crypto.randomUUID()}catch(_){return `${Date.now()}-${Math.random().toString(36).slice(2)}`}
  }

  // الطلب وحساب الطالب يستخدمان مفتاحي جهاز قديمين مختلفين.
  // نوحّدهما فقط عند أول استخدام، ولا نغيّر أي جهاز قديم حتى لا تضيع طلباته السابقة.
  function ensureStudentDevice(){
    try{
      const orderDevice=localStorage.getItem(DEVICE_V1);
      const accountDevice=localStorage.getItem(DEVICE_V3);
      const canonical=accountDevice||orderDevice||randomId();
      if(!orderDevice)localStorage.setItem(DEVICE_V1,canonical);
      if(!accountDevice)localStorage.setItem(DEVICE_V3,canonical);
      window.ALIN_STUDENT_DEVICE_ID=canonical;
      return canonical;
    }catch(_){
      const fallback=randomId();
      window.ALIN_STUDENT_DEVICE_ID=fallback;
      return fallback;
    }
  }

  function activeRole(){
    return String(window.current?.role||'').trim().toLowerCase();
  }

  function hasPublicCatalog(){
    const db=window.db||{};
    return Array.isArray(db.products)&&Array.isArray(db.booklets)&&Array.isArray(db.categories);
  }

  function readLastPublicRefresh(){
    try{return Number(localStorage.getItem(LAST_PUBLIC_REFRESH_KEY)||0)||0}catch(_){return 0}
  }

  function writeLastPublicRefresh(){
    try{localStorage.setItem(LAST_PUBLIC_REFRESH_KEY,String(Date.now()))}catch(_){}
  }

  function renderPublicStore(){
    try{
      if(typeof window.renderStore==='function')window.renderStore();
      window.dispatchEvent(new CustomEvent('alin:public-fast-render',{detail:{version:VERSION,at:Date.now()}}));
    }catch(error){console.warn('[ALIN v4.1.7 renderStore]',error)}
  }

  function showCachedPublicSnapshot(){
    try{window.AlinCloud?.loadCachedSnapshot?.()}catch(error){console.warn('[ALIN v4.1.7 cache]',error)}
    if(hasPublicCatalog()){
      if(typeof requestAnimationFrame==='function')requestAnimationFrame(renderPublicStore);
      else setTimeout(renderPublicStore,0);
      return true;
    }
    return false;
  }

  function scheduleDeferredLoad(originalLoad,baseOptions){
    clearTimeout(deferredTimer);
    deferredTimer=setTimeout(()=>{
      if(activeRole())return;
      Promise.resolve(originalLoad({
        ...baseOptions,
        tables:PUBLIC_DEFERRED_TABLES,
        render:false,
        status:false,
        force:true,
        reason:'public-deferred-v4.1.7'
      })).then(renderPublicStore).catch(error=>console.warn('[ALIN v4.1.7 deferred]',error));
    },1400);
  }

  function installLoadWrapper(){
    if(installed)return true;
    if(typeof window.load!=='function')return false;
    if(window.load.__alinPerformanceV417){installed=true;return true}

    const originalLoad=window.load.bind(window);

    async function optimizedLoad(options={}){
      const opts=options&&typeof options==='object'?{...options}:{};
      const role=activeRole();

      // واجهة الطالب/المتجر: افتح من الكاش فوراً، ثم حدّث البيانات الأساسية فقط.
      if(!role){
        const cacheReady=showCachedPublicSnapshot();
        const age=Date.now()-readLastPublicRefresh();
        if(!opts.force&&cacheReady&&age>=0&&age<PUBLIC_REFRESH_MS)return window.db;
        if(publicPromise)return publicPromise;

        publicPromise=Promise.resolve(originalLoad({
          ...opts,
          tables:PUBLIC_CORE_TABLES,
          render:false,
          status:false,
          reason:opts.reason||'public-core-v4.1.7'
        })).then(snapshot=>{
          writeLastPublicRefresh();
          renderPublicStore();
          scheduleDeferredLoad(originalLoad,opts);
          return snapshot;
        }).catch(error=>{
          if(cacheReady)return window.db;
          throw error;
        }).finally(()=>{publicPromise=null});

        return publicPromise;
      }

      // الحسابات المسجلة: امنع طلبات التحميل المتكررة الناتجة من ضغط الأزرار أو إعادة الرسم.
      const now=Date.now();
      if(!opts.force&&authenticatedPromise&&now-lastAuthenticatedStart<AUTH_DEDUPE_MS)return authenticatedPromise;
      lastAuthenticatedStart=now;
      authenticatedPromise=Promise.resolve(originalLoad(opts)).finally(()=>{authenticatedPromise=null});
      return authenticatedPromise;
    }

    optimizedLoad.__alinPerformanceV417=true;
    optimizedLoad.original=originalLoad;
    window.load=optimizedLoad;
    installed=true;
    document.documentElement.dataset.alinPerformance='4.1.7';
    window.dispatchEvent(new CustomEvent('alin:performance-ready',{detail:{version:VERSION}}));
    return true;
  }

  function boot(){
    ensureStudentDevice();
    let attempts=0;
    const timer=setInterval(()=>{
      attempts++;
      if(installLoadWrapper()||attempts>240)clearInterval(timer);
    },25);
    window.addEventListener('alin:auth-login',()=>installLoadWrapper());
    window.addEventListener('alin:auth-restored',()=>installLoadWrapper());
  }

  if(document.readyState==='loading')boot();
  else boot();
})();
