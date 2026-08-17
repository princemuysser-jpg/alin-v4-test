// === store/personal-offers.js ===
/* ALIN v4.2.0 — private student offers + storefront retention banner. */
(function(){
  'use strict';
  const esc=v=>String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const client=()=>window.sb||window.AlinCloud?.client?.()||null;
  let offers=[];
  let touchTimer=0;
  const DISMISS_KEY='alin_personal_offer_dismissed_v1';
  function dismissed(){try{return new Set(JSON.parse(sessionStorage.getItem(DISMISS_KEY)||'[]'))}catch(_){return new Set()}}
  function rememberDismiss(id){const set=dismissed();set.add(String(id));try{sessionStorage.setItem(DISMISS_KEY,JSON.stringify([...set]))}catch(_){}}
  async function rpc(name,args={}){const c=client();if(!c?.rpc)throw new Error('خدمة العروض غير متاحة');const {data,error}=await c.rpc(name,args);if(error)throw error;return data}
  const auth=()=>window.AlinStudentAuth;
  function rows(){return offers.slice()}
  function best(){const hidden=dismissed();return offers.find(o=>String(o.status||'active')==='active'&&!hidden.has(String(o.id)))||null}
  function discountText(o){if(!o)return'';return String(o.discount_type)==='fixed'?`${Number(o.discount_value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')} د.ع`:`${Number(o.discount_value||0)}%`}
  function ensureHost(){let host=document.getElementById('alinPersonalOfferHost');if(host)return host;const home=document.getElementById('alinStoreHomeView');const catalog=document.getElementById('alinStoreCatalogView');const grid=document.getElementById('storeGrid');const parent=home||catalog||grid?.parentElement;if(!parent)return null;host=document.createElement('div');host.id='alinPersonalOfferHost';host.className='alin-personal-offer-host';if(home)home.prepend(host);else if(grid)grid.parentElement.insertBefore(host,grid);else parent.prepend(host);return host}
  function render(){const host=ensureHost();if(!host)return;const student=auth()?.current?.();const o=student?best():null;if(!o){host.innerHTML='';host.hidden=true;return}host.hidden=false;host.innerHTML=`<article class="alin-personal-offer"><div class="alin-personal-offer-icon">🎁</div><div class="alin-personal-offer-copy"><span>عرض خاص لك</span><h3>${esc(o.offer_title||'اشتقنالك في منصة آلين')}</h3><p>${esc(o.offer_message||`خصم ${discountText(o)} مخصص لحسابك.`)}</p><div><b>خصم ${esc(discountText(o))}</b>${o.expires_at?`<small>ينتهي ${esc(new Date(o.expires_at).toLocaleDateString(window.AlinI18n?.locale?.()||'ar-IQ'))}</small>`:''}</div></div><div class="alin-personal-offer-actions"><button type="button" data-alin-click="AlinPersonalOffers.apply" data-alin-click-arg0="${esc(o.id)}">استخدم العرض</button><button type="button" class="secondary" data-alin-click="AlinPersonalOffers.dismiss" data-alin-click-arg0="${esc(o.id)}">لاحقاً</button></div></article>`}
  async function refresh(){const a=auth();const student=a?.current?.();if(!student||!a?.token?.()){offers=[];render();return offers}try{const data=await rpc('alin_student_personal_offers',{p_token:a.token(),p_device:a.deviceId()});offers=Array.isArray(data)?data:[];render();window.dispatchEvent(new CustomEvent('alin:personal-offers',{detail:{offers:rows()}}));return offers}catch(error){console.warn('[ALIN personal offers]',error);offers=[];render();return offers}}
  function apply(id){const o=offers.find(x=>String(x.id)===String(id))||best();if(!o)return;window.AlinCoupons?.apply?.(o);const input=document.getElementById('couponInput');if(input)input.value=o.code||'';window.toast?.(`تم تجهيز خصمك الخاص ${discountText(o)}`);window.openCart?.()}
  async function dismiss(id){rememberDismiss(id);const a=auth();if(a?.token?.()){rpc('alin_student_mark_offer_seen',{p_token:a.token(),p_device:a.deviceId(),p_coupon_id:id}).catch(()=>{})}const host=document.getElementById('alinPersonalOfferHost');if(host){host.hidden=true;host.innerHTML=''}}
  function touch(){const a=auth();if(!a?.current?.()||!a?.token?.())return;clearTimeout(touchTimer);touchTimer=setTimeout(()=>rpc('alin_student_touch_activity',{p_token:a.token(),p_device:a.deviceId()}).catch(()=>{}),500)}
  function startActivity(){['click','keydown','touchstart'].forEach(type=>document.addEventListener(type,touch,{passive:true}));document.addEventListener('visibilitychange',()=>{if(!document.hidden)touch()})}
  const api={rows,refresh,render,apply,dismiss,touch};window.AlinPersonalOffers=api;
  window.addEventListener('alin:student-session',()=>{refresh();touch()});window.addEventListener('alin:store-rendered',render);
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>{startActivity();setTimeout(refresh,250)},{once:true});else{startActivity();setTimeout(refresh,250)}
})();
