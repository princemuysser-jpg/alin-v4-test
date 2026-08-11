/* ALIN v4.2.0 RC14 — fast entry screen; routing starts immediately on slow networks. */
(()=>{
  'use strict';
  const root=document.getElementById('alinSplash');
  const route=window.AlinEntryRoute;
  if(!root||!route||typeof route.go!=='function')return;
  let leaving=false;
  const leave=()=>{
    if(leaving)return;
    leaving=true;
    root.classList.add('is-leaving');
    root.setAttribute('aria-hidden','true');
    setTimeout(route.go,90);
  };
  requestAnimationFrame(()=>setTimeout(leave,80));
  setTimeout(leave,350);
})();
