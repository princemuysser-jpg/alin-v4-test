// === admin/reports.js ===
/* ALIN v4.2 Stable Lock — reports financial metrics use the same canonical ledger as Finance. */
(function(){
  'use strict';
  const escx=v=>typeof esc==='function'?esc(v):String(v??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  const moneyx=v=>typeof money==='function'?money(v):Number(v||0).toLocaleString(window.AlinI18n?.locale?.()||'ar-IQ');
  const arr=v=>Array.isArray(v)?v:[];
  const num=v=>Number.isFinite(Number(v))?Number(v):0;
  const state={period:'all',from:'',to:'',kind:'all',q:'',partyRole:'teacher',partyId:''};
  const finance=()=>window.AlinFinance;
  function dbx(){try{return window.db||db||{}}catch(_){return window.db||{}}}
  function orderDate(o){return String(o?.created_at||o?.date||o?.updated_at||'').slice(0,10)}
  function statusKey(v){const s=String(v||'').toLowerCase();if(['delivered','completed','done','received','settled','تم التسليم'].includes(s))return'done';if(['cancelled','canceled','refunded','rejected'].includes(s))return'cancelled';if(['ready'].includes(s))return'ready';if(['printing','processing','preparing'].includes(s))return'processing';return'new'}
  function statusLabel(v){return({done:'مكتمل',cancelled:'ملغي',ready:'جاهز',processing:'قيد التنفيذ',new:'جديد'})[statusKey(v)]}
  function itemKind(o){const k=String(o?.kind||o?.item_type||o?.type||'').toLowerCase();return k.includes('book')||k==='booklet'?'booklet':'product'}
  function orderQty(o){return Math.max(1,num(o?.qty||o?.quantity||1))}
  function orderTotal(o){const explicit=num(o?.total||o?.total_amount||o?.grand_total||o?.amount);return explicit||num(o?.price||o?.unit_price)*orderQty(o)}
  function dateRange(){
    const now=new Date(),today=now.toISOString().slice(0,10);let from='',to=today;
    if(state.period==='today')from=today;
    else if(state.period==='week'){const d=new Date(now);d.setDate(d.getDate()-6);from=d.toISOString().slice(0,10)}
    else if(state.period==='month')from=today.slice(0,8)+'01';
    else if(state.period==='custom'){from=state.from||'';to=state.to||today}
    else if(state.period==='all'){from='';to=''}
    return{from,to};
  }
  function accountsByRole(role){const d=dbx();return arr(d.accounts?.[role+'s']||d.accounts?.[role]||d[role+'s'])}
  function accountName(role,id){if(!id)return'غير محدد';const rows=accountsByRole(role);const x=rows.find(a=>String(a.id)===String(id));return x?.name||x?.title||x?.username||'غير محدد'}
  function filteredOrders(){const d=dbx(),range=dateRange();return arr(d.orders).filter(o=>{const dt=orderDate(o),kind=itemKind(o),txt=`${o.order_number||o.order_no||o.code||o.id||''} ${o.student_name||o.customer_name||''} ${o.title||o.item_title||''}`.toLowerCase();return(!range.from||dt>=range.from)&&(!range.to||dt<=range.to)&&(state.kind==='all'||kind===state.kind)&&(!state.q||txt.includes(state.q.toLowerCase()))}).sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||'')))}
  function orderKeys(o){return[o?.id,o?.order_number,o?.order_no,o?.code].filter(v=>v!==null&&v!==undefined&&String(v)!=='').map(String)}
  function ledgerKeys(row){return[row?.order_id,row?.order_number].filter(v=>v!==null&&v!==undefined&&String(v)!=='').map(String)}
  function reportLedger(orderRows){
    const ledger=arr(finance()?.canonicalLedger?.());
    if(state.period==='all'&&state.kind==='all'&&!state.q)return ledger;
    const allowed=new Set(orderRows.flatMap(orderKeys));
    return ledger.filter(row=>ledgerKeys(row).some(key=>allowed.has(key)));
  }
  function paidOrders(orderRows,ledgerRows){const paidKeys=new Set(ledgerRows.flatMap(ledgerKeys));return orderRows.filter(order=>orderKeys(order).some(key=>paidKeys.has(key)))}
  function financialTotals(rows){return rows.reduce((out,row)=>{out.sales+=num(row.total);out.platform+=num(row.admin||row.alin);out.teacher+=num(row.teacher||row.teacher_amount);out.library+=num(row.library||row.library_amount);out.courier+=num(row.delegate||row.courier||row.courier_amount);return out},{sales:0,platform:0,teacher:0,library:0,courier:0})}
  function settlementParties(role){
    const d=dbx(),accounts=d.accounts||{};
    if(role==='teacher')return arr(accounts.teachers);
    if(role==='library')return arr(accounts.libraries);
    return arr(d.delegates||accounts.couriers||d.couriers);
  }
  function partyOptionName(row){return row?.name||row?.title||row?.username||String(row?.id||'حساب')}
  function settlementLookupHtml(){
    const role=state.partyRole||'teacher',rows=settlementParties(role).slice().sort((a,b)=>partyOptionName(a).localeCompare(partyOptionName(b),'ar'));
    if(state.partyId&&!rows.some(row=>String(row.id)===String(state.partyId)))state.partyId='';
    const options=rows.map(row=>`<option value="${escx(row.id)}" ${String(state.partyId)===String(row.id)?'selected':''}>${escx(partyOptionName(row))}</option>`).join('');
    let details='<div class="admin-v143-empty">اختر الحساب حتى تظهر أرقامه الحالية للتسوية.</div>';
    if(state.partyId){
      const row=rows.find(item=>String(item.id)===String(state.partyId)),name=partyOptionName(row||{id:state.partyId});
      if(role==='teacher'){
        const s=finance()?.teacherSummary?.(state.partyId)||finance()?.partySummary?.('teacher',state.partyId)||{};
        details=`<div class="admin-v143-metrics"><article class="admin-v143-metric"><small>إجمالي أرباح ${escx(name)}</small><strong>${moneyx(s.earned)} د.ع</strong></article><article class="admin-v143-metric green"><small>المسدد للمدرس</small><strong>${moneyx(s.paid)} د.ع</strong></article><article class="admin-v143-metric gold"><small>المتبقي للتسديد</small><strong>${moneyx(s.remaining)} د.ع</strong></article></div>`;
      }else if(role==='library'){
        const s=finance()?.librarySummary?.(state.partyId)||{};
        details=`<div class="admin-v143-metrics"><article class="admin-v143-metric"><small>ربح المكتبة — ${escx(name)}</small><strong>${moneyx(s.libraryProfit??s.profit)} د.ع</strong></article><article class="admin-v143-metric green"><small>المستلم من ذمة المكتبة</small><strong>${moneyx(s.settled)} د.ع</strong></article><article class="admin-v143-metric red"><small>الذمة المتبقية للإدارة</small><strong>${moneyx(s.remaining??s.debtRemaining)} د.ع</strong></article></div>`;
      }else{
        const s=finance()?.delegateSummary?.(state.partyId)||{};
        details=`<div class="admin-v143-metrics"><article class="admin-v143-metric"><small>ربح المندوب — ${escx(name)}</small><strong>${moneyx(s.earnings??s.earned)} د.ع</strong></article><article class="admin-v143-metric green"><small>المستلم من المندوب</small><strong>${moneyx(s.settled??s.paid)} د.ع</strong></article><article class="admin-v143-metric red"><small>الذمة المتبقية للإدارة</small><strong>${moneyx(s.debt??s.remaining)} د.ع</strong></article></div>`;
      }
    }
    return `<article class="admin-v143-card"><div class="admin-v143-card-head"><div><h3>كشف حساب سريع للتسوية</h3><small>الأرقام الحالية من النظام المالي الرسمي ولا تتأثر بفلتر فترة التقارير.</small></div></div><section class="admin-v143-toolbar"><select data-alin-change="alinV143PartyFilter" data-alin-change-arg0="partyRole" data-alin-change-arg1-source="value"><option value="teacher" ${role==='teacher'?'selected':''}>المدرسون</option><option value="library" ${role==='library'?'selected':''}>المكتبات</option><option value="delegate" ${role==='delegate'?'selected':''}>المندوبون</option></select><select data-alin-change="alinV143PartyFilter" data-alin-change-arg0="partyId" data-alin-change-arg1-source="value"><option value="">اختر الحساب</option>${options}</select></section>${details}</article>`;
  }
  function titleOf(o){return o.title||o.item_title||o.product_name||o.booklet_name||(itemKind(o)==='booklet'?'ملزمة':'منتج')}
  function rankBy(rows,keyFn,labelFn){const map=new Map();rows.forEach(o=>{const key=String(keyFn(o)||'unknown');const old=map.get(key)||{key,label:labelFn(o),qty:0,total:0};old.qty+=orderQty(o);old.total+=orderTotal(o);map.set(key,old)});return[...map.values()].sort((a,b)=>b.qty-a.qty||b.total-a.total)}
  function bestLibrary(rows){return rankBy(rows,o=>o.library_id||o.pickup_library_id,o=>accountName('library',o.library_id||o.pickup_library_id))}
  function bestTeacher(rows){return rankBy(rows,o=>o.teacher_id,o=>accountName('teacher',o.teacher_id))}
  function bestCourier(rows){return rankBy(rows,o=>o.courier_id||o.delegate_id,o=>accountName('courier',o.courier_id||o.delegate_id))}
  function rankHtml(rows,empty='لا توجد بيانات كافية'){if(!rows.length)return`<div class="admin-v143-empty">${empty}</div>`;return`<div class="admin-v143-rank-list">${rows.slice(0,5).map((r,i)=>`<div class="admin-v143-rank"><em>${i+1}</em><div><b>${escx(r.label||'غير محدد')}</b><small>${r.qty} قطعة أو نسخة</small></div><strong>${moneyx(r.total)} د.ع</strong></div>`).join('')}</div>`}
  function ensureButton(){const tabs=document.querySelector('#adminPage .admin-tabs');if(!tabs)return;let btn=tabs.querySelector('button[data-admin-tab="reports"]');if(!btn){btn=document.createElement('button');btn.type='button';btn.dataset.adminTab='reports';btn.setAttribute('data-alin-click','adminTab');btn.setAttribute('data-alin-click-arg0','reports');const settings=tabs.querySelector('button[data-admin-tab="settings"]');tabs.insertBefore(btn,settings||null)}btn.textContent='التقارير'}
  function markTab(){document.querySelectorAll('#adminPage .admin-tabs button').forEach(b=>b.classList.toggle('active-admin-tab',b.dataset.adminTab==='reports'))}
  function render(){
    ensureButton();markTab();window.activeAdminTab='reports';const root=document.getElementById('adminContent');if(!root)return;
    const rows=filteredOrders(),ledger=reportLedger(rows),paid=paidOrders(rows,ledger),financial=financialTotals(ledger),sales=financial.sales,profit=financial,cancelled=rows.filter(o=>statusKey(o.status)==='cancelled'),processing=rows.filter(o=>['new','processing','ready'].includes(statusKey(o.status)));
    const booklets=rankBy(paid.filter(o=>itemKind(o)==='booklet'),o=>o.item_id||o.booklet_id||titleOf(o),o=>titleOf(o));
    const products=rankBy(paid.filter(o=>itemKind(o)==='product'),o=>o.item_id||o.product_id||titleOf(o),o=>titleOf(o));
    const libraries=bestLibrary(paid),teachers=bestTeacher(paid),couriers=bestCourier(paid);
    const counts={new:0,processing:0,ready:0,done:0,cancelled:0};rows.forEach(o=>counts[statusKey(o.status)]++);const max=Math.max(1,...Object.values(counts));
    const statusHtml=Object.entries(counts).map(([k,v])=>`<div class="admin-v143-status"><span>${({new:'جديد',processing:'قيد التنفيذ',ready:'جاهز',done:'مكتمل',cancelled:'ملغي'})[k]}</span><div class="admin-v143-bar"><i style="width:${Math.round(v/max*100)}%"></i></div><b>${v}</b></div>`).join('');
    const settlementLookup=settlementLookupHtml();
    const table=rows.length?`<div class="admin-v143-table-wrap"><table class="admin-v143-table"><thead><tr><th>رقم الطلب</th><th>الطالب</th><th>العنصر</th><th>النوع</th><th>الجهة</th><th>الحالة</th><th>التاريخ</th><th>المبلغ</th></tr></thead><tbody>${rows.slice(0,300).map(o=>`<tr><td>#${escx(o.order_number||o.order_no||o.code||o.id||'—')}</td><td>${escx(o.student_name||o.customer_name||'—')}</td><td>${escx(titleOf(o))}</td><td>${itemKind(o)==='booklet'?'ملزمة':'منتج'}</td><td>${escx(accountName('library',o.library_id||o.pickup_library_id)||accountName('courier',o.courier_id||o.delegate_id))}</td><td><span class="admin-v143-status-pill ${statusKey(o.status)}">${statusLabel(o.status)}</span></td><td>${escx(orderDate(o)||'—')}</td><td>${moneyx(orderTotal(o))} د.ع</td></tr>`).join('')}</tbody></table></div>`:'<div class="admin-v143-empty">لا توجد طلبات ضمن الفترة المختارة.</div>';
    root.innerHTML=`<section class="admin-v143-reports"><header class="admin-v143-head"><div><h2>التقارير والتحليلات</h2><p>ملخص المبيعات والأرباح وأفضل العناصر والشركاء حسب الفترة المختارة.</p></div><div class="admin-v143-head-icon">📊</div></header><section class="admin-v143-toolbar"><input value="${escx(state.q)}" placeholder="بحث برقم الطلب أو اسم الطالب أو العنصر" data-alin-input="alinV143ReportFilter" data-alin-input-arg0="q" data-alin-input-arg1-source="value"><select data-alin-change="alinV143ReportFilter" data-alin-change-arg0="period" data-alin-change-arg1-source="value"><option value="all" ${state.period==='all'?'selected':''}>كل الفترات</option><option value="today" ${state.period==='today'?'selected':''}>اليوم</option><option value="week" ${state.period==='week'?'selected':''}>آخر 7 أيام</option><option value="month" ${state.period==='month'?'selected':''}>هذا الشهر</option><option value="custom" ${state.period==='custom'?'selected':''}>فترة مخصصة</option></select><input type="date" value="${escx(state.from)}" data-alin-change="alinV143ReportFilter" data-alin-change-arg0="from" data-alin-change-arg1-source="value" ${state.period==='custom'?'':'disabled'}><input type="date" value="${escx(state.to)}" data-alin-change="alinV143ReportFilter" data-alin-change-arg0="to" data-alin-change-arg1-source="value" ${state.period==='custom'?'':'disabled'}><select data-alin-change="alinV143ReportFilter" data-alin-change-arg0="kind" data-alin-change-arg1-source="value"><option value="all" ${state.kind==='all'?'selected':''}>كل الأنواع</option><option value="booklet" ${state.kind==='booklet'?'selected':''}>الملازم</option><option value="product" ${state.kind==='product'?'selected':''}>المنتجات</option></select><button class="secondary" data-alin-click="alinV143ExportReports">تصدير Excel</button><button class="gold" data-alin-click="print">طباعة / PDF</button></section><section class="admin-v143-metrics"><article class="admin-v143-metric gold"><small>إجمالي المبيعات</small><strong>${moneyx(sales)} د.ع</strong><span>${ledger.length} قيد مالي مكتمل</span></article><article class="admin-v143-metric"><small>عدد الطلبات</small><strong>${rows.length}</strong><span>${processing.length} طلب قيد المتابعة</span></article><article class="admin-v143-metric green"><small>حصة المنصة</small><strong>${moneyx(profit.platform)} د.ع</strong><span>من السجل المالي الرسمي</span></article><article class="admin-v143-metric red"><small>الطلبات الملغاة</small><strong>${cancelled.length}</strong><span>${rows.length?Math.round(cancelled.length/rows.length*100):0}% من النتائج</span></article><article class="admin-v143-metric"><small>أرباح المدرسين</small><strong>${moneyx(profit.teacher)} د.ع</strong><span>من السجل المالي الرسمي</span></article><article class="admin-v143-metric"><small>أرباح المكتبات</small><strong>${moneyx(profit.library)} د.ع</strong><span>من السجل المالي الرسمي</span></article><article class="admin-v143-metric"><small>أرباح المندوبين</small><strong>${moneyx(profit.courier)} د.ع</strong><span>أجرة المندوب المحتسبة مالياً</span></article><article class="admin-v143-metric"><small>متوسط الطلب</small><strong>${moneyx(ledger.length?sales/ledger.length:0)} د.ع</strong><span>متوسط القيود المالية المكتملة</span></article></section>${settlementLookup}<section class="admin-v143-grid"><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل الملازم</h3><small>حسب عدد النسخ</small></div>${rankHtml(booklets,'لا توجد مبيعات ملازم ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المنتجات</h3><small>حسب الكمية</small></div>${rankHtml(products,'لا توجد مبيعات منتجات ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المكتبات</h3><small>حسب المبيعات</small></div>${rankHtml(libraries,'لا توجد بيانات مكتبات ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المدرسين</h3><small>حسب مبيعات الملازم</small></div>${rankHtml(teachers,'لا توجد بيانات مدرسين ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>أفضل المندوبين</h3><small>حسب الطلبات المسلّمة</small></div>${rankHtml(couriers,'لا توجد بيانات مندوبين ضمن الفترة.')}</article><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>حالات الطلبات</h3><small>توزيع النتائج</small></div><div class="admin-v143-statuses">${statusHtml}</div></article></section><article class="admin-v143-card"><div class="admin-v143-card-head"><h3>تفاصيل الطلبات</h3><small>يتم عرض أول 300 طلب مطابق</small></div>${table}</article></section>`;
  }
  window.alinV143ReportFilter=(k,v)=>{state[k]=v;if(k==='period'&&v!=='custom'){state.from='';state.to=''}render()};
  window.alinV143PartyFilter=(k,v)=>{state[k]=v;if(k==='partyRole')state.partyId='';render()};
  window.alinV143ExportReports=()=>{const rows=filteredOrders();const data=[['رقم الطلب','الطالب','العنصر','النوع','المكتبة','المندوب','الحالة','التاريخ','الكمية','المبلغ'],...rows.map(o=>[o.order_number||o.order_no||o.code||o.id||'',o.student_name||o.customer_name||'',titleOf(o),itemKind(o)==='booklet'?'ملزمة':'منتج',accountName('library',o.library_id||o.pickup_library_id),accountName('courier',o.courier_id||o.delegate_id),statusLabel(o.status),orderDate(o),orderQty(o),orderTotal(o)])];const csv='\ufeff'+data.map(r=>r.map(v=>'"'+String(v??'').replace(/"/g,'""')+'"').join(',')).join('\n');const blob=new Blob([csv],{type:'text/csv;charset=utf-8'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='alin-reports-'+new Date().toISOString().slice(0,10)+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1500)};
  function install(){ensureButton();window.AlinAdminModules?.register?.('reports',render)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install);else install();
})();
