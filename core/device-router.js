/* ALIN v2.4.2 — device router for the animated entry screen. */
(()=>{
  'use strict';
  const STORAGE_KEY='alin_device_view';
  let destination='';
  let chosen='desktop';
  let navigated=false;

  const cleanQuery=url=>{
    url.searchParams.delete('view');
    url.searchParams.delete('splash');
    return url;
  };

  try{
    const current=new URL(location.href);
    const forced=current.searchParams.get('view');
    chosen=forced==='mobile'||forced==='desktop'?forced:'';
    if(chosen){
      try{sessionStorage.setItem(STORAGE_KEY,chosen)}catch(_){ }
    }else{
      // Touch phones/tablets are detected fresh on each load so landscape rotation never pins them to desktop.
      try{
        const saved=sessionStorage.getItem(STORAGE_KEY);
        const touchNow=(navigator.maxTouchPoints||0)>0;
        if(!touchNow&&(saved==='mobile'||saved==='desktop'))chosen=saved;
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
      chosen=(phone||tablet)?'mobile':'desktop';
      try{sessionStorage.setItem(STORAGE_KEY,chosen)}catch(_){ }
    }
    cleanQuery(current);
    current.pathname=current.pathname.replace(/[^/]*$/,'')+(chosen==='mobile'?'store-mobile':'store-desktop');
    destination=current.href;
  }catch(_){
    chosen=(window.innerWidth||1024)<800?'mobile':'desktop';
    let query='';
    try{
      query=String(location.search||'').replace(/^\?/,'').split('&').filter(part=>{
        if(!part)return false;
        let key=part.split('=')[0].replace(/\+/g,' ');
        try{key=decodeURIComponent(key)}catch(_){ }
        return key!=='view'&&key!=='splash';
      }).join('&');
    }catch(_){query=''}
    destination='./'+(chosen==='mobile'?'store-mobile':'store-desktop')+(query?'?'+query:'')+String(location.hash||'');
  }


  function warmMobileEntry(){
    if(chosen!=='mobile')return;
    const version='4.2.0-rc.16';
    const assets=[
      ['./dist/css/mobile-entry.v4.css','style'],
      ['./dist/alin-core.v4.js','script'],
      ['./alin-app-mobile.v4.1.5.js','script'],
      ['./core/mobile-bootstrap.v4.js','script'],
      ['./alin-config.js','script'],
      ['./core/ui-action-router.js','script']
    ];
    for(const [href,as] of assets){
      try{
        const link=document.createElement('link');
        link.rel='preload';link.as=as;link.href=href+'?v='+encodeURIComponent(version);
        link.fetchPriority='high';document.head.appendChild(link);
      }catch(_){ }
    }
    try{
      const image=document.createElement('link');
      image.rel='preload';image.as='image';image.href='./assets/images/hero-products-mobile.webp';
      image.fetchPriority='low';document.head.appendChild(image);
    }catch(_){ }
    try{
      const page=document.createElement('link');page.rel='prefetch';page.as='document';page.href=destination;document.head.appendChild(page);
    }catch(_){ }
  }

  warmMobileEntry();

  const go=()=>{
    if(navigated)return;
    navigated=true;
    location.replace(destination);
  };
  window.AlinEntryRoute=Object.freeze({view:chosen,target:destination,go});
  document.documentElement.dataset.alinEntryView=chosen;
  window.dispatchEvent(new CustomEvent('alin:entry-route-ready',{detail:{view:chosen,target:destination}}));
})();
