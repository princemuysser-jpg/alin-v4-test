-- ALIN — group one checkout as one courier delivery while keeping item rows intact.
-- Assignment, courier transitions and courier notes are applied atomically to all rows
-- sharing checkout_group_id (or checkout_request_key for legacy checkouts).

begin;

create or replace function public.alin_admin_assign_order_group(
  p_order_id text,
  p_courier_id text default null,
  p_library_id text default null
)
returns jsonb
language plpgsql
security invoker
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  v_seed public.orders%rowtype;
  v_group_id text;
  v_request_key text;
  v_ids text[];
  v_id text;
  v_results jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  select * into v_seed from public.orders where id=p_order_id;
  if not found then raise exception 'الطلب غير موجود'; end if;

  v_group_id:=nullif(btrim(coalesce(v_seed.checkout_group_id,'')),'');
  v_request_key:=nullif(btrim(coalesce(v_seed.checkout_request_key,'')),'');

  if v_group_id is not null then
    select array_agg(id order by created_at,id) into v_ids
    from public.orders where checkout_group_id=v_group_id;
  elsif v_request_key is not null then
    select array_agg(id order by created_at,id) into v_ids
    from public.orders where checkout_request_key=v_request_key;
  else
    v_ids:=array[p_order_id];
  end if;

  foreach v_id in array v_ids loop
    v_result:=public.alin_admin_assign_order(v_id,p_courier_id,p_library_id);
    v_results:=v_results||jsonb_build_array(v_result);
  end loop;

  return jsonb_build_object(
    'ok',true,
    'group_key',coalesce(v_group_id,v_request_key,p_order_id),
    'order_ids',to_jsonb(v_ids),
    'count',coalesce(array_length(v_ids,1),0),
    'results',v_results
  );
end
$function$;

create or replace function public.alin_order_transition_group(
  p_order_id text,
  p_status text,
  p_reason text default null
)
returns jsonb
language plpgsql
security invoker
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  v_seed public.orders%rowtype;
  v_group_id text;
  v_request_key text;
  v_ids text[];
  v_id text;
  v_results jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  select * into v_seed from public.orders where id=p_order_id;
  if not found then raise exception 'الطلب غير موجود'; end if;

  v_group_id:=nullif(btrim(coalesce(v_seed.checkout_group_id,'')),'');
  v_request_key:=nullif(btrim(coalesce(v_seed.checkout_request_key,'')),'');

  if v_group_id is not null then
    select array_agg(id order by created_at,id) into v_ids
    from public.orders where checkout_group_id=v_group_id;
  elsif v_request_key is not null then
    select array_agg(id order by created_at,id) into v_ids
    from public.orders where checkout_request_key=v_request_key;
  else
    v_ids:=array[p_order_id];
  end if;

  foreach v_id in array v_ids loop
    v_result:=public.alin_order_transition_atomic(v_id,p_status,p_reason);
    v_results:=v_results||jsonb_build_array(v_result);
  end loop;

  return jsonb_build_object(
    'ok',true,
    'group_key',coalesce(v_group_id,v_request_key,p_order_id),
    'order_ids',to_jsonb(v_ids),
    'count',coalesce(array_length(v_ids,1),0),
    'status',lower(btrim(coalesce(p_status,''))),
    'results',v_results
  );
end
$function$;

create or replace function public.alin_courier_set_order_note_group(
  p_order_id text,
  p_note text
)
returns jsonb
language plpgsql
security invoker
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  v_seed public.orders%rowtype;
  v_group_id text;
  v_request_key text;
  v_ids text[];
  v_id text;
  v_results jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  select * into v_seed from public.orders where id=p_order_id;
  if not found then raise exception 'الطلب غير موجود'; end if;

  v_group_id:=nullif(btrim(coalesce(v_seed.checkout_group_id,'')),'');
  v_request_key:=nullif(btrim(coalesce(v_seed.checkout_request_key,'')),'');

  if v_group_id is not null then
    select array_agg(id order by created_at,id) into v_ids
    from public.orders where checkout_group_id=v_group_id;
  elsif v_request_key is not null then
    select array_agg(id order by created_at,id) into v_ids
    from public.orders where checkout_request_key=v_request_key;
  else
    v_ids:=array[p_order_id];
  end if;

  foreach v_id in array v_ids loop
    v_result:=public.alin_courier_set_order_note(v_id,p_note);
    v_results:=v_results||jsonb_build_array(v_result);
  end loop;

  return jsonb_build_object(
    'ok',true,
    'group_key',coalesce(v_group_id,v_request_key,p_order_id),
    'order_ids',to_jsonb(v_ids),
    'count',coalesce(array_length(v_ids,1),0),
    'results',v_results
  );
end
$function$;

revoke execute on function public.alin_admin_assign_order_group(text,text,text) from public, anon;
revoke execute on function public.alin_order_transition_group(text,text,text) from public, anon;
revoke execute on function public.alin_courier_set_order_note_group(text,text) from public, anon;
grant execute on function public.alin_admin_assign_order_group(text,text,text) to authenticated;
grant execute on function public.alin_order_transition_group(text,text,text) to authenticated;
grant execute on function public.alin_courier_set_order_note_group(text,text) to authenticated;

commit;
