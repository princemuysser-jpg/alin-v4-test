-- ALIN 5.3.0 security / publish readiness.
-- Production migration applied on 2026-08-19.

create schema if not exists private;

create table if not exists private.student_erasure_tombstones (
  phone_hash text primary key,
  requested_at timestamptz not null default now()
);
revoke all on table private.student_erasure_tombstones from public, anon, authenticated;

create table if not exists private.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  phone_hash text not null,
  phone_last4 text not null default '',
  ip_hash text not null,
  status text not null default 'pending' check (status in ('pending','verified','completed','rejected')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  note text
);
create index if not exists account_deletion_requests_phone_time_idx on private.account_deletion_requests(phone_hash, requested_at desc);
create index if not exists account_deletion_requests_ip_time_idx on private.account_deletion_requests(ip_hash, requested_at desc);
revoke all on table private.account_deletion_requests from public, anon, authenticated;

update public.student_sessions
set expires_at=now()+interval '30 days'
where revoked_at is null and expires_at is null;

create or replace function private.alin_enforce_student_session_expiry()
returns trigger language plpgsql
set search_path to 'public','private','pg_temp'
as $function$
begin
  if new.expires_at is null then new.expires_at:=now()+interval '30 days'; end if;
  return new;
end
$function$;
revoke all on function private.alin_enforce_student_session_expiry() from public, anon, authenticated;
drop trigger if exists student_sessions_enforce_expiry on public.student_sessions;
create trigger student_sessions_enforce_expiry before insert on public.student_sessions
for each row execute function private.alin_enforce_student_session_expiry();

create or replace function private.alin_anonymize_erased_student_order()
returns trigger language plpgsql security definer
set search_path to 'public','private','extensions','pg_temp'
as $function$
declare v_phone text; v_hash text;
begin
  if lower(coalesce(new.status,'')) not in ('completed','cancelled','canceled','rejected','delivered','refunded') then return new; end if;
  v_phone:=regexp_replace(translate(btrim(coalesce(new.student_phone,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g');
  if v_phone='' or new.student_phone='محذوف' then return new; end if;
  v_hash:=encode(extensions.digest('alin-erasure-v1:'||v_phone,'sha256'),'hex');
  if exists(select 1 from private.student_erasure_tombstones where phone_hash=v_hash) then
    new.student_id:=null; new.student_name:='حساب محذوف'; new.student_phone:='محذوف'; new.notes:=null;
    new.delivery_landmark:=null; new.delivery_latitude:=null; new.delivery_longitude:=null;
    new.delivery_location_url:=null; new.delivery_location_accuracy:=null; new.delivery_location_source:=null;
  end if;
  return new;
end
$function$;
revoke all on function private.alin_anonymize_erased_student_order() from public, anon, authenticated;
drop trigger if exists orders_anonymize_erased_student on public.orders;
create trigger orders_anonymize_erased_student before update on public.orders
for each row execute function private.alin_anonymize_erased_student_order();

create or replace function public.alin_student_delete_account(p_token text,p_device text,p_pin text)
returns jsonb language plpgsql security definer
set search_path to 'public','private','extensions','pg_temp'
as $function$
declare
  v_id text:=public.alin_student_session_id(p_token,p_device);
  v_phone text; v_phone_hash text; v_checkout_hash text; v_account public.student_accounts%rowtype;
begin
  if v_id is null then raise exception 'جلسة الطالب منتهية. سجل الدخول مرة ثانية.'; end if;
  if length(coalesce(p_pin,''))<6 then raise exception 'اكتب الرمز السري لتأكيد حذف الحساب'; end if;
  select phone into v_phone from public.student_profiles where id=v_id for update;
  if not found then raise exception 'حساب الطالب غير موجود'; end if;
  select * into v_account from public.student_accounts where student_id=v_id for update;
  if not found or v_account.pin_hash<>extensions.crypt(p_pin,v_account.pin_hash) then raise exception 'الرمز السري غير صحيح'; end if;
  v_phone:=regexp_replace(translate(btrim(coalesce(v_phone,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g');
  v_phone_hash:=encode(extensions.digest('alin-erasure-v1:'||v_phone,'sha256'),'hex');
  v_checkout_hash:=encode(extensions.digest('alin-phone-v4:'||v_phone,'sha256'),'hex');
  insert into private.student_erasure_tombstones(phone_hash,requested_at) values(v_phone_hash,now())
  on conflict(phone_hash) do update set requested_at=excluded.requested_at;
  delete from public.notifications where role='student' and account_id=v_id;
  delete from public.push_subscriptions where student_id=v_id;
  update public.product_reviews set student_contact=null where regexp_replace(translate(btrim(coalesce(student_contact,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g')=v_phone;
  update public.stock_alerts set contact=null where regexp_replace(translate(btrim(coalesce(contact,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g')=v_phone;
  update public.group_order_members set contact=null where regexp_replace(translate(btrim(coalesce(contact,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g')=v_phone;
  update public.group_orders set owner_contact=null where regexp_replace(translate(btrim(coalesce(owner_contact,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g')=v_phone;
  delete from public.checkout_requests where phone_hash=v_checkout_hash;
  update public.orders set student_id=null,student_name='حساب محذوف',student_phone='محذوف',notes=null,
    delivery_landmark=null,delivery_latitude=null,delivery_longitude=null,delivery_location_url=null,
    delivery_location_accuracy=null,delivery_location_source=null
  where (student_id=v_id or regexp_replace(translate(btrim(coalesce(student_phone,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g')=v_phone)
    and lower(coalesce(status,'')) in ('completed','cancelled','canceled','rejected','delivered','refunded');
  delete from public.student_profiles where id=v_id;
  return jsonb_build_object('ok',true,'message','تم حذف حسابك وبيانات الحساب. بيانات الطلبات النشطة تبقى فقط لإكمال الطلب ثم تُزال تلقائياً.');
end
$function$;
revoke execute on function public.alin_student_delete_account(text,text,text) from public;
grant execute on function public.alin_student_delete_account(text,text,text) to anon,authenticated;

-- Least privilege: admin helpers are not public/anon.
revoke execute on function public.alin_admin_create_student_offer(text,text,numeric,integer,text,text,text) from public,anon;
revoke execute on function public.alin_admin_student_customers(integer,text,text) from public,anon;
revoke execute on function public.alin_admin_student_retention(integer,text) from public,anon;
revoke execute on function public.alin_push_subscription_stats() from public,anon;
revoke execute on function public.alin_current_account_id() from public,anon;
revoke execute on function public.alin_current_role() from public,anon;
revoke execute on function public.alin_is_admin() from public,anon;

-- Internal trigger/helper functions are never callable via PostgREST RPC.
revoke execute on function public.alin_protect_booklet_profit_snapshot() from public,anon,authenticated;
revoke execute on function public.alin_protect_product_variant_snapshot() from public,anon,authenticated;
revoke execute on function public.alin_recompute_product_variant_stock(text) from public,anon,authenticated;
revoke execute on function public.alin_snapshot_booklet_profit_shares() from public,anon,authenticated;
revoke execute on function public.alin_student_session_activity_stamp() from public,anon,authenticated;
revoke execute on function public.alin_sync_product_variant_stock() from public,anon,authenticated;
revoke execute on function public.alin_validate_order_personal_coupon() from public,anon,authenticated;
