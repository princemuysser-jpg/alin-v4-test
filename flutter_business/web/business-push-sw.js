/* Dedicated ALIN Business push worker: only notifies opted-in business users. */
self.addEventListener('push',event=>{
  let data={};
  try{data=event.data?.json()||{}}catch(_){data={body:event.data?.text()||''}}
  const title=String(data.title||'آلين للأعمال — طلب جديد').slice(0,160);
  const target=new URL('./',self.registration.scope);
  const raw=String(data.url||'');
  const match=raw.match(/[?&](?:order|order_id)=([^&]+)/);
  if(match)target.searchParams.set('order',decodeURIComponent(match[1]));
  const options={body:String(data.body||data.message||'وصل طلب جديد').slice(0,500),tag:String(data.tag||data.notification_id||'alin-business-order'),renotify:true,requireInteraction:true,
    icon:'./favicon.svg',badge:'./favicon.svg',vibrate:[350,150,350,150,600],data:{url:target.href}};
  event.waitUntil(self.registration.showNotification(title,options));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const url=event.notification.data?.url||new URL('./',self.registration.scope).href;
  event.waitUntil(clients.matchAll({type:'window',includeUncontrolled:true}).then(async windows=>{
    const existing=windows.find(c=>new URL(c.url).pathname.startsWith(new URL(self.registration.scope).pathname));
    if(existing){await existing.focus();await existing.navigate(url);return;}
    return clients.openWindow(url);
  }));
});
