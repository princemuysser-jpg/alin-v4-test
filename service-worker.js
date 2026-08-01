const VERSION='alin-v4.1.7-performance-student-isolation';
const STATIC_CACHE=`${VERSION}-static`;
const RUNTIME_CACHE=`${VERSION}-runtime`;

// ملفات التشغيل الأساسية. تُخزّن مسبقاً حتى تفتح المنصة فوراً في الزيارات التالية.
const CORE=[
  './','./index.html','./store-desktop.html','./store-mobile.html','./alin-config.js',
  './alin-performance-v4.1.7.js',
  './manifest-desktop.webmanifest','./manifest-mobile.webmanifest',
  './dist/alin-core.v4.js','./alin-app-desktop.v4.1.5.js','./alin-app-mobile.v4.1.5.js',
  './modules/core/navigation.js','./modules/core/account-admin-service.js',
  './modules/teacher/admin-word-download.js','./core/boot-recovery.js','./core/pwa-register.js',
  './core/device-router.js','./core/runtime-guard.js','./core/splash.js',
  './dist/css/desktop.bundle.css','./dist/css/mobile.bundle.css',
  './styles/alin-tokens.css','./styles/alin-shared.css','./styles/alin-branding.css',
  './styles/alin-i18n.css','./styles/alin-desktop.css','./styles/alin-mobile.css','./styles/alin-splash.css',
  './store/banners.css','./store/mobile-navigation.css',
  './assets/images/alin-splash-desktop.webp','./assets/images/alin-splash-mobile.webp',
  './assets/icons/icon-192.png','./assets/icons/icon-512.png'
];

async function cacheCore(){
  const cache=await caches.open(STATIC_CACHE);
  const results=await Promise.allSettled(CORE.map(async path=>{
    const request=new Request(path,{cache:'reload'});
    const response=await fetch(request,{cache:'no-store'});
    if(!response.ok)throw new Error(`${path}: ${response.status}`);
    await cache.put(request,response.clone());
  }));
  const failed=results.filter(item=>item.status==='rejected');
  if(failed.length)console.warn('ALIN PWA: بعض ملفات التشغيل لم تُخزّن',failed);
}

self.addEventListener('install',event=>event.waitUntil(cacheCore().then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(
  caches.keys()
    .then(keys=>Promise.all(keys.filter(key=>!key.startsWith(VERSION)).map(key=>caches.delete(key))))
    .then(()=>self.clients.claim())
));
self.addEventListener('message',event=>{if(event.data?.type==='SKIP_WAITING')self.skipWaiting()});

async function staleWhileRevalidate(request,event,cacheName=STATIC_CACHE){
  const cache=await caches.open(cacheName);
  const cached=await cache.match(request,{ignoreSearch:true});
  const refresh=fetch(request,{cache:'no-store'}).then(async response=>{
    if(response.ok)await cache.put(request,response.clone());
    return response;
  }).catch(()=>null);
  if(event&&cached)event.waitUntil(refresh);
  return cached||(await refresh)||Response.error();
}

async function cacheFirstRuntime(request){
  const cache=await caches.open(RUNTIME_CACHE);
  const cached=await cache.match(request,{ignoreSearch:true});
  if(cached)return cached;
  const response=await fetch(request);
  if(response.ok)await cache.put(request,response.clone());
  return response;
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;
  const url=new URL(request.url);

  // بيانات Supabase تبقى مباشرة ولا تُخزّن داخل Service Worker.
  if(url.hostname.includes('supabase.co'))return;

  // الصفحة تظهر من الكاش فوراً، ويجري تحديثها بالخلفية.
  if(request.mode==='navigate'){
    event.respondWith(staleWhileRevalidate(request,event,STATIC_CACHE).then(async response=>
      response&&response.type!=='error'?response:
      (await caches.match('./index.html',{ignoreSearch:true}))||Response.error()
    ));
    return;
  }

  if(url.origin===self.location.origin){
    const codeAsset=['script','style','worker'].includes(request.destination)||/\.(?:html?|css|js|json|webmanifest)$/i.test(url.pathname);
    if(codeAsset){event.respondWith(staleWhileRevalidate(request,event,STATIC_CACHE));return;}
    event.respondWith(cacheFirstRuntime(request));
    return;
  }

  if(url.hostname==='cdn.jsdelivr.net')event.respondWith(cacheFirstRuntime(request));
});
