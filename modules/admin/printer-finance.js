/* ALIN — Admin printer finance cards.
 * Each printer has two independent balances:
 * 1) operational/collector debt to administration, analogous to library debt;
 * 2) book-supply payable from administration to the printer.
 */
(function(){
  'use strict';
  if(window.__ALIN_ADMIN_PRINTER_FINANCE__)return;
  window.__ALIN_ADMIN_PRINTER_FINANCE__=true;

  const arr=v=>Array.isArray(v)?v:[];
  const num=v=>Math.max(0,Number(v)||0);
  const esc=v=>typeof window.esc==='function'?window.esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const money=v=>typeof window.money==='function'?window.money(v):Math.round(num(v)).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const db=()=>window.db||{};
  const client=()=>window.ALINAuthRuntime?.client?.()||window.sb||window.AlinCloud?.client?.()||null;
  const printers=()=>arr(db().accounts?.all).filter(x=>String(x.role||'').toLowerCase()==='printer'&&!x.deleted_at);
  let supplierBalances=[];
  let loading=false;

  function collectorSummary(id){
    const rows=arr(db().ledger).filter(l=>String(l.library_id||'')===String(id)&&String(l.collector_role||l.delivery_type||'library')==='library'&&!['cancelled','reversed'].includes(String(l.status||'')));
    const debtTotal=rows.reduce((s,l)=>s+num(l.collector_debt),0);
    const settlements=arr(db().settlements).filter(s=>String(s.party_role||'').toLowerCase()==='printer'&&String(s.party_id||'')===String(id)&&['received','paid'].includes(String(s.status||'').toLowerCase()));
    const settled=settlements.reduce((s,x)=>s+num(x.amount),0);
    return {debtTotal,settled,remaining:Math.max(0,debtTotal-settled),rows,settlements};
  }

  function supplierSummary(id){
    const row=supplierBalances.find(x=>String(x.supplier_id||'')===String(id));
    return {key:row?.supplier_key||`printer:${id}`,pending:num(row?.pending_amount),settled:num(row?.settled_amount),total:num(row?.total_amount),orders:Number(row?.orders_count||0)};
  }

  async function loadSupplierBalances(){
    const c=client();if(!c?.rpc)return[];
    const {data,error}=await c.rpc('alin_admin_book_supplier_balances');if(error)throw error;
    supplierBalances=arr(data);return supplierBalances;
  }

  async function settleDebt(id){
    const p=printers().find(x=>String(x.id)===String(id));if(!p)return alert('حساب المطبعة غير موجود');
    const s=collectorSummary(id);if(s.remaining<=0)return alert('ذمة المطبعة مصفّاة');
    const raw=prompt(`المتبقي بذمة ${p.name||'المطبعة'} هو ${money(s.remaining)} د.ع\nاكتب المبلغ المستلم`,String(s.remaining));if(raw===null)return;
    const amount=Number(String(raw).replace(/[,،]/g,''));if(!Number.isFinite(amount)||amount<=0||amount>s.remaining)return alert('مبلغ التسوية غير صحيح');
    try{
      const c=client();if(!c?.rpc)throw new Error('خدمة التسويات غير متاحة');
      const {error}=await c.rpc('alin_finance_record_settlement',{p_role:'printer',p_party_id:String(id),p_amount:amount,p_method:prompt('طريقة الاستلام','نقدي')||'نقدي',p_note:'تسوية ذمة مطبعة من لوحة الإدارة'});if(error)throw error;
      await window.load?.({force:true,reason:'printer-debt-settlement'});window.toast?.('تم تسجيل تسوية ذمة المطبعة');decorate(true);
    }catch(e){alert(e?.message||'تعذر تسجيل التسوية')}
  }

  async function settleSupply(id){
    const p=printers().find(x=>String(x.id)===String(id));if(!p)return alert('حساب المطبعة غير موجود');
    const s=supplierSummary(id);if(s.pending<=0)return alert('حساب توريد الكتب مصفّى');
    if(!confirm(`تسديد ${money(s.pending)} د.ع إلى ${p.name||'المطبعة'} عن توريد الكتب؟`))return;
    try{
      const c=client();if(!c?.rpc)throw new Error('خدمة التسويات غير متاحة');
      const {data,error}=await c.rpc('alin_admin_settle_book_supplier',{p_supplier_key:s.key,p_note:'تسوية توريد كتب من لوحة الإدارة'});if(error)throw error;
      await loadSupplierBalances();await window.load?.({force:true,reason:'printer-book-settlement'});window.toast?.(`تمت تسوية توريد الكتب ${money(data?.amount||s.pending)} د.ع`);decorate(false);
    }catch(e){alert(e?.message||'تعذر تسوية توريد الكتب')}
  }

  function card(p){
    const debt=collectorSummary(p.id),supply=supplierSummary(p.id);
    return `<article class="admin-v137-party-card alin-printer-finance-card" data-role="printer" data-search="${esc(`${p.name||''} مطبعة`.toLowerCase())}"><div><b>${esc(p.name||'مطبعة')}</b><small>مطبعة — حسابان ماليان مستقلان</small></div><div class="admin-v223-library-debt"><span>ذمة المطبعة للإدارة <b>${money(debt.remaining)} د.ع</b> • المسدد <b>${money(debt.settled)} د.ع</b></span>${debt.remaining>0?`<button class="secondary" data-alin-click="AlinAdminPrinterFinance.settleDebt" data-alin-click-arg0="${esc(p.id)}">تسوية الذمة</button>`:'<em>الذمة مصفّاة</em>'}</div><div class="admin-v223-library-debt"><span>توريد الكتب المستحق للمطبعة <b>${money(supply.pending)} د.ع</b> • المسدد <b>${money(supply.settled)} د.ع</b> • ${supply.orders} طلب</span>${supply.pending>0?`<button data-alin-click="AlinAdminPrinterFinance.settleSupply" data-alin-click-arg0="${esc(p.id)}">تسوية توريد الكتب</button>`:'<em>توريد الكتب مصفّى</em>'}</div></article>`;
  }

  async function decorate(forceLoad=false){
    if(window.activeAdminTab!=='finance')return;
    if(loading)return;loading=true;
    try{
      if(forceLoad||!supplierBalances.length)await loadSupplierBalances().catch(e=>console.warn('[ALIN printer balances]',e));
      const list=document.getElementById('financeBalances');if(!list)return;
      list.querySelectorAll('.alin-printer-finance-card').forEach(x=>x.remove());
      printers().forEach(p=>list.insertAdjacentHTML('beforeend',card(p)));
      const select=document.getElementById('financeRole');if(select&&!select.querySelector('option[value="printer"]'))select.insertAdjacentHTML('beforeend','<option value="printer">المطابع</option>');
    }finally{loading=false}
  }

  const api=Object.freeze({decorate,settleDebt,settleSupply});window.AlinAdminPrinterFinance=api;
  window.addEventListener('alin:admin-tab',e=>{if(e.detail?.tab==='finance')setTimeout(()=>decorate(true),0)});
  window.addEventListener('alin:data-refreshed',()=>{if(window.activeAdminTab==='finance')setTimeout(()=>decorate(true),0)});
  window.addEventListener('alin:role-runtime-ready',()=>setTimeout(()=>decorate(false),50));
})();
