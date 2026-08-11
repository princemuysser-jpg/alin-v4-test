'use strict';
(()=>{
  const script=document.getElementById('alinSupabaseCdnScript');
  if(!script)return;
  script.addEventListener('error',()=>{
    window.__ALIN_CDN_ERROR__=true;
    console.error('تعذر تحميل Supabase');
  },{once:true});
})();
