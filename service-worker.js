const VERSION='alin-4.2.0-rc.13';
const STATIC_CACHE=`${VERSION}-static`;
const RUNTIME_CACHE=`${VERSION}-runtime`;

// RC13: atomic app-shell install. A new worker is allowed to activate only
// after every file required to open the app has been cached successfully.
const CRITICAL_SHELL=[
  './',
  './index.html',
  './store-desktop.html',
  './store-mobile.html',
  './alin-config.js',
  './core/device-router.js',
  './core/runtime-guard.js',
  './core/splash.js',
  './core/pwa-register.js',
  './core/ui-action-router.js',
  './core/boot-recovery.js',
  './core/supabase-sdk-loader.js',
  './core/csp-app-bundle-guard.js',
  './styles/alin-splash.css'
];

const OPTIONAL_SHELL=[
  './manifest-desktop.webmanifest',
  './manifest-mobile.webmanifest',
  './assets/icons/icon-192.png',
  './assets/icons/icon-512.png'
];

const cacheable=response=>!!response&&(response.ok||response.type==='opaque');

async function fetchAndCache(cache,path){
  const request=new Request(path,{cache:'reload'});
  const response=await fetch(request,{cache:'no-cache'});
  if(!cacheable(response))throw new Error(`${path}: ${response?.status||'network'}`);
  await cache.put(request,response.clone());
  return response;
}

async function precacheShellAtomic(){
  const cache=await caches.open(STATIC_CACHE);

  // Critical files are all-or-nothing. If even one fails, installation rejects,
  // the currently active worker remains in control, and its cache is preserved.
  await Promise.all(CRITICAL_SHELL.map(path=>fetchAndCache(cache,path)));

  // Non-critical metadata/icons are best effort and never block activation.
  const optional=await Promise.allSettled(OPTIONAL_SHELL.map(path=>fetchAndCache(cache,path)));
  const failed=optional.filter(item=>item.status==='rejected');
  if(failed.length)console.warn('ALIN PWA: ملفات اختيارية لم تُخزّن',failed.length);
}

self.addEventListener('install',event=>{
  event.waitUntil(precacheShellAtomic().then(()=>self.skipWaiting()));
});

self.addEventListener('activate',event=>event.waitUntil((async()=>{
  // At this point CRITICAL_SHELL is guaranteed to exist for RC13.
  const keys=await caches.keys();
  await Promise.all(
    keys
      .filter(key=>key.startsWith('alin-')&&!key.startsWith(VERSION))
      .map(key=>caches.delete(key))
  );
  await self.clients.claim();
})()));

self.addEventListener('message',event=>{
  if(event.data?.type==='SKIP_WAITING')self.skipWaiting();
});

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
    return cacheable(response)?response:null;
  }catch(_){
    return null;
  }
}

async function staleWhileRevalidate(request,event,cacheName=RUNTIME_CACHE){
  const cached=await matchAny(request);
  const refresh=updateCache(request,cacheName);
  if(cached){
    if(event)event.waitUntil(refresh);
    return cached;
  }
  const network=await refresh;
  return network||new Response('',{status:503,statusText:'Offline'});
}

async function cacheFirst(request,cacheName=RUNTIME_CACHE){
  const cached=await matchAny(request);
  if(cached)return cached;
  const network=await updateCache(request,cacheName);
  return network||new Response('',{status:503,statusText:'Offline'});
}

function navigationFallbackPath(url){
  const path=url.pathname.toLowerCase();
  if(path.endsWith('/store-mobile.html'))return './store-mobile.html';
  if(path.endsWith('/store-desktop.html'))return './store-desktop.html';
  return './index.html';
}

async function navigationResponse(request,event){
  // Cache first gives instant startup on weak links. Refresh is background only.
  const cached=await matchAny(request);
  if(cached){
    event.waitUntil(updateCache(request,STATIC_CACHE));
    return cached;
  }

  const fallbackPath=navigationFallbackPath(new URL(request.url));
  const fallbackCached=await caches.match(fallbackPath,{ignoreSearch:true});
  if(fallbackCached){
    event.waitUntil(updateCache(request,STATIC_CACHE));
    return fallbackCached;
  }

  const network=await updateCache(request,STATIC_CACHE);
  if(network)return network;

  // RC13 never returns Response.error() for a top-level navigation. This avoids
  // Chromium's ERR_FAILED screen even during a temporary network outage.
  const indexCached=await caches.match('./index.html',{ignoreSearch:true});
  if(indexCached)return indexCached;

  return new Response(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>منصة آلين</title><body dir="rtl" style="font-family:Tahoma,Arial;padding:32px;text-align:center"><h2>منصة آلين</h2><p>الاتصال بالإنترنت ضعيف حالياً. أعد المحاولة بعد لحظات.</p></body>',
    {status:503,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}}
  );
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);

  // API/auth/data always stay network-authoritative.
  if(url.hostname.endsWith('.supabase.co'))return;

  if(request.mode==='navigate'){
    event.respondWith(navigationResponse(request,event));
    return;
  }

  if(url.origin===self.location.origin){
    const codeAsset=['script','style','worker','manifest'].includes(request.destination)||/\.(?:html?|css|js|json|webmanifest)$/i.test(url.pathname);
    if(codeAsset){
      event.respondWith(staleWhileRevalidate(request,event));
      return;
    }
    event.respondWith(cacheFirst(request));
    return;
  }

  // Cache the CDN SDK after first successful load.
  if(url.hostname==='cdn.jsdelivr.net')event.respondWith(cacheFirst(request));
});
