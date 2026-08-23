/* ALIN staff session boot guard — keep authenticated staff on the same page after refresh. */
(function(){
  'use strict';
  if(window.__ALIN_SESSION_BOOT_GUARD__)return;
  window.__ALIN_SESSION_BOOT_GUARD__=true;

  const HINT_KEY='alin_staff_session_hint_v2';
  const STAFF_ROLES=new Set(['admin','accountant','teacher','library','courier','delegate']);
  const normalizeRole=value=>String(value||'').toLowerCase()==='delegate'?'courier':String(value||'').toLowerCase();
  const cfg=()=>window.ALIN_CONFIG||{};
  let locked=false;
  let originalOpenPage=null;
  let resolveTimer=null;

  function safeGet(key){try{return localStorage.getItem(key)}catch(_){return null}}
  function safeSet(key,value){try{localStorage.setItem(key,value)}catch(_){}}
  function safeRemove(key){try{localStorage.removeItem(key)}catch(_){}}

  function readHint(){
    try{
      const raw=safeGet(HINT_KEY);if(!raw)return null;
      const hint=JSON.parse(raw);if(!hint||!STAFF_ROLES.has(normalizeRole(hint.role)))return null;
      return hint;
    }catch(_){return null}
  }

  function projectRef(){
    try{return new URL(String(cfg().supabaseUrl||'')).hostname.split('.')[0]||''}catch(_){return ''}
  }
  function hasPersistedSupabaseSession(){
    try{
      const ref=projectRef();
      if(ref){const raw=localStorage.getItem(`sb-${ref}-auth-token`);if(raw&&raw!=='null'&&raw!=='{}')return true}
      for(let i=0;i<localStorage.length;i++){
        const key=localStorage.key(i)||'';
        if(/^sb-.+-auth-token$/.test(key)){
          const raw=localStorage.getItem(key);
          if(raw&&raw!=='null'&&raw!=='{}')return true;
        }
      }
    }catch(_){ }
    return false;
  }

  function currentTab(role){
    role=normalizeRole(role);
    if(role==='admin'||role==='accountant')return String(window.activeAdminTab||'');
    if(role==='teacher')return String(window.TeacherApp?.active||window.activeTeacherTab||'');
    if(role==='library')return document.querySelector('#libraryPage .library-v116-tabs .active')?.dataset.libraryTab||'';
    if(role==='courier')return document.querySelector('#courierPage .courier-v161-tabs .active')?.dataset.courierTab||'';
    return '';
  }

  function saveHint(page){
    const current=window.current||{};
    const role=normalizeRole(current.role);
    if(!STAFF_ROLES.has(role)||!current.id)return;
    const target=String(page||((role==='accountant')?'admin':role));
    const hint={role,id:String(current.id),page:target,tab:currentTab(role),updated_at:new Date().toISOString()};
    safeSet(HINT_KEY,JSON.stringify(hint));
  }

  function updateHintTab(role,tab){
    const hint=readHint();if(!hint)return;
    const normalized=normalizeRole(role||hint.role);
    if(normalized!==normalizeRole(hint.role))return;
    hint.tab=String(tab||'');hint.updated_at=new Date().toISOString();safeSet(HINT_KEY,JSON.stringify(hint));
  }

  function ensureBootStyle(){
    if(document.getElementById('alinStaffBootGuardStyle'))return;
    const style=document.createElement('style');
    style.id='alinStaffBootGuardStyle';
    style.textContent='html[data-alin-staff-session-boot="1"] #app,html[data-alin-staff-session-boot="1"] #login{visibility:hidden!important}#alinStaffSessionBootOverlay{position:fixed;inset:0;z-index:2147483000;display:grid;place-items:center;background:#f4f7fb;color:#0b3568;font-family:Tahoma,"Segoe UI",sans-serif;text-align:center;padding:24px}#alinStaffSessionBootOverlay>div{background:#fff;border:1px solid #dce6f1;border-radius:20px;padding:22px 26px;box-shadow:0 12px 34px rgba(11,53,104,.12);font-weight:800}';
    document.head.appendChild(style);
  }

  function showOverlay(){
    if(!locked||!document.body||document.getElementById('alinStaffSessionBootOverlay'))return;
    const overlay=document.createElement('div');overlay.id='alinStaffSessionBootOverlay';overlay.innerHTML='<div>جارٍ استعادة جلستك ونفس الصفحة...</div>';document.body.appendChild(overlay);
  }
  function unlock(){
    locked=false;
    document.documentElement.removeAttribute('data-alin-staff-session-boot');
    document.getElementById('alinStaffSessionBootOverlay')?.remove();
  }
  function lock(){
    locked=true;ensureBootStyle();document.documentElement.setAttribute('data-alin-staff-session-boot','1');
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',showOverlay,{once:true});else showOverlay();
  }

  function patchOpenPage(){
    const fn=window.openPage;
    if(typeof fn!=='function'||fn.__alinStaffSessionGuard)return false;
    originalOpenPage=fn;
    const guarded=function(page,options){
      const target=String(page||'store');
      if(locked&&target==='store'&&!window.current)return false;
      const result=originalOpenPage.apply(this,arguments);
      if(result!==false&&window.current?.id)setTimeout(()=>saveHint(target),0);
      return result;
    };
    guarded.__alinStaffSessionGuard=true;
    guarded.__alinOriginalOpenPage=fn;
    window.openPage=guarded;
    return true;
  }

  function restoreTab(hint){
    if(!hint?.tab)return;
    const role=normalizeRole(window.current?.role||hint.role),tab=String(hint.tab||'');
    setTimeout(()=>{
      try{
        if((role==='admin'||role==='accountant')&&typeof window.adminTab==='function')window.adminTab(tab);
        else if(role==='teacher'&&typeof window.teacherTab==='function')window.teacherTab(tab);
        else if(role==='library'){
          if(tab==='receipts')document.getElementById('libraryReceiptsTab')?.click();
          else document.querySelector(`#libraryPage .library-v116-tabs [data-library-tab="${CSS.escape(tab)}"]`)?.click();
        }else if(role==='courier'){
          if(tab==='receipts')document.getElementById('courierReceiptsTab')?.click();
          else if(typeof window.renderCourierDashboard==='function')window.renderCourierDashboard(tab,{refresh:false});
        }
      }catch(error){console.warn('[ALIN session guard tab restore]',error)}
    },220);
  }

  function restoreRememberedPage(){
    const hint=readHint();
    const current=window.current||{};
    const role=normalizeRole(current.role);
    if(!hint||!current.id||normalizeRole(hint.role)!==role)return;
    const defaultPage=role==='accountant'?'admin':role;
    const page=hint.page==='store'?'store':defaultPage;
    const opener=window.openPage;
    if(typeof opener==='function')opener(page,{render:false});
    if(page!== 'store')restoreTab(hint);
  }

  async function verifyAndRestore(){
    if(!locked)return;
    patchOpenPage();
    const client=window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.();
    if(!client?.auth){clearTimeout(resolveTimer);resolveTimer=setTimeout(verifyAndRestore,700);return}
    let session=null;
    try{session=(await client.auth.getSession())?.data?.session||null}catch(_){ }
    if(!session?.user){
      safeRemove(HINT_KEY);unlock();
      const opener=originalOpenPage||window.openPage;if(typeof opener==='function')opener('store',{render:true});
      return;
    }
    try{
      const ok=await window.ALINAuth?.restoreSession?.();
      if(ok||window.current?.id){unlock();restoreRememberedPage();return}
    }catch(error){console.warn('[ALIN session guard restore]',error)}
    clearTimeout(resolveTimer);resolveTimer=setTimeout(verifyAndRestore,900);
  }

  function onAuthReady(){
    if(window.current?.id){saveHint();unlock();restoreRememberedPage();return}
    if(locked)verifyAndRestore();
  }

  function onLogout(){safeRemove(HINT_KEY);unlock()}

  document.addEventListener('click',event=>{
    const button=event.target?.closest?.('[data-admin-tab],[data-teacher-tab],[data-library-tab],[data-courier-tab],[data-alin415-receipts-role]');
    if(!button||!window.current?.id)return;
    if(button.dataset.adminTab)updateHintTab(window.current.role,button.dataset.adminTab);
    else if(button.dataset.teacherTab)updateHintTab('teacher',button.dataset.teacherTab);
    else if(button.dataset.libraryTab)updateHintTab('library',button.dataset.libraryTab);
    else if(button.dataset.courierTab)updateHintTab('courier',button.dataset.courierTab);
    else if(button.dataset.alin415ReceiptsRole)updateHintTab(button.dataset.alin415ReceiptsRole,'receipts');
  },true);

  window.addEventListener('alin:page-open',event=>{if(window.current?.id)saveHint(event.detail?.page)});
  window.addEventListener('alin:auth-login',onAuthReady);
  window.addEventListener('alin:auth-restored',onAuthReady);
  window.addEventListener('alin:supabase-ready',()=>setTimeout(verifyAndRestore,0));
  window.addEventListener('alin:logout',onLogout);

  if(readHint()||hasPersistedSupabaseSession())lock();
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>{patchOpenPage();if(locked)showOverlay()},{once:true});
  else patchOpenPage();
  let attempts=0;const patchTimer=setInterval(()=>{patchOpenPage();attempts+=1;if(attempts>=40||originalOpenPage)clearInterval(patchTimer)},100);

  window.AlinSessionBootGuard=Object.freeze({saveHint,verifyAndRestore,locked:()=>locked,clear:onLogout});
})();
