-- ALIN v4.2.0 — unified customer directory: active + inactive registered students.
create or replace function public.alin_admin_student_customers(
  p_days integer default 30,
  p_mode text default 'all',
  p_search text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','pg_temp'
as $function$
declare
  v_days integer:=greatest(1,least(coalesce(p_days,30),3650));
  v_mode text:=lower(btrim(coalesce(p_mode,'all')));
  v_search text:=lower(btrim(coalesce(p_search,'')));
  v_registered integer;
  v_active integer;
  v_inactive integer;
  v_rows jsonb;
begin
  if not public.alin_is_admin() then raise exception 'غير مسموح'; end if;
  if v_mode not in ('all','active','inactive') then v_mode:='all'; end if;

  select
    count(*),
    count(*) filter(where coalesce(p.last_active_at,p.last_login_at,p.created_at)>now()-(v_days||' days')::interval),
    count(*) filter(where coalesce(p.last_active_at,p.last_login_at,p.created_at)<=now()-(v_days||' days')::interval)
  into v_registered,v_active,v_inactive
  from public.student_profiles p;

  select coalesce(jsonb_agg(to_jsonb(q) order by q.is_active desc,q.days_inactive asc,q.name),'[]'::jsonb)
  into v_rows
  from (
    select
      p.id,p.name,p.phone,p.grade,p.created_at,p.last_login_at,p.last_active_at,p.last_offer_at,
      floor(extract(epoch from (now()-coalesce(p.last_active_at,p.last_login_at,p.created_at)))/86400)::integer as days_inactive,
      (coalesce(p.last_active_at,p.last_login_at,p.created_at)>now()-(v_days||' days')::interval) as is_active,
      coalesce(o.order_count,0)::integer as order_count,
      o.last_order_at,
      ac.code as active_offer_code,
      ac.expires_at as active_offer_expires_at,
      ac.discount_type as active_offer_type,
      ac.discount_value as active_offer_value
    from public.student_profiles p
    left join lateral (
      select count(*)::integer order_count,max(ord.created_at) last_order_at
      from public.orders ord where ord.student_id=p.id
    ) o on true
    left join lateral (
      select c.code,c.expires_at,c.discount_type,c.discount_value
      from public.coupons c
      where c.bound_student_id=p.id
        and c.personal_offer
        and c.status='active'
        and (c.expires_at is null or c.expires_at>=now())
        and (c.max_uses=0 or c.used_count<c.max_uses)
      order by c.created_at desc limit 1
    ) ac on true
    where
      (v_search='' or lower(p.name) like '%'||v_search||'%' or lower(p.phone) like '%'||v_search||'%')
      and (
        v_mode='all'
        or (v_mode='active' and coalesce(p.last_active_at,p.last_login_at,p.created_at)>now()-(v_days||' days')::interval)
        or (v_mode='inactive' and coalesce(p.last_active_at,p.last_login_at,p.created_at)<=now()-(v_days||' days')::interval)
      )
  ) q;

  return jsonb_build_object(
    'days',v_days,
    'mode',v_mode,
    'stats',jsonb_build_object('registered',v_registered,'active',v_active,'inactive',v_inactive),
    'rows',v_rows
  );
end
$function$;

revoke all on function public.alin_admin_student_customers(integer,text,text) from public;
grant execute on function public.alin_admin_student_customers(integer,text,text) to authenticated;
