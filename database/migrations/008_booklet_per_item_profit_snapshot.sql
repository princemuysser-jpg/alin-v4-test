-- ALIN v4.2.0 — Per-booklet profit percentages with immutable order snapshot.
-- Existing completed finance rows are never recalculated by this migration.

alter table public.booklets
  add column if not exists platform_share_percent numeric;

update public.booklets
set platform_share_percent = greatest(0, 100 - coalesce(teacher_share_percent,0) - coalesce(library_share_percent,0))
where platform_share_percent is null;

alter table public.booklets
  alter column platform_share_percent set default 20,
  alter column platform_share_percent set not null;

alter table public.booklets drop constraint if exists booklets_platform_share_percent_range;
alter table public.booklets add constraint booklets_platform_share_percent_range
  check (platform_share_percent between 0 and 100);
alter table public.booklets drop constraint if exists booklets_teacher_share_percent_range;
alter table public.booklets add constraint booklets_teacher_share_percent_range
  check (teacher_share_percent between 0 and 100);
alter table public.booklets drop constraint if exists booklets_library_share_percent_range;
alter table public.booklets add constraint booklets_library_share_percent_range
  check (library_share_percent between 0 and 100);
alter table public.booklets drop constraint if exists booklets_profit_shares_total_100;
alter table public.booklets add constraint booklets_profit_shares_total_100
  check (platform_share_percent + teacher_share_percent + library_share_percent = 100);

alter table public.orders
  add column if not exists booklet_platform_share_percent numeric,
  add column if not exists booklet_teacher_share_percent numeric,
  add column if not exists booklet_library_share_percent numeric,
  add column if not exists booklet_teacher_id_snapshot text,
  add column if not exists booklet_share_snapshot_at timestamptz;

alter table public.orders drop constraint if exists orders_booklet_share_snapshot_valid;
alter table public.orders add constraint orders_booklet_share_snapshot_valid check (
  (booklet_platform_share_percent is null and booklet_teacher_share_percent is null and booklet_library_share_percent is null)
  or
  (
    booklet_platform_share_percent between 0 and 100
    and booklet_teacher_share_percent between 0 and 100
    and booklet_library_share_percent between 0 and 100
    and booklet_platform_share_percent + booklet_teacher_share_percent + booklet_library_share_percent = 100
  )
);

create or replace function public.alin_snapshot_booklet_profit_shares()
returns trigger
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  b public.booklets%rowtype;
  v_total numeric;
begin
  if lower(coalesce(new.kind,'')) <> 'booklet' then
    return new;
  end if;

  select * into b from public.booklets where id=new.item_id;
  if not found then raise exception 'الملزمة غير موجودة لتثبيت نسب الحسابات'; end if;

  v_total:=coalesce(b.platform_share_percent,0)+coalesce(b.teacher_share_percent,0)+coalesce(b.library_share_percent,0);
  if v_total<>100 then raise exception 'مجموع نسب الملزمة يجب أن يساوي 100%% قبل إنشاء الطلب'; end if;

  new.booklet_platform_share_percent:=b.platform_share_percent;
  new.booklet_teacher_share_percent:=b.teacher_share_percent;
  new.booklet_library_share_percent:=b.library_share_percent;
  new.booklet_teacher_id_snapshot:=b.teacher_id;
  new.booklet_share_snapshot_at:=coalesce(new.booklet_share_snapshot_at,now());
  return new;
end
$function$;

drop trigger if exists orders_snapshot_booklet_profit_shares on public.orders;
create trigger orders_snapshot_booklet_profit_shares
before insert on public.orders
for each row execute function public.alin_snapshot_booklet_profit_shares();

-- Freeze current percentages for legacy booklet orders that are still in progress.
-- Completed/cancelled/rejected orders are intentionally not touched.
do $block$
begin
  perform set_config('alin.internal_order_transition','on',true);
  update public.orders o
  set booklet_platform_share_percent=b.platform_share_percent,
      booklet_teacher_share_percent=b.teacher_share_percent,
      booklet_library_share_percent=b.library_share_percent,
      booklet_teacher_id_snapshot=b.teacher_id,
      booklet_share_snapshot_at=coalesce(o.booklet_share_snapshot_at,now())
  from public.booklets b
  where o.kind='booklet'
    and o.item_id=b.id
    and o.status not in ('completed','cancelled','rejected')
    and (o.booklet_platform_share_percent is null
      or o.booklet_teacher_share_percent is null
      or o.booklet_library_share_percent is null
      or o.booklet_teacher_id_snapshot is null);
  perform set_config('alin.internal_order_transition','off',true);
end
$block$;

create or replace function public.alin_protect_booklet_profit_snapshot()
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

  if old.booklet_platform_share_percent is distinct from new.booklet_platform_share_percent
     or old.booklet_teacher_share_percent is distinct from new.booklet_teacher_share_percent
     or old.booklet_library_share_percent is distinct from new.booklet_library_share_percent
     or old.booklet_teacher_id_snapshot is distinct from new.booklet_teacher_id_snapshot
     or old.booklet_share_snapshot_at is distinct from new.booklet_share_snapshot_at then
    raise exception 'نسب الملزمة المثبتة على الطلب لا يمكن تعديلها بعد إنشاء الطلب';
  end if;
  return new;
end
$function$;

drop trigger if exists orders_protect_booklet_profit_snapshot on public.orders;
create trigger orders_protect_booklet_profit_snapshot
before update on public.orders
for each row execute function public.alin_protect_booklet_profit_snapshot();

create or replace function public.alin_upsert_order_finance_atomic(p_order_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  o public.orders%rowtype;
  b public.booklets%rowtype;
  l public.ledger%rowtype;
  v_teacher_id text; v_library_id text; v_delegate_id text; v_collector_role text; v_collector_id text;
  v_total numeric; v_delivery numeric; v_merchandise numeric;
  v_platform_pct numeric:=0; v_teacher_pct numeric:=0; v_library_pct numeric:=0; v_delegate_pct numeric:=0;
  v_teacher numeric:=0; v_library numeric:=0; v_delegate numeric:=0; v_admin numeric:=0; v_debt numeric:=0;
  v_ledger_id text;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if o.status<>'completed' then raise exception 'لا يمكن إنشاء الحسابات قبل تسليم الطلب'; end if;

  -- Any existing ledger row is authoritative and frozen. Repeated completion must never recalculate old money.
  select * into l from public.ledger where order_id=o.id;
  if found then
    return jsonb_build_object(
      'ledger_id',l.id,'order_id',o.id,'total',l.total,'admin',l.admin,
      'teacher',l.teacher,'library',l.library,'delegate',l.delegate,
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
    -- Preserve the existing delivery model: no library collector/share is posted on home-delivery orders.
    v_library:=0;
  else
    v_collector_role:='library';
    v_collector_id:=v_library_id;
    if v_collector_id is null then raise exception 'طلب الاستلام غير مرتبط بمكتبة'; end if;
    v_library:=least(
      greatest(v_merchandise-v_teacher,0),
      round(v_merchandise*least(greatest(v_library_pct,0),100)/100)
    );
  end if;

  -- Platform gets the exact reconciled remainder, so teacher+library+platform never lose/gain a dinar by rounding.
  v_admin:=greatest(v_total-v_teacher-v_library-v_delegate,0);
  v_debt:=greatest(v_total-case when v_collector_role='library' then v_library else v_delegate end,0);

  v_ledger_id:='LG'||replace(extensions.gen_random_uuid()::text,'-','');
  insert into public.ledger(
    id,order_id,order_number,title,total,merchandise_total,delivery_fee,alin,admin,teacher,teacher_id,library,library_id,
    delegate,courier,delegate_id,courier_id,collector_role,collector_id,collector_debt,delivery_type,status,settlement_status,
    finance_version,is_current,note
  ) values (
    v_ledger_id,o.id,o.order_number,o.title,v_total,v_merchandise,v_delivery,v_admin,v_admin,v_teacher,v_teacher_id,v_library,v_library_id,
    v_delegate,v_delegate,v_delegate_id,v_delegate_id,v_collector_role,v_collector_id,v_debt,v_collector_role,'pending','pending',
    '4.2.1-booklet-snapshot',true,
    case when o.kind='booklet' then
      'قيد مالي ذري — نسب الملزمة مثبتة عند إنشاء الطلب: منصة '||v_platform_pct||'%، مدرس '||v_teacher_pct||'%، مكتبة '||v_library_pct||'%'
    else 'قيد مالي ذري من الطلب المكتمل' end
  )
  on conflict(order_id) do nothing
  returning id into v_ledger_id;

  if v_ledger_id is null then
    select * into l from public.ledger where order_id=o.id;
    return jsonb_build_object(
      'ledger_id',l.id,'order_id',o.id,'total',l.total,'admin',l.admin,
      'teacher',l.teacher,'library',l.library,'delegate',l.delegate,
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
    cash_collected_by=v_collector_role,
    cash_collected_at=coalesce(cash_collected_at,now()),
    library_cash_collected=case when v_collector_role='library' then v_total else 0 end,
    delegate_cash_collected=case when v_collector_role='delegate' then v_total else 0 end,
    finance_version='4.2.1-booklet-snapshot'
  where id=o.id;
  perform set_config('alin.internal_order_transition','off',true);

  return jsonb_build_object(
    'ledger_id',v_ledger_id,'order_id',o.id,'total',v_total,'admin',v_admin,
    'teacher',v_teacher,'library',v_library,'delegate',v_delegate,
    'collector_debt',v_debt,
    'shares',case when o.kind='booklet' then jsonb_build_object('platform',v_platform_pct,'teacher',v_teacher_pct,'library',v_library_pct) else null end
  );
end
$function$;
