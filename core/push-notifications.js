/* ALIN v4.2.0 — storefront Web Push opt-in for guests and registered students. */
(function(){
  'use strict';
  const STUDENT_SESSION_KEY='alin_student_secure_session_v3';
  const LEGACY_DISMISS_KEY='alin_push_prompt_dismissed_at_v2';
  let dismissedThisVisit=false;
  const PUBLIC_KEY='BI-mAjJvDZXH9HEus8ypbEs85J4c47DL9CRibbrT54KYsFygUVbm1B2lYaDnnFKPqLSXmy6lv1rwBvU7dzjrzwc';
  const supported=()=>('serviceWorker' in navigator)&&('PushManager' in window)&&('Notification' in window)&&/^https?:$/.test(location.protocol);
  const client=()=>window.sb||window.AlinCloud?.client?.()||null;
  const studentState=()=>{try{return JSON.parse(localStorage.getItem(STUDENT_SESSION_KEY)||sessionStorage.getItem(STUDENT_SESSION_KEY)||'null')}catch(_){return null}};
  const deviceId=()=>window.ALINStudentAuth?.deviceId?.()||window.AlinStudentAuth?.deviceId?.()||(()=>{try{let v=localStorage.getItem('alin_device_id_v3');if(!v){v=crypto.randomUUID?.()||`${Date.now()}-${Math.random()}`;localStorage.setItem('alin_device_id_v3',v)}return v}catch(_){return'browser-device'}})();
  const b64ToUint8=value=>{const pad='='.repeat((4-value.length%4)%4);const raw=atob((value+pad).replace(/-/g,'+').replace(/_/g,'/'));return Uint8Array.from([...raw].map(c=>c.charCodeAt(0)))};
  const b64=value=>{const bytes=new Uint8Array(value);let raw='';bytes.forEach(v=>raw+=String.fromCharCode(v));return btoa(raw).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')};

  async function registerSubscription(subscription){
    const c=client(); if(!c)throw new Error('خدمة الإشعارات غير جاهزة');
    const json=subscription.toJSON(); const state=studentState();
    const {data,error}=await c.rpc('alin_register_push_subscription',{
      p_endpoint:json.endpoint,
      p_p256dh:json.keys?.p256dh||b64(subscription.getKey('p256dh')),
      p_auth:json.keys?.auth||b64(subscription.getKey('auth')),
      p_user_agent:navigator.userAgent,
      p_student_token:state?.token||null,
      p_student_device:state?.token?deviceId():null
    });
    if(error)throw error; return data;
  }

  async function currentRegistration(){return navigator.serviceWorker.ready}
  async function existing(){if(!supported())return null;const reg=await currentRegistration();return reg.pushManager.getSubscription()}

  async function sync(){
    if(!supported()||Notification.permission!=='granted')return false;
    try{const sub=await existing();if(!sub)return false;await registerSubscription(sub);return true}catch(error){console.warn('[ALIN push sync]',error);return false}
  }

  async function enable(){
    if(!supported())throw new Error('هذا الجهاز أو المتصفح لا يدعم إشعارات التطبيق');
    let permission=Notification.permission;
    if(permission!=='granted')permission=await Notification.requestPermission();
    if(permission!=='granted'){hidePrompt();throw new Error('لم يتم السماح بإشعارات منصة آلين')}
    const reg=await currentRegistration();
    let sub=await reg.pushManager.getSubscription();
    if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:b64ToUint8(PUBLIC_KEY)});
    await registerSubscription(sub);
    hidePrompt();
    window.toast?.('تم تفعيل إشعارات منصة آلين');
    return true;
  }

  function promptAllowed(){
    if(!supported()||Notification.permission==='denied'||Notification.permission==='granted')return false;
    return !dismissedThisVisit;
  }
  function hidePrompt(){document.getElementById('alinPushPrompt')?.remove()}
  function dismiss(){dismissedThisVisit=true;hidePrompt()}
  function renderPrompt(){
    if(!promptAllowed()||document.getElementById('alinPushPrompt'))return;
    const box=document.createElement('div');box.id='alinPushPrompt';box.className='alin-push-prompt';
    box.innerHTML='<div class="alin-push-prompt-icon" aria-hidden="true"><span>🔔</span></div><div class="alin-push-prompt-copy"><div class="alin-push-prompt-kicker">إشعارات آلين</div><strong>خلّك قريب من كل جديد</strong><span>فعّل الإشعارات لتصلك العروض والإعلانات الجديدة أول بأول.</span><div class="alin-push-prompt-tags"><i>العروض الجديدة</i><i>الإعلانات</i></div></div><div class="alin-push-prompt-actions"><button type="button" data-push-enable><span>تفعيل الإشعارات</span></button><button type="button" class="secondary" data-push-dismiss>لاحقاً</button></div>';
    box.querySelector('[data-push-enable]')?.addEventListener('click',async e=>{const btn=e.currentTarget;btn.disabled=true;btn.textContent='جارٍ التفعيل...';try{await enable()}catch(error){window.toast?.(error?.message||'تعذر تفعيل الإشعارات');btn.disabled=false;btn.textContent='تفعيل الإشعارات'}});
    box.querySelector('[data-push-dismiss]')?.addEventListener('click',dismiss);
    document.body.appendChild(box);
  }

  function boot(){
    if(!supported())return;
    try{localStorage.removeItem(LEGACY_DISMISS_KEY)}catch(_){}
    if(Notification.permission==='granted')sync(); else setTimeout(renderPrompt,1800);
  }
  window.addEventListener('load',boot,{once:true});
  window.addEventListener('alin:student-session',()=>{if(Notification.permission==='granted')sync()});
  document.addEventListener('visibilitychange',()=>{
    if(document.visibilityState!=='visible')return;
    if(Notification.permission==='granted')sync();
    else if(Notification.permission==='denied')hidePrompt();
  });
  window.AlinPush=Object.freeze({supported,enable,sync,existing,renderPrompt});
})();
