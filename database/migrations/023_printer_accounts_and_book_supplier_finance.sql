-- ALIN — Printer accounts + printer-only book supplier finance.
-- Libraries no longer participate in book-supplier profit. Printers have
-- their own account type, collector-debt settlement path, and book-supply
-- settlement path, all separate from library finance.

begin;

-- 1) Existing pending library book-supplier profit is cancelled from the
-- library and moved back to the platform so the accounting total stays exact.
select set_config('alin.internal_order_transition','on',true);

with targets as (
  select l.order_id,coalesce(l.supplier,0) as supplier_amount
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_type='library'
    and coalesce(l.supplier,0)>0
    and l.supplier_settlement_status='pending'
    and l.status not in ('cancelled','reversed')
)
update public.orders o
set book_platform_share_percent=100,
    book_supplier_share_percent=0,
    book_supplier_account_id=null,
    book_supplier_type='platform',
    book_supplier_name_snapshot='منصة آلين',
    pickup_source_type='platform',
    pickup_source_account_id=null,
    pickup_source_label='منصة آلين',
    book_platform_merchandise_profit=coalesce(o.book_platform_merchandise_profit,0)+t.supplier_amount,
    book_supplier_profit=0,
    updated_at=now()
from targets t
where o.id=t.order_id;

update public.ledger l
set alin=coalesce(l.alin,0)+coalesce(l.supplier,0),
    admin=coalesce(l.admin,0)+coalesce(l.supplier,0),
    supplier=0,
    supplier_id=null,
    supplier_type=null,
    supplier_name=null,
    supplier_key=null,
    supplier_settlement_status='cancelled',
    supplier_settled_at=null,
    supplier_settlement_id=null,
    updated_at=now()
where l.supplier_type='library'
  and coalesce(l.supplier,0)>0
  and l.supplier_settlement_status='pending'
  and l.status not in ('cancelled','reversed')
  and exists(select 1 from public.orders o where o.id=l.order_id and o.kind='book');

update public.products
set supplier_type='platform',
    supplier_account_id=null,
    supplier_name='منصة آلين',
    supplier_share_percent=0,
    platform_share_percent=100,
    supplier_pickup_enabled=false,
    updated_at=now()
where type='book' and supplier_type='library';

-- 2) Printer becomes a first-class account role.
alter table public.accounts drop constraint if exists accounts_role_check;
alter table public.accounts
  add constraint accounts_role_check
  check (role in ('admin','accountant','teacher','library','courier','printer'));

-- Printer collector-debt settlements are distinct from library settlements.
alter table public.settlements drop constraint if exists settlements_party_role_check;
alter table public.settlements
  add constraint settlements_party_role_check
  check (party_role in ('admin','teacher','library','delegate','printer'));

-- 3) New books may be supplied only by the platform or by a printer account.
alter table public.products drop constraint if exists products_book_supplier_type_check;
alter table public.products add constraint products_book_supplier_type_check check (
  type<>'book' or supplier_type in ('platform','printer')
);

create or replace function public.alin_validate_book_supplier_config()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  a public.accounts%rowtype;
begin
  if lower(coalesce(new.type,''))<>'book' then return new; end if;

  new.platform_share_percent:=coalesce(new.platform_share_percent,100);
  new.supplier_share_percent:=coalesce(new.supplier_share_percent,0);
  new.supplier_type:=coalesce(nullif(lower(btrim(new.supplier_type)),''),'platform');

  if new.platform_share_percent<0 or new.platform_share_percent>100
     or new.supplier_share_percent<0 or new.supplier_share_percent>100
     or new.platform_share_percent+new.supplier_share_percent<>100 then
    raise exception 'مجموع نسب الكتاب يجب أن يساوي 100%%';
  end if;

  if new.supplier_type not in ('platform','printer') then
    raise exception 'مورد الكتاب يجب أن يكون منصة آلين أو حساب مطبعة';
  end if;

  if new.supplier_type='platform' then
    new.supplier_account_id:=null;
    new.supplier_name:='منصة آلين';
    new.supplier_share_percent:=0;
    new.platform_share_percent:=100;
    new.supplier_pickup_enabled:=false;
    return new;
  end if;

  if nullif(btrim(coalesce(new.supplier_account_id,'')),'') is null then
    raise exception 'اختر حساب المطبعة الموردة للكتاب';
  end if;

  select * into a
  from public.accounts
  where id=new.supplier_account_id
    and role='printer'
    and status='active'
    and deleted_at is null;

  if not found then
    raise exception 'حساب المطبعة الموردة غير موجود أو غير فعال';
  end if;

  new.supplier_name:=a.name;
  new.supplier_pickup_enabled:=false;
  return new;
end
$function$;

-- 4) Libraries can no longer read supplier-profit rows. Only the printer that
-- owns a printer supplier row can read that row, in addition to finance staff.
drop policy if exists ledger_read on public.ledger;
create policy ledger_read on public.ledger
for select to authenticated
using (
  public.alin_is_finance_staff()
  or teacher_id=public.alin_current_account_id()
  or library_id=public.alin_current_account_id()
  or delegate_id=public.alin_current_account_id()
  or courier_id=public.alin_current_account_id()
  or (supplier_type='printer' and supplier_id=public.alin_current_account_id())
);

alter table public.book_supplier_settlements enable row level security;
drop policy if exists book_supplier_settlements_read on public.book_supplier_settlements;
create policy book_supplier_settlements_read on public.book_supplier_settlements
for select to authenticated
using (
  public.alin_is_finance_staff()
  or (supplier_type='printer' and supplier_id=public.alin_current_account_id())
);

-- 5) The normal settlement service can also settle a printer's collector debt.
create or replace function public.alin_finance_record_settlement(
  p_role text,p_party_id text,p_amount numeric,p_method text,p_note text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  v_role text:=lower(btrim(p_role));
  v_id text;
  v_receipt text;
begin
  if not public.alin_is_finance_staff() then raise exception 'هذه العملية للإدارة المالية فقط'; end if;
  if v_role='courier' then v_role:='delegate'; end if;
  if v_role not in ('admin','teacher','library','delegate','printer') then raise exception 'نوع الحساب المالي غير صحيح'; end if;
  if p_amount is null or p_amount<=0 then raise exception 'المبلغ غير صحيح'; end if;

  if v_role='printer' and not exists(
    select 1 from public.accounts a
    where a.id=p_party_id and a.role='printer' and a.deleted_at is null
  ) then
    raise exception 'حساب المطبعة غير موجود';
  end if;

  v_id:='STL'||replace(extensions.gen_random_uuid()::text,'-','');
  v_receipt:='RC-'||to_char(clock_timestamp(),'YYMMDDHH24MISS')||'-'||substr(replace(extensions.gen_random_uuid()::text,'-',''),1,5);

  insert into public.settlements(id,receipt_number,party_role,party_id,amount,payment_method,status,note,created_by)
  values(
    v_id,v_receipt,v_role,nullif(p_party_id,''),p_amount,
    coalesce(nullif(btrim(p_method),''),'cash'),
    case when v_role in ('admin','teacher') then 'paid' else 'received' end,
    nullif(btrim(p_note),''),public.alin_current_account_id()
  );

  return jsonb_build_object('id',v_id,'receipt_number',v_receipt,'role',v_role,'amount',p_amount);
end
$function$;

-- 6) Admin book-supplier balances and settlements are printer-only.
create or replace function public.alin_admin_book_supplier_balances()
returns table(
  supplier_key text,supplier_type text,supplier_id text,supplier_name text,
  pending_amount numeric,settled_amount numeric,total_amount numeric,orders_count bigint
)
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
begin
  if not public.alin_is_finance_staff() then raise exception 'غير مصرح بعرض حسابات موردي الكتب'; end if;
  return query
  select l.supplier_key,'printer'::text,l.supplier_id,max(l.supplier_name),
         coalesce(sum(l.supplier) filter(where l.supplier_settlement_status='pending'),0),
         coalesce(sum(l.supplier) filter(where l.supplier_settlement_status='settled'),0),
         coalesce(sum(l.supplier) filter(where l.supplier_settlement_status in ('pending','settled')),0),
         count(*) filter(where l.supplier>0)
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_type='printer'
    and l.supplier_id is not null
    and coalesce(l.supplier,0)>0
    and l.status not in ('cancelled','reversed')
  group by l.supplier_key,l.supplier_id
  order by 5 desc,4;
end
$function$;

create or replace function public.alin_admin_settle_book_supplier(p_supplier_key text,p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  v_key text:=btrim(coalesce(p_supplier_key,''));
  v_amount numeric:=0;
  v_count integer:=0;
  v_type text;
  v_id text;
  v_name text;
  v_settlement_id text;
  v_actor text:=public.alin_current_account_id();
begin
  if not public.alin_is_finance_staff() then raise exception 'غير مصرح بتسوية حسابات موردي الكتب'; end if;
  if v_key='' then raise exception 'حدد المطبعة المطلوب تسويتها'; end if;

  perform 1
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_type='printer'
    and l.supplier_key=v_key
    and l.supplier>0
    and l.supplier_settlement_status='pending'
    and l.status not in ('cancelled','reversed')
  for update of l;

  select coalesce(sum(l.supplier),0),count(*)::integer,max(l.supplier_type),max(l.supplier_id),max(l.supplier_name)
  into v_amount,v_count,v_type,v_id,v_name
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_type='printer'
    and l.supplier_key=v_key
    and l.supplier>0
    and l.supplier_settlement_status='pending'
    and l.status not in ('cancelled','reversed');

  if v_count=0 or v_amount<=0 then raise exception 'لا توجد مبالغ مستحقة غير مسددة لهذه المطبعة'; end if;
  if v_type<>'printer' or v_id is null then raise exception 'حساب مورد الكتاب ليس مطبعة مرتبطة'; end if;
  if not exists(select 1 from public.accounts a where a.id=v_id and a.role='printer' and a.deleted_at is null) then
    raise exception 'حساب المطبعة غير موجود';
  end if;

  v_settlement_id:='BSS'||replace(extensions.gen_random_uuid()::text,'-','');
  insert into public.book_supplier_settlements(
    id,supplier_key,supplier_type,supplier_id,supplier_name,amount,orders_count,settled_by,note
  ) values(
    v_settlement_id,v_key,'printer',v_id,coalesce(v_name,'مطبعة'),v_amount,v_count,v_actor,
    nullif(btrim(coalesce(p_note,'')),'')
  );

  update public.ledger l
  set supplier_settlement_status='settled',
      supplier_settled_at=now(),
      supplier_settlement_id=v_settlement_id,
      updated_at=now()
  where l.supplier_type='printer'
    and l.supplier_key=v_key
    and l.supplier>0
    and l.supplier_settlement_status='pending'
    and exists(select 1 from public.orders o where o.id=l.order_id and o.kind='book')
    and l.status not in ('cancelled','reversed');

  return jsonb_build_object(
    'ok',true,'settlement_id',v_settlement_id,'supplier_key',v_key,
    'supplier_type','printer','supplier_id',v_id,'supplier_name',v_name,
    'amount',v_amount,'orders_count',v_count
  );
end
$function$;

-- 7) Printer dashboard summary. This exposes only the logged-in printer's
-- collector-debt and book-supply finance, with separate settlement histories.
create or replace function public.alin_printer_finance_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_id text:=public.alin_current_account_id();
  v_name text;
  v_collector_total numeric:=0;
  v_collector_settled numeric:=0;
  v_book_pending numeric:=0;
  v_book_settled numeric:=0;
  v_book_total numeric:=0;
  v_book_orders bigint:=0;
  v_book_rows jsonb:='[]'::jsonb;
  v_book_settlements jsonb:='[]'::jsonb;
  v_collector_settlements jsonb:='[]'::jsonb;
begin
  select a.name into v_name
  from public.accounts a
  where a.id=v_id and a.role='printer' and a.status='active' and a.deleted_at is null;
  if not found then raise exception 'هذا الحساب ليس حساب مطبعة فعال'; end if;

  select coalesce(sum(greatest(coalesce(l.collector_debt,0),0)),0)
  into v_collector_total
  from public.ledger l
  where l.library_id=v_id
    and coalesce(l.collector_role,l.delivery_type,'library')='library'
    and l.status not in ('cancelled','reversed');

  select coalesce(sum(s.amount),0)
  into v_collector_settled
  from public.settlements s
  where s.party_role='printer'
    and s.party_id=v_id
    and s.status in ('received','paid');

  select
    coalesce(sum(l.supplier) filter(where l.supplier_settlement_status='pending'),0),
    coalesce(sum(l.supplier) filter(where l.supplier_settlement_status='settled'),0),
    coalesce(sum(l.supplier) filter(where l.supplier_settlement_status in ('pending','settled')),0),
    count(*) filter(where l.supplier>0)
  into v_book_pending,v_book_settled,v_book_total,v_book_orders
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_type='printer'
    and l.supplier_id=v_id
    and l.supplier>0
    and l.status not in ('cancelled','reversed');

  select coalesce(jsonb_agg(jsonb_build_object(
    'ledger_id',q.ledger_id,
    'order_id',q.order_id,
    'order_number',q.order_number,
    'title',q.title,
    'amount',q.amount,
    'status',q.settlement_status,
    'created_at',q.created_at
  ) order by q.created_at desc),'[]'::jsonb)
  into v_book_rows
  from (
    select l.id as ledger_id,l.order_id,o.order_number,o.title,l.supplier as amount,
           l.supplier_settlement_status as settlement_status,
           coalesce(l.settled_at,l.created_at,o.created_at) as created_at
    from public.ledger l
    join public.orders o on o.id=l.order_id
    where o.kind='book'
      and l.supplier_type='printer'
      and l.supplier_id=v_id
      and l.supplier>0
      and l.status not in ('cancelled','reversed')
    order by coalesce(l.settled_at,l.created_at,o.created_at) desc
    limit 100
  ) q;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',q.id,'amount',q.amount,'orders_count',q.orders_count,'created_at',q.created_at,'note',q.note
  ) order by q.created_at desc),'[]'::jsonb)
  into v_book_settlements
  from (
    select s.id,s.amount,s.orders_count,s.created_at,s.note
    from public.book_supplier_settlements s
    where s.supplier_type='printer' and s.supplier_id=v_id
    order by s.created_at desc
    limit 100
  ) q;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id',q.id,'receipt_number',q.receipt_number,'amount',q.amount,
    'payment_method',q.payment_method,'status',q.status,'created_at',q.created_at,'note',q.note
  ) order by q.created_at desc),'[]'::jsonb)
  into v_collector_settlements
  from (
    select s.id,s.receipt_number,s.amount,s.payment_method,s.status,s.created_at,s.note
    from public.settlements s
    where s.party_role='printer' and s.party_id=v_id
    order by s.created_at desc
    limit 100
  ) q;

  return jsonb_build_object(
    'ok',true,
    'printer_id',v_id,
    'printer_name',v_name,
    'collector_debt_total',v_collector_total,
    'collector_settled',v_collector_settled,
    'collector_remaining',greatest(v_collector_total-v_collector_settled,0),
    'collector_settlements',v_collector_settlements,
    'book_supply_pending',v_book_pending,
    'book_supply_settled',v_book_settled,
    'book_supply_total',v_book_total,
    'book_orders_count',v_book_orders,
    'book_rows',v_book_rows,
    'book_settlements',v_book_settlements
  );
end
$function$;

grant execute on function public.alin_printer_finance_summary() to authenticated;
grant execute on function public.alin_admin_book_supplier_balances() to authenticated;
grant execute on function public.alin_admin_settle_book_supplier(text,text) to authenticated;

commit;
