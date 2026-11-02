-- ALIN Business browser push subscriptions. Never expose business endpoints to students.
create table if not exists private.business_web_push_subscriptions (
  endpoint text primary key,
  p256dh text not null,
  auth text not null,
  account_id text not null references public.accounts(id) on delete cascade,
  account_role text not null,
  auth_user_id uuid not null,
  user_agent text,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index if not exists business_web_push_recipient_idx
  on private.business_web_push_subscriptions(account_role,account_id,status);
alter table private.business_web_push_subscriptions enable row level security;
revoke all on private.business_web_push_subscriptions from public, anon, authenticated;

create or replace function public.alin_register_business_web_push(
  p_endpoint text,p_p256dh text,p_auth text,p_user_agent text default null)
returns jsonb
language plpgsql security definer
set search_path = public, private, pg_temp
as $$
declare
  v_account public.accounts%rowtype;
  v_role text;
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  if p_endpoint !~ '^https://' or length(p_endpoint)>2048 then raise exception 'رابط الاشتراك غير صالح'; end if;
  if length(coalesce(p_p256dh,'')) not between 40 and 300
    or length(coalesce(p_auth,'')) not between 8 and 200
    then raise exception 'مفاتيح الاشتراك غير صالحة'; end if;
  select * into v_account from public.accounts
   where auth_user_id=auth.uid() and status='active' and deleted_at is null limit 1;
  if not found then raise exception 'حساب الأعمال غير نشط'; end if;
  v_role:=lower(coalesce(v_account.role,''));
  if v_role='delegate' then v_role:='courier'; end if;
  if v_role not in ('admin','accountant','teacher','library','printer','courier')
    then raise exception 'الحساب غير مصرح له بالإشعارات'; end if;
  insert into private.business_web_push_subscriptions
    (endpoint,p256dh,auth,account_id,account_role,auth_user_id,user_agent,status,last_seen_at,updated_at)
  values
    (p_endpoint,p_p256dh,p_auth,v_account.id,v_role,auth.uid(),left(coalesce(p_user_agent,''),500),'active',now(),now())
  on conflict(endpoint) do update set
    p256dh=excluded.p256dh,auth=excluded.auth,
    account_id=excluded.account_id,account_role=excluded.account_role,
    auth_user_id=excluded.auth_user_id,user_agent=excluded.user_agent,
    status='active',last_seen_at=now(),updated_at=now();
  return jsonb_build_object('ok',true,'role',v_role);
end
$$;
revoke all on function public.alin_register_business_web_push(text,text,text,text) from public, anon;
grant execute on function public.alin_register_business_web_push(text,text,text,text) to authenticated;

create or replace function public.alin_unregister_business_web_push(p_endpoint text)
returns boolean
language plpgsql security definer
set search_path=public,private,pg_temp
as $$
begin
  if auth.uid() is null then raise exception 'يجب تسجيل الدخول أولاً'; end if;
  update private.business_web_push_subscriptions
     set status='inactive',updated_at=now()
   where endpoint=p_endpoint and auth_user_id=auth.uid();
  return found;
end
$$;
revoke all on function public.alin_unregister_business_web_push(text) from public, anon;
grant execute on function public.alin_unregister_business_web_push(text) to authenticated;

create or replace function public.alin_business_web_push_targets(p_role text,p_account_id text default null)
returns table(endpoint text,p256dh text,auth text)
language plpgsql security definer
set search_path=public,private,pg_temp
as $$
begin
  if lower(coalesce(p_role,'')) not in ('admin','accountant','teacher','library','printer','courier')
     then raise exception 'Invalid target role'; end if;
  return query
    select s.endpoint,s.p256dh,s.auth
    from private.business_web_push_subscriptions s
    join public.accounts a on a.id=s.account_id
    where s.status='active' and a.status='active' and a.deleted_at is null
      and s.account_role=lower(p_role)
      and (nullif(p_account_id,'') is null or s.account_id=p_account_id)
      and a.auth_user_id=s.auth_user_id;
end
$$;
revoke all on function public.alin_business_web_push_targets(text,text) from public, anon, authenticated;
grant execute on function public.alin_business_web_push_targets(text,text) to service_role;

create or replace function public.alin_disable_business_web_push_endpoint(p_endpoint text)
returns boolean
language plpgsql security definer
set search_path=public,private,pg_temp
as $$
begin
  update private.business_web_push_subscriptions
    set status='inactive', updated_at=now() where endpoint=p_endpoint;
  return found;
end
$$;
revoke all on function public.alin_disable_business_web_push_endpoint(text) from public, anon, authenticated;
grant execute on function public.alin_disable_business_web_push_endpoint(text) to service_role;
