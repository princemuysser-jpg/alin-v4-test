-- ALIN v4.2.0 RC3 — Step 3
-- Atomic server-side login attempt protection. Safe to run once; CREATE OR REPLACE is idempotent.
begin;

create or replace function public.alin_login_guard_check(p_identifier text,p_device text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  v_i text:=public.alin_login_guard_key(p_identifier);
  v_d text:=public.alin_login_guard_key(p_device);
  g public.auth_login_guard%rowtype;
  v_attempts integer;
  v_lock timestamptz;
begin
  select * into g from public.auth_login_guard
  where identifier_hash=v_i and device_hash=v_d
  for update;

  if found and g.locked_until is not null and g.locked_until>now() then
    return jsonb_build_object(
      'allowed',false,
      'retry_after_seconds',greatest(1,extract(epoch from (g.locked_until-now()))::integer),
      'remaining',0
    );
  end if;

  if not found then
    v_attempts:=1;
    v_lock:=null;
    insert into public.auth_login_guard(identifier_hash,device_hash,failed_attempts,locked_until,last_failed_at,updated_at)
    values(v_i,v_d,v_attempts,v_lock,now(),now());
  else
    if g.last_failed_at is null or g.last_failed_at < now()-interval '15 minutes' then
      v_attempts:=1;
    else
      v_attempts:=coalesce(g.failed_attempts,0)+1;
    end if;
    v_lock:=case when v_attempts>=5 then now()+interval '15 minutes' else null end;
    update public.auth_login_guard
       set failed_attempts=v_attempts,
           locked_until=v_lock,
           last_failed_at=now(),
           updated_at=now()
     where identifier_hash=v_i and device_hash=v_d;
  end if;

  -- The current reserved attempt is allowed, including attempt 5. If attempt 5 fails,
  -- alin_login_guard_fail reports the already-created 15-minute lock.
  return jsonb_build_object(
    'allowed',true,
    'remaining',greatest(0,5-v_attempts),
    'retry_after_seconds',case when v_lock is not null then greatest(1,extract(epoch from (v_lock-now()))::integer) else 0 end
  );
end $$;

create or replace function public.alin_login_guard_fail(p_identifier text,p_device text)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare
  v_i text:=public.alin_login_guard_key(p_identifier);
  v_d text:=public.alin_login_guard_key(p_device);
  g public.auth_login_guard%rowtype;
begin
  select * into g from public.auth_login_guard
  where identifier_hash=v_i and device_hash=v_d;

  if not found then
    return jsonb_build_object('allowed',true,'remaining',4,'retry_after_seconds',0);
  end if;

  return jsonb_build_object(
    'allowed',not(g.locked_until is not null and g.locked_until>now()),
    'remaining',greatest(0,5-coalesce(g.failed_attempts,0)),
    'retry_after_seconds',case when g.locked_until is not null and g.locked_until>now() then greatest(1,extract(epoch from (g.locked_until-now()))::integer) else 0 end
  );
end $$;

create or replace function public.alin_login_guard_success(p_identifier text,p_device text)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  delete from public.auth_login_guard
  where identifier_hash=public.alin_login_guard_key(p_identifier)
    and device_hash=public.alin_login_guard_key(p_device);
  return true;
end $$;

revoke execute on function public.alin_login_guard_check(text,text) from public,anon,authenticated;
revoke execute on function public.alin_login_guard_fail(text,text) from public,anon,authenticated;
revoke execute on function public.alin_login_guard_success(text,text) from public,anon,authenticated;
grant execute on function public.alin_login_guard_check(text,text) to service_role;
grant execute on function public.alin_login_guard_fail(text,text) to service_role;
grant execute on function public.alin_login_guard_success(text,text) to service_role;

commit;
