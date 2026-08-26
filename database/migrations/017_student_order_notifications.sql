-- ALIN v4.2 Stable Lock — secure per-student order notifications.
-- Registered students use the existing custom token + device session. No private notification is exposed to anon reads.

create or replace function public.alin_student_notifications(p_token text,p_device text)
returns table(
  id text,
  title text,
  message text,
  role text,
  account_id text,
  type text,
  link text,
  status text,
  created_by text,
  created_at timestamptz,
  expires_at timestamptz,
  is_read boolean
)
language plpgsql
stable
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_student text;
begin
  v_student:=public.alin_student_session_id(p_token,p_device);
  if coalesce(v_student,'')='' then raise exception 'جلسة الطالب غير صالحة'; end if;

  return query
  select
    n.id,n.title,n.message,n.role,n.account_id,n.type,n.link,n.status,n.created_by,n.created_at,n.expires_at,
    exists(
      select 1 from public.notification_reads r
      where r.notification_id=n.id and r.account_id=v_student
    ) as is_read
  from public.notifications n
  where n.status='active'
    and (n.expires_at is null or n.expires_at>=now())
    and (
      n.account_id=v_student
      or (n.account_id is null and n.role in ('all','student'))
    )
  order by n.created_at desc
  limit 200;
end
$$;

create or replace function public.alin_student_notification_mark_read(p_token text,p_device text,p_notification_id text)
returns boolean
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_student text;
  v_allowed boolean;
begin
  v_student:=public.alin_student_session_id(p_token,p_device);
  if coalesce(v_student,'')='' then raise exception 'جلسة الطالب غير صالحة'; end if;

  select exists(
    select 1 from public.notifications n
    where n.id=p_notification_id
      and n.status='active'
      and (n.expires_at is null or n.expires_at>=now())
      and (n.account_id=v_student or (n.account_id is null and n.role in ('all','student')))
  ) into v_allowed;
  if not v_allowed then return false; end if;

  insert into public.notification_reads(notification_id,account_id,read_at)
  values(p_notification_id,v_student,now())
  on conflict(notification_id,account_id) do update set read_at=excluded.read_at;
  return true;
end
$$;

create or replace function public.alin_student_notifications_mark_all(p_token text,p_device text)
returns integer
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_student text;
  v_count integer:=0;
begin
  v_student:=public.alin_student_session_id(p_token,p_device);
  if coalesce(v_student,'')='' then raise exception 'جلسة الطالب غير صالحة'; end if;

  insert into public.notification_reads(notification_id,account_id,read_at)
  select n.id,v_student,now()
  from public.notifications n
  where n.status='active'
    and (n.expires_at is null or n.expires_at>=now())
    and (n.account_id=v_student or (n.account_id is null and n.role in ('all','student')))
  on conflict(notification_id,account_id) do update set read_at=excluded.read_at;
  get diagnostics v_count=row_count;
  return v_count;
end
$$;

create or replace function public.alin_order_status_student_notification()
returns trigger
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  v_status text:=lower(btrim(coalesce(new.status,'new')));
  v_code text:=coalesce(nullif(btrim(new.order_number),''),new.id);
  v_title text;
  v_message text;
begin
  if coalesce(btrim(new.student_id),'')='' then return new; end if;
  if tg_op='UPDATE' and new.status is not distinct from old.status then return new; end if;

  v_title:=case v_status
    when 'ready' then 'طلبك جاهز'
    when 'completed' then 'تم تسليم طلبك'
    when 'delivered' then 'تم تسليم طلبك'
    when 'cancelled' then 'تم إلغاء طلبك'
    when 'rejected' then 'تم رفض طلبك'
    else 'تحديث حالة طلبك'
  end;

  v_message:=case v_status
    when 'pending' then 'تم استلام طلبك '||v_code||' وهو قيد المتابعة.'
    when 'new' then 'تم استلام طلبك '||v_code||' وهو قيد المتابعة.'
    when 'pending_admin' then 'طلبك '||v_code||' بانتظار التعيين.'
    when 'payment_pending' then 'طلبك '||v_code||' بانتظار تأكيد الدفع.'
    when 'paid' then 'تم تأكيد الدفع للطلب '||v_code||'.'
    when 'assigned' then 'تم تعيين مندوب للطلب '||v_code||'.'
    when 'accepted' then 'قبل المندوب الطلب '||v_code||'.'
    when 'processing' then 'طلبك '||v_code||' قيد التجهيز.'
    when 'printing' then 'طلبك '||v_code||' قيد الطباعة.'
    when 'ready' then 'طلبك '||v_code||' جاهز.'
    when 'picked_up' then 'استلم المندوب الطلب '||v_code||'.'
    when 'out_for_delivery' then 'طلبك '||v_code||' في الطريق إليك.'
    when 'out_delivery' then 'طلبك '||v_code||' في الطريق إليك.'
    when 'completed' then 'تم تسليم الطلب '||v_code||'.'
    when 'delivered' then 'تم تسليم الطلب '||v_code||'.'
    when 'cancelled' then 'تم إلغاء الطلب '||v_code||'.'
    when 'rejected' then 'تم رفض الطلب '||v_code||'.'
    when 'receipt_rejected' then 'تم رفض وصل الطلب '||v_code||'. راجع بيانات الطلب.'
    else 'تم تحديث حالة الطلب '||v_code||' إلى '||coalesce(new.status,'جديد')||'.'
  end;

  insert into public.notifications(id,title,message,role,account_id,type,link,status,is_read,created_by,created_at)
  values(
    'NT-'||replace(extensions.gen_random_uuid()::text,'-',''),
    v_title,v_message,'student',new.student_id,'order_status','order:'||v_code,'active',false,'system',now()
  );
  return new;
end
$$;

drop trigger if exists trg_order_status_student_notification on public.orders;
create trigger trg_order_status_student_notification
after insert or update of status on public.orders
for each row execute function public.alin_order_status_student_notification();

revoke all on function public.alin_student_notifications(text,text) from public;
revoke all on function public.alin_student_notification_mark_read(text,text,text) from public;
revoke all on function public.alin_student_notifications_mark_all(text,text) from public;
grant execute on function public.alin_student_notifications(text,text) to anon,authenticated;
grant execute on function public.alin_student_notification_mark_read(text,text,text) to anon,authenticated;
grant execute on function public.alin_student_notifications_mark_all(text,text) to anon,authenticated;
