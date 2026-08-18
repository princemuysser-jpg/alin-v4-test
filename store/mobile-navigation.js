/* ALIN 2.0.1 - mobile navigation controller */

(function(){
  const byId=id=>document.getElementById(id);
  function showSheet(id){
    const backdrop=byId('alinSheetBackdrop');
    ['alinAccountSheet','alinTrackingSheet'].forEach(x=>{const el=byId(x); if(el) el.hidden=x!==id;});
    if(backdrop) backdrop.hidden=false;
    document.body.style.overflow='hidden';
  }
  window.alinOpenAccountSheet=()=>showSheet('alinAccountSheet');
  window.alinOpenTrackingSheet=()=>showSheet('alinTrackingSheet');
  window.alinCloseMobileSheets=function(){
    ['alinAccountSheet','alinTrackingSheet'].forEach(x=>{const el=byId(x);if(el)el.hidden=true;});
    const backdrop=byId('alinSheetBackdrop'); if(backdrop)backdrop.hidden=true;
    document.body.style.overflow='';
  };
  window.alinAccountAction=function(action){
    if(action==='login'||action==='signup'){
      alinCloseMobileSheets();
      if(typeof openStudentAuth==='function') openStudentAuth(action);
      else document.getElementById('studentAuthBtn')?.click();
      return;
    }
    if(action==='about'){
      alinCloseMobileSheets();
      document.getElementById('storeAbout')?.scrollIntoView({behavior:'smooth',block:'start'});
    }
  };
  window.alinSubmitMobileTracking=async function(){
    const source=byId('alinMobileTrackingInput');
    const target=byId('trackOrderInput');
    const result=byId('alinMobileTrackingResult');
    if(!source?.value.trim()){if(result)result.innerHTML='<div class="notice">اكتب رقم الطلب أولاً.</div>';return false;}
    if(target)target.value=source.value.trim();
    if(result)result.innerHTML='<div class="notice">جاري البحث عن الطلب...</div>';
    try{
      if(typeof window.trackOrder==='function')await window.trackOrder();
    }catch(_){ }
    const original=byId('trackOrderResult');
    if(result&&original)result.innerHTML=original.innerHTML||'<div class="notice">تعذر جلب حالة الطلب الآن.</div>';
    return true;
  };
  document.addEventListener('keydown',e=>{if(e.key==='Escape')alinCloseMobileSheets();});
})();
