/* ALIN v4.2.0 Stable — non-blocking lifecycle-only PWA registration. */
(function(){
  'use strict';
  try{localStorage.removeItem('alin_v121_accountant_pass');localStorage.removeItem('alin_v121_accountant_user')}catch(_){ }
  if(!('serviceWorker' in navigator)||!/^https?:$/.test(location.protocol))return;

  window.addEventListener('load',()=>{
    setTimeout(async()=>{
      try{
        const registration=await navigator.serviceWorker.register('./service-worker.js?v=4.2.0',{
          scope:'./',
          updateViaCache:'none'
        });
        if(registration.waiting)registration.waiting.postMessage({type:'SKIP_WAITING'});
        try{await registration.update()}catch(_){ }
      }catch(error){console.warn('[ALIN PWA]',error)}
    },0);
  },{once:true});
})();
