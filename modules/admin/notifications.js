// === admin/notifications.js ===
/* ALIN v4.2 Stable Lock — notification center with registered-student targeting. */
(function(){
  'use strict';

  const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,char=>({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[char]));
  const roleLabel=role=>({
    all:'الجميع',teacher:'المدرسون',library:'المكتبات',student:'الطلبة والمتجر',courier:'المندوبون',accountant:'المحاسب'
  })[String(role||'all')]||'الجميع';
  const state={
    query:'',role:'',sending:false,
    students:[],studentsLoaded:false,studentsLoading:false,
    draft:{audience:'all',priority:'normal',targetId:'',title:'',message:''}
  };

  function service(){return window.AlinNotifications}
  function client(){return window.sb||window.AlinCloud?.client?.()||null}
  function rows(){return service()?.rows?.()||[]}
  function tagged(list,role){return (Array.isArray(list)?list:[]).map(row=>({...row,__notifyRole:role}))}
  function users(){
    const accounts=window.db?.accounts||{};
    return [
      ...tagged(accounts.teachers,'teacher'),
      ...tagged(accounts.libraries,'library'),
      ...tagged(accounts.couriers,'courier'),
      ...tagged(accounts.accountants,'accountant'),
      ...tagged(state.students,'student')
    ];
  }
  function userRole(row){return String(row?.__notifyRole||row?.role||'').toLowerCase().replace('delegate','courier')}
  function userLabel(row){
    const role=userRole(row);
    const name=row?.name||row?.username||row?.email||row?.phone||'حساب';
    return `${roleLabel(role).replace('الطلبة والمتجر','طالب').replace('المدرسون','مدرس').replace('المكتبات','مكتبة').replace('المندوبون','مندوب')} — ${name}`;
  }
  async function loadStudents(){
    if(state.studentsLoaded||state.studentsLoading)return state.students;
    state.studentsLoading=true;
    try{
      const c=client();if(!c?.rpc)throw new Error('خدمة العملاء غير متاحة');
      const {data,error}=await c.rpc('alin_admin_student_customers',{p_days:3650,p_mode:'all',p_search:null});
      if(error)throw error;
      state.students=Array.isArray(data?.rows)?data.rows:[];
      state.studentsLoaded=true;
    }catch(error){
      console.warn('[ALIN admin notifications] students',error);
    }finally{state.studentsLoading=false}
    return state.students;
  }
  function dateText(value){
    try{return new Date(value).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ')}
    catch(_){return ''}
  }
  function filteredRows(){
    const query=state.query.trim().toLowerCase();
    return rows().filter(row=>{
      const searchable=`${row.title||''} ${row.message||row.text||''}`.toLowerCase();
      const role=String(row.target_role||row.audience||row.role||'all');
      return (!query||searchable.includes(query))&&(!state.role||role===state.role);
    });
  }

  function captureDraft(){
    const audience=document.getElementById('v146Audience');
    const priority=document.getElementById('v146Priority');
    const target=document.getElementById('v146Target');
    const title=document.getElementById('v146Title');
    const message=document.getElementById('v146Message');
    if(audience)state.draft.audience=audience.value||'all';
    if(priority)state.draft.priority=priority.value||'normal';
    if(target)state.draft.targetId=target.value||'';
    if(title)state.draft.title=title.value||'';
    if(message)state.draft.message=message.value||'';
  }

  function clearDraft(){
    state.draft={audience:'all',priority:'normal',targetId:'',title:'',message:''};
  }

  function render(){
    const root=document.getElementById('adminContent');
    if(!root)return false;
    captureDraft();
    if(!state.studentsLoaded&&!state.studentsLoading){
      loadStudents().then(()=>{if(window.activeAdminTab==='notifications')render()});
    }
    const all=rows(),list=filteredRows();
    const week=all.filter(row=>Date.now()-new Date(row.created_at||0).getTime()<=7*864e5).length;
    const people=users();
    const accountOptions=people.map(account=>`<option value="${escapeHtml(account.id)}" ${state.draft.targetId===String(account.id)?'selected':''}>${escapeHtml(userLabel(account))}</option>`).join('');
    root.innerHTML=`<section class="admin-v146-notifications">
      <header class="admin-v146-head"><div><h2>مركز الإشعارات</h2><p>إرسال الإشعارات ومراجعة السجل من مصدر واحد.</p></div><div class="admin-v146-bell">🔔</div></header>
      <div class="admin-v146-grid">
        <article class="admin-v146-card"><h3>إرسال إشعار جديد</h3><div class="admin-v146-form">
          <select id="v146Audience"><option value="all" ${state.draft.audience==='all'?'selected':''}>الجميع</option><option value="teacher" ${state.draft.audience==='teacher'?'selected':''}>المدرسون</option><option value="library" ${state.draft.audience==='library'?'selected':''}>المكتبات</option><option value="student" ${state.draft.audience==='student'?'selected':''}>الطلبة والمتجر</option><option value="courier" ${state.draft.audience==='courier'?'selected':''}>المندوبون</option><option value="accountant" ${state.draft.audience==='accountant'?'selected':''}>المحاسب</option></select>
          <select id="v146Priority"><option value="normal" ${state.draft.priority==='normal'?'selected':''}>عادي</option><option value="important" ${state.draft.priority==='important'?'selected':''}>مهم</option><option value="urgent" ${state.draft.priority==='urgent'?'selected':''}>عاجل</option></select>
          <select id="v146Target" class="full" data-alin-change="AlinAdminNotifications.target" data-alin-change-arg0-source="value"><option value="" ${state.draft.targetId?'':'selected'}>بدون حساب محدد</option>${accountOptions}</select>
          <small class="full">اختيار حساب محدد يرسل الإشعار لهذا الحساب فقط. الطلاب المسجلون ظاهرون ضمن نفس القائمة.</small>
          <input id="v146Title" class="full" placeholder="عنوان الإشعار" value="${escapeHtml(state.draft.title)}">
          <textarea id="v146Message" class="full" placeholder="اكتب نص الإشعار">${escapeHtml(state.draft.message)}</textarea>
          <button id="v146SendButton" class="admin-v146-send" type="button" data-alin-click="AlinAdminNotifications.send">إرسال الإشعار</button>
          <div id="v146Status" class="admin-v146-status"></div>
        </div></article>
        <article class="admin-v146-card"><div class="admin-v146-list-head"><h3>سجل الإشعارات</h3><button type="button" data-alin-click="AlinAdminNotifications.refresh">تحديث</button></div>
          <div class="admin-v146-stats"><div><small>الإجمالي</small><b>${all.length}</b></div><div><small>آخر 7 أيام</small><b>${week}</b></div><div><small>النتائج</small><b>${list.length}</b></div></div>
          <div class="admin-v146-tools"><input placeholder="بحث" value="${escapeHtml(state.query)}" data-alin-input="AlinAdminNotifications.filter" data-alin-input-arg0="query" data-alin-input-arg1-source="value"><select data-alin-change="AlinAdminNotifications.filter" data-alin-change-arg0="role" data-alin-change-arg1-source="value"><option value="">كل الفئات</option>${['all','teacher','library','student','courier','accountant'].map(role=>`<option value="${role}" ${state.role===role?'selected':''}>${roleLabel(role)}</option>`).join('')}</select></div>
          <div class="admin-v146-list">${list.length?list.map(row=>`<div class="admin-v146-item"><div><h4>${escapeHtml(row.title||'إشعار')}</h4><p>${escapeHtml(row.message||row.text||'')}</p><div class="admin-v146-meta"><span>${roleLabel(row.target_role||row.audience||row.role||'all')}</span><span>${escapeHtml(row.priority||'normal')}</span><span>${escapeHtml(dateText(row.created_at))}</span></div></div><button type="button" class="danger" data-alin-click="AlinAdminNotifications.remove" data-alin-click-arg0="${escapeHtml(row.id)}">حذف</button></div>`).join(''):'<div class="admin-v146-empty">لا توجد إشعارات حالياً.</div>'}</div>
        </article>
      </div>
    </section>`;
    return true;
  }

  function target(value){
    captureDraft();
    state.draft.targetId=String(value||'');
    const selected=users().find(row=>String(row.id)===state.draft.targetId);
    if(selected)state.draft.audience=userRole(selected)||state.draft.audience;
    render();
  }

  async function send(){
    if(state.sending)return false;
    const status=document.getElementById('v146Status');
    const button=document.getElementById('v146SendButton');
    const title=document.getElementById('v146Title')?.value.trim()||'';
    const message=document.getElementById('v146Message')?.value.trim()||'';
    const selectedRole=document.getElementById('v146Audience')?.value||'all';
    const priority=document.getElementById('v146Priority')?.value||'normal';
    const targetId=document.getElementById('v146Target')?.value||'';
    captureDraft();
    const targetAccount=targetId?users().find(row=>String(row.id)===String(targetId)):null;
    const role=targetAccount?(userRole(targetAccount)||selectedRole):selectedRole;
    if(!title||!message){if(status)status.textContent='اكتب العنوان ونص الإشعار.';return false}
    if(!service()?.send){if(status)status.textContent='خدمة الإشعارات غير جاهزة.';return false}
    state.sending=true;
    if(button){button.disabled=true;button.textContent='جارٍ الإرسال...'}
    try{
      const result=await service().send({title,message,role,target_id:targetId||null,priority,from_user:'admin'});
      let push=null;
      if(result.remote&&(role==='all'||role==='student')){
        try{
          const invoke=window.ALINAuthRuntime?.invokeAdmin;
          if(typeof invoke==='function')push=await invoke('admin-send-push',{notification_id:result.id,title,message,role,target_id:targetId||null,url:'./index.html'});
        }catch(pushError){console.warn('[ALIN push send]',pushError);push={ok:false,error:pushError?.message||'تعذر إرسال Push'}}
      }
      if(typeof window.audit==='function')await window.audit('notification',`إرسال إشعار ${title}`);
      if(status){
        if(!result.remote)status.textContent='تم حفظ الإشعار محليًا، وتعذر رفعه إلى الخادم.';
        else if(push?.ok)status.textContent=`تم إرسال الإشعار. وصل Push إلى ${Number(push.sent||0)} جهاز${push.failed?`، وتعذر ${push.failed}`:''}.`;
        else if(role==='all'||role==='student')status.textContent=`تم حفظ الإشعار داخل المنصة${push?.error?'، لكن Push الخارجي تعذر: '+push.error:''}.`;
        else status.textContent='تم إرسال الإشعار داخل المنصة بنجاح.';
      }
      clearDraft();
      render();
      return true;
    }catch(error){
      console.error('[ALIN admin notifications]',error);
      if(status)status.textContent=error?.message||'تعذر إرسال الإشعار.';
      return false;
    }finally{
      state.sending=false;
      if(button&&document.body.contains(button)){button.disabled=false;button.textContent='إرسال الإشعار'}
    }
  }

  async function refresh(){
    captureDraft();
    state.studentsLoaded=false;
    await Promise.allSettled([service()?.refresh?.(),loadStudents()]);
    render();
  }

  async function remove(id){
    if(!confirm('حذف هذا الإشعار؟'))return false;
    try{captureDraft();await service()?.remove?.(id);render();return true}
    catch(error){console.error(error);alert(error?.message||'تعذر حذف الإشعار');return false}
  }

  function filter(key,value){state[key]=value;render()}

  const api=Object.freeze({render,send,refresh,remove,filter,target,loadStudents});
  window.AlinAdminNotifications=api;
  window.renderNotificationsAdmin=render;
  window.AlinAdminModules?.register?.('notifications',render);

  window.addEventListener('alin:notifications-updated',()=>{
    if(window.activeAdminTab!=='notifications')return;
    const active=document.activeElement;
    if(active&&active.closest?.('.admin-v146-form')){captureDraft();return}
    render();
  });
})();
