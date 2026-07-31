/* ALIN v4.2.1 — reliable PWA updater for browser and home-screen installs. */
(function(){
  'use strict';
  const PWA_VERSION='4.2.1';
  const RELOAD_KEY='alin_pwa_reload_'+PWA_VERSION;

  try{
    localStorage.removeItem('alin_v121_accountant_pass');
    localStorage.removeItem('alin_v121_accountant_user');
  }catch(_){ }

  if(!('serviceWorker' in navigator))return;
  if(!/^https?:$/.test(location.protocol))return;

  let reloading=false;
  navigator.serviceWorker.addEventListener('controllerchange',()=>{
    if(reloading)return;
    try{
      if(sessionStorage.getItem(RELOAD_KEY)==='1')return;
      sessionStorage.setItem(RELOAD_KEY,'1');
    }catch(_){ }
    reloading=true;
    location.reload();
  });

  window.addEventListener('load',async()=>{
    try{
      const registration=await navigator.serviceWorker.register(
        './service-worker.js?v='+PWA_VERSION,
        {scope:'./',updateViaCache:'none'}
      );

      const activate=worker=>{
        if(worker&&worker.state==='installed')worker.postMessage({type:'SKIP_WAITING'});
      };

      registration.addEventListener('updatefound',()=>{
        const worker=registration.installing;
        if(!worker)return;
        worker.addEventListener('statechange',()=>activate(worker));
      });

      if(registration.waiting)registration.waiting.postMessage({type:'SKIP_WAITING'});
      await registration.update().catch(()=>{});
    }catch(error){
      console.warn('[ALIN PWA v4.2.1]',error);
    }
  },{once:true});
})();
