-- ALIN UI13: Student account stays signed in on this device until explicit logout.
-- Existing active sessions are migrated away from the former 30-day expiry.

alter table public.student_sessions alter column expires_at drop not null;
update public.student_sessions set expires_at=null where revoked_at is null;

create or replace function public.alin_student_session_id(p_token text,p_device text)
returns text language sql stable security definer set search_path=public,extensions as $$
  select s.student_id from public.student_sessions s
  where s.token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex')
    and s.device_hash=encode(extensions.digest(coalesce(p_device,''),'sha256'),'hex')
    and s.revoked_at is null
    and (s.expires_at is null or s.expires_at>now())
  limit 1
$$;

create or replace function public.alin_student_register(p_name text,p_phone text,p_pin text,p_device text)
returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_phone text; v_student public.student_profiles%rowtype; v_token text; v_token_hash text; v_device_hash text;
begin
  v_phone:=regexp_replace(translate(btrim(coalesce(p_phone,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g');
  if length(btrim(coalesce(p_name,'')))<2 then raise exception 'اكتب اسم الطالب بصورة صحيحة'; end if;
  if v_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'اكتب رقم هاتف صحيح'; end if;
  if length(coalesce(p_pin,''))<6 then raise exception 'الرمز السري يجب أن يكون 6 أحرف أو أرقام على الأقل'; end if;
  if exists(select 1 from public.student_profiles where phone=v_phone) then raise exception 'يوجد حساب بهذا الرقم'; end if;
  insert into public.student_profiles(phone,name) values(v_phone,left(btrim(p_name),120)) returning * into v_student;
  insert into public.student_accounts(student_id,pin_hash) values(v_student.id,extensions.crypt(p_pin,extensions.gen_salt('bf')));
  v_token:=replace(extensions.gen_random_uuid()::text,'-','')||replace(extensions.gen_random_uuid()::text,'-','');
  v_token_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_device_hash:=encode(extensions.digest(coalesce(p_device,''),'sha256'),'hex');
  insert into public.student_sessions(student_id,token_hash,device_hash,expires_at) values(v_student.id,v_token_hash,v_device_hash,null);
  return jsonb_build_object('student',jsonb_build_object('id',v_student.id,'name',v_student.name,'phone',v_student.phone,'grade',v_student.grade),'token',v_token);
end $$;

create or replace function public.alin_student_login(p_phone text,p_pin text,p_device text)
returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_phone text; v_student public.student_profiles%rowtype; v_account public.student_accounts%rowtype; v_token text; v_hash text; v_device_hash text;
begin
  v_phone:=regexp_replace(translate(btrim(coalesce(p_phone,'')),'٠١٢٣٤٥٦٧٨٩','0123456789'),'[^0-9+]','','g');
  select p.* into v_student from public.student_profiles p where p.phone=v_phone;
  if not found then raise exception 'بيانات الدخول غير صحيحة'; end if;
  select * into v_account from public.student_accounts where student_id=v_student.id for update;
  if v_account.locked_until is not null and v_account.locked_until>now() then raise exception 'تم إيقاف المحاولات مؤقتاً'; end if;
  if v_account.pin_hash<>extensions.crypt(p_pin,v_account.pin_hash) then
    update public.student_accounts set failed_attempts=failed_attempts+1,locked_until=case when failed_attempts+1>=5 then now()+interval '10 minutes' else null end where student_id=v_student.id;
    raise exception 'بيانات الدخول غير صحيحة';
  end if;
  update public.student_accounts set failed_attempts=0,locked_until=null where student_id=v_student.id;
  v_token:=replace(extensions.gen_random_uuid()::text,'-','')||replace(extensions.gen_random_uuid()::text,'-','');
  v_hash:=encode(extensions.digest(v_token,'sha256'),'hex');
  v_device_hash:=encode(extensions.digest(coalesce(p_device,''),'sha256'),'hex');
  -- Keep one current session per student/device. A new explicit login replaces an older token on that device.
  update public.student_sessions set revoked_at=now()
  where student_id=v_student.id and device_hash=v_device_hash and revoked_at is null;
  insert into public.student_sessions(student_id,token_hash,device_hash,expires_at) values(v_student.id,v_hash,v_device_hash,null);
  return jsonb_build_object('student',jsonb_build_object('id',v_student.id,'name',v_student.name,'phone',v_student.phone,'grade',v_student.grade),'token',v_token);
end $$;
