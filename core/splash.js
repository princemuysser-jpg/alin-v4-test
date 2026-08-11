/* ALIN v4.2.0 RC17 — approved branded splash; fixed 3-second entry, independent of network speed. */
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
  // Phones/tablets route immediately; their 3-second splash runs inside store-mobile while assets load in parallel.
  if(route.view==='mobile'){route.go();return;}
  // Desktop keeps the approved 3-second entry.
  setTimeout(leave,2740);
  setTimeout(route.go,3000);
})();
