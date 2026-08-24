// === admin/finance-settlement-ui.js ===
/* ALIN — safe settlement UI over the existing authoritative finance service. */
(function(){
  'use strict';
  if(window.__ALIN_FINANCE_SETTLEMENT_UI__)return;
  window.__ALIN_FINANCE_SETTLEMENT_UI__=true;

  const state={role:'',id:'',busy:false,observer:null,scheduled:false};
  const num=value=>Number.isFinite(Number(value))?Number(value):0;
  const esc=value=>String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const money=value=>typeof window.money==='function'?window.money(value):Math.round(num(value)).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const finance=()=>window.AlinFinance;
  const normalizedRole=role=>String(role||'').toLowerCase().replace('courier','delegate');
  const roleLabel=role=>({admin:'المنصة',teacher:'المدرس',library:'المكتبة',delegate:'المندوب'})[normalizedRole(role)]||'الحساب';

  function summary(role,id){
    role=normalizedRole(role);
    const api=finance();if(!api)return {remaining:0};
    if(role==='library'){
      const s=api.librarySummary?.(id)||{};
      return {...s,remaining:Math.max(0,num(s.remaining??s.debtRemaining))};
    }
    if(role==='delegate'){
      const s=api.delegateSummary?.(id)||{};
      return {...s,remaining:Math.max(0,num(s.debt??s.remaining))};
    }
    const s=api.balance?.(role,id)||{};
    return {...s,remaining:Math.max(0,num(s.remaining))};
  }

  function partyName(role,id){return finance()?.partyName?.(normalizedRole(role),id)||roleLabel(role)}

  function ensureStyle(){
    if(document.getElementById('alinFinanceSettlementCss'))return;
    const link=document.createElement('link');
    link.id='alinFinanceSettlementCss';link.rel='stylesheet';
    const version=window.ALIN_CONFIG?.assetVersion||window.ALIN_CONFIG?.version||'4.2.0';
    link.href=`./styles/alin-finance-settlement-ui.css?v=${encodeURIComponent(version)}`;
    document.head.appendChild(link);
  }

  function ensureModal(){
    let layer=document.getElementById('alinFinanceSettlementLayer');
    if(layer)return layer;
    layer=document.createElement('div');
    layer.id='alinFinanceSettlementLayer';
    layer.hidden=true;
    layer.innerHTML=`<section class="alin-finance-settlement-card" role="dialog" aria-modal="true" aria-labelledby="alinFinanceSettlementTitle">
      <button type="button" class="alin-finance-settlement-close" data-alin-click="AlinFinanceSettlementUI.close" aria-label="إغلاق">×</button>
      <header><small>تسوية مالية</small><h2 id="alinFinanceSettlementTitle">تسوية الحساب</h2><p id="alinFinanceSettlementSubtitle"></p></header>
      <section class="alin-finance-settlement-summary">
        <div><small>الحساب</small><b id="alinFinanceSettlementName">—</b></div>
        <div><small>نوع الحساب</small><b id="alinFinanceSettlementRole">—</b></div>
        <div class="balance"><small>الرصيد الحالي</small><b id="alinFinanceSettlementBalance">0 د.ع</b></div>
      </section>
      <div class="alin-finance-settlement-form">
        <label><span>مبلغ التسوية</span><input id="alinFinanceSettlementAmount" inputmode="numeric" autocomplete="off" placeholder="0"></label>
        <div class="alin-finance-settlement-shortcuts"><button type="button" data-alin-click="AlinFinanceSettlementUI.useFullBalance">تسوية كامل الرصيد</button></div>
        <label><span>طريقة الدفع / الاستلام</span><select id="alinFinanceSettlementMethod"><option value="نقدي">نقدي</option><option value="تحويل">تحويل</option><option value="زين كاش">زين كاش</option><option value="آسيا حوالة">آسيا حوالة</option><option value="أخرى">أخرى</option></select></label>
        <label><span>ملاحظة <small>اختياري</small></span><textarea id="alinFinanceSettlementNote" rows="3" placeholder="مثال: تسوية كاملة حتى تاريخ اليوم"></textarea></label>
        <div id="alinFinanceSettlementMessage" class="alin-finance-settlement-message" aria-live="polite"></div>
        <footer><button type="button" class="secondary" data-alin-click="AlinFinanceSettlementUI.close">إلغاء</button><button type="button" id="alinFinanceSettlementConfirm" data-alin-click="AlinFinanceSettlementUI.confirm">تأكيد التسوية</button></footer>
      </div>
    </section>`;
    layer.addEventListener('click',event=>{if(event.target===layer)close()});
    document.body.appendChild(layer);
    return layer;
  }

  function setMessage(message,type=''){
    const box=document.getElementById('alinFinanceSettlementMessage');if(!box)return;
    box.textContent=message||'';box.dataset.type=type||'';box.hidden=!message;
  }

  function open(role,id){
    role=normalizedRole(role);id=String(id||role);
    if(!['admin','teacher','library','delegate'].includes(role))return false;
    const currentRole=String(window.current?.role||'').toLowerCase();
    if(!['admin','accountant'].includes(currentRole)){alert('هذا الإجراء متاح للإدارة فقط');return false}
    const s=summary(role,id);
    if(s.remaining<=0){alert(role==='library'?'حساب المكتبة مصفّى ولا توجد ذمة متبقية':role==='delegate'?'ذمة المندوب مصفّاة':'لا يوجد رصيد متبقٍ');return false}
    state.role=role;state.id=id;state.busy=false;
    ensureStyle();const layer=ensureModal();
    const name=partyName(role,id);
    document.getElementById('alinFinanceSettlementTitle').textContent='تسوية الحساب';
    document.getElementById('alinFinanceSettlementSubtitle').textContent='تُسجل العملية كسند مستقل بدون حذف أي حركة أو طلب سابق.';
    document.getElementById('alinFinanceSettlementName').textContent=name;
    document.getElementById('alinFinanceSettlementRole').textContent=roleLabel(role);
    document.getElementById('alinFinanceSettlementBalance').textContent=`${money(s.remaining)} د.ع`;
    const amount=document.getElementById('alinFinanceSettlementAmount');if(amount){amount.value=String(Math.round(s.remaining));amount.max=String(Math.round(s.remaining));}
    const method=document.getElementById('alinFinanceSettlementMethod');if(method)method.value='نقدي';
    const note=document.getElementById('alinFinanceSettlementNote');if(note)note.value='';
    const confirm=document.getElementById('alinFinanceSettlementConfirm');if(confirm){confirm.disabled=false;confirm.textContent='تأكيد التسوية'}
    setMessage('');layer.hidden=false;document.body.classList.add('alin-finance-settlement-open');
    setTimeout(()=>amount?.focus(),30);return true;
  }

  function close(){
    if(state.busy)return false;
    const layer=document.getElementById('alinFinanceSettlementLayer');if(layer)layer.hidden=true;
    document.body.classList.remove('alin-finance-settlement-open');setMessage('');return true;
  }

  function useFullBalance(){
    const s=summary(state.role,state.id),input=document.getElementById('alinFinanceSettlementAmount');
    if(input)input.value=String(Math.round(s.remaining));
  }

  async function confirm(){
    if(state.busy)return false;
    const role=state.role,id=state.id,api=finance();if(!api?.recordSettlement)return false;
    const latest=summary(role,id),remaining=Math.max(0,num(latest.remaining));
    if(remaining<=0){setMessage('الحساب أصبح مصفّى ولا توجد ذمة متبقية.','success');setTimeout(()=>{state.busy=false;close()},700);return false}
    const input=document.getElementById('alinFinanceSettlementAmount');
    const amount=num(String(input?.value||'').replace(/[ ,،]/g,''));
    if(amount<=0){setMessage('اكتب مبلغ تسوية أكبر من صفر.','error');input?.focus();return false}
    if(amount>remaining){setMessage(`المبلغ أكبر من الرصيد الحالي (${money(remaining)} د.ع).`,'error');input?.focus();return false}
    const method=document.getElementById('alinFinanceSettlementMethod')?.value||'نقدي';
    const customNote=document.getElementById('alinFinanceSettlementNote')?.value?.trim()||'';
    const defaultNote=role==='library'?'تسوية ذمة مكتبة من لوحة الإدارة':role==='delegate'?'تسوية ذمة مندوب من لوحة الإدارة':role==='admin'?'استلام ربح المنصة':'تسديد أرباح المدرس';
    const note=customNote?`${defaultNote} — ${customNote}`:defaultNote;
    const button=document.getElementById('alinFinanceSettlementConfirm');
    state.busy=true;if(button){button.disabled=true;button.textContent='جارٍ تثبيت التسوية...'}setMessage('جارٍ تسجيل السند والتحقق من الرصيد...','working');
    try{
      const result=await api.recordSettlement(role,id,amount,method,note);
      if(typeof window.load==='function')await window.load({force:true,reason:'finance-settlement-ui'});
      setMessage(`تم تسجيل تسوية بقيمة ${money(amount)} د.ع بنجاح.`,'success');
      if(typeof window.audit==='function')await window.audit('finance',`تسوية ${roleLabel(role)} ${partyName(role,id)} بمبلغ ${Math.round(amount)} د.ع`);
      if(typeof window.renderFinanceAdmin==='function')window.renderFinanceAdmin();
      if(typeof window.toast==='function')window.toast('تم تسجيل سند التسوية');
      setTimeout(()=>{state.busy=false;close()},650);
      return result;
    }catch(error){
      console.error('[ALIN finance settlement UI]',error);
      state.busy=false;if(button){button.disabled=false;button.textContent='تأكيد التسوية'}
      setMessage(error?.message||'تعذر تسجيل التسوية. لم يتم تغيير الرصيد.','error');return false;
    }
  }

  function patchButtons(root=document){
    root.querySelectorAll('[data-alin-click="AlinFinance.payBalance"]').forEach(button=>{
      const role=button.dataset.alinClickArg0||'';const id=button.dataset.alinClickArg1||'';
      button.dataset.alinClick='AlinFinanceSettlementUI.open';button.dataset.alinClickArg0=normalizedRole(role);button.dataset.alinClickArg1=id;
    });
    root.querySelectorAll('[data-alin-click="AlinFinance.settleLibrary"]').forEach(button=>{
      const id=button.dataset.alinClickArg0||'';button.dataset.alinClick='AlinFinanceSettlementUI.open';button.dataset.alinClickArg0='library';button.dataset.alinClickArg1=id;
    });
    root.querySelectorAll('[data-alin-click="AlinFinance.settleDelegate"]').forEach(button=>{
      const id=button.dataset.alinClickArg0||'';button.dataset.alinClick='AlinFinanceSettlementUI.open';button.dataset.alinClickArg0='delegate';button.dataset.alinClickArg1=id;
    });
  }

  function schedule(){if(state.scheduled)return;state.scheduled=true;requestAnimationFrame(()=>{state.scheduled=false;patchButtons(document)})}
  function start(){ensureStyle();ensureModal();patchButtons(document);state.observer=new MutationObserver(schedule);state.observer.observe(document.body,{childList:true,subtree:true})}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
  ['alin:role-runtime-ready','alin:data-refreshed','alin:page-open'].forEach(type=>window.addEventListener(type,schedule));

  window.AlinFinanceSettlementUI=Object.freeze({open,close,confirm,useFullBalance,patchButtons});
})();

;
