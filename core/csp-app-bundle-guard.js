'use strict';
(()=>{
  const script=document.getElementById('alinAppBundleScript');
  if(!script)return;
  script.addEventListener('load',()=>window.alinAppBundleLoaded?.(),{once:true});
  script.addEventListener('error',()=>window.alinAppBundleFailed?.(),{once:true});
})();
