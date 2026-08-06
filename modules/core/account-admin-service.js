// === core/account-admin-service.js ===
/* ALIN v4.1.6 prepublish 1n — account administration with direct database fallback for profile edits. */
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
  const edgeUnavailable=error=>/failed to send a request to the edge function|edge function|failed to fetch|networkerror|load failed|network request failed|خدمة الإدارة الآمنة غير متاحة/i.test(String(error?.message||error||''));
  const compact=object=>Object.fromEntries(Object.entries(object||{}).filter(([,value])=>value!==undefined));
  function missingColumn(error){
    const text=String(error?.message||error||'');
    return text.match(/Could not find the '([^']+)' column/i)?.[1]
      ||text.match(/column\s+"?([a-zA-Z0-9_]+)"?\s+.*does not exist/i)?.[1]
      ||text.match(/column\s+([a-zA-Z0-9_]+)\s+of relation/i)?.[1]
      ||'';
  }
  async function updateCompat(table,id,values,select='*'){
    const c=client();if(!c?.from)throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const payload=compact(values);
    for(let attempt=0;attempt<10;attempt++){
      const {data,error}=await c.from(table).update(payload).eq('id',String(id)).select(select).maybeSingle();
      if(!error)return data||null;
      const column=missingColumn(error);
      if(column&&Object.prototype.hasOwnProperty.call(payload,column)){delete payload[column];continue}
      throw error;
    }
    throw new Error('تعذر توافق حقول الحساب مع قاعدة البيانات');
  }
  async function directUpdateAccount(payload){
    const c=client();if(!c?.from)throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const accountId=String(payload?.account_id||'').trim();
    if(!accountId)throw new Error('معرّف الحساب غير موجود');
    const {data:before,error:readError}=await c.from('accounts').select('*').eq('id',accountId).maybeSingle();
    if(readError)throw readError;
    if(!before)throw new Error('الحساب غير موجود');

    const requestedRole=String(payload.role||before.role||'');
    const requestedUsername=String(payload.username||before.username||'').trim();
    const warnings=[];
    if(requestedRole&&requestedRole!==String(before.role||''))warnings.push('تم حفظ البيانات الأساسية فقط؛ تغيير نوع الحساب يحتاج خدمة الحسابات الآمنة');
    if(requestedUsername&&requestedUsername!==String(before.username||''))warnings.push('تم حفظ البيانات الأساسية فقط؛ تغيير اسم الدخول يحتاج خدمة الحسابات الآمنة');
    if(payload.password)warnings.push('تم حفظ البيانات الأساسية، لكن كلمة المرور لم تتغير لأن خدمة الحسابات الآمنة غير متصلة');

    const account=await updateCompat('accounts',accountId,{
      name:String(payload.name??before.name??'').trim(),
      status:payload.status===undefined?undefined:String(payload.status||'active'),
      phone:payload.phone===undefined?undefined:String(payload.phone||'').trim(),
      area:payload.area===undefined?undefined:String(payload.area||'').trim(),
      landmark:payload.landmark===undefined?undefined:String(payload.landmark||'').trim(),
      notes:payload.notes===undefined?undefined:String(payload.notes||'').trim(),
      deleted_at:String(payload.status||'')==='active'?null:undefined,
      updated_at:new Date().toISOString()
    },'id,role,name,username,status,auth_user_id,phone,area,landmark,notes,admin_level,deleted_at');

    if(String(before.role||'')==='courier'){
      const areas=Array.isArray(payload.areas)?[...new Set(payload.areas.map(x=>String(x||'').trim()).filter(Boolean))]:undefined;
      const courierValues=compact({
        name:String(payload.name??before.name??'').trim(),
        username:String(before.username||''),
        phone:payload.phone===undefined?undefined:String(payload.phone||'').trim(),
        area:payload.area===undefined?(areas?.[0]||undefined):String(payload.area||'').trim(),
        areas,
        availability:payload.availability===undefined?undefined:String(payload.availability||'available'),
        status:payload.status===undefined?undefined:(String(payload.status)==='active'?'active':'inactive'),
        updated_at:new Date().toISOString()
      });
      const {data:existing,error:existsError}=await c.from('couriers').select('id').eq('id',accountId).maybeSingle();
      if(existsError)throw existsError;
      if(existing)await updateCompat('couriers',accountId,courierValues,'id,name,username,phone,area,areas,availability,status');
      else{
        const {error:insertError}=await c.from('couriers').insert({id:accountId,...courierValues,created_at:new Date().toISOString()});
        if(insertError)throw insertError;
      }
    }
    if(typeof load==='function')try{await load()}catch(error){console.warn('[ALIN account refresh after direct save]',error)}
    return Object.assign({},account||before,{warning:warnings.join(' — '),saved_directly:true});
  }

  async function createAccount(payload){
    if(!payload?.name||!payload?.username||!payload?.password)throw new Error('أكمل الاسم واسم الدخول وكلمة المرور');
    if(!strongPassword(payload.password))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      const data=await invokeAdmin('admin-create-account',payload);
      if(typeof load==='function')await load();
      return data.account;
    }catch(error){
      if(edgeUnavailable(error))throw new Error('تعذر إنشاء حساب جديد لأن خدمة إنشاء الحسابات في Supabase غير منشورة. تعديل بيانات الحسابات الحالية يعمل مباشرة.');
      throw error;
    }
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
    try{
      const data=await invokeAdmin('admin-update-account',payload);
      if(typeof load==='function')await load();
      return data.account;
    }catch(error){
      if(!edgeUnavailable(error))throw error;
      console.warn('[ALIN account direct update fallback]',error?.message||error);
      return directUpdateAccount(payload);
    }
  }
  async function resetPasswordFromAdmin(accountId,password){
    if(!strongPassword(password))throw new Error('كلمة المرور يجب أن تكون 12 حرفاً على الأقل وتتضمن حروفاً وأرقاماً');
    try{
      await repairAuthLink(accountId);
      return await invokeAdmin('admin-reset-password',{account_id:accountId,password});
    }catch(error){
      if(edgeUnavailable(error))throw new Error('تعذر تغيير كلمة المرور لأن خدمة الحسابات الآمنة غير متصلة. بقية بيانات الحساب يمكن حفظها بصورة طبيعية.');
      throw error;
    }
  }
  async function deleteAccountFromAdmin(accountId){return invokeAdmin('admin-delete-account',{account_id:accountId})}
  window.ALINAuth=Object.assign(window.ALINAuth||{},
    {createAccount,createAccountFromAdmin,updateAccountFromAdmin,resetPasswordFromAdmin,repairAuthLink,deleteAccountFromAdmin});
  window.addAccount=createAccountFromAdmin;
  window.ALINAccountAdmin=Object.freeze({createAccount,createAccountFromAdmin,updateAccountFromAdmin,resetPasswordFromAdmin,repairAuthLink,deleteAccountFromAdmin});
  window.dispatchEvent(new CustomEvent('alin:account-admin-ready'));
})();
