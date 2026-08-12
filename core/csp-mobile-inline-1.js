(function(){try{var mode=localStorage.getItem('alin_theme_v234')==='dark'?'dark':'light';document.documentElement.dataset.alinTheme=mode;document.documentElement.dataset.alinThemeMode=mode}catch(_){document.documentElement.dataset.alinTheme='light';document.documentElement.dataset.alinThemeMode='light'}})();

/* RC22: replay entry splash only when iOS/Safari restores the page from BFCache. */
(function(){
  function replay(){
    var el=document.getElementById('alinMobileEntrySplash');
    if(!el)return;
    el.style.animation='none';
    void el.offsetWidth;
    el.style.animation='';
  }
  addEventListener('pageshow',function(ev){if(ev.persisted)replay()},{passive:true});
})();
