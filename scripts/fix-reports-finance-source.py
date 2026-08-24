#!/usr/bin/env python3
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
REPORTS=ROOT/'modules/admin/reports.js'
CONFIG=ROOT/'alin-config.js'
PAGES=[ROOT/'store-desktop.html',ROOT/'store-mobile.html',ROOT/'store-tablet.html']
TOKEN='4.2.0-stable-reports-ledger-20260825-0125'

text=REPORTS.read_text(encoding='utf-8')

old="const state={period:'month',from:'',to:'',kind:'all',q:''};"
new="const state={period:'all',from:'',to:'',kind:'all',q:''};\n  const finance=()=>window.AlinFinance;"
if old in text:
    text=text.replace(old,new,1)
elif "const state={period:'all'" not in text or 'const finance=()=>window.AlinFinance;' not in text:
    raise SystemExit('reports state anchor missing')

old="""    else if(state.period==='month')from=today.slice(0,8)+'01';
    else if(state.period==='custom'){from=state.from||'';to=state.to||today}
    return{from,to};
"""
new="""    else if(state.period==='month')from=today.slice(0,8)+'01';
    else if(state.period==='custom'){from=state.from||'';to=state.to||today}
    else if(state.period==='all'){from='';to=''}
    return{from,to};
"""
if old in text:
    text=text.replace(old,new,1)
elif "else if(state.period==='all'){from='';to=''}" not in text:
    raise SystemExit('reports dateRange anchor missing')

old="function profits(rows){return rows.reduce((a,o)=>{a.platform+=num(o.platform_profit||o.admin_profit||o.platform_amount);a.teacher+=num(o.teacher_profit||o.teacher_amount);a.library+=num(o.library_profit||o.library_amount);a.courier+=num(o.courier_profit||o.delivery_fee||o.courier_amount);return a},{platform:0,teacher:0,library:0,courier:0})}"
new="""function orderKeys(o){return[o?.id,o?.order_number,o?.order_no,o?.code].filter(v=>v!==null&&v!==undefined&&String(v)!=='').map(String)}
  function ledgerKeys(row){return[row?.order_id,row?.order_number].filter(v=>v!==null&&v!==undefined&&String(v)!=='').map(String)}
  function reportLedger(orderRows){
    const ledger=arr(finance()?.canonicalLedger?.());
    if(state.period==='all'&&state.kind==='all'&&!state.q)return ledger;
    const allowed=new Set(orderRows.flatMap(orderKeys));
    return ledger.filter(row=>ledgerKeys(row).some(key=>allowed.has(key)));
  }
  function financialTotals(rows){return rows.reduce((out,row)=>{out.sales+=num(row.total);out.platform+=num(row.admin||row.alin);out.teacher+=num(row.teacher||row.teacher_amount);out.library+=num(row.library||row.library_amount);out.courier+=num(row.delegate||row.courier||row.courier_amount);return out},{sales:0,platform:0,teacher:0,library:0,courier:0})}"""
if old in text:
    text=text.replace(old,new,1)
elif 'function reportLedger(orderRows)' not in text or 'function financialTotals(rows)' not in text:
    raise SystemExit('legacy reports profits anchor missing')

old="const rows=filteredOrders(),paid=paidOrders(rows),sales=paid.reduce((a,o)=>a+orderTotal(o),0),profit=profits(paid),cancelled=rows.filter(o=>statusKey(o.status)==='cancelled'),processing=rows.filter(o=>['new','processing','ready'].includes(statusKey(o.status)));"
new="const rows=filteredOrders(),paid=paidOrders(rows),ledger=reportLedger(rows),financial=financialTotals(ledger),sales=financial.sales,profit=financial,cancelled=rows.filter(o=>statusKey(o.status)==='cancelled'),processing=rows.filter(o=>['new','processing','ready'].includes(statusKey(o.status)));"
if old in text:
    text=text.replace(old,new,1)
elif 'ledger=reportLedger(rows)' not in text:
    raise SystemExit('reports render totals anchor missing')

text=text.replace("<span>${paid.length} طلب مكتمل</span>","<span>${ledger.length} قيد مالي مكتمل</span>")
text=text.replace("<span>حسب السجلات الحالية</span>","<span>من السجل المالي الرسمي</span>")
text=text.replace("<span>من الطلبات المكتملة</span>","<span>من السجل المالي الرسمي</span>")
text=text.replace("<span>رسوم وعمولات التوصيل</span>","<span>أجرة المندوب المحتسبة مالياً</span>")
text=text.replace("${moneyx(paid.length?sales/paid.length:0)}","${moneyx(ledger.length?sales/ledger.length:0)}")
text=text.replace("<span>متوسط الطلب المكتمل</span>","<span>متوسط القيود المالية المكتملة</span>")

REPORTS.write_text(text,encoding='utf-8')

cfg=CONFIG.read_text(encoding='utf-8')
cfg,count=re.subn(r"assetVersion:'[^']+'",f"assetVersion:'{TOKEN}'",cfg,count=1)
if count!=1: raise SystemExit('assetVersion anchor missing')
CONFIG.write_text(cfg,encoding='utf-8')

for page in PAGES:
    data=page.read_text(encoding='utf-8')
    data=re.sub(r'\?v=[A-Za-z0-9._:-]+',f'?v={TOKEN}',data)
    page.write_text(data,encoding='utf-8')

print('reports finance source unified; cache token',TOKEN)
