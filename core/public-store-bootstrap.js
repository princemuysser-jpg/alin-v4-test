/* ALIN v4.2.0 RC19 — start the public catalog request immediately, without waiting for the Supabase SDK CDN. */
(function(){
  'use strict';
  const cfg=window.ALIN_CONFIG||{};
  const url=String(cfg.supabaseUrl||'').replace(/\/$/,'');
  const key=String(cfg.supabaseAnonKey||'');
  if(!url||!key||!navigator.onLine){window.__ALIN_PUBLIC_BOOTSTRAP_PROMISE__=Promise.resolve(null);return}
  const controller=typeof AbortController==='function'?new AbortController():null;
  const timer=controller?setTimeout(()=>controller.abort(),12000):null;
  window.__ALIN_PUBLIC_BOOTSTRAP_STARTED_AT__=performance.now();
  window.__ALIN_PUBLIC_BOOTSTRAP_PROMISE__=fetch(url+'/rest/v1/rpc/alin_public_store_bootstrap',{
    method:'POST',
    headers:{'apikey':key,'Content-Type':'application/json','Accept':'application/json'},
    body:'{}',
    cache:'no-store',
    signal:controller?.signal
  }).then(async response=>{
    if(!response.ok)throw new Error('public-bootstrap-'+response.status);
    const data=await response.json();
    window.__ALIN_PUBLIC_BOOTSTRAP__=data&&typeof data==='object'?data:null;
    window.__ALIN_PUBLIC_BOOTSTRAP_MS__=Math.round(performance.now()-window.__ALIN_PUBLIC_BOOTSTRAP_STARTED_AT__);
    return window.__ALIN_PUBLIC_BOOTSTRAP__;
  }).catch(error=>{
    console.warn('[ALIN public bootstrap]',error?.message||error);
    return null;
  }).finally(()=>{if(timer)clearTimeout(timer)});
})();
