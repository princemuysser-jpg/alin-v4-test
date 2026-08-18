/* ALIN v4.2.0 Stable — lifecycle-only Service Worker.
   Runtime assets are NOT intercepted or cached by the Service Worker.
   Cloudflare Pages + the browser HTTP cache own HTML/CSS/JS/image delivery.
   This prevents stale release assets from surviving on phones/tablets. */
const VERSION='alin-4.2.0-ui7';

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


/* ALIN Web Push — external device notifications. */
self.addEventListener('push',event=>{
  event.waitUntil((async()=>{
    let data={};
    try{data=event.data?.json?.()||{body:event.data?.text?.()||''}}catch(_){data={body:event.data?.text?.()||''}}
    const title=String(data.title||'منصة آلين');
    const options={
      body:String(data.body||data.message||''),
      icon:data.icon||'./assets/icons/alin-icon-192-v2.png',
      badge:data.badge||'./assets/icons/alin-icon-192-v2.png',
      tag:String(data.tag||data.notification_id||'alin-notification'),
      renotify:data.renotify!==false,
      data:{url:data.url||'./store-mobile.html',notification_id:data.notification_id||null},
      dir:'rtl',lang:'ar'
    };
    await self.registration.showNotification(title,options);
  })());
});

self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const target=new URL(event.notification.data?.url||'./store-mobile.html',self.registration.scope).href;
  event.waitUntil((async()=>{
    const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of windows){
      if('focus' in client){try{await client.focus();if('navigate' in client)await client.navigate(target);return}catch(_){}}
    }
    if(self.clients.openWindow)await self.clients.openWindow(target);
  })());
});
