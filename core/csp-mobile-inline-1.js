(function(){
  'use strict';
  try{
    var standalone=(window.matchMedia&&window.matchMedia('(display-mode: standalone)').matches)||navigator.standalone===true;
    if(standalone)document.documentElement.dataset.alinStandalone='1';
  }catch(_){ }

  try{
    var mode=localStorage.getItem('alin_theme_v234')==='dark'?'dark':'light';
    document.documentElement.dataset.alinTheme=mode;
    document.documentElement.dataset.alinThemeMode=mode;
  }catch(_){
    document.documentElement.dataset.alinTheme='light';
    document.documentElement.dataset.alinThemeMode='light';
  }

  /* One splash lifecycle for phone/tablet/iPad: exactly 2 seconds, then remove the overlay. */
  function startEntrySplash(){
    var el=document.getElementById('alinMobileEntrySplash');
    if(!el)return;
    if(document.documentElement.dataset.alinStandalone==='1'){
      if(el.parentNode)el.parentNode.removeChild(el);
      return;
    }
    if(el.dataset.alinSplashStarted==='1')return;
    el.dataset.alinSplashStarted='1';
    var done=false;
    var finish=function(){
      if(done)return;
      done=true;
      el.setAttribute('aria-hidden','true');
      el.classList.add('is-complete');
      window.setTimeout(function(){
        if(el&&el.parentNode)el.parentNode.removeChild(el);
      },280);
    };
    el.addEventListener('animationend',function(event){
      if(event.target===el&&event.animationName.indexOf('alinMobileEntrySplash')===0)finish();
    },{once:true});
    window.setTimeout(finish,2050);
  }

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',startEntrySplash,{once:true});
  }else{
    startEntrySplash();
  }
})();
