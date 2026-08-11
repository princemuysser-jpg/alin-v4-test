/* ALIN v4.1.6 prepublish 1n — permanently hide removed admin diagnostic tabs. */
(()=>{
  'use strict';
  const remove=()=>document.querySelectorAll('#adminPage .admin-tabs button').forEach(button=>{
    const key=String(button.dataset.adminTab||'');
    if(key==='systemHealth'||key==='supabaseReadiness')button.remove();
  });
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',remove,{once:true});else remove();
})();
