// === core/account-admin-service.js ===
/* ALIN RC7 — account administration through authenticated Edge Functions only. */
(function(){
  'use strict';
  const runtime=()=>window.ALINAuthRuntime||{};
  const client=()=>runtime().client?.()||window.sb||window.AlinCloud?.client?.()||null;
  const strongPassword=value=>String(value||'').length>=12&&/[0-9]/.test(value)&&/[A-Za-z\u0600-\u06FF]/.test(value);
  const invokeAdmin=(name,body)=>{
    const invoke=runtime().invokeAdmin;
    if(typeof invoke!=='function')throw new Error('خدمة إدارة الحسابات غير جاهزة');
    return invoke(name,body);
  };


  async function createAccount(payload){
    if(!payload?.name||!payload?.username||!payload?.password)throw new Error('أكمل الاسم واسم الدخول وكلمة المرور');
    if(!strongPassword(payload.password))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      const data=await invokeAdmin('admin-create-account',payload);
      if(typeof load==='function')await load();
      return data.account;
    }catch(error){throw new Error(error?.message||'تعذر إنشاء الحساب عبر خدمة الإدارة الآمنة')}
  }

  async function createAccountFromAdmin(){
    const button=document.getElementById('v131SaveAccountButton');
    if(button?.disabled)return null;
    const originalLabel=button?.textContent||'حفظ الحساب';
    try{
      if(button){button.disabled=true;button.textContent='جارٍ الحفظ...'}
      const role=document.getElementById('aRole')?.value||'';
      const selectedAreas=[...document.querySelectorAll('#v163CourierAreaPicker input:checked')].map(x=>String(x.value||'').trim()).filter(Boolean);
      const payload={
        role,
        name:document.getElementById('aName')?.value?.trim()||'',
        username:document.getElementById('aUser')?.value?.trim()||'',
        password:document.getElementById('aPass')?.value||'',
        phone:document.getElementById('aPhone')?.value?.trim()||document.getElementById('v163CourierPhone')?.value?.trim()||'',
        area:role==='courier'?(selectedAreas[0]||''):(document.getElementById('aArea')?.value?.trim()||''),
        landmark:role==='courier'?'':(document.getElementById('aLandmark')?.value?.trim()||''),
        availability:document.getElementById('v163CourierAvailability')?.value||'available',
        areas:selectedAreas,
        status:'active'
      };
      if(!['teacher','library','courier','accountant'].includes(role))throw new Error('اختر نوع الحساب');
      if(role==='courier'&&!payload.areas.length)throw new Error('اختر منطقة عمل واحدة على الأقل');
      if(role==='courier'&&!payload.phone)throw new Error('أدخل رقم هاتف المندوب');
      const account=await createAccount(payload);
      ['aName','aUser','aPass','aPhone','aArea','aLandmark'].forEach(id=>{const el=document.getElementById(id);if(el)el.value=''});
      document.querySelectorAll('#v163CourierAreaPicker input').forEach(el=>{el.checked=false});
      window.v131CourierAreaCount?.();
      window.v131ToggleAccountForm?.(false);
      if(typeof renderAccountsAdmin==='function')renderAccountsAdmin();
      if(typeof toast==='function')toast(`تم إنشاء الحساب: ${account.username}`);else alert(`تم إنشاء الحساب بنجاح: ${account.username}`);
      return account;
    }catch(e){
      alert(e?.message||'تعذر إنشاء الحساب');
      return null;
    }finally{
      if(button){button.disabled=false;button.textContent=originalLabel}
    }
  }

  async function repairAuthLink(accountId){
    const c=client();if(!c?.rpc||!accountId)return 0;
    const {data,error}=await c.rpc('alin_repair_auth_links',{p_account_id:String(accountId)});
    if(error){
      const text=String(error.message||'');
      if(/PGRST202|Could not find the function|schema cache/i.test(text))throw new Error('خدمة ربط الحسابات غير مهيأة في مشروع Supabase الجديد');
      throw error;
    }
    return Number(data||0);
  }
  async function updateAccountFromAdmin(payload){
    const data=await invokeAdmin('admin-update-account',payload);
    if(typeof load==='function')await load();
    return data.account;
  }
  async function resetPasswordFromAdmin(accountId,password){
    if(!strongPassword(password))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      await repairAuthLink(accountId);
      return await invokeAdmin('admin-reset-password',{account_id:accountId,password});
    }catch(error){throw new Error(error?.message||'تعذر تغيير كلمة المرور عبر خدمة الإدارة الآمنة')}
  }
  async function deleteAccountFromAdmin(accountId){return invokeAdmin('admin-delete-account',{account_id:accountId})}
  window.ALINAuth=Object.assign(window.ALINAuth||{},
    {createAccount,createAccountFromAdmin,updateAccountFromAdmin,resetPasswordFromAdmin,repairAuthLink,deleteAccountFromAdmin});
  window.addAccount=createAccountFromAdmin;
  window.ALINAccountAdmin=Object.freeze({createAccount,createAccountFromAdmin,updateAccountFromAdmin,resetPasswordFromAdmin,repairAuthLink,deleteAccountFromAdmin});
  window.dispatchEvent(new CustomEvent('alin:account-admin-ready'));
})();
