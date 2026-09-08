/* ALIN — Printer role bridge. */
(function(){
  'use strict';
  if(window.__ALIN_PRINTER_ROLE_BRIDGE__)return;
  window.__ALIN_PRINTER_ROLE_BRIDGE__=true;

  let wrapped=false,loadingDashboard=false;

  function addLoginButton(){
    const actions=document.querySelector('#login .login-actions');if(!actions||actions.querySelector('[data-login-role="printer"]'))return;
    const admin=actions.querySelector('[data-login-role="admin"]');
    const button=document.createElement('button');button.type='button';button.dataset.loginRole='printer';button.textContent='المطبعة';
    button.addEventListener('click',()=>window.showLogin?.('printer'));
    if(admin)actions.insertBefore(button,admin);else actions.appendChild(button);
  }

  function loadDashboard(){
    if(window.__ALIN_PRINTER_DASHBOARD__||loadingDashboard)return;
    loadingDashboard=true;
    const script=document.createElement('script');script.id='alinPrinterDashboardScript';
    script.src=`./modules/printer/dashboard.js?v=${encodeURIComponent(window.ALIN_CONFIG?.assetVersion||'printer')}`;script.async=false;
    script.addEventListener('load',()=>{loadingDashboard=false;window.AlinPrinterDashboard?.render?.(false)},{once:true});
    script.addEventListener('error',()=>{loadingDashboard=false;script.remove()},{once:true});document.head.appendChild(script);
  }

  function install(){
    addLoginButton();
    if(wrapped||typeof window.openPage!=='function')return false;
    const base=window.openPage;
    const patched=function(page,options={}){
      const requested=String(page||'store');
      if(requested!=='printer')return base.call(this,page,options);
      const current=window.current;
      if(!current||String(current.role)!=='printer')return false;
      const role=current.role;
      try{
        current.role='library';
        const result=base.call(this,'library',options);
        return result;
      }finally{
        current.role=role;
        setTimeout(loadDashboard,0);
      }
    };
    window.openPage=patched;
    wrapped=true;
    return true;
  }

  document.addEventListener('DOMContentLoaded',()=>setTimeout(()=>{install();addLoginButton()},0),{once:true});
  window.addEventListener('alin:role-runtime-ready',()=>{install();if(window.current?.role==='printer')loadDashboard()});
  window.addEventListener('alin:auth-login',()=>{if(window.current?.role==='printer')setTimeout(loadDashboard,0)});
  window.addEventListener('alin:auth-restored',()=>{if(window.current?.role==='printer')setTimeout(loadDashboard,0)});
  const timer=setInterval(()=>{install();addLoginButton();if(wrapped)clearInterval(timer)},100);
  setTimeout(()=>clearInterval(timer),10000);
})();
