'use strict';
(()=>{
  const $=id=>document.getElementById(id);
  function cleanUrl(){return $('url').value.trim().replace(/\/+$/,'')}
  function configText(){return `// ALIN 4.2.0-rc.21 Release Candidate\nwindow.ALIN_CONFIG=Object.freeze({\n  version:'4.2.0-rc.21',\n  desktopPage:'./store-desktop.html',\n  mobilePage:'./store-mobile.html',\n  currency:'د.ع',\n  locale:'ar-IQ',\n  locales:{ar:'ar-IQ',ku:'ckb-IQ',en:'en-IQ'},\n  authEnabled:true,\n  authEmailDomain:'users.alin.local',\n  supabaseUrl:${JSON.stringify(cleanUrl())},\n  supabaseAnonKey:${JSON.stringify($('key').value.trim())}\n});\nwindow.Alin=window.Alin||{};\nwindow.Alin.helpers={byId:id=>document.getElementById(id),one:(selector,root=document)=>root.querySelector(selector),all:(selector,root=document)=>[...root.querySelectorAll(selector)],money:value=>Number(value||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')+' د.ع'};\n;\n`}
  function refresh(){$('preview').textContent=configText()}
  async function createAdmin(){
    const status=$('status');status.className='';status.textContent='جارٍ إنشاء المدير...';
    try{
      const url=cleanUrl(),key=$('key').value.trim();
      if(!url||!key)throw new Error('أدخل Project URL وAnon Key');
      const response=await fetch(`${url}/functions/v1/bootstrap-first-admin`,{
        method:'POST',
        headers:{'Content-Type':'application/json','apikey':key,'Authorization':`Bearer ${key}`},
        body:JSON.stringify({bootstrap_key:$('bootstrap').value,username:$('username').value,name:$('name').value,password:$('password').value})
      });
      const body=await response.json().catch(()=>({}));
      if(!response.ok||!body.ok)throw new Error(body.error||'تعذر إنشاء المدير');
      status.className='ok';status.textContent=`تم إنشاء المدير: ${body.account?.username||$('username').value}`;
    }catch(error){status.className='err';status.textContent=error.message||String(error)}
  }
  function downloadConfig(){
    const blob=new Blob([configText()],{type:'text/javascript;charset=utf-8'});
    const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='alin-config.js';a.click();
    setTimeout(()=>URL.revokeObjectURL(a.href),1000);
    $('status').className='ok';$('status').textContent='نزّل الملف. ارفع ملف alin-config.js إلى جذر ملفات المنصة مكان الملف الموجود. لا تحتاج إعادة بناء الحزمة.';
  }
  ['url','key'].forEach(id=>$(id).addEventListener('input',refresh));
  $('create').addEventListener('click',createAdmin);
  $('download').addEventListener('click',downloadConfig);
  refresh();
})();
