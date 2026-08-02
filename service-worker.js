const VERSION='alin-v4.1.9.0-clean-integrated-receipts';
const STATIC_CACHE=`${VERSION}-static`;
const RUNTIME_CACHE=`${VERSION}-runtime`;

const CORE=[
  './','./index.html','./store-desktop.html','./store-mobile.html','./alin-config.js',
  './alin-performance-v4.1.7.js',
  './manifest-desktop.webmanifest','./manifest-mobile.webmanifest',
  './dist/alin-core.v4.js','./alin-app-desktop.v4.1.5.js','./alin-app-mobile.v4.1.5.js',
  './modules/core/navigation.js','./modules/core/receipts.js','./modules/core/account-admin-service.js',
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

self.addEventListener('install',event=>{
  event.waitUntil(cacheCore().then(()=>self.skipWaiting()));
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(key=>!key.startsWith(VERSION)).map(key=>caches.delete(key))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('message',event=>{
  if(event.data?.type==='SKIP_WAITING')self.skipWaiting();
});

function fallbackPath(request){
  const pathname=new URL(request.url).pathname.toLowerCase().replace(/\/+$/,'');
  if(/\/store-mobile(?:\.html)?$/.test(pathname))return './store-mobile.html';
  if(/\/store-desktop(?:\.html)?$/.test(pathname))return './store-desktop.html';
  return './index.html';
}

async function cachedNavigation(request){
  const cache=await caches.open(STATIC_CACHE);
  return (await cache.match(request,{ignoreSearch:true}))
    ||(await cache.match(fallbackPath(request),{ignoreSearch:true}))
    ||(await caches.match(fallbackPath(request),{ignoreSearch:true}))
    ||(await caches.match('./index.html',{ignoreSearch:true}));
}

async function networkFirstNavigation(request,timeoutMs=6000){
  const cache=await caches.open(STATIC_CACHE);
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),timeoutMs);

  try{
    const response=await fetch(request,{cache:'no-store',signal:controller.signal});
    if(response&&response.ok){
      await cache.put(request,response.clone());
      return response;
    }
    return (await cachedNavigation(request))||offlinePage();
  }catch(_){
    return (await cachedNavigation(request))||offlinePage();
  }finally{
    clearTimeout(timer);
  }
}

function offlinePage(){
  return new Response(
    '<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>منصة آلين</title><body style="font-family:system-ui;display:grid;place-items:center;min-height:100vh;margin:0;background:#f7f9fc;color:#163451"><main style="text-align:center;padding:24px"><h2>تعذر الاتصال مؤقتاً</h2><p>تحقق من الإنترنت ثم أعد فتح منصة آلين.</p><button onclick="location.reload()" style="padding:12px 24px;border:0;border-radius:12px;background:#0b5fa5;color:white;font-weight:800">إعادة المحاولة</button></main></body></html>',
    {status:503,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}}
  );
}

async function staleWhileRevalidate(request,event,cacheName=STATIC_CACHE){
  const cache=await caches.open(cacheName);
  const cached=await cache.match(request,{ignoreSearch:true});
  const refresh=fetch(request,{cache:'no-store'}).then(async response=>{
    if(response&&response.ok)await cache.put(request,response.clone());
    return response&&response.ok?response:null;
  }).catch(()=>null);

  if(cached){
    if(event)event.waitUntil(refresh);
    return cached;
  }

  return (await refresh)||new Response('',{status:503,statusText:'Temporarily unavailable'});
}

async function cacheFirstRuntime(request){
  const cache=await caches.open(RUNTIME_CACHE);
  const cached=await cache.match(request,{ignoreSearch:true});
  if(cached)return cached;
  try{
    const response=await fetch(request);
    if(response&&response.ok)await cache.put(request,response.clone());
    return response;
  }catch(_){
    return new Response('',{status:503,statusText:'Temporarily unavailable'});
  }
}

self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET')return;

  const url=new URL(request.url);

  // بيانات Supabase تبقى مباشرة ولا تُخزّن داخل Service Worker.
  if(url.hostname.includes('supabase.co'))return;

  // فتح الصفحات يبقى مستقراً: الشبكة أولاً ثم نسخة مخزنة، ولا نرجع ERR_FAILED.
  if(request.mode==='navigate'){
    event.respondWith(networkFirstNavigation(request,6000));
    return;
  }

  if(url.origin===self.location.origin){
    const codeAsset=['script','style','worker'].includes(request.destination)
      ||/\.(?:html?|css|js|json|webmanifest)$/i.test(url.pathname);

    if(codeAsset){
      event.respondWith(staleWhileRevalidate(request,event,STATIC_CACHE));
      return;
    }

    event.respondWith(cacheFirstRuntime(request));
    return;
  }

  if(url.hostname==='cdn.jsdelivr.net'){
    event.respondWith(cacheFirstRuntime(request));
  }
});
