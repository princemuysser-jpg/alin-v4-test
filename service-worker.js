const VERSION='alin-4.2.0-rc.12';
const STATIC_CACHE=`${VERSION}-static`;
const RUNTIME_CACHE=`${VERSION}-runtime`;

// Small app shell only. Heavy desktop/mobile bundles are cached naturally after the device opens them.
const SHELL=[
  './','./index.html','./store-desktop.html','./store-mobile.html','./alin-config.js',
  './manifest-desktop.webmanifest','./manifest-mobile.webmanifest',
  './core/device-router.js','./core/runtime-guard.js','./core/splash.js','./core/pwa-register.js',
  './core/ui-action-router.js','./core/boot-recovery.js','./core/supabase-sdk-loader.js','./core/csp-app-bundle-guard.js',
  './styles/alin-splash.css','./assets/icons/icon-192.png','./assets/icons/icon-512.png'
];

const cacheable=response=>!!response&&(response.ok||response.type==='opaque');

async function precacheShell(){
  const cache=await caches.open(STATIC_CACHE);
  const results=await Promise.allSettled(SHELL.map(async path=>{
    const request=new Request(path,{cache:'reload'});
    const response=await fetch(request,{cache:'no-cache'});
    if(!cacheable(response))throw new Error(`${path}: ${response?.status||'network'}`);
    await cache.put(request,response.clone());
  }));
  const failed=results.filter(item=>item.status==='rejected');
  if(failed.length)console.warn('ALIN PWA: بعض ملفات الغلاف لم تُخزّن',failed.length);
}

self.addEventListener('install',event=>event.waitUntil(precacheShell().then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  const keys=await caches.keys();
  await Promise.all(keys.filter(key=>key.startsWith('alin-')&&!key.startsWith(VERSION)).map(key=>caches.delete(key)));
  await self.clients.claim();
})()));
self.addEventListener('message',event=>{if(event.data?.type==='SKIP_WAITING')self.skipWaiting()});

async function matchAny(request){
  return (await caches.match(request,{ignoreSearch:true}))||null;
}

async function updateCache(request,cacheName){
  try{
    const response=await fetch(request,{cache:'no-cache'});
    if(cacheable(response)){
      const cache=await caches.open(cacheName);
      await cache.put(request,response.clone());
    }
    return response;
  }catch(_){return null}
}

async function staleWhileRevalidate(request,event,cacheName=RUNTIME_CACHE){
  const cached=await matchAny(request);
  const refresh=updateCache(request,cacheName);
  if(cached){
    if(event)event.waitUntil(refresh);
    return cached;
  }
  return (await refresh)||Response.error();
}

async function cacheFirst(request,cacheName=RUNTIME_CACHE){
  const cached=await matchAny(request);
  if(cached)return cached;
  return (await updateCache(request,cacheName))||Response.error();
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);

  // API/auth/data always stay network-authoritative.
  if(url.hostname.endsWith('.supabase.co'))return;

  // Navigations and local code must never wait on a slow network when a cached copy exists.
  if(request.mode==='navigate'){
    event.respondWith((async()=>{
      const cached=await matchAny(request);
      if(cached){event.waitUntil(updateCache(request,STATIC_CACHE));return cached}
      const network=await updateCache(request,STATIC_CACHE);
      if(network)return network;
      return (await caches.match('./index.html',{ignoreSearch:true}))||Response.error();
    })());
    return;
  }

  if(url.origin===self.location.origin){
    const codeAsset=['script','style','worker','manifest'].includes(request.destination)||/\.(?:html?|css|js|json|webmanifest)$/i.test(url.pathname);
    if(codeAsset){event.respondWith(staleWhileRevalidate(request,event));return}
    event.respondWith(cacheFirst(request));
    return;
  }

  // Cache the CDN SDK too (opaque responses are valid cache entries for script requests).
  if(url.hostname==='cdn.jsdelivr.net')event.respondWith(cacheFirst(request));
});
