/* ALIN v4.2.0 CLEAN2 — one app-owned splash across desktop, tablet and phone. */
(()=>{
  'use strict';
  const root=document.getElementById('alinSplash');
  const route=window.AlinEntryRoute;
  if(!root||!route||typeof route.go!=='function')return;

  const phone=route.view==='mobile';
  const tablet=route.view==='tablet';
  const totalMs=phone?1800:(tablet?2200:2600);
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
  document.documentElement.dataset.alinSplashDevice=phone?'phone':(tablet?'tablet':'desktop');
  setTimeout(leave,fadeAt);
  setTimeout(()=>route.go(),totalMs);
})();
