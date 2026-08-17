/* ALIN v4.2.0 CLEAN1 — a single app-owned splash for desktop entry only.
   Phone/tablet/iPad are routed before index body paint; installed PWAs use the OS launch screen. */
(()=>{
  'use strict';
  const root=document.getElementById('alinSplash');
  const route=window.AlinEntryRoute;
  if(!root||!route||typeof route.go!=='function')return;

  if(route.view==='mobile'){
    document.documentElement.dataset.alinSplashDuration='0';
    route.go();
    return;
  }

  const totalMs=3000;
  const fadeMs=260;
  const fadeAt=Math.max(0,totalMs-fadeMs);
  let leaving=false;

  const leave=()=>{
    if(leaving)return;
    leaving=true;
    root.classList.add('is-leaving');
    root.setAttribute('aria-hidden','true');
  };

  document.documentElement.dataset.alinSplashDuration=String(totalMs);
  setTimeout(leave,fadeAt);
  setTimeout(route.go,totalMs);
})();
