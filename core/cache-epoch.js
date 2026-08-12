/* ALIN v4.2.0 Stable — one-time stale Service Worker/CacheStorage cleanup.
   Does NOT touch cart, account, auth, language, theme, IndexedDB or app data. */
(function(){
  'use strict';
  const EPOCH='4.2.0-layoutfix-1';
  const KEY='alin_cache_epoch';
  const PARAM='__alin_clean';

  const currentUrl=()=>{ try{return new URL(location.href)}catch(_){return null} };
  const removeMarker=()=>{
    const url=currentUrl();
    if(!url||url.searchParams.get(PARAM)!==EPOCH)return;
    url.searchParams.delete(PARAM);
    try{history.replaceState(history.state,'',url.pathname+(url.searchParams.toString()?'?'+url.searchParams.toString():'')+url.hash)}catch(_){ }
  };

  let marked='';
  try{marked=localStorage.getItem(KEY)||''}catch(_){ }
  if(marked===EPOCH){ removeMarker(); return; }

  if(!('serviceWorker' in navigator)&&!('caches' in window)){
    try{localStorage.setItem(KEY,EPOCH)}catch(_){ }
    removeMarker();
    return;
  }

  (async()=>{
    let registrations=[];
    let cacheKeys=[];
    try{if('serviceWorker' in navigator)registrations=await navigator.serviceWorker.getRegistrations()}catch(_){ }
    try{if('caches' in window)cacheKeys=await caches.keys()}catch(_){ }

    const oldAlinCaches=cacheKeys.filter(key=>/^alin-/i.test(key));
    const hasOldWorker=registrations.some(reg=>{
      try{return new URL(reg.scope).origin===location.origin}catch(_){return true}
    });
    const needsReset=hasOldWorker||oldAlinCaches.length>0||!!navigator.serviceWorker?.controller;

    try{localStorage.setItem(KEY,EPOCH)}catch(_){ }
    if(!needsReset){ removeMarker(); return; }

    // Stop the old controlled document before it can finish loading stale JS/CSS.
    try{window.stop()}catch(_){ }
    try{document.documentElement.style.visibility='hidden'}catch(_){ }

    await Promise.allSettled(registrations.map(reg=>reg.unregister()));
    await Promise.allSettled(oldAlinCaches.map(key=>caches.delete(key)));

    const url=currentUrl();
    if(!url){ location.reload(); return; }
    url.searchParams.set(PARAM,EPOCH);
    location.replace(url.href);
  })().catch(()=>{
    try{localStorage.setItem(KEY,EPOCH)}catch(_){ }
    removeMarker();
  });
})();
