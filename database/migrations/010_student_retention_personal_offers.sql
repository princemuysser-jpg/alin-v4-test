-- ALIN v4.2.0 — registered-student activity + private retention offers.
-- Complete reproducible migration. Personal coupons are excluded from public coupon feeds
-- and require a valid owner session at checkout.

alter table public.student_profiles
  add column if not exists last_login_at timestamptz,
  add column if not exists last_active_at timestamptz,
  add column if not exists last_offer_at timestamptz;
create index if not exists student_profiles_last_active_idx on public.student_profiles(last_active_at desc nulls last);

alter table public.coupons
  add column if not exists bound_student_id text references public.student_profiles(id) on delete cascade,
  add column if not exists personal_offer boolean not null default false,
  add column if not exists offer_title text,
  add column if not exists offer_message text,
  add column if not exists offer_seen_at timestamptz;
create index if not exists coupons_bound_student_idx
  on public.coupons(bound_student_id,status,expires_at) where bound_student_id is not null;

create or replace function public.alin_student_session_activity_stamp()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $function$
begin
  update public.student_profiles
  set last_login_at=now(),last_active_at=now(),updated_at=now()
  where id=new.student_id;
  return new;
end
$function$;
drop trigger if exists student_sessions_activity_stamp on public.student_sessions;
create trigger student_sessions_activity_stamp
after insert on public.student_sessions
for each row execute function public.alin_student_session_activity_stamp();

create or replace function public.alin_student_touch_activity(p_token text,p_device text)
returns jsonb language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare v_id text:=public.alin_student_session_id(p_token,p_device); v_last timestamptz;
begin
  if v_id is null then raise exception 'جلسة الطالب منتهية'; end if;
  select last_active_at into v_last from public.student_profiles where id=v_id for update;
  if v_last is null or v_last<now()-interval '5 minutes' then
    update public.student_profiles set last_active_at=now(),updated_at=now() where id=v_id;
    v_last:=now();
  end if;
  return jsonb_build_object('student_id',v_id,'last_active_at',v_last);
end
$function$;
revoke all on function public.alin_student_touch_activity(text,text) from public;
grant execute on function public.alin_student_touch_activity(text,text) to anon,authenticated;

-- Private coupons must never be discoverable in the public coupon list.
drop policy if exists coupons_public_read on public.coupons;
create policy coupons_public_read on public.coupons
for select to anon,authenticated
using ((status='active' and bound_student_id is null) or public.alin_is_admin());

create or replace function public.alin_public_store_bootstrap()
returns jsonb language sql stable set search_path to 'public','pg_temp' as $function$
with
settings_obj as (
  select jsonb_build_object('storeType','booklet')
    || coalesce((select s.data from public.alin_public_settings s where s.key='__main__' or s.id='main' order by case when s.key='__main__' then 0 else 1 end limit 1),'{}'::jsonb)
    || coalesce((select jsonb_object_agg(s.key,to_jsonb(s.value)) from public.alin_public_settings s where s.key is not null and s.key<>'__main__'),'{}'::jsonb) as value
),
teachers as (select coalesce(jsonb_agg(to_jsonb(a) order by a.name),'[]'::jsonb) value from public.alin_public_accounts a where a.role='teacher'),
libraries as (select coalesce(jsonb_agg(to_jsonb(a) order by a.name),'[]'::jsonb) value from public.alin_public_accounts a where a.role='library'),
delivery_areas as (select coalesce(jsonb_agg(to_jsonb(d) order by d.sort_order nulls last,d.name),'[]'::jsonb) value from public.delivery_areas d),
categories as (select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order nulls last,c.created_at),'[]'::jsonb) value from public.categories c),
product_subcategories as (select coalesce(jsonb_agg(to_jsonb(s) order by s.parent_category_id,s.sort_order,s.name),'[]'::jsonb) value from public.product_subcategories s where s.status='active'),
product_variants as (select coalesce(jsonb_agg(to_jsonb(v) order by v.product_id,v.sort_order,v.code),'[]'::jsonb) value from public.product_variants v where v.status='active'),
booklets as (select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at desc),'[]'::jsonb) value from public.alin_public_booklets b),
products as (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc),'[]'::jsonb) value from public.products p),
banners as (select coalesce(jsonb_agg(to_jsonb(b) order by b.sort_order nulls last,b.created_at desc),'[]'::jsonb) value from public.banners b),
coupons as (select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at desc),'[]'::jsonb) value from public.coupons c where c.bound_student_id is null)
select jsonb_build_object(
  'settings',(select value from settings_obj),
  'accounts',jsonb_build_object('all','[]'::jsonb,'teachers',(select value from teachers),'libraries',(select value from libraries),'couriers','[]'::jsonb,'accountants','[]'::jsonb),
  'deliveryAreas',(select value from delivery_areas),'categories',(select value from categories),
  'productSubcategories',(select value from product_subcategories),'productVariants',(select value from product_variants),
  'booklets',(select value from booklets),'products',(select value from products),'banners',(select value from banners),
  'coupons',(select value from coupons),'notifications','[]'::jsonb
);
$function$;

create or replace function public.alin_validate_order_personal_coupon()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare v_bound text; v_session_student text:=nullif(current_setting('alin.checkout_student_id',true),'');
begin
  if nullif(btrim(coalesce(new.coupon_code,'')),'') is null then return new; end if;
  select c.bound_student_id into v_bound from public.coupons c where lower(c.code)=lower(btrim(new.coupon_code)) limit 1;
  if v_bound is not null and v_session_student is distinct from v_bound then
    raise exception 'هذا العرض مخصص لحساب طالب محدد. سجل الدخول بالحساب الذي استلم العرض.';
  end if;
  return new;
end
$function$;
drop trigger if exists orders_validate_personal_coupon on public.orders;
create trigger orders_validate_personal_coupon before insert on public.orders
for each row execute function public.alin_validate_order_personal_coupon();

create or replace function public.alin_create_store_orders_guarded(
  p_items jsonb,p_customer jsonb,p_fulfillment jsonb,p_coupon_code text,p_request_key text,p_device_id text,
  p_student_token text,p_student_device text
)
returns table(order_number text,order_id text)
language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare
  v_student_id text:=public.alin_student_session_id(p_student_token,p_student_device);
  v_profile public.student_profiles%rowtype; v_customer_phone text;
begin
  if v_student_id is null then raise exception 'جلسة الطالب منتهية. سجل الدخول مرة ثانية.'; end if;
  select * into v_profile from public.student_profiles where id=v_student_id;
  if not found then raise exception 'حساب الطالب غير موجود'; end if;
  v_customer_phone:=regexp_replace(translate(btrim(coalesce(p_customer->>'phone','')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g');
  if v_customer_phone<>v_profile.phone then raise exception 'رقم الطلب لا يطابق حساب الطالب المسجل'; end if;
  perform set_config('alin.checkout_student_id',v_student_id,true);
  update public.student_profiles set last_active_at=now(),updated_at=now() where id=v_student_id;
  return query select * from public.alin_create_store_orders_guarded(p_items,p_customer,p_fulfillment,p_coupon_code,p_request_key,p_device_id);
end
$function$;
revoke all on function public.alin_create_store_orders_guarded(jsonb,jsonb,jsonb,text,text,text,text,text) from public;
grant execute on function public.alin_create_store_orders_guarded(jsonb,jsonb,jsonb,text,text,text,text,text) to anon,authenticated;

create or replace function public.alin_student_personal_offers(p_token text,p_device text)
returns jsonb language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare v_id text:=public.alin_student_session_id(p_token,p_device); v_rows jsonb;
begin
  if v_id is null then raise exception 'جلسة الطالب منتهية'; end if;
  update public.student_profiles
  set last_active_at=case when last_active_at is null or last_active_at<now()-interval '5 minutes' then now() else last_active_at end,
      updated_at=case when last_active_at is null or last_active_at<now()-interval '5 minutes' then now() else updated_at end
  where id=v_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'code',c.code,'discount_type',c.discount_type,'discount_value',c.discount_value,'applies_to',c.applies_to,
    'status',c.status,'starts_at',c.starts_at,'expires_at',c.expires_at,'max_uses',c.max_uses,'used_count',c.used_count,
    'usage_count',c.usage_count,'min_order',c.min_order,'max_discount',c.max_discount,'bound_student_id',c.bound_student_id,
    'personal_offer',true,'offer_title',coalesce(c.offer_title,'عرض خاص لك'),'offer_message',coalesce(c.offer_message,''),
    'offer_seen_at',c.offer_seen_at,'created_at',c.created_at
  ) order by c.created_at desc),'[]'::jsonb) into v_rows
  from public.coupons c
  where c.bound_student_id=v_id and c.personal_offer and c.status='active'
    and (c.starts_at is null or c.starts_at<=now()) and (c.expires_at is null or c.expires_at>=now())
    and (c.max_uses=0 or c.used_count<c.max_uses);
  return v_rows;
end
$function$;
revoke all on function public.alin_student_personal_offers(text,text) from public;
grant execute on function public.alin_student_personal_offers(text,text) to anon,authenticated;

create or replace function public.alin_student_mark_offer_seen(p_token text,p_device text,p_coupon_id text)
returns boolean language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare v_id text:=public.alin_student_session_id(p_token,p_device);
begin
  if v_id is null then raise exception 'جلسة الطالب منتهية'; end if;
  update public.coupons set offer_seen_at=coalesce(offer_seen_at,now()),updated_at=now()
  where id=p_coupon_id and bound_student_id=v_id and personal_offer;
  return found;
end
$function$;
revoke all on function public.alin_student_mark_offer_seen(text,text,text) from public;
grant execute on function public.alin_student_mark_offer_seen(text,text,text) to anon,authenticated;

create or replace function public.alin_admin_student_retention(p_days integer default 30,p_search text default null)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare v_days integer:=greatest(0,least(coalesce(p_days,30),3650)); v_search text:=lower(btrim(coalesce(p_search,'')));
  v_rows jsonb; v_registered integer; v_inactive integer;
begin
  if not public.alin_is_admin() then raise exception 'غير مسموح'; end if;
  select count(*) into v_registered from public.student_profiles;
  select count(*) into v_inactive from public.student_profiles p
    where coalesce(p.last_active_at,p.last_login_at,p.created_at)<=now()-(v_days||' days')::interval;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.days_inactive desc,q.name),'[]'::jsonb) into v_rows
  from (
    select p.id,p.name,p.phone,p.grade,p.created_at,p.last_login_at,p.last_active_at,p.last_offer_at,
      floor(extract(epoch from (now()-coalesce(p.last_active_at,p.last_login_at,p.created_at)))/86400)::integer as days_inactive,
      coalesce(o.order_count,0)::integer as order_count,o.last_order_at,
      ac.code as active_offer_code,ac.expires_at as active_offer_expires_at,ac.discount_type as active_offer_type,ac.discount_value as active_offer_value
    from public.student_profiles p
    left join lateral (select count(*)::integer order_count,max(ord.created_at) last_order_at from public.orders ord where ord.student_id=p.id) o on true
    left join lateral (
      select c.code,c.expires_at,c.discount_type,c.discount_value from public.coupons c
      where c.bound_student_id=p.id and c.personal_offer and c.status='active'
        and (c.expires_at is null or c.expires_at>=now()) and (c.max_uses=0 or c.used_count<c.max_uses)
      order by c.created_at desc limit 1
    ) ac on true
    where coalesce(p.last_active_at,p.last_login_at,p.created_at)<=now()-(v_days||' days')::interval
      and (v_search='' or lower(p.name) like '%'||v_search||'%' or lower(p.phone) like '%'||v_search||'%')
  ) q;
  return jsonb_build_object('days',v_days,'stats',jsonb_build_object('registered',v_registered,'inactive',v_inactive),'rows',v_rows);
end
$function$;
revoke all on function public.alin_admin_student_retention(integer,text) from public;
grant execute on function public.alin_admin_student_retention(integer,text) to authenticated;

-- Initial creator; migration 011 upgrades this function to enforce one active offer per student.
create or replace function public.alin_admin_create_student_offer(
  p_student_id text,p_discount_type text,p_discount_value numeric,p_days_valid integer default 3,
  p_applies_to text default 'all',p_title text default null,p_message text default null
)
returns jsonb language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare
  v_student public.student_profiles%rowtype; v_type text:=lower(btrim(coalesce(p_discount_type,'percent')));
  v_value numeric:=coalesce(p_discount_value,0); v_days integer:=greatest(1,least(coalesce(p_days_valid,3),30));
  v_applies text:=lower(btrim(coalesce(p_applies_to,'all'))); v_code text;
  v_coupon_id text:='CP'||replace(extensions.gen_random_uuid()::text,'-',''); v_title text; v_message text; v_try integer:=0;
begin
  if not public.alin_is_admin() then raise exception 'غير مسموح'; end if;
  select * into v_student from public.student_profiles where id=p_student_id;
  if not found then raise exception 'حساب الطالب غير موجود'; end if;
  if v_type not in ('percent','fixed') then raise exception 'نوع الخصم غير صحيح'; end if;
  if v_value<=0 then raise exception 'قيمة الخصم يجب أن تكون أكبر من صفر'; end if;
  if v_type='percent' and v_value>100 then raise exception 'نسبة الخصم لا تتجاوز 100%%'; end if;
  if v_applies not in ('all','booklet','stationery','gift') then raise exception 'القسم المحدد للخصم غير صحيح'; end if;
  loop
    v_try:=v_try+1; v_code:='ALIN-'||upper(substr(replace(extensions.gen_random_uuid()::text,'-',''),1,8));
    exit when not exists(select 1 from public.coupons where lower(code)=lower(v_code));
    if v_try>=5 then raise exception 'تعذر إنشاء كود فريد. حاول مرة أخرى'; end if;
  end loop;
  v_title:=left(coalesce(nullif(btrim(p_title),''),'اشتقنالك في منصة آلين 🎁'),160);
  v_message:=left(coalesce(nullif(btrim(p_message),''),'عندك خصم خاص '||case when v_type='percent' then trim(to_char(v_value,'FM999999990.##'))||'%' else trim(to_char(v_value,'FM999999990.##'))||' د.ع' end||' صالح لمدة '||v_days||' يوم.'),500);
  insert into public.coupons(id,code,discount_type,discount_value,applies_to,status,starts_at,expires_at,max_uses,used_count,usage_count,min_order,max_discount,note,bound_student_id,personal_offer,offer_title,offer_message,offer_seen_at)
  values(v_coupon_id,v_code,v_type,v_value,v_applies,'active',now(),now()+(v_days||' days')::interval,1,0,0,0,0,'عرض استرجاع عميل مسجل',v_student.id,true,v_title,v_message,null);
  update public.student_profiles set last_offer_at=now(),updated_at=now() where id=v_student.id;
  insert into public.notifications(id,title,message,role,account_id,type,link,status,is_read,created_by,expires_at)
  values('NT'||replace(extensions.gen_random_uuid()::text,'-',''),v_title,v_message,'student',v_student.id,'personal_offer','coupon:'||v_coupon_id,'active',false,'admin',now()+(v_days||' days')::interval);
  return jsonb_build_object('ok',true,'student',jsonb_build_object('id',v_student.id,'name',v_student.name,'phone',v_student.phone),'coupon',jsonb_build_object('id',v_coupon_id,'code',v_code,'discount_type',v_type,'discount_value',v_value,'applies_to',v_applies,'expires_at',now()+(v_days||' days')::interval,'offer_title',v_title,'offer_message',v_message));
end
$function$;
revoke all on function public.alin_admin_create_student_offer(text,text,numeric,integer,text,text,text) from public;
grant execute on function public.alin_admin_create_student_offer(text,text,numeric,integer,text,text,text) to authenticated;
