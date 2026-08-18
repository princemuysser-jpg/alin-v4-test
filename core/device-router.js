/* ALIN v2.4.3 — device router for the animated entry screen on all device classes. */
(()=>{
  'use strict';
  const STORAGE_KEY='alin_device_view';
  let destination='';
  let chosen='desktop';
  let navigated=false;

  const cleanQuery=url=>{
    url.searchParams.delete('view');
    url.searchParams.delete('splash');
    url.searchParams.delete('__alin_entry');
    return url;
  };

  try{
    const current=new URL(location.href);
    const forced=current.searchParams.get('view');
    chosen=['mobile','tablet','desktop'].includes(forced)?forced:'';
    if(chosen){
      try{sessionStorage.setItem(STORAGE_KEY,chosen)}catch(_){ }
    }else{
      // Touch phones/tablets are detected fresh on each load so landscape rotation never pins them to desktop.
      try{
        const saved=sessionStorage.getItem(STORAGE_KEY);
        const touchNow=(navigator.maxTouchPoints||0)>0;
        if(!touchNow&&['mobile','tablet','desktop'].includes(saved))chosen=saved;
      }catch(_){ }
    }
    if(!chosen){
      const viewportWidth=window.visualViewport&&window.visualViewport.width;
      const width=Math.max(1,Math.round(viewportWidth||window.innerWidth||document.documentElement.clientWidth||1024));
      let coarse=false,hoverNone=false,portrait=false,touch=false;
      try{
        coarse=matchMedia('(pointer: coarse)').matches;
        hoverNone=matchMedia('(hover: none)').matches;
        portrait=matchMedia('(orientation: portrait)').matches;
      }catch(_){portrait=innerHeight>=innerWidth}
      try{touch=(navigator.maxTouchPoints||0)>0}catch(_){ }
      const ua=String(navigator.userAgent||'');
      const hintedMobile=!!(navigator.userAgentData&&navigator.userAgentData.mobile===true);
      const phone=hintedMobile||/iPhone|iPod|Android.+Mobile|Windows Phone|Mobile/i.test(ua)||(width<800&&coarse);
      const tablet=/iPad|Tablet|Kindle|Silk|Android(?!.*Mobile)/i.test(ua)||(/Macintosh/i.test(ua)&&touch)||((coarse||hoverNone)&&touch&&width>=800&&width<=1180);
      chosen=phone?'mobile':(tablet?'tablet':'desktop');
      try{sessionStorage.setItem(STORAGE_KEY,chosen)}catch(_){ }
    }
    cleanQuery(current);
    current.pathname=current.pathname.replace(/[^/]*$/,'')+(chosen==='mobile'?'store-mobile':(chosen==='tablet'?'store-tablet':'store-desktop'));
    current.searchParams.set('__alin_entry','1');
    destination=current.href;
  }catch(_){
    chosen=(window.innerWidth||1024)<760?'mobile':((navigator.maxTouchPoints||0)>0&&Math.min(window.innerWidth||1024,window.innerHeight||768)>=540?'tablet':'desktop');
    let query='';
    try{
      query=String(location.search||'').replace(/^\?/,'').split('&').filter(part=>{
        if(!part)return false;
        let key=part.split('=')[0].replace(/\+/g,' ');
        try{key=decodeURIComponent(key)}catch(_){ }
        return key!=='view'&&key!=='splash';
      }).join('&');
    }catch(_){query=''}
    destination='./'+(chosen==='mobile'?'store-mobile':(chosen==='tablet'?'store-tablet':'store-desktop'))+'?'+(query?query+'&':'')+'__alin_entry=1'+String(location.hash||'');
  }

  const go=()=>{
    if(navigated)return;
    navigated=true;
    location.replace(destination);
  };
  window.AlinEntryRoute=Object.freeze({view:chosen,target:destination,go});
  document.documentElement.dataset.alinEntryView=chosen;
  window.dispatchEvent(new CustomEvent('alin:entry-route-ready',{detail:{view:chosen,target:destination}}));

  // All browser/PWA entries stay on index long enough for one ALIN splash, then route once.
  // The manifest background matches the splash so the OS launch surface blends into the same visual.
})();
