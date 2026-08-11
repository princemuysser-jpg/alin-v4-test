/* ALIN v4.2.0 RC18 — role runtime lazy loader. Public storefront never downloads staff dashboards until needed. */
(function(){
  'use strict';
  let state='idle';
  let promise=null;
  const version=window.ALIN_CONFIG?.version||'4.2.0-rc.18';
  const needsRole=role=>!['','store','student'].includes(String(role||'').toLowerCase());
  function ensureStaffCss(){
    if(!document.body?.classList.contains('store-mobile'))return Promise.resolve(true);
    const existing=document.getElementById('alinRoleRuntimeCss');
    if(existing?.dataset.ready==='1')return Promise.resolve(true);
    return new Promise((resolve,reject)=>{
      const link=existing||document.createElement('link');
      const done=()=>{link.dataset.ready='1';resolve(true)};
      if(link.sheet){done();return}
      link.addEventListener('load',done,{once:true});
      link.addEventListener('error',()=>{link.remove();reject(new Error('تعذر تحميل تصميم لوحة الحساب'))},{once:true});
      if(!existing){
        link.id='alinRoleRuntimeCss';
        link.rel='stylesheet';
        link.href=`./dist/css/mobile-role.v4.css?v=${encodeURIComponent(version)}`;
        document.head.appendChild(link);
      }
    });
  }
  function ensureStaffScript(){
    const existing=document.getElementById('alinRoleRuntimeScript');
    if(existing?.dataset.ready==='1')return Promise.resolve(true);
    return new Promise((resolve,reject)=>{
      const script=existing||document.createElement('script');
      const done=()=>{script.dataset.ready='1';resolve(true)};
      if(script.dataset.ready==='1'){done();return}
      script.addEventListener('load',done,{once:true});
      script.addEventListener('error',()=>{script.remove();reject(new Error('تعذر تحميل وظائف لوحة الحساب'))},{once:true});
      if(!existing){
        script.id='alinRoleRuntimeScript';
        script.src=`./dist/alin-role-runtime.v4.js?v=${encodeURIComponent(version)}`;
        script.async=true;
        document.head.appendChild(script);
      }
    });
  }
  function ensure(role){
    if(!needsRole(role))return Promise.resolve(false);
    if(state==='ready')return Promise.resolve(true);
    if(promise)return promise;
    state='loading';
    promise=Promise.all([ensureStaffCss(),ensureStaffScript()]).then(()=>{
      state='ready';
      window.dispatchEvent(new CustomEvent('alin:role-runtime-ready',{detail:{role:String(role||''),version}}));
      return true;
    }).catch(error=>{
      state='error';promise=null;
      throw new Error(error?.message||'تعذر تحميل لوحة الحساب. تحقق من الإنترنت وحاول مرة أخرى.');
    });
    return promise;
  }
  window.AlinRoleRuntime=Object.freeze({version,ensure,ready:()=>state==='ready',state:()=>state});
})();
