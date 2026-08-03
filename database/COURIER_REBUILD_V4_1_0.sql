-- منصة آلين v4.1.0 — إعادة بناء نظام المندوب لمسار قائم
-- ملف موحد واحد: لا يحذف الطلبات ولا الحسابات ولا الحركات المالية.

begin;
select pg_advisory_xact_lock(hashtext('alin-courier-rebuild-v4.1.0'));

do $$
begin
  if to_regclass('public.orders') is null
     or to_regclass('public.accounts') is null
     or to_regclass('public.couriers') is null
     or to_regclass('public.order_timeline') is null then
    raise exception 'قاعدة منصة آلين غير مكتملة. أوقف التنفيذ ولا تستخدم هذا الملف على مشروع مختلف.';
  end if;

  if exists(
    select 1 from (values
      ('status'),('assignment_status'),('status_history'),('courier_id'),('delegate_id'),
      ('assigned_at'),('accepted_at'),('picked_up_at'),('out_for_delivery_at'),
      ('completed_at'),('delivered_at'),('rejected_at'),('cancelled_at'),('updated_at')
    ) required(column_name)
    where not exists(
      select 1 from information_schema.columns c
      where c.table_schema='public' and c.table_name='orders' and c.column_name=required.column_name
    )
  ) then
    raise exception 'جدول الطلبات لا يطابق بنية آلين v4. أوقف التنفيذ وخذ نسخة احتياطية قبل أي معالجة.';
  end if;
end $$;

-- =========================================================
-- ALIN v4.1.0 — authoritative courier assignment and workflow
-- =========================================================

create or replace function public.alin_admin_assign_order(
  p_order_id text,
  p_courier_id text default null,
  p_library_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  o public.orders%rowtype;
  v_updated public.orders%rowtype;
  c public.couriers%rowtype;
  a public.accounts%rowtype;
  l public.accounts%rowtype;
  v_actor text:=public.alin_current_account_id();
  v_role text:=public.alin_current_role();
  v_courier_id text:=nullif(btrim(coalesce(p_courier_id,'')),'');
  v_library_id text:=nullif(btrim(coalesce(p_library_id,'')),'');
  v_now timestamptz:=now();
  v_area text;
  v_area_ok boolean:=false;
  v_same boolean:=false;
  v_next_status text;
  v_history_status text;
begin
  if not public.alin_is_finance_staff() then
    raise exception 'هذه العملية متاحة للإدارة فقط';
  end if;

  select * into o from public.orders where id=p_order_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;

  if lower(btrim(coalesce(o.status,''))) in ('completed','delivered','cancelled','canceled','rejected') then
    raise exception 'لا يمكن تغيير تعيين طلب مكتمل أو ملغي';
  end if;

  -- طلبات التوصيل المنزلي تعتمد المندوب حصراً.
  if o.fulfillment_type='home_delivery' or o.delivery_type='courier' then
    if v_courier_id is null then
      if lower(btrim(coalesce(o.status,''))) in ('picked_up','out_for_delivery','out_delivery') then
        raise exception 'لا يمكن إلغاء تعيين المندوب بعد استلام الطلب أو بدء التوصيل';
      end if;

      if o.courier_id is null and o.delegate_id is null
         and lower(btrim(coalesce(o.status,'')))='pending_admin' then
        return jsonb_build_object('ok',true,'order',to_jsonb(o),'idempotent',true);
      end if;

      perform set_config('alin.internal_order_transition','on',true);
      update public.orders set
        courier_id=null,
        delegate_id=null,
        status='pending_admin',
        assignment_status='pending_admin',
        assigned_at=null,
        accepted_at=null,
        picked_up_at=null,
        out_for_delivery_at=null,
        status_history=coalesce(status_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
          'status','pending_admin','at',v_now,'by',coalesce(v_actor,'system'),'role',coalesce(v_role,'system'),
          'reason','إلغاء تعيين المندوب'
        )),
        updated_at=v_now
      where id=o.id
      returning * into v_updated;
      perform set_config('alin.internal_order_transition','off',true);

      insert into public.order_timeline(order_id,status,actor_id,actor_role,reason,meta)
      values(o.id,'pending_admin',v_actor,coalesce(v_role,'admin'),'إلغاء تعيين المندوب',jsonb_build_object('courier_id',null));

      return jsonb_build_object('ok',true,'order',to_jsonb(v_updated),'unassigned',true);
    end if;

    select * into a from public.accounts
    where id=v_courier_id and role='courier' and status='active' and deleted_at is null;
    if not found then raise exception 'حساب المندوب غير موجود أو غير فعال'; end if;

    select * into c from public.couriers where id=v_courier_id and status='active';
    if not found then raise exception 'بيانات المندوب غير مهيأة أو الحساب موقوف'; end if;

    v_area:=lower(regexp_replace(
      btrim(split_part(replace(replace(coalesce(o.delivery_area,''),'–','-'),'—','-'),'-',1)),
      '\s+',' ','g'
    ));

    if v_area='' then
      v_area_ok:=true;
    else
      v_area_ok:=
        lower(regexp_replace(btrim(coalesce(c.area,'')),'\s+',' ','g'))=v_area
        or exists(
          select 1 from unnest(coalesce(c.areas,array[]::text[])) area_name
          where lower(regexp_replace(
            btrim(split_part(replace(replace(area_name,'–','-'),'—','-'),'-',1)),
            '\s+',' ','g'
          ))=v_area
        )
        or exists(
          select 1
          from public.courier_areas ca
          join public.delivery_areas da on da.id=ca.area_id
          where ca.courier_id=v_courier_id
            and (
              (o.delivery_area_id is not null and da.id=o.delivery_area_id)
              or lower(regexp_replace(
                btrim(split_part(replace(replace(da.name,'–','-'),'—','-'),'-',1)),
                '\s+',' ','g'
              ))=v_area
            )
        );
    end if;

    if not v_area_ok then raise exception 'المندوب غير مرتبط بمنطقة الطلب'; end if;

    v_same:=coalesce(o.courier_id,o.delegate_id,'')=v_courier_id;
    if not v_same and lower(btrim(coalesce(o.status,''))) in ('picked_up','out_for_delivery','out_delivery') then
      raise exception 'لا يمكن تغيير المندوب بعد استلام الطلب أو بدء التوصيل';
    end if;

    if v_same and lower(btrim(coalesce(o.status,''))) in ('assigned','accepted','picked_up','out_for_delivery')
       and o.courier_id=v_courier_id and o.delegate_id=v_courier_id then
      return jsonb_build_object('ok',true,'order',to_jsonb(o),'idempotent',true);
    end if;

    v_next_status:=case
      when v_same and lower(btrim(coalesce(o.status,''))) in ('accepted','picked_up','out_for_delivery')
        then lower(btrim(o.status))
      else 'assigned'
    end;

    perform set_config('alin.internal_order_transition','on',true);
    update public.orders set
      courier_id=v_courier_id,
      delegate_id=v_courier_id,
      status=v_next_status,
      assignment_status=case when v_next_status='accepted' then 'accepted' else 'assigned' end,
      assigned_at=case when v_same then coalesce(assigned_at,v_now) else v_now end,
      accepted_at=case when v_next_status='accepted' then accepted_at else null end,
      picked_up_at=case when v_next_status='picked_up' then picked_up_at else null end,
      out_for_delivery_at=case when v_next_status='out_for_delivery' then out_for_delivery_at else null end,
      delivery_note=case when v_same then delivery_note else null end,
      status_history=coalesce(status_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
        'status',v_next_status,'at',v_now,'by',coalesce(v_actor,'system'),'role',coalesce(v_role,'system'),
        'reason',case when v_same then 'تثبيت تعيين المندوب' else 'تعيين المندوب' end,
        'courier_id',v_courier_id
      )),
      updated_at=v_now
    where id=o.id
    returning * into v_updated;
    perform set_config('alin.internal_order_transition','off',true);

    insert into public.order_timeline(order_id,status,actor_id,actor_role,reason,meta)
    values(o.id,v_next_status,v_actor,coalesce(v_role,'admin'),
      case when v_same then 'تثبيت تعيين المندوب' else 'تعيين المندوب' end,
      jsonb_build_object('courier_id',v_courier_id,'courier_name',a.name));

    return jsonb_build_object('ok',true,'order',to_jsonb(v_updated),'assigned',true);
  end if;

  -- طلبات الاستلام من المكتبة تعتمد المكتبة ولا تقبل مندوباً.
  if v_courier_id is not null then
    raise exception 'طلب الاستلام من المكتبة لا يقبل تعيين مندوب';
  end if;
  if v_library_id is null then raise exception 'اختر مكتبة لاستلام الطلب'; end if;

  select * into l from public.accounts
  where id=v_library_id and role='library' and status='active' and deleted_at is null;
  if not found then raise exception 'حساب المكتبة غير موجود أو غير فعال'; end if;

  if o.library_id=v_library_id and o.pickup_library_id=v_library_id
     and o.courier_id is null and o.delegate_id is null then
    return jsonb_build_object('ok',true,'order',to_jsonb(o),'idempotent',true);
  end if;

  perform set_config('alin.internal_order_transition','on',true);
  update public.orders set
    library_id=v_library_id,
    pickup_library_id=v_library_id,
    courier_id=null,
    delegate_id=null,
    assignment_status='pending_admin',
    assigned_at=null,
    accepted_at=null,
    picked_up_at=null,
    out_for_delivery_at=null,
    status_history=coalesce(status_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
      'status',o.status,'at',v_now,'by',coalesce(v_actor,'system'),'role',coalesce(v_role,'system'),
      'reason','تعيين مكتبة الاستلام','library_id',v_library_id
    )),
    updated_at=v_now
  where id=o.id
  returning * into v_updated;
  perform set_config('alin.internal_order_transition','off',true);

  insert into public.order_timeline(order_id,status,actor_id,actor_role,reason,meta)
  values(o.id,v_updated.status,v_actor,coalesce(v_role,'admin'),'تعيين مكتبة الاستلام',
    jsonb_build_object('library_id',v_library_id,'library_name',l.name));

  return jsonb_build_object('ok',true,'order',to_jsonb(v_updated),'library_assigned',true);
end $$;

create or replace function public.alin_order_transition_atomic(
  p_order_id text,
  p_status text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_temp
as $$
declare
  o public.orders%rowtype;
  v_updated public.orders%rowtype;
  v_role text:=public.alin_current_role();
  v_account text:=public.alin_current_account_id();
  v_target text:=lower(btrim(coalesce(p_status,'')));
  v_source text;
  v_allowed boolean:=false;
  v_now timestamptz:=now();
  v_finance jsonb;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;

  v_source:=lower(btrim(coalesce(o.status,'new')));
  if v_source='delivered' then v_source:='completed'; end if;
  if v_source='out_delivery' then v_source:='out_for_delivery'; end if;
  if v_source='canceled' then v_source:='cancelled'; end if;
  if v_target='delivered' then v_target:='completed'; end if;
  if v_target='out_delivery' then v_target:='out_for_delivery'; end if;
  if v_target='canceled' then v_target:='cancelled'; end if;

  if v_target not in ('new','pending_admin','assigned','accepted','picked_up','out_for_delivery','processing','printing','ready','completed','cancelled','rejected') then
    raise exception 'حالة الطلب المطلوبة غير صحيحة';
  end if;

  if v_source='completed' and v_target='completed' then
    v_finance:=public.alin_upsert_order_finance_atomic(o.id);
    select * into v_updated from public.orders where id=o.id;
    return jsonb_build_object('ok',true,'status','completed','order',to_jsonb(v_updated),'finance',v_finance,'idempotent',true);
  end if;
  if v_source='completed' then raise exception 'الطلب المكتمل لا يرجع لحالة سابقة'; end if;
  if v_source in ('cancelled','rejected') then raise exception 'الطلب الملغي أو المرفوض لا يمكن تحديثه'; end if;

  if public.alin_is_finance_staff() then
    v_allowed:=true;
  elsif v_role='library' and v_account in (o.library_id,o.pickup_library_id) then
    v_allowed:=
      (v_source in ('new','pending','pending_admin','accepted') and v_target in ('processing','cancelled'))
      or (v_source in ('processing','printing') and v_target in ('ready','cancelled'))
      or (v_source='ready' and v_target in ('completed','cancelled'));
  elsif v_role='courier' and v_account in (o.courier_id,o.delegate_id) then
    v_allowed:=
      (v_source in ('new','pending','pending_admin','assigned') and v_target in ('accepted','rejected'))
      or (v_source='accepted' and v_target='picked_up')
      or (v_source='picked_up' and v_target='out_for_delivery')
      or (v_source='out_for_delivery' and v_target='completed');
  end if;

  if not v_allowed then
    raise exception 'غير مسموح بانتقال الطلب من الحالة % إلى % لهذا الحساب',v_source,v_target;
  end if;

  if v_target in ('cancelled','rejected') and nullif(btrim(coalesce(p_reason,'')),'') is null then
    raise exception 'اكتب سبب الإلغاء أو الرفض';
  end if;

  if v_source=v_target then
    return jsonb_build_object('ok',true,'status',v_target,'order',to_jsonb(o),'idempotent',true);
  end if;

  if v_target in ('cancelled','rejected') and o.stock_reserved and o.stock_restored_at is null and o.kind<>'booklet' then
    update public.products set stock=stock+o.qty where id=o.item_id;
  end if;

  perform set_config('alin.internal_order_transition','on',true);
  update public.orders set
    status=v_target,
    assignment_status=case
      when v_target='assigned' then 'assigned'
      when v_target='accepted' then 'accepted'
      when v_target='completed' then 'completed'
      when v_target='cancelled' then 'cancelled'
      when v_target='rejected' then 'rejected'
      else assignment_status
    end,
    status_history=coalesce(status_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
      'status',v_target,'at',v_now,'by',coalesce(v_account,'system'),'role',coalesce(v_role,'system'),
      'reason',nullif(btrim(coalesce(p_reason,'')),'')
    )),
    assigned_at=case when v_target='assigned' then coalesce(assigned_at,v_now) else assigned_at end,
    accepted_at=case when v_target='accepted' then coalesce(accepted_at,v_now) else accepted_at end,
    picked_up_at=case when v_target='picked_up' then coalesce(picked_up_at,v_now) else picked_up_at end,
    out_for_delivery_at=case when v_target='out_for_delivery' then coalesce(out_for_delivery_at,v_now) else out_for_delivery_at end,
    processing_at=case when v_target in ('processing','printing') then coalesce(processing_at,v_now) else processing_at end,
    ready_at=case when v_target='ready' then coalesce(ready_at,v_now) else ready_at end,
    completed_at=case when v_target='completed' then coalesce(completed_at,v_now) else completed_at end,
    delivered_at=case when v_target='completed' then coalesce(delivered_at,v_now) else delivered_at end,
    rejected_at=case when v_target='rejected' then coalesce(rejected_at,v_now) else rejected_at end,
    cancelled_at=case when v_target in ('cancelled','rejected') then coalesce(cancelled_at,v_now) else cancelled_at end,
    cancellation_reason=case when v_target in ('cancelled','rejected') then btrim(p_reason) else cancellation_reason end,
    payment_status=case when v_target='completed' then 'paid' when v_target in ('cancelled','rejected') then 'cancelled' else payment_status end,
    stock_reserved=case when v_target in ('cancelled','rejected') then false else stock_reserved end,
    stock_restored_at=case when v_target in ('cancelled','rejected') and stock_reserved and stock_restored_at is null and kind<>'booklet' then v_now else stock_restored_at end,
    settlement_done=case when v_target in ('cancelled','rejected') then false else settlement_done end,
    settlement_cancelled=case when v_target in ('cancelled','rejected') then true else settlement_cancelled end,
    platform_profit=case when v_target in ('cancelled','rejected') then 0 else platform_profit end,
    teacher_profit=case when v_target in ('cancelled','rejected') then 0 else teacher_profit end,
    library_profit=case when v_target in ('cancelled','rejected') then 0 else library_profit end,
    delegate_profit=case when v_target in ('cancelled','rejected') then 0 else delegate_profit end,
    courier_profit=case when v_target in ('cancelled','rejected') then 0 else courier_profit end,
    updated_at=v_now
  where id=o.id
  returning * into v_updated;
  perform set_config('alin.internal_order_transition','off',true);

  insert into public.order_timeline(order_id,status,actor_id,actor_role,reason)
  values(o.id,v_target,v_account,coalesce(v_role,'system'),nullif(btrim(coalesce(p_reason,'')),''));

  if v_target='completed' then
    v_finance:=public.alin_upsert_order_finance_atomic(o.id);
    select * into v_updated from public.orders where id=o.id;
  elsif v_target in ('cancelled','rejected') then
    update public.ledger
    set status='cancelled',settlement_status='cancelled',is_current=false,
        note=coalesce(note,'')||' | ألغي الطلب قبل التسوية',updated_at=v_now
    where order_id=o.id and status<>'settled';
  end if;

  return jsonb_build_object('ok',true,'status',v_target,'order',to_jsonb(v_updated),'finance',v_finance);
end $$;


-- إصلاح آمن للطلبات القديمة التي لديها مندوب لكن بقيت بانتظار الإدارة.
select set_config('alin.internal_order_transition','on',true);
with repaired as (
  update public.orders
  set status='assigned',
      assignment_status='assigned',
      assigned_at=coalesce(assigned_at,now()),
      status_history=coalesce(status_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object(
        'status','assigned','at',now(),'by','system','role','system','reason','إصلاح v4.1.0 لطلب قديم مرتبط بمندوب'
      )),
      updated_at=now()
  where coalesce(courier_id,delegate_id) is not null
    and status in ('new','pending_admin')
    and (fulfillment_type='home_delivery' or delivery_type='courier')
  returning id
)
insert into public.order_timeline(order_id,status,actor_id,actor_role,reason,meta)
select id,'assigned',null,'system','إصلاح v4.1.0 لطلب قديم مرتبط بمندوب',jsonb_build_object('repair',true)
from repaired;
select set_config('alin.internal_order_transition','off',true);

grant execute on function public.alin_admin_assign_order(text,text,text) to authenticated;
grant execute on function public.alin_order_transition_atomic(text,text,text) to authenticated;

insert into public.settings(key,value,version,updated_at)
values('courier_workflow_version','4.1.0','4.1.0',now())
on conflict(key) do update set value=excluded.value,version=excluded.version,updated_at=excluded.updated_at;

notify pgrst, 'reload schema';
commit;

select
  to_regprocedure('public.alin_admin_assign_order(text,text,text)') is not null as assignment_rpc_ready,
  to_regprocedure('public.alin_order_transition_atomic(text,text,text)') is not null as transition_rpc_ready,
  (select value from public.settings where key='courier_workflow_version') as courier_workflow_version;
