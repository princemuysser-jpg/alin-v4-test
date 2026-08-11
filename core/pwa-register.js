/* ALIN v4.2.0 RC16 — idle PWA registration for weak-network startup. */
(function(){
  'use strict';
  try{localStorage.removeItem('alin_v121_accountant_pass');localStorage.removeItem('alin_v121_accountant_user')}catch(_){ }
  if(!('serviceWorker' in navigator)||!/^https?:$/.test(location.protocol))return;

  const UPDATE_KEY='alin_sw_update_check_v1';
  const DAY=24*60*60*1000;
  const schedule=callback=>{
    if('requestIdleCallback' in window)requestIdleCallback(callback,{timeout:3500});
    else setTimeout(callback,1200);
  };

  window.addEventListener('load',()=>schedule(async()=>{
    try{
      const registration=await navigator.serviceWorker.register('./service-worker.js?v=4.2.0-rc.16',{scope:'./',updateViaCache:'none'});
      registration.addEventListener('updatefound',()=>{
        const worker=registration.installing;
        if(!worker)return;
        worker.addEventListener('statechange',()=>{
          if(worker.state==='installed'&&navigator.serviceWorker.controller)worker.postMessage({type:'SKIP_WAITING'});
        });
      });
      if(registration.waiting)registration.waiting.postMessage({type:'SKIP_WAITING'});

      let last=0;
      try{last=Number(localStorage.getItem(UPDATE_KEY)||0)}catch(_){ }
      if(Date.now()-last>DAY){
        try{localStorage.setItem(UPDATE_KEY,String(Date.now()))}catch(_){ }
        setTimeout(()=>registration.update().catch(()=>{}),5000);
      }
    }catch(error){console.warn('[ALIN PWA]',error)}
  }),{once:true});
})();
