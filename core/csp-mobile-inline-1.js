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
})();
