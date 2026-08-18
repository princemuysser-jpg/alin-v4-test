/* ALIN v4.2.0 UI13 — safe release cache cleanup for installed PWAs.
   Never stops the document, unregisters the active Service Worker, or reloads the app during launch.
   Versioned asset URLs + the lifecycle-only Service Worker own updates. */
(function(){
  'use strict';
  const EPOCH='4.2.0-ui13-student-session';
  const KEY='alin_cache_epoch';

  let marked='';
  try{marked=localStorage.getItem(KEY)||''}catch(_){ }
  if(marked===EPOCH)return;

  try{localStorage.setItem(KEY,EPOCH)}catch(_){ }

  // Cleanup only old CacheStorage entries. This is intentionally non-blocking and never navigates.
  if('caches' in window){
    Promise.resolve().then(async()=>{
      try{
        const keys=await caches.keys();
        await Promise.allSettled(keys.filter(key=>/^alin-/i.test(key)).map(key=>caches.delete(key)));
      }catch(error){console.warn('[ALIN cache cleanup]',error)}
    });
  }

  // Ask the current registration to update in the background. Do not unregister it.
  if('serviceWorker' in navigator){
    Promise.resolve().then(async()=>{
      try{
        const registration=await navigator.serviceWorker.getRegistration('./');
        await registration?.update?.();
      }catch(_){ }
    });
  }
})();
