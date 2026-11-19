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
  // Browser permission and the PushSubscription persist across sessions.
  // After login, restore the same subscription or recreate it silently if
  // the user had already approved notifications previously.
  async function subscribeAndRegister(jwt,key,baseUrl) {
    const reg=await registration();
    let sub=await reg.pushManager.getSubscription();
    if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:keyBytes()});
    const json=sub.toJSON();
    await rpc('alin_register_business_web_push',{
      p_endpoint:json.endpoint,
      p_p256dh:json.keys?.p256dh||raw(sub.getKey('p256dh')),
      p_auth:json.keys?.auth||raw(sub.getKey('auth')),
      p_user_agent:navigator.userAgent
    },jwt,key,baseUrl);
    return true;
  }
  async function enable(jwt,key,baseUrl) {
    if(!supported())throw Error('المتصفح لا يدعم Web Push؛ على آيفون أضف الموقع للشاشة الرئيسية');
    const permission=Notification.permission==='granted'
      ? 'granted' : await Notification.requestPermission();
    if(permission!=='granted')throw Error('اسمح بإشعارات لوحة تحكم منصة الين من إعدادات المتصفح');
    return subscribeAndRegister(jwt,key,baseUrl);
  }
  async function sync(jwt,key,baseUrl){
    if(!supported()||Notification.permission!=='granted')return false;
    try {return await subscribeAndRegister(jwt,key,baseUrl);}
    catch(e){console.warn('business push sync',e);return false;}
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
  // A page cannot play sound until a user gesture unlocks Web Audio.
  // This chime applies to push received in a focused browser tab;
  // background notification sounds are controlled by the OS/browser.
  let audioContext=null;
  function unlockTone(){
    try {
      const Audio=window.AudioContext||window.webkitAudioContext;
      if(!Audio)return;
      audioContext ||= new Audio();
      if(audioContext.state==='suspended')void audioContext.resume();
    }catch(_){}
  }
  document.addEventListener('pointerdown',unlockTone,{passive:true});
  function playTone(){
    if(document.visibilityState!=='visible'||!document.hasFocus())return;
    if(!audioContext||audioContext.state!=='running')return;
    const notes=[659.25,830.61,1046.50];
    const start=audioContext.currentTime+.01;
    notes.forEach((hz,i)=>{
      const t=start+i*.14;
      const oscillator=audioContext.createOscillator();
      const gain=audioContext.createGain();
      oscillator.type='sine';
      oscillator.frequency.value=hz;
      gain.gain.setValueAtTime(.0001,t);
      gain.gain.exponentialRampToValueAtTime(.11,t+.012);
      gain.gain.exponentialRampToValueAtTime(.0001,t+.26);
      oscillator.connect(gain).connect(audioContext.destination);
      oscillator.start(t);
      oscillator.stop(t+.28);
    });
  }
  if('serviceWorker' in navigator){
    navigator.serviceWorker.addEventListener('message',event=>{
      if(event.data?.type==='alin-business-push-received')playTone();
    });
  }
  window.AlinBusinessPush=Object.freeze({enable,sync,disable,supported});
})();
