/* ALIN v4.2.0 RC16 — approved branded splash; fixed 3-second entry, independent of network speed. */
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
  };
  // Keep the approved splash visible for a total of 3 seconds.
  setTimeout(leave,2740);
  setTimeout(route.go,3000);
})();
