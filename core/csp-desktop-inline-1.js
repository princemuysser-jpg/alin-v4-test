(function(){
  'use strict';
  try{
    var url=new URL(location.href);
    var navEntry=performance&&performance.getEntriesByType?performance.getEntriesByType('navigation')[0]:null;
    var isReload=(navEntry&&navEntry.type==='reload')||(performance&&performance.navigation&&performance.navigation.type===1);
    if(url.searchParams.get('__alin_entry')==='1'){
      url.searchParams.delete('__alin_entry');
      history.replaceState(history.state,'',url.pathname+(url.searchParams.toString()?'?'+url.searchParams.toString():'')+url.hash);
    }else if(!isReload){
      url.searchParams.delete('view');
      url.searchParams.delete('splash');
      url.pathname=url.pathname.replace(/[^/]*$/,'')+'index.html';
      url.searchParams.set('view','desktop');
      location.replace(url.href);
      return;
    }
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
