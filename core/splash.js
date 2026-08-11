/* ALIN v4.2.0 RC20 — phone splash reduced to 1 second; tablet/desktop remain 3 seconds. */
(()=>{
  'use strict';
  const root=document.getElementById('alinSplash');
  const route=window.AlinEntryRoute;
  if(!root||!route||typeof route.go!=='function')return;

  const ua=String(navigator.userAgent||'');
  const width=Math.max(1,Math.round((window.visualViewport&&window.visualViewport.width)||window.innerWidth||document.documentElement.clientWidth||1024));
  const phoneUA=/iPhone|iPod|Android.+Mobile|Windows Phone|Mobile/i.test(ua);
  const isPhone=route.view==='mobile'&&(phoneUA||width<=760);
  const totalMs=isPhone?1000:3000;
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
