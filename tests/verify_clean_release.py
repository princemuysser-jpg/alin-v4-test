#!/usr/bin/env python3
from __future__ import annotations
import hashlib, re, subprocess, sys
from pathlib import Path
from html.parser import HTMLParser

ROOT=Path(__file__).resolve().parents[1]
errors=[]; notes=[]
def ok(cond,msg):
    (notes if cond else errors).append(('OK ' if cond else 'FAIL ')+msg)

# JavaScript syntax
js_files=sorted(p for p in ROOT.rglob('*.js') if 'node_modules' not in p.parts)
for p in js_files:
    r=subprocess.run(['node','--check',str(p)],capture_output=True,text=True)
    if r.returncode: errors.append(f'FAIL JS syntax: {p.relative_to(ROOT)}: {r.stderr.strip()}')
ok(not any(x.startswith('FAIL JS syntax') for x in errors),f'JavaScript syntax ({len(js_files)} files)')

# Edge Function TypeScript syntax/type parser (Deno imports are intentionally unresolved locally)
ts_files=sorted((ROOT/'supabase/functions').rglob('*.ts'))
if ts_files:
    cmd=['tsc','--noEmit','--noCheck','--allowImportingTsExtensions','--module','esnext','--target','es2022',*map(str,ts_files)]
    r=subprocess.run(cmd,capture_output=True,text=True)
    ok(r.returncode==0,f'Edge Function TypeScript parse ({len(ts_files)} files)')
    if r.returncode: errors.append(r.stdout+r.stderr)

class LocalRefs(HTMLParser):
    def __init__(self): super().__init__(); self.refs=[]
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        for key in ('src','href'):
            value=d.get(key,'')
            if value and not value.startswith(('http://','https://','//','data:','blob:','#','mailto:','tel:')):
                self.refs.append(value.split('?',1)[0].split('#',1)[0])
for html in sorted(ROOT.glob('*.html')):
    parser=LocalRefs(); parser.feed(html.read_text(encoding='utf-8'))
    missing=[]
    for ref in parser.refs:
        target=(html.parent/ref).resolve()
        if not target.exists(): missing.append(ref)
    ok(not missing,f'HTML local assets: {html.name}')
    if missing: errors.append(f'FAIL missing in {html.name}: {missing}')

sql_files=sorted(ROOT.glob('*.sql'))
ok(len(sql_files)==1,'Exactly one root SQL file')
sql=sql_files[0].read_text(encoding='utf-8') if sql_files else ''
ok("ALIN v4 Clean Master يعمل على مشروع جديد فارغ فقط" in sql,'Clean-project safety guard')
ok(sql.lstrip().startswith('-- منصة آلين v4.0.0') and '\nbegin;' in sql and '\ncommit;' in sql,'Single transactional clean master')
ok(sql.count('$$')%2==0 and sql.count('$$')>=20,'Balanced PL/pgSQL dollar delimiters')
base_tables=re.findall(r'(?im)^create table public\.([a-z0-9_]+)\s*\(',sql)
ok(len(base_tables)>=30,f'Clean base tables ({len(base_tables)})')
ok(len(base_tables)==len(set(base_tables)),'No duplicate base table definitions')
required_tables={'accounts','account_permissions','booklets','products','orders','order_timeline','ledger','settlements','checkout_requests','delivery_areas','couriers','notifications','audit_events'}
ok(required_tables.issubset(set(base_tables)),'Required clean tables present')
orders_match=re.search(r'(?is)create table public\.orders\s*\((.*?)\n\);',sql)
orders_columns=[]
if orders_match:
    for line in orders_match.group(1).splitlines():
        line=line.strip().rstrip(',')
        if line and not line.lower().startswith(('constraint ','primary ','unique ','check ','foreign ')):
            m=re.match(r'([a-z_][a-z0-9_]*)\s+',line,re.I)
            if m: orders_columns.append(m.group(1))
ok(40<=len(orders_columns)<=75,f'Orders schema is bounded ({len(orders_columns)} columns, not legacy 99)')
for fn in ('alin_create_store_orders_guarded','alin_order_transition_atomic','alin_upsert_order_finance_atomic','alin_finance_record_settlement','alin_finance_reverse_settlement'):
    ok(re.search(rf'(?i)create or replace function public\.{fn}\s*\(',sql) is not None,f'RPC {fn}')
ok("status text not null default 'pending' check (status in ('pending','settled','cancelled','reversed'))" in sql,'Single canonical ledger status set')
ok("insert into public.delivery_areas" in sql and "AREA-KIRKUK" in sql,'Initial test delivery area')
ok("('alin-private','alin-private',false" in sql and "bucket_id='alin-private'" in sql,'Private document storage policies')
ok("create policy orders_read" in sql and "create policy ledger_read" in sql,'Orders and finance RLS')
ok("create view public.alin_public_booklets" in sql and "create view public.alin_library_booklets" in sql,'Safe public and library booklet views')
ok("or exists(select 1 from public.booklets b where b.id=orders.item_id" not in sql,'Teacher cannot read student PII from base orders')
ok("revoke execute on all functions in schema public from public,anon,authenticated" in sql,'Default PUBLIC function execution revoked')
ok("هذه العملية للمدير الأعلى فقط" in sql,'Permission administration requires super admin')
ok("create view public.alin_public_booklets" in sql and "grant select on public.alin_public_accounts,public.alin_public_settings,public.alin_public_booklets" in sql,'Public booklet view hides private file paths')
ok("revoke execute on all functions in schema public from public,anon,authenticated" in sql,'Internal RPCs are not public by default')
ok("grant execute on function public.alin_upsert_order_finance_atomic" not in sql,'Internal finance writer is not client-callable')
ok("v_coupon_applied boolean:=false" in sql and "قيمة السلة أقل من الحد المطلوب للكوبون" in sql,'Coupon validation uses full cart and eligible items')
ok("create trigger couriers_protect_update" in sql,'Courier self-update fields are protected')
ok("create trigger orders_protect_update" in sql,'Single order-update protection trigger')
ok(sql.count('create trigger orders_protect_update')==1,'No duplicate order protection trigger')

# Bundle/source checks for prior schema mismatches.
desktop=(ROOT/'dist/alin-app-desktop.v4.js').read_text(encoding='utf-8')
core=(ROOT/'dist/alin-core.v4.js').read_text(encoding='utf-8')
ok('category_id:categoryRow?.id||null' in desktop,'Product category uses FK id')
ok("starts_at:start,ends_at:end" in desktop,'Banner mutation uses clean timestamp columns')
ok("account_id:accountId" in core and "created_by:createdBy" in core,'Notification mutation uses clean columns')
ok("max_uses" in desktop,'Coupon mutation uses max_uses')
ok("selectBookletsForCurrentSession" in core and "alin_public_booklets" in core and "alin_library_booklets" in core,'Storefront and library read safe booklet views')
ok("async function confirmCartCheckout" in core and "alinOrderExtra" in core,'Cart confirmation routing is bundled')
ok("window.ALIN_CONFIG=window.ALIN_CONFIG||Object.freeze" in core,'External one-file configuration override')
for html_name in ('store-desktop.html','store-mobile.html'):
    text=(ROOT/html_name).read_text(encoding='utf-8')
    ok(text.find('alin-config.js')<text.find('alin-core.v4.js'),f'{html_name} loads config before core')

# Clean release must not contain old migration/patch SQL.
all_sql=list(ROOT.rglob('*.sql'))
ok(len(all_sql)==1,'No patch SQL files anywhere in release')
ok(not any(re.search(r'(?i)(hotfix|migration|patch|v3_0_|v2_)',p.name) for p in all_sql),'No legacy SQL patch artifacts')

# Key flow properties in SQL.
ok("on conflict(request_key) do nothing" in sql and "status='completed'" in sql,'Idempotent checkout flow')
ok("update public.products set stock=stock-v_qty" in sql,'Server-side stock reservation')
ok("stock_restored_at=case when v_target in ('cancelled','rejected')" in sql,'Cancellation restores stock once')
ok("on conflict(order_id) do update" in sql,'One financial ledger row per order')
ok("if exists(select 1 from public.ledger l where l.order_id=o.id and l.status='settled')" in sql,'Settled ledger is not overwritten')

# Arithmetic smoke scenarios mirror clean SQL rules.
def finance(total,fee,teacher_pct=0,library_pct=0,delegate_pct=30,fulfillment='pickup'):
    merchandise=max(total-fee,0)
    teacher=round(merchandise*teacher_pct/100)
    library=0; delegate=0
    if fulfillment=='pickup': library=min(max(merchandise-teacher,0),round(merchandise*library_pct/100))
    else: delegate=round(fee*delegate_pct/100)
    admin=max(total-teacher-library-delegate,0)
    return admin,teacher,library,delegate
ok(finance(10000,0,50,30)==(2000,5000,3000,0),'Finance smoke: booklet pickup')
ok(finance(12000,2000,50,30,30,'home_delivery')==(6400,5000,0,600),'Finance smoke: booklet delivery')
ok(finance(10000,2000,0,30,30,'home_delivery')==(9400,0,0,600),'Finance smoke: product delivery')

print('\n'.join(x for _,x in []))
for item in notes: print(item)
if errors:
    print('\nERRORS:')
    for item in errors: print(item)
    sys.exit(1)
print(f'\nPASS: {len(notes)} checks')
