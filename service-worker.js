const VERSION='alin-4.2.0-rc.14';
const STATIC_CACHE=`${VERSION}-static`;
const RUNTIME_CACHE=`${VERSION}-runtime`;

// RC14 stability rule:
// Cloudflare Pages owns HTML/navigation delivery and redirects.
// The Service Worker NEVER calls respondWith() for top-level navigations.
// This prevents a controlled page from turning a normal Pages navigation into
// Chromium ERR_FAILED after the first successful visit.

const CORE_ASSETS=[
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

const cacheable=response=>!!response&&(response.ok||response.type==='opaque');

async function safeFetch(request){
  try{
    const response=await fetch(request,{cache:'no-cache'});
    return cacheable(response)?response:null;
  }catch(_){
    return null;
  }
}

async function precacheCore(){
  const cache=await caches.open(STATIC_CACHE);
  await Promise.allSettled(CORE_ASSETS.map(async path=>{
    const response=await safeFetch(new Request(path,{cache:'reload'}));
    if(response)await cache.put(path,response.clone());
  }));
}

self.addEventListener('install',event=>{
  event.waitUntil(precacheCore().then(()=>self.skipWaiting()));
});

self.addEventListener('activate',event=>event.waitUntil((async()=>{
  const keys=await caches.keys();
  await Promise.all(keys.filter(key=>key.startsWith('alin-')&&!key.startsWith(VERSION)).map(key=>caches.delete(key)));
  if(self.registration.navigationPreload){
    try{await self.registration.navigationPreload.disable()}catch(_){ }
  }
  await self.clients.claim();
})()));

self.addEventListener('message',event=>{
  if(event.data?.type==='SKIP_WAITING')self.skipWaiting();
});

async function cacheFirst(request,cacheName=RUNTIME_CACHE){
  const cached=await caches.match(request,{ignoreSearch:true});
  if(cached)return cached;
  const network=await safeFetch(request);
  if(network){
    try{const cache=await caches.open(cacheName);await cache.put(request,network.clone())}catch(_){ }
    return network;
  }
  return new Response('',{status:503,statusText:'Offline'});
}

async function staleWhileRevalidate(request,event,cacheName=RUNTIME_CACHE){
  const cached=await caches.match(request,{ignoreSearch:true});
  const refresh=(async()=>{
    const network=await safeFetch(request);
    if(network){
      try{const cache=await caches.open(cacheName);await cache.put(request,network.clone())}catch(_){ }
    }
    return network;
  })();
  if(cached){
    event.waitUntil(refresh);
    return cached;
  }
  return (await refresh)||new Response('',{status:503,statusText:'Offline'});
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;

  // IMPORTANT: never intercept page navigations. Let Cloudflare Pages and the
  // browser handle HTML, redirects, HTTP cache, ETag/304 and connection errors.
  if(request.mode==='navigate')return;

  const url=new URL(request.url);

  // API/auth/data remain network-authoritative.
  if(url.hostname.endsWith('.supabase.co'))return;

  if(url.origin===self.location.origin){
    const codeAsset=['script','style','worker','manifest'].includes(request.destination)||/\.(?:css|js|json|webmanifest)$/i.test(url.pathname);
    if(codeAsset){
      event.respondWith(staleWhileRevalidate(request,event));
      return;
    }
    if(['image','font'].includes(request.destination)||/\.(?:png|jpe?g|webp|gif|svg|ico|woff2?)$/i.test(url.pathname)){
      event.respondWith(cacheFirst(request));
    }
    return;
  }

  // The optional CDN SDK can be reused after one successful request.
  if(url.hostname==='cdn.jsdelivr.net')event.respondWith(cacheFirst(request));
});
