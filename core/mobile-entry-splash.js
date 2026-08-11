/* ALIN v4.2.0 RC17 — splash runs inside store-mobile while app assets load behind it. */
(function(){
  'use strict';
  const root=document.getElementById('alinMobileEntrySplash');
  if(!root)return;
  const started=Number(window.__ALIN_MOBILE_PAGE_STARTED__||performance.now());
  const elapsed=Math.max(0,performance.now()-started);
  const leaveDelay=Math.max(0,2740-elapsed);
  const removeDelay=Math.max(0,3000-elapsed);
  setTimeout(()=>{root.classList.add('is-leaving');root.setAttribute('aria-hidden','true')},leaveDelay);
  setTimeout(()=>{root.remove();document.documentElement.classList.add('alin-mobile-entry-complete');window.dispatchEvent(new CustomEvent('alin:mobile-entry-complete'))},removeDelay);
})();
