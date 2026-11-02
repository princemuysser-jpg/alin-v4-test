(function () {
  'use strict';
  const VAPID='BI-mAjJvDZXH9HEus8ypbEs85J4c47DL9CRibbrT54KYsFygUVbm1B2lYaDnnFKPqLSXmy6lv1rwBvU7dzjrzwc';
  const supported=()=>location.protocol==='https:'&&'Notification' in window&&'PushManager' in window&&'serviceWorker' in navigator;
  const raw=(bytes)=>{let result='';new Uint8Array(bytes).forEach(byte=>result+=String.fromCharCode(byte));return btoa(result).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');};
  const keyBytes=()=>Uint8Array.from(atob(VAPID.replace(/-/g,'+').replace(/_/g,'/')),ch=>ch.charCodeAt(0));
  async function registration(){
    const reg=await navigator.serviceWorker.register('./business-push-sw.js',{scope:'./',updateViaCache:'none'});
    await navigator.serviceWorker.ready;
    return reg;
  }
  async function rpc(name,args,jwt,key,baseUrl){
    const response=await fetch(baseUrl+'/rest/v1/rpc/'+name,{
      method:'POST',headers:{'apikey':key,'Authorization':'Bearer '+jwt,'Content-Type':'application/json'},body:JSON.stringify(args)
    });
    if(!response.ok)throw Error('تعذر تسجيل إشعارات الأعمال ('+response.status+')');
    return response.json();
  }
  async function enable(jwt,key,baseUrl) {
    if(!supported())throw Error('المتصفح لا يدعم Web Push؛ على آيفون أضف الموقع للشاشة الرئيسية');
    const permission=await Notification.requestPermission();
    if(permission!=='granted')throw Error('اسمح بإشعارات آلين للأعمال من إعدادات المتصفح');
    const reg=await registration();
    let sub=await reg.pushManager.getSubscription();
    if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:keyBytes()});
    const json=sub.toJSON();
    await rpc('alin_register_business_web_push',{p_endpoint:json.endpoint,p_p256dh:json.keys?.p256dh||raw(sub.getKey('p256dh')),p_auth:json.keys?.auth||raw(sub.getKey('auth')),p_user_agent:navigator.userAgent},jwt,key,baseUrl);
    return true;
  }
  async function sync(jwt,key,baseUrl){
    if(!supported()||Notification.permission!=='granted')return false;
    try{
      const reg=await registration();
      const sub=await reg.pushManager.getSubscription();
      if(!sub)return false;
      const json=sub.toJSON();
      await rpc('alin_register_business_web_push',{p_endpoint:json.endpoint,p_p256dh:json.keys?.p256dh||raw(sub.getKey('p256dh')),p_auth:json.keys?.auth||raw(sub.getKey('auth')),p_user_agent:navigator.userAgent},jwt,key,baseUrl);
      return true;
    }catch(e){console.warn('business push sync',e);return false;}
  }
  async function disable(jwt,key,baseUrl){
    if(!supported())return false;
    const reg=await registration();
    const sub=await reg.pushManager.getSubscription();
    if(!sub)return true;
    await rpc('alin_unregister_business_web_push',{p_endpoint:sub.endpoint},jwt,key,baseUrl);
    await sub.unsubscribe();
    return true;
  }
  window.AlinBusinessPush=Object.freeze({enable,sync,disable,supported});
})();
