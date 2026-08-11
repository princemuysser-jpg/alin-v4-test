// === admin/finance.js ===
/* ALIN v2.2.6 — authoritative admin finance UI. No wrapper chains. */
(function(){
  'use strict';
  const arr=value=>Array.isArray(value)?value:[];
  const num=value=>Number.isFinite(Number(value))?Number(value):0;
  const escv=value=>typeof window.esc==='function'?window.esc(value):String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const moneyv=value=>typeof window.money==='function'?window.money(value):Math.round(num(value)).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const finance=()=>window.AlinFinance;
  const database=()=>window.db||{};

  function parties(){
    const accounts=database().accounts||{};
    return [
      {role:'admin',id:'admin',name:'منصة آلين',label:'ربح المنصة'},
      ...arr(accounts.teachers).map(row=>({role:'teacher',id:row.id,name:row.name,label:'مدرس'})),
      ...arr(accounts.libraries).map(row=>({role:'library',id:row.id,name:row.name,label:'مكتبة'})),
      ...arr(database().delegates||accounts.couriers||database().couriers).map(row=>({role:'delegate',id:row.id,name:row.name,label:'مندوب'}))
    ];
  }

  function totals(){
    return (finance()?.canonicalLedger?.()||[]).reduce((out,row)=>{
      out.sales+=num(row.total);out.admin+=num(row.admin||row.alin);out.teacher+=num(row.teacher);out.library+=num(row.library);out.delegate+=num(row.delegate||row.courier);return out;
    },{sales:0,admin:0,teacher:0,library:0,delegate:0});
  }

  function balanceCards(){
    return parties().map(p=>{
      const summary=finance()?.partySummary?.(p.role,p.id)||{earned:0,paid:0,remaining:0};
      const libraryDebt=p.role==='library'?(summary.debt||finance()?.librarySummary?.(p.id)):null;
      const delegateDebt=['delegate','courier'].includes(String(p.role||'').toLowerCase())?(finance()?.delegateSummary?.(p.id)||summary):null;
      const payoutRole=['admin','teacher'].includes(p.role);
      return `<article class="admin-v137-party-card" data-role="${escv(p.role)}" data-search="${escv(`${p.name||''} ${p.label}`.toLowerCase())}">
        <div><b>${escv(p.name||p.label)}</b><small>${escv(p.label)} — الإجمالي ${moneyv(summary.earned||summary.earnings)} د.ع</small></div>
        ${payoutRole?`<div class="admin-v137-party-values"><span>المسدد <b>${moneyv(summary.paid)}</b></span><span class="remain">المتبقي <b>${moneyv(summary.remaining)}</b></span>${summary.remaining>0?`<button data-alin-click="AlinFinance.payBalance" data-alin-click-arg0="${escv(p.role)}" data-alin-click-arg1="${escv(p.id)}">${p.role==='admin'?'استلام الربح':'تسديد الأرباح'}</button>`:'<em>مصفّى</em>'}</div>`:''}
        ${libraryDebt?`<div class="admin-v223-library-debt"><span>ربح المكتبة <b>${moneyv(libraryDebt.libraryProfit)} د.ع</b> • ذمتها للإدارة <b>${moneyv(libraryDebt.remaining)} د.ع</b></span>${libraryDebt.remaining>0?`<button class="secondary" data-alin-click="AlinFinance.settleLibrary" data-alin-click-arg0="${escv(p.id)}">تثبيت التسوية</button>`:'<em>الذمة مصفّاة</em>'}</div>`:''}
        ${delegateDebt?`<div class="admin-v223-library-debt"><span>ربح المندوب <b>${moneyv(delegateDebt.earnings||delegateDebt.earned)} د.ع</b> • ذمته للإدارة <b>${moneyv(delegateDebt.debt||delegateDebt.remaining)} د.ع</b></span>${(delegateDebt.debt||delegateDebt.remaining)>0?`<button class="secondary" data-alin-click="AlinFinance.settleDelegate" data-alin-click-arg0="${escv(p.id)}">تثبيت تسوية المندوب</button>`:'<em>الذمة مصفّاة</em>'}</div>`:''}
      </article>`;
    }).join('');
  }

  function withdrawals(){
    const rows=arr(database().withdrawals).slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')));
    return rows.map(row=>`<div class="admin-v137-finance-row"><div><b>${escv(row.role||'حساب')} — ${moneyv(row.amount)} د.ع</b><small>${escv(row.account_id||'')} • ${escv(String(row.created_at||'').slice(0,10))}</small></div><div class="row-actions"><span>${escv(row.status||'pending')}</span>${row.status==='pending'?`<button data-alin-click="withdrawStatus" data-alin-click-arg0="${escv(row.id)}" data-alin-click-arg1="approved">موافقة</button><button data-alin-click="withdrawStatus" data-alin-click-arg0="${escv(row.id)}" data-alin-click-arg1="paid">دفع</button><button class="danger" data-alin-click="withdrawStatus" data-alin-click-arg0="${escv(row.id)}" data-alin-click-arg1="rejected">رفض</button>`:''}</div></div>`).join('')||'<div class="empty">لا توجد طلبات سحب.</div>';
  }

  function settlementRows(){
    const rows=arr(database().settlements).slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')));
    return rows.map(row=>{
      const role=String(row.party_role||'').toLowerCase().replace('courier','delegate');
      const name=finance()?.partyName?.(role,row.party_id)||role||'حساب';
      return `<div class="admin-v137-finance-row"><div><b>${escv(name)}</b><small>${escv(row.receipt_number||row.id||'')} • ${escv(String(row.created_at||'').slice(0,10))} • ${escv(row.payment_method||'نقدي')}</small></div><div><strong>${moneyv(row.amount)} د.ع</strong><span>${escv(row.status||'')}</span></div></div>`;
    }).join('')||'<div class="empty">لا توجد سندات أو تسويات.</div>';
  }

  function ledgerRows(){
    const rows=finance()?.canonicalLedger?.()||[];
    return rows.slice().sort((a,b)=>String(b.settled_at||b.created_at||'').localeCompare(String(a.settled_at||a.created_at||''))).map(row=>`<div class="admin-v137-finance-row"><div><b>${escv(row.order_number||row.order_id)}</b><small>منصة ${moneyv(row.admin||row.alin)} • مدرس ${moneyv(row.teacher)} • مكتبة ${moneyv(row.library)} • مندوب ${moneyv(row.delegate||row.courier)}</small></div><span>${moneyv(row.total)} د.ع</span></div>`).join('')||'<div class="empty">لا توجد طلبات مسلّمة محتسبة.</div>';
  }

  function renderFinanceAdmin(){
    const root=document.getElementById('adminContent');if(!root)return false;
    const t=totals();
    const libraryDebt=arr(database().accounts?.libraries).reduce((sum,row)=>sum+num(finance()?.librarySummary?.(row.id)?.remaining),0);
    const delegateDebt=arr(database().delegates||database().accounts?.couriers||database().couriers).reduce((sum,row)=>sum+num(finance()?.delegateSummary?.(row.id)?.debt),0);
    const debt=libraryDebt+delegateDebt;
    root.innerHTML=`<section class="admin-v137-finance">
      <header class="admin-v137-finance-head"><div><h2>المالية والتسويات</h2><p>مسار مالي واحد للطلبات المسلّمة، الأرباح، ذمم المكتبات وسندات التسديد.</p></div><span class="admin-v137-finance-date">${new Date().toLocaleDateString(window.AlinI18n?.locale?.()||'ar-IQ')}</span></header>
      <section class="admin-v137-finance-metrics">
        <article class="admin-v137-finance-metric gold"><small>المبيعات المسلّمة</small><strong>${moneyv(t.sales)} د.ع</strong></article>
        <article class="admin-v137-finance-metric green"><small>ربح المنصة</small><strong>${moneyv(t.admin)} د.ع</strong></article>
        <article class="admin-v137-finance-metric"><small>أرباح المدرسين</small><strong>${moneyv(t.teacher)} د.ع</strong></article>
        <article class="admin-v137-finance-metric"><small>أرباح المكتبات</small><strong>${moneyv(t.library)} د.ع</strong></article>
        <article class="admin-v137-finance-metric"><small>أرباح المندوبين</small><strong>${moneyv(t.delegate)} د.ع</strong></article>
        <article class="admin-v137-finance-metric red"><small>ذمم المكتبات والمندوبين</small><strong>${moneyv(debt)} د.ع</strong></article>
      </section>
      <nav class="admin-v137-finance-tabs"><button class="active" data-finance-tab="balances">الأرصدة</button><button data-finance-tab="ledger">القيود</button><button data-finance-tab="settlements">السندات والتسويات</button><button data-finance-tab="withdrawals">طلبات السحب</button></nav>
      <section data-finance-panel="balances"><div class="admin-v137-finance-panel"><div class="admin-v137-finance-search"><input id="financeSearch" placeholder="ابحث باسم الحساب"><select id="financeRole"><option value="">كل الحسابات</option><option value="teacher">المدرسون</option><option value="library">المكتبات</option><option value="delegate">المندوبون</option><option value="admin">المنصة</option></select></div><div id="financeBalances" class="admin-v137-finance-list">${balanceCards()}</div></div></section>
      <section data-finance-panel="ledger" hidden><div class="admin-v137-finance-panel"><div class="row-actions"><button data-alin-click="AlinAdminFinance.exportLedger">تصدير CSV</button></div>${ledgerRows()}</div></section>
      <section data-finance-panel="settlements" hidden><div class="admin-v137-finance-panel">${settlementRows()}</div></section>
      <section data-finance-panel="withdrawals" hidden><div class="admin-v137-finance-panel">${withdrawals()}</div></section>
    </section>`;
    bind();return true;
  }

  function bind(){
    const tabs=[...document.querySelectorAll('[data-finance-tab]')];
    tabs.forEach(button=>button.addEventListener('click',()=>{
      tabs.forEach(item=>item.classList.toggle('active',item===button));
      document.querySelectorAll('[data-finance-panel]').forEach(panel=>panel.hidden=panel.dataset.financePanel!==button.dataset.financeTab);
    }));
    const filter=()=>{
      const q=(document.getElementById('financeSearch')?.value||'').trim().toLowerCase();
      const role=document.getElementById('financeRole')?.value||'';
      document.querySelectorAll('#financeBalances .admin-v137-party-card').forEach(card=>card.hidden=!((!q||card.dataset.search.includes(q))&&(!role||card.dataset.role===role)));
    };
    document.getElementById('financeSearch')?.addEventListener('input',filter);
    document.getElementById('financeRole')?.addEventListener('change',filter);
  }

  function csvEscape(value){return `"${String(value??'').replace(/"/g,'""')}"`}
  function exportLedger(){
    const rows=finance()?.canonicalLedger?.()||[];
    const csv='\ufeff'+[['الطلب','الإجمالي','المنصة','المدرس','المكتبة','المندوب','التاريخ'],...rows.map(row=>[row.order_number||row.order_id,row.total,row.admin||row.alin,row.teacher,row.library,row.delegate||row.courier,row.settled_at||row.created_at])].map(row=>row.map(csvEscape).join(',')).join('\n');
    const link=document.createElement('a');link.href=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));link.download=`alin-finance-${new Date().toISOString().slice(0,10)}.csv`;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);
  }

  window.renderFinanceAdmin=renderFinanceAdmin;
  window.AlinAdminFinance=Object.freeze({render:renderFinanceAdmin,exportLedger});
  window.AlinAdminModules?.register?.('finance',renderFinanceAdmin);
})();
