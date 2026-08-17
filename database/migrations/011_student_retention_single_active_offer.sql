-- ALIN v4.2.0 — one active unused personal offer per registered student.
create or replace function public.alin_admin_create_student_offer(
  p_student_id text,p_discount_type text,p_discount_value numeric,p_days_valid integer default 3,
  p_applies_to text default 'all',p_title text default null,p_message text default null
)
returns jsonb language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare
  v_student public.student_profiles%rowtype;
  v_type text:=lower(btrim(coalesce(p_discount_type,'percent')));
  v_value numeric:=coalesce(p_discount_value,0);
  v_days integer:=greatest(1,least(coalesce(p_days_valid,3),30));
  v_applies text:=lower(btrim(coalesce(p_applies_to,'all')));
  v_code text; v_coupon_id text:='CP'||replace(extensions.gen_random_uuid()::text,'-','');
  v_title text; v_message text; v_try integer:=0;
begin
  if not public.alin_is_admin() then raise exception 'غير مسموح'; end if;
  select * into v_student from public.student_profiles where id=p_student_id;
  if not found then raise exception 'حساب الطالب غير موجود'; end if;
  if v_type not in ('percent','fixed') then raise exception 'نوع الخصم غير صحيح'; end if;
  if v_value<=0 then raise exception 'قيمة الخصم يجب أن تكون أكبر من صفر'; end if;
  if v_type='percent' and v_value>100 then raise exception 'نسبة الخصم لا تتجاوز 100%%'; end if;
  if v_applies not in ('all','booklet','stationery','gift') then raise exception 'القسم المحدد للخصم غير صحيح'; end if;

  update public.coupons
  set status='inactive',updated_at=now(),note=coalesce(note,'')||' | استبدل بعرض شخصي أحدث'
  where bound_student_id=v_student.id and personal_offer and status='active' and (max_uses=0 or used_count<max_uses);

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
