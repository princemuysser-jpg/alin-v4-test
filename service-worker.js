/* ALIN v4.2.0 RC21 — lifecycle-only Service Worker.
   Runtime assets are NOT intercepted or cached by the Service Worker.
   Cloudflare Pages + the browser HTTP cache own HTML/CSS/JS/image delivery.
   This prevents stale RC assets from surviving on phones/tablets. */
const VERSION='alin-4.2.0-rc.21';

self.addEventListener('install',event=>{
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(key=>/^alin-/i.test(key)).map(key=>caches.delete(key)));
    if(self.registration.navigationPreload){
      try{await self.registration.navigationPreload.disable()}catch(_){ }
    }
    await self.clients.claim();
  })());
});

self.addEventListener('message',event=>{
  if(event.data?.type==='SKIP_WAITING')self.skipWaiting();
  if(event.data?.type==='CLEAR_ALIN_CACHES'){
    event.waitUntil((async()=>{
      const keys=await caches.keys();
      await Promise.all(keys.filter(key=>/^alin-/i.test(key)).map(key=>caches.delete(key)));
    })());
  }
});

// Deliberately no fetch event handler.
// A registered PWA remains supported, while network/versioned HTTP caching is authoritative.
