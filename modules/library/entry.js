// === library/dashboard.js ===
/* ALIN v2.0.9 — single library entry and dashboard runtime. */
(function(){
  'use strict';
  window.AlinLibraryModules=window.AlinLibraryModules||{};

  function openLibraryJoinPortal(){
    try{
      window.pendingRole='library';
      if(typeof window.showLogin!=='function')throw new Error('login unavailable');
      window.showLogin('library');
      document.getElementById('login')?.classList.remove('hidden');
      document.getElementById('app')?.classList.add('hidden');
      document.getElementById('loginForm')?.classList.remove('hidden');
      const user=document.getElementById('loginU');
      const pass=document.getElementById('loginPass');
      const msg=document.getElementById('loginMsg');
      if(user){user.placeholder='اسم دخول المكتبة';setTimeout(()=>user.focus(),0)}
      if(pass)pass.placeholder='الرمز السري للمكتبة';
      if(msg){msg.textContent='دخول المكتبة';msg.dataset.role='library'}
    }catch(error){
      console.error('[ALIN library entry]',error);
      alert('تعذر فتح دخول المكتبة. حدّث الصفحة وحاول مرة أخرى.');
    }
  }

  function showLibraryPage(){
    if(window.current?.role!=='library')return false;
    const login=document.getElementById('login');
    const app=document.getElementById('app');
    const page=document.getElementById('libraryPage');
    if(!app||!page)return false;
    login?.classList.add('hidden');
    app.classList.remove('hidden','store-mode');
    document.querySelectorAll('.page').forEach(node=>node.classList.add('hidden'));
    page.classList.remove('hidden');
    const nav=document.getElementById('activeNav');
    if(nav)nav.innerHTML='<button type="button">المكتبة</button>';
    requestAnimationFrame(()=>window.AlinLibraryModules.renderLibrary?.());
    return true;
  }

  window.openLibraryJoinPortal=openLibraryJoinPortal;
  window.AlinLibraryModules.openLibraryJoinPortal=openLibraryJoinPortal;
  window.AlinLibraryModules.showLibraryPage=showLibraryPage;
  window.addEventListener('alin:auth-restored',event=>{
    if(event.detail?.account?.role==='library')showLibraryPage();
  });
  window.addEventListener('alin:data-refreshed',()=>{
    if(window.current?.role==='library')window.AlinLibraryModules.renderLibrary?.();
  });
})();
