/* ALIN — Printer accounts bridge.
 * Adds a first-class "مطبعة" account type without mixing it into library
 * book-supplier profit. Printers remain visible in the ordinary Accounts page.
 */
(function(){
  'use strict';
  if(window.__ALIN_PRINTER_ACCOUNTS__)return;
  window.__ALIN_PRINTER_ACCOUNTS__=true;

  const esc=v=>typeof window.esc==='function'?window.esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const arr=v=>Array.isArray(v)?v:[];
  const printers=()=>arr(window.db?.accounts?.all).filter(x=>String(x.role||'').toLowerCase()==='printer'&&!x.deleted_at);
  const normalizedStatus=x=>{const s=String(x?.status||'active').toLowerCase();return s==='active'?'active':s==='pending'?'pending':'inactive'};
  const state={query:'',role:'all',status:'all',area:'all'};
  let baseRender=null,baseFilter=null,baseAdd=null;

  function printerCard(x){
    const st=normalizedStatus(x),meta=[x.username?`الدخول: ${esc(x.username)}`:'',x.phone?esc(x.phone):'',x.area?esc(x.area):''].filter(Boolean);
    return `<article class="v131-account-card alin-printer-account-card" data-alin-printer-card data-search="${esc([x.name,x.username,x.phone,x.area,'مطبعة'].join(' ').toLowerCase())}" data-status="${st}" data-area="${esc(x.area||'')}"><div class="v131-avatar printer">${esc(String(x.name||'م').trim().slice(0,1)||'م')}</div><div class="v131-account-info"><h3>${esc(x.name||'مطبعة')}</h3><div class="v131-account-meta"><span class="v131-chip">مطبعة</span>${meta.map(m=>`<span class="v131-chip">${m}</span>`).join('')}<span class="v131-status ${st}">${st==='active'?'فعال':st==='pending'?'قيد المراجعة':'موقوف'}</span></div></div><div class="v131-card-actions"><button class="secondary" data-alin-click="AlinPrinterAccounts.edit" data-alin-click-arg0="${esc(x.id)}">تعديل</button><button class="warning" data-alin-click="AlinPrinterAccounts.toggle" data-alin-click-arg0="${esc(x.id)}" data-alin-click-arg1="${st==='active'?'inactive':'active'}">${st==='active'?'إيقاف':'تفعيل'}</button></div></article>`;
  }

  function injectOptions(){
    const role=document.getElementById('aRole');
    if(role&&!role.querySelector('option[value="printer"]'))role.insertAdjacentHTML('beforeend','<option value="printer">مطبعة</option>');
    document.querySelectorAll('.v131-account-tools select').forEach(sel=>{
      if(sel.querySelector('option[value="all"]')&&!sel.querySelector('option[value="printer"]'))sel.querySelector('option[value="library"]')?.insertAdjacentHTML('afterend','<option value="printer">المطابع</option>');
    });
    const tabs=document.querySelector('.v131-role-tabs');
    if(tabs&&!tabs.querySelector('[data-printer-role-tab]'))tabs.insertAdjacentHTML('beforeend','<button data-printer-role-tab data-alin-click="AlinPrinterAccounts.filterRole">المطابع</button>');
    const stats=document.querySelector('.v131-account-stats');
    if(stats&&!stats.querySelector('[data-printer-stat]'))stats.insertAdjacentHTML('beforeend',`<article class="v131-account-stat" data-printer-stat><small>المطابع</small><b>${printers().length}</b></article>`);
  }

  function visiblePrinters(){
    return printers().filter(x=>{
      const text=[x.name,x.username,x.phone,x.area,'مطبعة'].join(' ').toLowerCase();
      return (state.role==='all'||state.role==='printer')&&(!state.query||text.includes(state.query.toLowerCase()))&&(state.status==='all'||normalizedStatus(x)===state.status)&&(state.area==='all'||String(x.area||'')===state.area);
    });
  }

  function decorate(){
    if(window.activeAdminTab&&window.activeAdminTab!=='accounts')return;
    injectOptions();
    const grid=document.querySelector('.v131-account-grid');if(!grid)return;
    grid.querySelectorAll('[data-alin-printer-card]').forEach(x=>x.remove());
    if(state.role==='printer')grid.querySelectorAll('.v131-account-card:not([data-alin-printer-card])').forEach(x=>x.remove());
    const rows=visiblePrinters();
    rows.forEach(x=>grid.insertAdjacentHTML('beforeend',printerCard(x)));
    if(state.role==='printer'&&!rows.length)grid.innerHTML='<div class="v131-empty">لا توجد حسابات مطابع مطابقة.</div>';
  }

  function wrap(){
    if(!baseRender&&typeof window.renderAccountsAdmin==='function')baseRender=window.renderAccountsAdmin;
    if(!baseFilter&&typeof window.v131AccountFilter==='function')baseFilter=window.v131AccountFilter;
    if(!baseAdd&&typeof window.addAccount==='function')baseAdd=window.addAccount;
    if(!baseRender)return false;

    const wrapped=function(){const result=baseRender.apply(this,arguments);setTimeout(decorate,0);return result};
    window.renderAccountsAdmin=wrapped;
    window.AlinAdminModules?.register?.('accounts',wrapped);

    if(baseFilter)window.v131AccountFilter=(k,v)=>{state[k]=String(v??'');const r=baseFilter(k,v);setTimeout(decorate,0);return r};
    window.AlinPrinterAccounts=Object.freeze({
      filterRole(){state.role='printer';if(baseFilter)baseFilter('role','all');setTimeout(()=>{decorate();document.querySelectorAll('.v131-role-tabs button').forEach(b=>b.classList.toggle('active',b.hasAttribute('data-printer-role-tab')))},0)},
      async toggle(id,status){try{if(!window.ALINAuth?.updateAccountFromAdmin)throw new Error('خدمة الحسابات غير جاهزة');await window.ALINAuth.updateAccountFromAdmin({account_id:id,status});await window.load?.();wrapped();window.toast?.('تم تحديث حساب المطبعة')}catch(e){alert(e?.message||'تعذر تحديث الحساب')}},
      async edit(id){
        const x=printers().find(a=>String(a.id)===String(id));if(!x)return alert('تعذر العثور على حساب المطبعة');
        const name=prompt('اسم المطبعة',x.name||'');if(name===null)return;
        const phone=prompt('رقم الهاتف',x.phone||'');if(phone===null)return;
        const area=prompt('المنطقة',x.area||'');if(area===null)return;
        try{await window.ALINAuth.updateAccountFromAdmin({account_id:id,role:'printer',name:String(name).trim(),username:x.username,status:x.status||'active',phone:String(phone).trim(),area:String(area).trim(),landmark:x.landmark||'',notes:x.notes||''});await window.load?.();wrapped();window.toast?.('تم حفظ حساب المطبعة')}catch(e){alert(e?.message||'تعذر حفظ الحساب')}
      }
    });

    window.addAccount=async function(){
      const role=document.getElementById('aRole')?.value||'';
      if(role!=='printer')return baseAdd?.apply(this,arguments);
      const payload={role:'printer',name:document.getElementById('aName')?.value?.trim()||'',username:document.getElementById('aUser')?.value?.trim()||'',password:document.getElementById('aPass')?.value||'',phone:document.getElementById('aPhone')?.value?.trim()||'',area:document.getElementById('aArea')?.value?.trim()||'',landmark:document.getElementById('aLandmark')?.value?.trim()||'',status:'active'};
      try{
        const account=await window.ALINAuth?.createAccount?.(payload);if(!account)throw new Error('تعذر إنشاء حساب المطبعة');
        ['aName','aUser','aPass','aPhone','aArea','aLandmark'].forEach(id=>{const el=document.getElementById(id);if(el)el.value=''});
        window.v131ToggleAccountForm?.(false);await window.load?.();wrapped();window.toast?.(`تم إنشاء حساب المطبعة: ${account.username}`);return account;
      }catch(e){alert(e?.message||'تعذر إنشاء حساب المطبعة');return null}
    };
    return true;
  }

  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(()=>{wrap();decorate()},0));
  window.addEventListener('alin:data-refreshed',()=>setTimeout(decorate,0));
  window.addEventListener('alin:admin-tab',e=>{if(e.detail?.tab==='accounts')setTimeout(()=>{wrap();decorate()},0)});
  setTimeout(()=>{wrap();decorate()},100);
})();
