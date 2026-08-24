#!/usr/bin/env python3
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]

# 1) Teacher delivery label correction becomes authoritative in teacher/finance.js.
p=ROOT/'modules/teacher/finance.js'
text=p.read_text(encoding='utf-8')
anchor="  function statusGroup(value){const key=String(value||'').toLowerCase();return done.has(key)?'done':cancelled.has(key)?'cancelled':'active'}\n"
helper="""  function statusGroup(value){const key=String(value||'').toLowerCase();return done.has(key)?'done':cancelled.has(key)?'cancelled':'active'}
  function teacherOrderDeliveryInfo(order){
    const fulfillment=String(order?.fulfillment_type||'').toLowerCase();
    const deliveryType=String(order?.delivery_type||'').toLowerCase();
    const courierId=order?.courier_id||order?.delegate_id||'';
    const byCourier=fulfillment==='home_delivery'||deliveryType==='courier'||Boolean(courierId);
    if(byCourier){
      const couriers=arr(window.db?.accounts?.couriers||window.db?.couriers);
      const courier=couriers.find(row=>same(row.id,courierId));
      return {kind:'courier',label:courier?.name?`التوصيل: مندوب — ${courier.name}`:'التوصيل: مندوب'};
    }
    const libraries=arr(window.db?.accounts?.libraries);
    const library=libraries.find(row=>same(row.id,order?.library_id));
    return {kind:'library',label:`الاستلام: مكتبة — ${library?.name||'-'}`};
  }
"""
if 'function teacherOrderDeliveryInfo(order)' not in text:
    if anchor not in text:
        raise SystemExit('teacher statusGroup anchor missing')
    text=text.replace(anchor,helper,1)
old="""    const libraries=arr(window.db?.accounts?.libraries);
    const cards=d.orders.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).map(order=>{
      const book=d.books.find(row=>same(row.id,order.item_id||order.booklet_id));
      const library=libraries.find(row=>same(row.id,order.library_id));
      const group=statusGroup(order.status);
      return `<article class=\"teacher-v154-order\" data-search=\"${escv(`${order.order_number||order.id} ${order.title||book?.title||''}`.toLowerCase())}\" data-status=\"${group}\" data-library=\"${escv(order.library_id||'')}\" data-date=\"${escv(dateOnly(order.created_at))}\"><div><h4>${escv(order.order_number||order.id)} — ${escv(order.title||book?.title||'ملزمة')}</h4><small>النسخ: ${Number(order.qty)||1} • المكتبة: ${escv(library?.name||'-')} • ${dateOnly(order.created_at)}</small></div><div class=\"teacher-v154-order-side\"><span class=\"teacher-v154-status ${group}\">${escv(statusText(order.status))}</span><b>${moneyv(order.total)} د.ع</b></div></article>`;
    }).join('')||'<div class=\"teacher-v154-empty\">لا توجد طلبات مرتبطة بملازمك.</div>';
"""
new="""    const cards=d.orders.slice().sort((a,b)=>String(b.created_at||'').localeCompare(String(a.created_at||''))).map(order=>{
      const book=d.books.find(row=>same(row.id,order.item_id||order.booklet_id));
      const group=statusGroup(order.status);
      const delivery=teacherOrderDeliveryInfo(order);
      return `<article class=\"teacher-v154-order\" data-search=\"${escv(`${order.order_number||order.id} ${order.title||book?.title||''}`.toLowerCase())}\" data-status=\"${group}\" data-delivery=\"${delivery.kind}\" data-date=\"${escv(dateOnly(order.created_at))}\"><div><h4>${escv(order.order_number||order.id)} — ${escv(order.title||book?.title||'ملزمة')}</h4><small>النسخ: ${Number(order.qty)||1} • ${escv(delivery.label)} • ${dateOnly(order.created_at)}</small></div><div class=\"teacher-v154-order-side\"><span class=\"teacher-v154-status ${group}\">${escv(statusText(order.status))}</span><b>${moneyv(order.total)} د.ع</b></div></article>`;
    }).join('')||'<div class=\"teacher-v154-empty\">لا توجد طلبات مرتبطة بملازمك.</div>';
"""
if old in text:
    text=text.replace(old,new,1)
elif 'const delivery=teacherOrderDeliveryInfo(order);' not in text:
    raise SystemExit('teacher order render block missing')
p.write_text(text,encoding='utf-8')

# 2) Persisted courier_fee remains authoritative, but inside finance source itself.
p=ROOT/'core/finance-runtime.js'
text=p.read_text(encoding='utf-8')
old="""    const delegate=delivery==='delegate'?Math.min(deliveryFee,Math.max(0,Math.round(deliveryFee*rate.delegate/100))):0;
    const admin=Math.max(0,total-teacher-library-delegate);
    const collectorId=delivery==='library'?(order?.library_id||order?.pickup_library_id||order?.assigned_library_id||''):(order?.delegate_id||order?.courier_id||'');
    const collectorProfit=delivery==='library'?library:delegate;
"""
new="""    const calculatedDelegate=delivery==='delegate'?Math.min(deliveryFee,Math.max(0,Math.round(deliveryFee*rate.delegate/100))):0;
    const rawCourierFee=order?.courier_fee;
    const hasCourierFee=rawCourierFee!==null&&rawCourierFee!==undefined&&String(rawCourierFee).trim()!=='';
    const parsedCourierFee=hasCourierFee?Number(rawCourierFee):NaN;
    const delegate=delivery==='delegate'&&hasCourierFee&&Number.isFinite(parsedCourierFee)?Math.max(0,Math.round(parsedCourierFee)):calculatedDelegate;
    const admin=Math.max(0,total-teacher-library-delegate);
    const collectorId=delivery==='library'?(order?.library_id||order?.pickup_library_id||order?.assigned_library_id||''):(order?.delegate_id||order?.courier_id||'');
    const collectorProfit=delivery==='library'?library:delegate;
"""
if old in text:
    text=text.replace(old,new,1)
elif 'const rawCourierFee=order?.courier_fee;' not in text:
    raise SystemExit('finance delegate formula anchor missing')
p.write_text(text,encoding='utf-8')

# 3) Config only bootstraps things that are not already in role runtime.
p=ROOT/'alin-config.js'
text=p.read_text(encoding='utf-8')
markers=[
    '/* One admin courier hub: couriers + areas + delivery orders + settlements. */',
    '/* Teacher orders: show the real delivery method (courier/library) in the orders tab. */',
    '/* ALIN v4.3.0 courier-fee compatibility. */',
    '/* ALIN v4.3.0 delivery pricing UI bridge. */',
]
for marker in markers:
    if marker not in text:
        continue
    start=text.index(marker)
    end=text.find('\n})();',start)
    if end<0:
        raise SystemExit(f'config block end missing: {marker}')
    end+=len('\n})();')
    while end<len(text) and text[end] in '\r\n':
        end+=1
    text=text[:start]+text[end:]
p.write_text(text,encoding='utf-8')

# Remove obsolete display-only patch now that its logic is in the source renderer.
obsolete=ROOT/'modules/teacher/order-delivery-label-fix.js'
if obsolete.exists():
    obsolete.unlink()

# Stable lock policy file.
(ROOT/'STABLE_LOCK.md').write_text('''# ALIN v4.2 Stable Lock

The current baseline is feature-frozen.

Allowed changes only:
- verified bug fixes
- security fixes
- performance fixes that preserve behavior
- responsive/UI corrections that do not change financial or order semantics

Protected invariants:
- student delivery fee and courier fee remain independent
- persisted courier_fee is authoritative for courier earnings when present
- settlement history remains append-only; balances are derived from ledger/settlements
- teacher/library/courier/admin behavior remains available on desktop, tablet and mobile
- generated runtimes are rebuilt only from authoritative source modules

No new feature is merged while the stable lock is active.
''',encoding='utf-8')

# Stable financial/routing smoke test committed with the baseline.
(ROOT/'scripts/stable-lock-smoke.js').write_text(r'''\
'use strict';
const fs=require('fs');
const vm=require('vm');
const assert=require('assert');
global.window={};window.window=window;window.current={role:'admin',id:'admin'};
window.db={settings:{teacher_profit_percent:50,library_profit_percent:30,delegate_profit_percent:30},booklets:[{id:'B1',teacher_id:'T1',teacher_share_percent:50,library_share_percent:30}],orders:[],ledger:[],settlements:[],withdrawals:[],accounts:{teachers:[],libraries:[],couriers:[]},couriers:[]};
vm.runInThisContext(fs.readFileSync('core/finance-runtime.js','utf8'),{filename:'core/finance-runtime.js'});
assert(window.AlinFinance,'finance runtime did not install');
const courierOrder={id:'O1',kind:'booklet',item_id:'B1',total:6000,delivery_fee:2000,courier_fee:1500,fulfillment_type:'home_delivery',courier_id:'C1'};
const a=window.AlinFinance.shares(courierOrder);
assert.strictEqual(a.delivery,'delegate');assert.strictEqual(a.deliveryFee,2000);assert.strictEqual(a.delegate,1500);assert.strictEqual(a.merchandise,4000);assert.strictEqual(a.teacher,2000);assert.strictEqual(a.library,0);assert.strictEqual(a.admin,2500);assert.strictEqual(a.debt,4500);
const noPersisted={...courierOrder,id:'O2'};delete noPersisted.courier_fee;const b=window.AlinFinance.shares(noPersisted);assert.strictEqual(b.delegate,600);
const libraryOrder={id:'O3',kind:'booklet',item_id:'B1',total:4000,delivery_fee:0,fulfillment_type:'library',library_id:'L1'};const c=window.AlinFinance.shares(libraryOrder);assert.strictEqual(c.delivery,'library');assert.strictEqual(c.teacher,2000);assert.strictEqual(c.library,1200);assert.strictEqual(c.delegate,0);assert.strictEqual(c.admin,800);
const teacher=fs.readFileSync('modules/teacher/finance.js','utf8');assert(teacher.includes('function teacherOrderDeliveryInfo(order)'));assert(teacher.includes('التوصيل: مندوب'));assert(teacher.includes('الاستلام: مكتبة'));assert(!teacher.includes('• المكتبة: ${escv(library?.name'));
const config=fs.readFileSync('alin-config.js','utf8');for(const x of ['loadAlinCourierAdminHub','loadTeacherOrderDeliveryFix','installCourierFeeDisplayCompatibility','installDeliveryPricingUiBridge'])assert(!config.includes(x),`duplicate runtime loader remains: ${x}`);
console.log('ALIN v4.2 stable-lock smoke tests passed');
'''.lstrip('\\'),encoding='utf-8')

# Cache token for the frozen baseline on all device pages.
token='4.2.0-stable-lock-20260825'
p=ROOT/'alin-config.js'
text=p.read_text(encoding='utf-8')
text,n=re.subn(r"assetVersion:'[^']+'",f"assetVersion:'{token}'",text,count=1)
if n!=1:
    raise SystemExit('assetVersion not found')
p.write_text(text,encoding='utf-8')
for name in ('store-desktop.html','store-mobile.html','store-tablet.html'):
    p=ROOT/name
    page=p.read_text(encoding='utf-8')
    page=re.sub(r'\?v=[A-Za-z0-9._:-]+',f'?v={token}',page)
    p.write_text(page,encoding='utf-8')

print('ALIN v4.2 stable-lock source consolidation complete')
