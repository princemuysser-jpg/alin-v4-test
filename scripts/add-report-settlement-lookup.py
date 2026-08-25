#!/usr/bin/env python3
from pathlib import Path

p=Path('modules/admin/reports.js')
text=p.read_text(encoding='utf-8')

state_old="const state={period:'all',from:'',to:'',kind:'all',q:''};"
state_new="const state={period:'all',from:'',to:'',kind:'all',q:'',partyRole:'teacher',partyId:''};"
if state_old in text:
    text=text.replace(state_old,state_new,1)
elif state_new not in text:
    raise SystemExit('reports state anchor missing')

anchor="  function financialTotals(rows){return rows.reduce((out,row)=>{out.sales+=num(row.total);out.platform+=num(row.admin||row.alin);out.teacher+=num(row.teacher||row.teacher_amount);out.library+=num(row.library||row.library_amount);out.courier+=num(row.delegate||row.courier||row.courier_amount);return out},{sales:0,platform:0,teacher:0,library:0,courier:0})}\n"
helper="""  function financialTotals(rows){return rows.reduce((out,row)=>{out.sales+=num(row.total);out.platform+=num(row.admin||row.alin);out.teacher+=num(row.teacher||row.teacher_amount);out.library+=num(row.library||row.library_amount);out.courier+=num(row.delegate||row.courier||row.courier_amount);return out},{sales:0,platform:0,teacher:0,library:0,courier:0})}
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
"""
if 'function settlementLookupHtml()' not in text:
    if anchor not in text: raise SystemExit('financial totals anchor missing')
    text=text.replace(anchor,helper,1)

if 'const settlementLookup=settlementLookupHtml();' not in text:
    old='    const table=rows.length?`<div class="admin-v143-table-wrap"'
    new='    const settlementLookup=settlementLookupHtml();\n    const table=rows.length?`<div class="admin-v143-table-wrap"'
    if old not in text: raise SystemExit('table anchor missing')
    text=text.replace(old,new,1)

if '${settlementLookup}<section class="admin-v143-grid">' not in text:
    old='</article></section><section class="admin-v143-grid">'
    new='</article></section>${settlementLookup}<section class="admin-v143-grid">'
    if old not in text: raise SystemExit('metrics grid anchor missing')
    text=text.replace(old,new,1)

if 'window.alinV143PartyFilter=' not in text:
    old="  window.alinV143ReportFilter=(k,v)=>{state[k]=v;if(k==='period'&&v!=='custom'){state.from='';state.to=''}render()};\n"
    new="  window.alinV143ReportFilter=(k,v)=>{state[k]=v;if(k==='period'&&v!=='custom'){state.from='';state.to=''}render()};\n  window.alinV143PartyFilter=(k,v)=>{state[k]=v;if(k==='partyRole')state.partyId='';render()};\n"
    if old not in text: raise SystemExit('filter anchor missing')
    text=text.replace(old,new,1)

p.write_text(text,encoding='utf-8')
print('reports settlement lookup integrated')
