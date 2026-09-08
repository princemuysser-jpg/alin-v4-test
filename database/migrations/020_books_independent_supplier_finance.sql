-- ALIN v4.2.x — Independent books supplier finance.
-- Books use the existing products/order/delivery pipeline, but keep their
-- supplier accounting completely separate from booklet/teacher accounting.

begin;

-- 1) Books are a first-class retail type.
alter table public.products drop constraint if exists products_type_check;
alter table public.products
  add constraint products_type_check
  check (type in ('product','stationery','gift','deal','book'));

alter table public.orders drop constraint if exists orders_kind_check;
alter table public.orders
  add constraint orders_kind_check
  check (kind in ('booklet','product','stationery','gift','book'));

insert into public.categories(id,type,name,status,sort_order)
values('CAT-BOOKS','book','كتب','active',2)
on conflict(type,name) do update
set status='active',
    sort_order=least(public.categories.sort_order,excluded.sort_order),
    updated_at=now();

-- 2) Per-book supplier configuration.
alter table public.products
  add column if not exists platform_share_percent numeric(5,2),
  add column if not exists supplier_share_percent numeric(5,2),
  add column if not exists supplier_account_id text references public.accounts(id) on delete set null,
  add column if not exists supplier_type text,
  add column if not exists supplier_name text,
  add column if not exists supplier_pickup_enabled boolean not null default false;

update public.products
set platform_share_percent=coalesce(platform_share_percent,100),
    supplier_share_percent=coalesce(supplier_share_percent,0),
    supplier_type=coalesce(nullif(lower(btrim(supplier_type)),''),'platform'),
    supplier_name=case
      when coalesce(nullif(lower(btrim(supplier_type)),''),'platform')='platform'
      then coalesce(nullif(btrim(supplier_name),''),'منصة آلين')
      else supplier_name
    end
where type='book';

alter table public.products drop constraint if exists products_book_share_range_check;
alter table public.products add constraint products_book_share_range_check check (
  type<>'book'
  or (
    platform_share_percent between 0 and 100
    and supplier_share_percent between 0 and 100
    and platform_share_percent + supplier_share_percent = 100
  )
);

alter table public.products drop constraint if exists products_book_supplier_type_check;
alter table public.products add constraint products_book_supplier_type_check check (
  type<>'book'
  or supplier_type in ('platform','library','printer')
);

alter table public.products drop constraint if exists products_book_platform_supplier_check;
alter table public.products add constraint products_book_platform_supplier_check check (
  type<>'book'
  or supplier_type<>'platform'
  or (
    supplier_account_id is null
    and supplier_share_percent=0
    and platform_share_percent=100
  )
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
  if lower(coalesce(new.type,''))<>'book' then
    return new;
  end if;

  new.platform_share_percent:=coalesce(new.platform_share_percent,100);
  new.supplier_share_percent:=coalesce(new.supplier_share_percent,0);
  new.supplier_type:=coalesce(nullif(lower(btrim(new.supplier_type)),''),'platform');

  if new.platform_share_percent<0 or new.platform_share_percent>100
     or new.supplier_share_percent<0 or new.supplier_share_percent>100
     or new.platform_share_percent+new.supplier_share_percent<>100 then
    raise exception 'مجموع نسب الكتاب يجب أن يساوي 100%%';
  end if;

  if new.supplier_type not in ('platform','library','printer') then
    raise exception 'نوع مورد الكتاب غير صحيح';
  end if;

  if new.supplier_type='platform' then
    new.supplier_account_id:=null;
    new.supplier_name:='منصة آلين';
    new.supplier_share_percent:=0;
    new.platform_share_percent:=100;
    new.supplier_pickup_enabled:=false;
    return new;
  end if;

  if new.supplier_type='library' then
    if nullif(btrim(coalesce(new.supplier_account_id,'')),'') is null then
      raise exception 'اختر المكتبة الموردة للكتاب';
    end if;
    select * into a
    from public.accounts
    where id=new.supplier_account_id
      and role='library'
      and status='active'
      and deleted_at is null;
    if not found then
      raise exception 'المكتبة الموردة غير موجودة أو غير فعالة';
    end if;
    new.supplier_name:=coalesce(nullif(btrim(new.supplier_name),''),a.name);
  elsif new.supplier_type='printer' then
    -- Printer suppliers may be tracked by name even before a login/account
    -- is created for them. If an account id is supplied it must exist.
    if nullif(btrim(coalesce(new.supplier_account_id,'')),'') is not null then
      select * into a
      from public.accounts
      where id=new.supplier_account_id
        and status='active'
        and deleted_at is null;
      if not found then
        raise exception 'حساب المطبعة الموردة غير موجود أو غير فعال';
      end if;
      new.supplier_name:=coalesce(nullif(btrim(new.supplier_name),''),a.name);
    end if;
    if nullif(btrim(coalesce(new.supplier_name,'')),'') is null then
      raise exception 'اكتب اسم المطبعة الموردة للكتاب';
    end if;
  end if;

  return new;
end
$function$;

drop trigger if exists products_validate_book_supplier_config on public.products;
create trigger products_validate_book_supplier_config
before insert or update of type,platform_share_percent,supplier_share_percent,supplier_account_id,supplier_type,supplier_name,supplier_pickup_enabled
on public.products
for each row execute function public.alin_validate_book_supplier_config();

-- 3) Immutable finance and pickup-source snapshot on the order.
alter table public.orders
  add column if not exists book_platform_share_percent numeric(5,2),
  add column if not exists book_supplier_share_percent numeric(5,2),
  add column if not exists book_supplier_account_id text,
  add column if not exists book_supplier_type text,
  add column if not exists book_supplier_name_snapshot text,
  add column if not exists book_share_snapshot_at timestamptz,
  add column if not exists pickup_source_type text,
  add column if not exists pickup_source_account_id text,
  add column if not exists pickup_source_label text,
  add column if not exists book_supplier_profit numeric(14,2) not null default 0,
  add column if not exists book_platform_merchandise_profit numeric(14,2) not null default 0;

alter table public.orders drop constraint if exists orders_book_share_snapshot_valid;
alter table public.orders add constraint orders_book_share_snapshot_valid check (
  (
    book_platform_share_percent is null
    and book_supplier_share_percent is null
    and book_supplier_type is null
  )
  or
  (
    book_platform_share_percent between 0 and 100
    and book_supplier_share_percent between 0 and 100
    and book_platform_share_percent + book_supplier_share_percent = 100
    and book_supplier_type in ('platform','library','printer')
  )
);

create or replace function public.alin_classify_and_snapshot_book_order()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  p public.products%rowtype;
begin
  -- Secure checkout currently inserts every non-booklet retail item using
  -- product/stationery/gift. Reclassify from the authoritative product row.
  select * into p
  from public.products
  where id=new.item_id;

  if not found or lower(coalesce(p.type,''))<>'book' then
    return new;
  end if;

  new.kind:='book';

  if p.platform_share_percent is null
     or p.supplier_share_percent is null
     or p.platform_share_percent<0
     or p.supplier_share_percent<0
     or p.platform_share_percent>100
     or p.supplier_share_percent>100
     or p.platform_share_percent+p.supplier_share_percent<>100 then
    raise exception 'نسب الحسابات الخاصة بالكتاب غير صحيحة';
  end if;

  if p.supplier_type not in ('platform','library','printer') then
    raise exception 'نوع مورد الكتاب غير صحيح';
  end if;

  new.book_platform_share_percent:=p.platform_share_percent;
  new.book_supplier_share_percent:=p.supplier_share_percent;
  new.book_supplier_account_id:=p.supplier_account_id;
  new.book_supplier_type:=p.supplier_type;
  new.book_supplier_name_snapshot:=coalesce(
    nullif(btrim(p.supplier_name),''),
    case p.supplier_type when 'platform' then 'منصة آلين' else null end
  );
  new.book_share_snapshot_at:=coalesce(new.book_share_snapshot_at,now());

  new.pickup_source_type:=p.supplier_type;
  new.pickup_source_account_id:=p.supplier_account_id;
  new.pickup_source_label:=case
    when p.supplier_type='platform' then 'منصة آلين'
    when p.supplier_type='library' then
      'مكتبة '||coalesce(nullif(btrim(p.supplier_name),''),
        (select name from public.accounts where id=p.supplier_account_id),
        'غير محددة')
    when p.supplier_type='printer' then
      'مطبعة '||coalesce(nullif(btrim(p.supplier_name),''),'غير محددة')
    else 'منصة آلين'
  end;

  -- Direct supplier pickup is intentionally not routed through the old
  -- library pickup path yet. Home delivery remains the safe default.
  if new.fulfillment_type='pickup' then
    raise exception 'الكتب متاحة حالياً بالتوصيل بالمندوب. الاستلام المباشر من المورد سيُفعل بعد ربط مسار المورد.';
  end if;

  return new;
end
$function$;

drop trigger if exists orders_classify_and_snapshot_book on public.orders;
create trigger orders_classify_and_snapshot_book
before insert on public.orders
for each row execute function public.alin_classify_and_snapshot_book_order();

create or replace function public.alin_protect_book_finance_snapshot()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
begin
  if current_setting('request.jwt.claim.role',true)='service_role'
     or current_setting('alin.internal_order_transition',true)='on' then
    return new;
  end if;

  if old.book_platform_share_percent is distinct from new.book_platform_share_percent
     or old.book_supplier_share_percent is distinct from new.book_supplier_share_percent
     or old.book_supplier_account_id is distinct from new.book_supplier_account_id
     or old.book_supplier_type is distinct from new.book_supplier_type
     or old.book_supplier_name_snapshot is distinct from new.book_supplier_name_snapshot
     or old.book_share_snapshot_at is distinct from new.book_share_snapshot_at
     or old.pickup_source_type is distinct from new.pickup_source_type
     or old.pickup_source_account_id is distinct from new.pickup_source_account_id
     or old.pickup_source_label is distinct from new.pickup_source_label then
    raise exception 'بيانات مورد الكتاب المثبتة على الطلب لا يمكن تغييرها بعد إنشاء الطلب';
  end if;
  return new;
end
$function$;

drop trigger if exists orders_protect_book_finance_snapshot on public.orders;
create trigger orders_protect_book_finance_snapshot
before update on public.orders
for each row execute function public.alin_protect_book_finance_snapshot();

-- 4) Dedicated supplier columns on the ledger. Existing booklet/library
-- columns stay untouched.
alter table public.ledger
  add column if not exists supplier numeric(14,2) not null default 0,
  add column if not exists supplier_id text,
  add column if not exists supplier_type text,
  add column if not exists supplier_name text,
  add column if not exists supplier_key text,
  add column if not exists supplier_settlement_status text not null default 'settled',
  add column if not exists supplier_settled_at timestamptz,
  add column if not exists supplier_settlement_id text;

alter table public.ledger drop constraint if exists ledger_supplier_nonnegative;
alter table public.ledger add constraint ledger_supplier_nonnegative check (supplier>=0);

alter table public.ledger drop constraint if exists ledger_supplier_type_valid;
alter table public.ledger add constraint ledger_supplier_type_valid check (
  supplier_type is null or supplier_type in ('platform','library','printer')
);

alter table public.ledger drop constraint if exists ledger_supplier_settlement_status_valid;
alter table public.ledger add constraint ledger_supplier_settlement_status_valid check (
  supplier_settlement_status in ('pending','settled','cancelled')
);

create index if not exists ledger_book_supplier_pending_idx
  on public.ledger(supplier_key,supplier_settlement_status)
  where supplier>0;

-- 5) Replace the atomic finance function with book-aware logic.
-- Book merchandise is split only by the book percentages. Delivery stays
-- outside that split and keeps the existing courier calculation.
create or replace function public.alin_upsert_order_finance_atomic(p_order_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  o public.orders%rowtype;
  b public.booklets%rowtype;
  p public.products%rowtype;
  l public.ledger%rowtype;
  v_teacher_id text; v_library_id text; v_delegate_id text; v_collector_role text; v_collector_id text;
  v_total numeric; v_delivery numeric; v_merchandise numeric;
  v_platform_pct numeric:=0; v_teacher_pct numeric:=0; v_library_pct numeric:=0; v_delegate_pct numeric:=0;
  v_teacher numeric:=0; v_library numeric:=0; v_delegate numeric:=0; v_admin numeric:=0; v_debt numeric:=0;
  v_supplier numeric:=0; v_supplier_id text; v_supplier_type text; v_supplier_name text;
  v_platform_merchandise numeric:=0;
  v_ledger_id text;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if o.status<>'completed' then raise exception 'لا يمكن إنشاء الحسابات قبل تسليم الطلب'; end if;

  select * into l from public.ledger where order_id=o.id;
  if found then
    return jsonb_build_object(
      'ledger_id',l.id,'order_id',o.id,'total',l.total,'admin',l.admin,
      'teacher',l.teacher,'library',l.library,'delegate',l.delegate,
      'supplier',coalesce(l.supplier,0),'supplier_id',l.supplier_id,
      'supplier_type',l.supplier_type,'supplier_name',l.supplier_name,
      'collector_debt',l.collector_debt,'frozen',true
    );
  end if;

  v_total:=o.total;
  v_delivery:=least(o.total,greatest(o.delivery_fee,0));
  v_merchandise:=greatest(v_total-v_delivery,0);
  v_library_id:=coalesce(o.library_id,o.pickup_library_id);
  v_delegate_id:=coalesce(o.delegate_id,o.courier_id);

  if o.kind='booklet' then
    select * into b from public.booklets where id=o.item_id;
    if not found then raise exception 'الملزمة المرتبطة بالطلب غير موجودة'; end if;

    v_teacher_id:=coalesce(o.booklet_teacher_id_snapshot,b.teacher_id);
    v_platform_pct:=coalesce(o.booklet_platform_share_percent,b.platform_share_percent);
    v_teacher_pct:=coalesce(o.booklet_teacher_share_percent,b.teacher_share_percent);
    v_library_pct:=coalesce(o.booklet_library_share_percent,b.library_share_percent);

    if v_platform_pct is null or v_teacher_pct is null or v_library_pct is null
       or v_platform_pct<0 or v_teacher_pct<0 or v_library_pct<0
       or v_platform_pct>100 or v_teacher_pct>100 or v_library_pct>100
       or v_platform_pct+v_teacher_pct+v_library_pct<>100 then
      raise exception 'نسب الحسابات الخاصة بهذه الملزمة غير صحيحة';
    end if;

    v_teacher:=round(v_merchandise*v_teacher_pct/100);
  elsif o.kind='book' then
    select * into p from public.products where id=o.item_id;
    if not found then raise exception 'الكتاب المرتبط بالطلب غير موجود'; end if;

    v_platform_pct:=coalesce(o.book_platform_share_percent,p.platform_share_percent);
    v_supplier_id:=coalesce(o.book_supplier_account_id,p.supplier_account_id);
    v_supplier_type:=coalesce(o.book_supplier_type,p.supplier_type);
    v_supplier_name:=coalesce(o.book_supplier_name_snapshot,p.supplier_name);
    v_teacher_pct:=0;
    v_library_pct:=0;

    if v_platform_pct is null or o.book_supplier_share_percent is null
       or v_platform_pct<0 or o.book_supplier_share_percent<0
       or v_platform_pct>100 or o.book_supplier_share_percent>100
       or v_platform_pct+o.book_supplier_share_percent<>100
       or v_supplier_type not in ('platform','library','printer') then
      raise exception 'نسب الحسابات الخاصة بهذا الكتاب غير صحيحة';
    end if;

    v_supplier:=round(v_merchandise*o.book_supplier_share_percent/100);
    v_platform_merchandise:=greatest(v_merchandise-v_supplier,0);
  else
    v_teacher_pct:=0;
    v_library_pct:=public.alin_setting_numeric('library_profit_percent',30);
  end if;

  v_delegate_pct:=public.alin_setting_numeric('delegate_profit_percent',30);

  if o.fulfillment_type='home_delivery' then
    v_collector_role:='delegate';
    v_collector_id:=v_delegate_id;
    if v_collector_id is null then raise exception 'طلب التوصيل غير مرتبط بمندوب'; end if;
    v_delegate:=round(v_delivery*least(greatest(v_delegate_pct,0),100)/100);
    v_library:=0;
  else
    if o.kind='book' then
      raise exception 'الاستلام المباشر للكتب غير مفعل في النسخة الحالية من مسار المورد';
    end if;
    v_collector_role:='library';
    v_collector_id:=v_library_id;
    if v_collector_id is null then raise exception 'طلب الاستلام غير مرتبط بمكتبة'; end if;
    v_library:=least(
      greatest(v_merchandise-v_teacher,0),
      round(v_merchandise*least(greatest(v_library_pct,0),100)/100)
    );
  end if;

  if o.kind='book' then
    -- Exact reconciliation: book shares apply only to merchandise, while
    -- the courier share is paid only from the delivery fee.
    v_admin:=greatest(v_platform_merchandise + (v_delivery-v_delegate),0);
  else
    v_admin:=greatest(v_total-v_teacher-v_library-v_delegate,0);
  end if;
  v_debt:=greatest(v_total-case when v_collector_role='library' then v_library else v_delegate end,0);

  v_ledger_id:='LG'||replace(extensions.gen_random_uuid()::text,'-','');
  insert into public.ledger(
    id,order_id,order_number,title,total,merchandise_total,delivery_fee,alin,admin,teacher,teacher_id,library,library_id,
    delegate,courier,delegate_id,courier_id,collector_role,collector_id,collector_debt,delivery_type,status,settlement_status,
    finance_version,is_current,note,supplier,supplier_id,supplier_type,supplier_name,supplier_key,supplier_settlement_status
  ) values (
    v_ledger_id,o.id,o.order_number,o.title,v_total,v_merchandise,v_delivery,v_admin,v_admin,v_teacher,v_teacher_id,v_library,v_library_id,
    v_delegate,v_delegate,v_delegate_id,v_delegate_id,v_collector_role,v_collector_id,v_debt,v_collector_role,'pending','pending',
    case when o.kind='book' then '4.2-books-supplier-snapshot' else '4.2.1-booklet-snapshot' end,
    true,
    case
      when o.kind='booklet' then
        'قيد مالي ذري — نسب الملزمة مثبتة عند إنشاء الطلب: منصة '||v_platform_pct||'%، مدرس '||v_teacher_pct||'%، مكتبة '||v_library_pct||'%'
      when o.kind='book' then
        'قيد كتاب مستقل — قيمة الكتاب فقط: منصة '||v_platform_pct||'%، مورد '||o.book_supplier_share_percent||'%؛ التوصيل مستقل'
      else 'قيد مالي ذري من الطلب المكتمل'
    end,
    v_supplier,v_supplier_id,v_supplier_type,v_supplier_name,
    case when o.kind='book' and v_supplier>0 then coalesce(nullif(v_supplier_id,''),'name:'||lower(coalesce(v_supplier_name,'غير محدد'))) else null end,
    case when o.kind='book' and v_supplier>0 then 'pending' else 'settled' end
  )
  on conflict(order_id) do nothing
  returning id into v_ledger_id;

  if v_ledger_id is null then
    select * into l from public.ledger where order_id=o.id;
    return jsonb_build_object(
      'ledger_id',l.id,'order_id',o.id,'total',l.total,'admin',l.admin,
      'teacher',l.teacher,'library',l.library,'delegate',l.delegate,
      'supplier',coalesce(l.supplier,0),'supplier_id',l.supplier_id,
      'supplier_type',l.supplier_type,'supplier_name',l.supplier_name,
      'collector_debt',l.collector_debt,'frozen',true
    );
  end if;

  perform set_config('alin.internal_order_transition','on',true);
  update public.orders set
    settlement_done=true,
    settlement_cancelled=false,
    settlement_at=coalesce(settlement_at,now()),
    settlement_party=v_collector_role,
    platform_profit=v_admin,
    teacher_profit=v_teacher,
    library_profit=v_library,
    delegate_profit=v_delegate,
    courier_profit=v_delegate,
    book_supplier_profit=case when kind='book' then v_supplier else book_supplier_profit end,
    book_platform_merchandise_profit=case when kind='book' then v_platform_merchandise else book_platform_merchandise_profit end,
    cash_collected_by=v_collector_role,
    cash_collected_at=coalesce(cash_collected_at,now()),
    library_cash_collected=case when v_collector_role='library' then v_total else 0 end,
    delegate_cash_collected=case when v_collector_role='delegate' then v_total else 0 end,
    finance_version=case when kind='book' then '4.2-books-supplier-snapshot' else '4.2.1-booklet-snapshot' end
  where id=o.id;
  perform set_config('alin.internal_order_transition','off',true);

  return jsonb_build_object(
    'ledger_id',v_ledger_id,'order_id',o.id,'total',v_total,'admin',v_admin,
    'teacher',v_teacher,'library',v_library,'delegate',v_delegate,
    'supplier',v_supplier,'supplier_id',v_supplier_id,'supplier_type',v_supplier_type,'supplier_name',v_supplier_name,
    'collector_debt',v_debt,
    'shares',case
      when o.kind='booklet' then jsonb_build_object('platform',v_platform_pct,'teacher',v_teacher_pct,'library',v_library_pct)
      when o.kind='book' then jsonb_build_object('platform',v_platform_pct,'supplier',o.book_supplier_share_percent)
      else null
    end
  );
end
$function$;

-- 6) Admin-only supplier balance RPC. Supplier money is not posted into
-- legacy library/teacher columns, so booklet settlements remain untouched.
create or replace function public.alin_admin_book_supplier_balances()
returns table(
  supplier_key text,
  supplier_type text,
  supplier_id text,
  supplier_name text,
  pending_amount numeric,
  settled_amount numeric,
  total_amount numeric,
  orders_count bigint
)
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
begin
  if not public.alin_is_finance_staff() then
    raise exception 'غير مصرح بعرض حسابات موردي الكتب';
  end if;

  return query
  select
    l.supplier_key as supplier_key,
    coalesce(l.supplier_type,'platform') as supplier_type,
    l.supplier_id,
    max(l.supplier_name) as supplier_name,
    coalesce(sum(l.supplier) filter(where l.supplier_settlement_status='pending'),0) as pending_amount,
    coalesce(sum(l.supplier) filter(where l.supplier_settlement_status='settled'),0) as settled_amount,
    coalesce(sum(l.supplier) filter(where l.supplier_settlement_status in ('pending','settled')),0) as total_amount,
    count(*) filter(where l.supplier>0) as orders_count
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and coalesce(l.supplier,0)>0
    and l.status not in ('cancelled','reversed')
  group by
    l.supplier_key,
    coalesce(l.supplier_type,'platform'),
    l.supplier_id
  order by pending_amount desc, supplier_name;
end
$function$;

revoke all on function public.alin_admin_book_supplier_balances() from public,anon;
grant execute on function public.alin_admin_book_supplier_balances() to authenticated;

create table if not exists public.book_supplier_settlements (
  id text primary key default ('BSS' || replace(extensions.gen_random_uuid()::text,'-','')),
  supplier_key text not null,
  supplier_type text not null check (supplier_type in ('library','printer')),
  supplier_id text,
  supplier_name text not null,
  amount numeric(14,2) not null check (amount>=0),
  orders_count integer not null default 0 check (orders_count>=0),
  settled_by text,
  note text,
  created_at timestamptz not null default now()
);

alter table public.book_supplier_settlements enable row level security;
revoke all on public.book_supplier_settlements from anon,authenticated;

create or replace function public.alin_admin_settle_book_supplier(
  p_supplier_key text,
  p_note text default null
)
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
  if not public.alin_is_finance_staff() then
    raise exception 'غير مصرح بتسوية حسابات موردي الكتب';
  end if;
  if v_key='' then raise exception 'حدد المورد المطلوب تسويته'; end if;

  -- Lock only this supplier's unpaid book rows. This settlement never
  -- touches teacher/library/courier settlement states.
  perform 1
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_key=v_key
    and l.supplier>0
    and l.supplier_settlement_status='pending'
    and l.status not in ('cancelled','reversed')
  for update of l;

  select
    coalesce(sum(l.supplier),0),
    count(*)::integer,
    max(l.supplier_type),
    max(l.supplier_id),
    max(l.supplier_name)
  into v_amount,v_count,v_type,v_id,v_name
  from public.ledger l
  join public.orders o on o.id=l.order_id
  where o.kind='book'
    and l.supplier_key=v_key
    and l.supplier>0
    and l.supplier_settlement_status='pending'
    and l.status not in ('cancelled','reversed');

  if v_count=0 or v_amount<=0 then
    raise exception 'لا توجد مبالغ مستحقة غير مسددة لهذا المورد';
  end if;
  if v_type not in ('library','printer') then
    raise exception 'نوع المورد غير قابل للتسوية';
  end if;

  v_settlement_id:='BSS'||replace(extensions.gen_random_uuid()::text,'-','');

  insert into public.book_supplier_settlements(
    id,supplier_key,supplier_type,supplier_id,supplier_name,amount,orders_count,settled_by,note
  ) values (
    v_settlement_id,v_key,v_type,v_id,coalesce(v_name,'مورد كتب'),v_amount,v_count,v_actor,nullif(btrim(coalesce(p_note,'')),'')
  );

  update public.ledger l
  set supplier_settlement_status='settled',
      supplier_settled_at=now(),
      supplier_settlement_id=v_settlement_id,
      updated_at=now()
  where l.supplier_key=v_key
    and l.supplier>0
    and l.supplier_settlement_status='pending'
    and exists(select 1 from public.orders o where o.id=l.order_id and o.kind='book')
    and l.status not in ('cancelled','reversed');

  return jsonb_build_object(
    'ok',true,
    'settlement_id',v_settlement_id,
    'supplier_key',v_key,
    'supplier_type',v_type,
    'supplier_id',v_id,
    'supplier_name',v_name,
    'amount',v_amount,
    'orders_count',v_count
  );
end
$function$;

revoke all on function public.alin_admin_settle_book_supplier(text,text) from public,anon;
grant execute on function public.alin_admin_settle_book_supplier(text,text) to authenticated;

commit;
