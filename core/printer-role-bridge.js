/* ALIN — Printer role bridge. Navigation owns page routing natively. */
(function(){
  'use strict';
  if(window.__ALIN_PRINTER_ROLE_BRIDGE__)return;
  window.__ALIN_PRINTER_ROLE_BRIDGE__=true;

  let loadingDashboard=false;

  function addLoginButton(){
    const actions=document.querySelector('#login .login-actions');
    if(!actions||actions.querySelector('[data-login-role="printer"]'))return;
    const admin=actions.querySelector('[data-login-role="admin"]');
    const button=document.createElement('button');
    button.type='button';
    button.dataset.loginRole='printer';
    button.textContent='المطبعة';
    button.addEventListener('click',()=>window.showLogin?.('printer'));
    if(admin)actions.insertBefore(button,admin);else actions.appendChild(button);
  }

  function loadDashboard(){
    if(window.__ALIN_PRINTER_DASHBOARD__||loadingDashboard)return;
    loadingDashboard=true;
    const script=document.createElement('script');
    script.id='alinPrinterDashboardScript';
    script.src=`./modules/printer/dashboard.js?v=${encodeURIComponent(window.ALIN_CONFIG?.assetVersion||'printer')}`;
    script.async=false;
    script.addEventListener('load',()=>{
      loadingDashboard=false;
      if(window.current?.role==='printer')window.AlinPrinterDashboard?.render?.(false);
    },{once:true});
    script.addEventListener('error',()=>{loadingDashboard=false;script.remove()},{once:true});
    document.head.appendChild(script);
  }

  function install(){
    addLoginButton();
    if(window.current?.role==='printer')loadDashboard();
  }

  document.addEventListener('DOMContentLoaded',()=>setTimeout(install,0),{once:true});
  window.addEventListener('alin:role-runtime-ready',install);
  window.addEventListener('alin:auth-login',install);
  window.addEventListener('alin:auth-restored',install);
  window.addEventListener('alin:page-open',event=>{
    if(event.detail?.page==='printer'&&window.current?.role==='printer')loadDashboard();
  });

  const timer=setInterval(install,150);
  setTimeout(()=>clearInterval(timer),8000);
})();
