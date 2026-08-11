begin;

-- RC7: role routes write only through narrow server-authoritative RPCs.

create or replace function public.alin_teacher_update_profile(
  p_phone text,
  p_area text,
  p_specialty text,
  p_bio text,
  p_avatar_path text
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_id text := public.alin_current_account_id();
  v_role text := public.alin_current_role();
  v_row public.accounts%rowtype;
begin
  if v_id is null or v_role <> 'teacher' then
    raise exception 'هذه العملية متاحة للمدرس فقط';
  end if;

  update public.accounts
     set phone=nullif(left(btrim(coalesce(p_phone,'')),40),''),
         area=nullif(left(btrim(coalesce(p_area,'')),120),''),
         specialty=nullif(left(btrim(coalesce(p_specialty,'')),160),''),
         bio=nullif(left(btrim(coalesce(p_bio,'')),1200),''),
         avatar_path=nullif(left(btrim(coalesce(p_avatar_path,'')),700),''),
         updated_at=now()
   where id=v_id and role='teacher' and status='active' and deleted_at is null
   returning * into v_row;

  if not found then raise exception 'حساب المدرس غير متاح'; end if;
  return jsonb_build_object('ok',true,'account',to_jsonb(v_row)-'auth_user_id');
end $$;

create or replace function public.alin_courier_set_availability(p_value text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_id text := public.alin_current_account_id();
  v_role text := public.alin_current_role();
  v_value text := lower(btrim(coalesce(p_value,'')));
  v_row public.couriers%rowtype;
begin
  if v_id is null or v_role <> 'courier' then raise exception 'هذه العملية متاحة للمندوب فقط'; end if;
  if v_value not in ('available','busy','offline') then raise exception 'حالة المندوب غير صالحة'; end if;

  update public.couriers
     set availability=v_value,updated_at=now()
   where id=v_id and status <> 'inactive'
   returning * into v_row;
  if not found then raise exception 'حساب المندوب غير متاح'; end if;
  return jsonb_build_object('ok',true,'courier',to_jsonb(v_row));
end $$;

create or replace function public.alin_courier_set_order_note(p_order_id text,p_note text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_id text := public.alin_current_account_id();
  v_role text := public.alin_current_role();
  v_note text := btrim(coalesce(p_note,''));
  v_row public.orders%rowtype;
begin
  if v_id is null or v_role <> 'courier' then raise exception 'هذه العملية متاحة للمندوب فقط'; end if;
  if length(v_note) < 2 or length(v_note) > 800 then raise exception 'الملاحظة يجب أن تكون بين حرفين و800 حرف'; end if;

  update public.orders
     set delivery_note=v_note,updated_at=now()
   where id=p_order_id
     and (courier_id=v_id or delegate_id=v_id)
     and lower(coalesce(status,'')) not in ('completed','delivered','cancelled','canceled','rejected')
   returning * into v_row;
  if not found then raise exception 'الطلب غير متاح لهذا المندوب'; end if;
  return jsonb_build_object('ok',true,'order',to_jsonb(v_row));
end $$;

create or replace function public.alin_use_print_permit(p_permit_id text)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_id text := public.alin_current_account_id();
  v_role text := public.alin_current_role();
  v_row public.permits%rowtype;
  v_used integer;
  v_status text;
begin
  if v_id is null or v_role <> 'library' then raise exception 'هذه العملية متاحة للمكتبة فقط'; end if;

  select * into v_row from public.permits
   where id=p_permit_id and library_id=v_id
   for update;
  if not found then raise exception 'إذن النسخ غير موجود'; end if;
  if v_row.expires_at is not null and v_row.expires_at <= now() then raise exception 'إذن النسخ منتهي'; end if;
  if lower(coalesce(v_row.status,'active')) not in ('active','open') then raise exception 'إذن النسخ غير فعال'; end if;
  if coalesce(v_row.used,0) >= greatest(1,coalesce(v_row.allowed,1)) then raise exception 'إذن النسخ منتهي'; end if;

  v_used := coalesce(v_row.used,0)+1;
  v_status := case when v_used >= greatest(1,coalesce(v_row.allowed,1)) then 'used' else 'active' end;
  update public.permits set used=v_used,status=v_status,updated_at=now() where id=v_row.id returning * into v_row;
  return jsonb_build_object('ok',true,'permit',to_jsonb(v_row));
end $$;

create or replace function public.alin_teacher_create_request(
  p_id text,
  p_title text,
  p_subject text,
  p_grade text,
  p_note text,
  p_source_file_path text,
  p_source_file_name text,
  p_source_mime_type text
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_id text := public.alin_current_account_id();
  v_role text := public.alin_current_role();
  v_name text;
  v_row public.teacher_requests%rowtype;
begin
  if v_id is null or v_role <> 'teacher' then raise exception 'هذه العملية متاحة للمدرس فقط'; end if;
  if length(btrim(coalesce(p_id,''))) < 3 then raise exception 'معرف الطلب غير صالح'; end if;
  if length(btrim(coalesce(p_title,''))) < 2 or length(p_title) > 220 then raise exception 'اسم الملزمة غير صالح'; end if;
  if length(btrim(coalesce(p_source_file_path,''))) < 3 then raise exception 'ملف الطلب غير موجود'; end if;
  if btrim(p_source_file_path) not like 'alin-private/teacher-requests/'||v_id||'/%' and btrim(p_source_file_path) not like 'teacher-requests/'||v_id||'/%' then raise exception 'مسار ملف الطلب غير تابع لحساب المدرس'; end if;
  if lower(coalesce(p_source_file_name,'')) not like '%.docx' then raise exception 'الملف يجب أن يكون DOCX'; end if;

  select name into v_name from public.accounts where id=v_id and role='teacher' and status='active' and deleted_at is null;
  if v_name is null then raise exception 'حساب المدرس غير متاح'; end if;

  insert into public.teacher_requests(
    id,teacher_id,teacher_name,title,subject,grade,note,
    source_file_path,source_file_name,source_file_type,source_mime_type,
    status,version_history,reviewed_at,reviewed_by,created_at,updated_at
  ) values (
    left(btrim(p_id),120),v_id,v_name,left(btrim(p_title),220),
    nullif(left(btrim(coalesce(p_subject,'')),160),''),nullif(left(btrim(coalesce(p_grade,'')),160),''),
    nullif(left(btrim(coalesce(p_note,'')),1200),''),left(btrim(p_source_file_path),700),left(btrim(p_source_file_name),260),
    'docx',nullif(left(btrim(coalesce(p_source_mime_type,'')),180),''),'new','[]'::jsonb,null,null,now(),now()
  ) returning * into v_row;

  return jsonb_build_object('ok',true,'request',to_jsonb(v_row));
end $$;

create or replace function public.alin_teacher_resubmit_request(
  p_id text,
  p_source_file_path text,
  p_source_file_name text,
  p_note text
) returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_id text := public.alin_current_account_id();
  v_role text := public.alin_current_role();
  v_row public.teacher_requests%rowtype;
  v_history jsonb;
begin
  if v_id is null or v_role <> 'teacher' then raise exception 'هذه العملية متاحة للمدرس فقط'; end if;
  if length(btrim(coalesce(p_source_file_path,''))) < 3 then raise exception 'ملف الطلب غير موجود'; end if;
  if btrim(p_source_file_path) not like 'alin-private/teacher-requests/'||v_id||'/%' and btrim(p_source_file_path) not like 'teacher-requests/'||v_id||'/%' then raise exception 'مسار ملف الطلب غير تابع لحساب المدرس'; end if;
  if lower(coalesce(p_source_file_name,'')) not like '%.docx' then raise exception 'الملف يجب أن يكون DOCX'; end if;

  select * into v_row
    from public.teacher_requests
   where id=p_id and teacher_id=v_id
   for update;
  if not found then raise exception 'الطلب غير موجود لهذا المدرس'; end if;
  if lower(coalesce(v_row.status,'')) not in ('changes_requested','rejected') then
    raise exception 'لا يمكن إعادة إرسال هذا الطلب في حالته الحالية';
  end if;

  v_history := coalesce(v_row.version_history,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'file_name',coalesce(v_row.source_file_name,''),
    'file_path',coalesce(v_row.source_file_path,''),
    'status',coalesce(v_row.status,''),
    'at',now()
  ));

  update public.teacher_requests
     set source_file_path=left(btrim(p_source_file_path),700),
         source_file_name=left(btrim(p_source_file_name),260),
         source_file_type='docx',
         note=nullif(left(btrim(coalesce(p_note,'')),1200),''),
         version_history=v_history,
         status='resubmitted',updated_at=now()
   where id=v_row.id
   returning * into v_row;
  return jsonb_build_object('ok',true,'request',to_jsonb(v_row));
end $$;

-- Remove broad self-write RLS paths. Admin policies stay unchanged.
drop policy if exists accounts_teacher_profile_update on public.accounts;
drop policy if exists couriers_self_update on public.couriers;
drop policy if exists orders_party_update on public.orders;
drop policy if exists teacher_requests_teacher_insert on public.teacher_requests;
drop policy if exists teacher_requests_teacher_update on public.teacher_requests;
drop policy if exists permits_update on public.permits;

create policy permits_admin_update on public.permits
for update to authenticated
using (public.alin_is_admin())
with check (public.alin_is_admin());

revoke execute on function public.alin_teacher_update_profile(text,text,text,text,text) from public,anon;
revoke execute on function public.alin_courier_set_availability(text) from public,anon;
revoke execute on function public.alin_courier_set_order_note(text,text) from public,anon;
revoke execute on function public.alin_use_print_permit(text) from public,anon;
revoke execute on function public.alin_teacher_create_request(text,text,text,text,text,text,text,text) from public,anon;
revoke execute on function public.alin_teacher_resubmit_request(text,text,text,text) from public,anon;

grant execute on function public.alin_teacher_update_profile(text,text,text,text,text) to authenticated,service_role;
grant execute on function public.alin_courier_set_availability(text) to authenticated,service_role;
grant execute on function public.alin_courier_set_order_note(text,text) to authenticated,service_role;
grant execute on function public.alin_use_print_permit(text) to authenticated,service_role;
grant execute on function public.alin_teacher_create_request(text,text,text,text,text,text,text,text) to authenticated,service_role;
grant execute on function public.alin_teacher_resubmit_request(text,text,text,text) to authenticated,service_role;

-- Views are read contracts only. Remove auto-updatable DML privileges from browser roles.
revoke all privileges on public.alin_public_accounts from anon,authenticated;
revoke all privileges on public.alin_public_settings from anon,authenticated;
revoke all privileges on public.alin_public_booklets from anon,authenticated;
revoke all privileges on public.alin_library_booklets from anon,authenticated;
revoke all privileges on public.alin_teacher_orders from anon,authenticated;
grant select on public.alin_public_accounts to anon,authenticated;
grant select on public.alin_public_settings to anon,authenticated;
grant select on public.alin_public_booklets to anon,authenticated;
grant select on public.alin_library_booklets to authenticated;
grant select on public.alin_teacher_orders to authenticated;

-- Sensitive authenticated routes must never be callable as anonymous RPCs.
revoke execute on function public.alin_admin_assign_order(text,text,text) from public,anon;
revoke execute on function public.alin_admin_set_account_permissions(text,text[]) from public,anon;
revoke execute on function public.alin_audit_write(text,text,text,text,jsonb) from public,anon;
revoke execute on function public.alin_finance_party_balance(text,text) from public,anon;
revoke execute on function public.alin_finance_record_settlement(text,text,numeric,text,text) from public,anon;
revoke execute on function public.alin_finance_reverse_settlement(text,text,text) from public,anon;
revoke execute on function public.alin_library_set_order_status(text,text,text) from public,anon;
revoke execute on function public.alin_order_transition_atomic(text,text,text) from public,anon;
revoke execute on function public.alin_repair_auth_links(text) from public,anon;
revoke execute on function public.alin_set_library_open(boolean) from public,anon;
revoke execute on function public.alin_teacher_approve_booklet(text) from public,anon;

commit;
