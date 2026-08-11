/* ALIN v4.2.0 RC17 — role runtime lazy loader. Public storefront never downloads staff dashboards until needed. */
(function(){
  'use strict';
  let state='idle';
  let promise=null;
  const version=window.ALIN_CONFIG?.version||'4.2.0-rc.17';
  const needsRole=role=>!['','store','student'].includes(String(role||'').toLowerCase());
  function ensureRoleStyle(){
    if(!document.body?.classList.contains('store-mobile'))return Promise.resolve(true);
    const current=document.getElementById('alinMobileRoleCss');
    if(current&&current.dataset.ready==='1')return Promise.resolve(true);
    return new Promise((resolve,reject)=>{
      const link=current||document.createElement('link');
      if(!current){
        link.id='alinMobileRoleCss';link.rel='stylesheet';
        link.href=`./dist/css/mobile-entry.v4.css?v=${encodeURIComponent(version)}`;
        document.head.appendChild(link);
      }
      const done=()=>{link.dataset.ready='1';resolve(true)};
      if(link.sheet){done();return;}
      link.addEventListener('load',done,{once:true});
      link.addEventListener('error',()=>reject(new Error('تعذر تحميل تصميم لوحة الحساب')),{once:true});
    });
  }
  function ensure(role){
    if(!needsRole(role))return Promise.resolve(false);
    if(state==='ready')return ensureRoleStyle().then(()=>true);
    if(promise)return promise;
    state='loading';
    promise=Promise.all([ensureRoleStyle(),new Promise((resolve,reject)=>{
      const existing=document.getElementById('alinRoleRuntimeScript');
      if(existing){
        existing.addEventListener('load',()=>{state='ready';resolve(true)},{once:true});
        existing.addEventListener('error',()=>{state='error';promise=null;reject(new Error('تعذر تحميل لوحة الحساب'))},{once:true});
        return;
      }
      const script=document.createElement('script');
      script.id='alinRoleRuntimeScript';
      script.src=`./dist/alin-role-runtime.v4.js?v=${encodeURIComponent(version)}`;
      script.async=true;
      script.addEventListener('load',()=>{
        state='ready';
        window.dispatchEvent(new CustomEvent('alin:role-runtime-ready',{detail:{role:String(role||''),version}}));
        resolve(true);
      },{once:true});
      script.addEventListener('error',()=>{
        state='error';promise=null;script.remove();
        reject(new Error('تعذر تحميل لوحة الحساب. تحقق من الإنترنت وحاول مرة أخرى.'));
      },{once:true});
      document.head.appendChild(script);
    })]).then(()=>true).catch(error=>{state='error';promise=null;throw error});
    return promise;
  }
  window.AlinRoleRuntime=Object.freeze({version,ensure,ready:()=>state==='ready',state:()=>state});
})();
