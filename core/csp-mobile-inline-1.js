(function(){
  'use strict';
  try{
    var url=new URL(location.href);
    if(url.searchParams.get('__alin_entry')==='1'){
      url.searchParams.delete('__alin_entry');
      history.replaceState(history.state,'',url.pathname+(url.searchParams.toString()?'?'+url.searchParams.toString():'')+url.hash);
    }else{
      url.searchParams.delete('view');
      url.searchParams.delete('splash');
      url.pathname=url.pathname.replace(/[^/]*$/,'');
      url.searchParams.set('view','mobile');
      location.replace(url.href);
      return;
    }
  }catch(_){ }
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
