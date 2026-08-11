/* ALIN v4.2.0 RC16 — non-blocking Supabase SDK loader with automatic retry. */
(function(){
  'use strict';
  const CDN='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.110.7';
  let loading=false;
  let retryTimer=null;

  function ready(){
    window.__ALIN_CDN_READY__=true;
    window.__ALIN_CDN_ERROR__=false;
    try{window.init?.()}catch(_){ }
    window.dispatchEvent(new CustomEvent('alin:supabase-ready'));
    Promise.resolve(window.ALINAuth?.restoreSession?.()).catch(()=>false).finally(()=>{
      if(navigator.onLine)window.AlinCloud?.refresh?.({force:true,reason:'supabase-ready'}).catch(()=>{});
    });
  }

  function load(){
    if(window.supabase){ready();return}
    if(loading||!navigator.onLine)return;
    loading=true;
    const existing=document.getElementById('alinSupabaseCdnScript');
    if(existing){existing.remove()}
    const script=document.createElement('script');
    script.id='alinSupabaseCdnScript';
    script.src=CDN;
    script.async=true;
    script.fetchPriority='low';
    script.addEventListener('load',()=>{loading=false;ready()},{once:true});
    script.addEventListener('error',()=>{
      loading=false;window.__ALIN_CDN_ERROR__=true;
      window.dispatchEvent(new CustomEvent('alin:supabase-unavailable'));
      clearTimeout(retryTimer);
      retryTimer=setTimeout(load,6000);
    },{once:true});
    document.head.appendChild(script);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(load,0),{once:true});
  else setTimeout(load,0);
  window.addEventListener('online',()=>setTimeout(load,150));
  window.AlinSupabaseSdk=Object.freeze({load,ready:()=>!!window.supabase});
})();
