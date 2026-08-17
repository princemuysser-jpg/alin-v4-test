-- ALIN v4.2.0 — Web Push schema/RPCs for guest and registered-student devices.
-- Security note: the VAPID private key is intentionally NOT hardcoded in source control.
-- admin-send-push reads VAPID_PUBLIC_KEY/VAPID_PRIVATE_KEY environment secrets first and
-- can fall back to push_config on an existing production deployment.

create table if not exists public.push_config (
  id text primary key,
  vapid_public_key text,
  vapid_private_key text,
  subject text not null default 'mailto:admin@alinplatform.com',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.push_config enable row level security;
revoke all on public.push_config from anon,authenticated;

insert into public.push_config(id,vapid_public_key,vapid_private_key,subject)
select 'main','BI-mAjJvDZXH9HEus8ypbEs85J4c47DL9CRibbrT54KYsFygUVbm1B2lYaDnnFKPqLSXmy6lv1rwBvU7dzjrzwc',null,'mailto:admin@alinplatform.com'
where not exists(select 1 from public.push_config where id='main');
update public.push_config
set vapid_public_key='BI-mAjJvDZXH9HEus8ypbEs85J4c47DL9CRibbrT54KYsFygUVbm1B2lYaDnnFKPqLSXmy6lv1rwBvU7dzjrzwc',updated_at=now()
where id='main';

create table if not exists public.push_subscriptions (
  id uuid primary key default extensions.gen_random_uuid(),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  role text not null default 'student',
  student_id text references public.student_profiles(id) on delete set null,
  user_agent text,
  status text not null default 'active' check(status in ('active','inactive')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint push_subscriptions_endpoint_https check(endpoint ~ '^https://'),
  constraint push_subscriptions_key_lengths check(length(p256dh) between 40 and 300 and length(auth) between 8 and 200)
);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon,authenticated;
create index if not exists push_subscriptions_target_idx on public.push_subscriptions(role,student_id,status);
create index if not exists push_subscriptions_last_seen_idx on public.push_subscriptions(last_seen_at desc);

create or replace function public.alin_push_public_key()
returns text language sql stable security definer set search_path to 'public','pg_temp' as $function$
  select vapid_public_key from public.push_config where id='main'
$function$;
revoke all on function public.alin_push_public_key() from public;
grant execute on function public.alin_push_public_key() to anon,authenticated;

create or replace function public.alin_register_push_subscription(
  p_endpoint text,p_p256dh text,p_auth text,p_user_agent text default null,
  p_student_token text default null,p_student_device text default null
)
returns jsonb language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare
  v_endpoint text:=btrim(coalesce(p_endpoint,'')); v_p256dh text:=btrim(coalesce(p_p256dh,''));
  v_auth text:=btrim(coalesce(p_auth,'')); v_student_id text; v_row public.push_subscriptions%rowtype;
begin
  if v_endpoint !~ '^https://' or length(v_endpoint)>2048 then raise exception 'اشتراك الإشعارات غير صالح'; end if;
  if length(v_p256dh) not between 40 and 300 or length(v_auth) not between 8 and 200 then raise exception 'مفاتيح الإشعارات غير صالحة'; end if;
  if nullif(btrim(coalesce(p_student_token,'')),'') is not null then
    v_student_id:=public.alin_student_session_id(p_student_token,p_student_device);
    if v_student_id is null then raise exception 'جلسة الطالب منتهية'; end if;
  end if;
  insert into public.push_subscriptions(endpoint,p256dh,auth,role,student_id,user_agent,status,last_seen_at)
  values(v_endpoint,v_p256dh,v_auth,'student',v_student_id,left(coalesce(p_user_agent,''),500),'active',now())
  on conflict(endpoint) do update set p256dh=excluded.p256dh,auth=excluded.auth,role='student',student_id=excluded.student_id,
    user_agent=excluded.user_agent,status='active',last_seen_at=now(),updated_at=now()
  returning * into v_row;
  return jsonb_build_object('ok',true,'id',v_row.id,'student_id',v_row.student_id,'status',v_row.status);
end
$function$;
revoke all on function public.alin_register_push_subscription(text,text,text,text,text,text) from public;
grant execute on function public.alin_register_push_subscription(text,text,text,text,text,text) to anon,authenticated;

create or replace function public.alin_unregister_push_subscription(p_endpoint text)
returns boolean language plpgsql security definer set search_path to 'public','pg_temp' as $function$
begin
  update public.push_subscriptions set status='inactive',updated_at=now() where endpoint=btrim(coalesce(p_endpoint,''));
  return true;
end
$function$;
revoke all on function public.alin_unregister_push_subscription(text) from public;
grant execute on function public.alin_unregister_push_subscription(text) to anon,authenticated;

create or replace function public.alin_push_subscription_stats()
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare v_total integer; v_registered integer; v_guests integer;
begin
  if not public.alin_is_admin() then raise exception 'غير مسموح'; end if;
  select count(*),count(*) filter(where student_id is not null),count(*) filter(where student_id is null)
    into v_total,v_registered,v_guests from public.push_subscriptions where status='active';
  return jsonb_build_object('active_devices',v_total,'registered_student_devices',v_registered,'guest_devices',v_guests,'general_push_targets',v_total);
end
$function$;
revoke all on function public.alin_push_subscription_stats() from public;
grant execute on function public.alin_push_subscription_stats() to authenticated;
