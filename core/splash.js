/* ALIN v4.2.0 UI5 — one app-owned splash for mobile, tablet and desktop. */
(()=>{
  'use strict';
  const root=document.getElementById('alinSplash');
  const route=window.AlinEntryRoute;
  if(!root||!route||typeof route.go!=='function')return;

  const isMobile=route.view==='mobile';
  const totalMs=isMobile?1650:2200;
  const fadeMs=240;
  const fadeAt=Math.max(0,totalMs-fadeMs);
  let leaving=false;

  root.style.setProperty('--alin-splash-progress-duration',`${Math.max(650,fadeAt-90)}ms`);
  document.documentElement.dataset.alinSplashDuration=String(totalMs);

  const leave=()=>{
    if(leaving)return;
    leaving=true;
    root.classList.add('is-leaving');
    root.setAttribute('aria-hidden','true');
  };

  setTimeout(leave,fadeAt);
  setTimeout(route.go,totalMs);
})();
