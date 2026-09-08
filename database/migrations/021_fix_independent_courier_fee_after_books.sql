-- ALIN v4.2.x — Restore independent courier fee settlement after books migration.
-- The books migration accidentally recalculated courier profit from delivery_fee
-- using delegate_profit_percent. The authoritative courier amount is orders.courier_fee.

begin;

create or replace function public.alin_upsert_order_finance_atomic(p_order_id text)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions','pg_temp'
as $function$
declare
  o public.orders%rowtype;
  b public.booklets%rowtype;
  p public.products%rowtype;
  l public.ledger%rowtype;
  v_teacher_id text;
  v_library_id text;
  v_delegate_id text;
  v_collector_role text;
  v_collector_id text;
  v_total numeric;
  v_delivery numeric;
  v_merchandise numeric;
  v_platform_pct numeric:=0;
  v_teacher_pct numeric:=0;
  v_library_pct numeric:=0;
  v_delegate_pct numeric:=0;
  v_teacher numeric:=0;
  v_library numeric:=0;
  v_delegate numeric:=0;
  v_admin numeric:=0;
  v_debt numeric:=0;
  v_supplier numeric:=0;
  v_supplier_id text;
  v_supplier_type text;
  v_supplier_name text;
  v_platform_merchandise numeric:=0;
  v_ledger_id text;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  if o.status<>'completed' then raise exception 'لا يمكن إنشاء الحسابات قبل تسليم الطلب'; end if;

  select * into l from public.ledger where order_id=o.id;
  if found then
    return jsonb_build_object(
      'ledger_id',l.id,'order_id',o.id,'total',l.total,'admin',l.admin,
      'teacher',l.teacher,'library',l.library,'delegate',l.delegate,
      'supplier',coalesce(l.supplier,0),'supplier_id',l.supplier_id,
      'supplier_type',l.supplier_type,'supplier_name',l.supplier_name,
      'collector_debt',l.collector_debt,'frozen',true
    );
  end if;

  v_total:=o.total;
  v_delivery:=least(o.total,greatest(o.delivery_fee,0));
  v_merchandise:=greatest(v_total-v_delivery,0);
  v_library_id:=coalesce(o.library_id,o.pickup_library_id);
  v_delegate_id:=coalesce(o.delegate_id,o.courier_id);

  if o.kind='booklet' then
    select * into b from public.booklets where id=o.item_id;
    if not found then raise exception 'الملزمة المرتبطة بالطلب غير موجودة'; end if;

    v_teacher_id:=coalesce(o.booklet_teacher_id_snapshot,b.teacher_id);
    v_platform_pct:=coalesce(o.booklet_platform_share_percent,b.platform_share_percent);
    v_teacher_pct:=coalesce(o.booklet_teacher_share_percent,b.teacher_share_percent);
    v_library_pct:=coalesce(o.booklet_library_share_percent,b.library_share_percent);

    if v_platform_pct is null or v_teacher_pct is null or v_library_pct is null
       or v_platform_pct<0 or v_teacher_pct<0 or v_library_pct<0
       or v_platform_pct>100 or v_teacher_pct>100 or v_library_pct>100
       or v_platform_pct+v_teacher_pct+v_library_pct<>100 then
      raise exception 'نسب الحسابات الخاصة بهذه الملزمة غير صحيحة';
    end if;

    v_teacher:=round(v_merchandise*v_teacher_pct/100);
  elsif o.kind='book' then
    select * into p from public.products where id=o.item_id;
    if not found then raise exception 'الكتاب المرتبط بالطلب غير موجود'; end if;

    v_platform_pct:=coalesce(o.book_platform_share_percent,p.platform_share_percent);
    v_supplier_id:=coalesce(o.book_supplier_account_id,p.supplier_account_id);
    v_supplier_type:=coalesce(o.book_supplier_type,p.supplier_type);
    v_supplier_name:=coalesce(o.book_supplier_name_snapshot,p.supplier_name);
    v_teacher_pct:=0;
    v_library_pct:=0;

    if v_platform_pct is null or o.book_supplier_share_percent is null
       or v_platform_pct<0 or o.book_supplier_share_percent<0
       or v_platform_pct>100 or o.book_supplier_share_percent>100
       or v_platform_pct+o.book_supplier_share_percent<>100
       or v_supplier_type not in ('platform','library','printer') then
      raise exception 'نسب الحسابات الخاصة بهذا الكتاب غير صحيحة';
    end if;

    v_supplier:=round(v_merchandise*o.book_supplier_share_percent/100);
    v_platform_merchandise:=greatest(v_merchandise-v_supplier,0);
  else
    v_teacher_pct:=0;
    v_library_pct:=public.alin_setting_numeric('library_profit_percent',30);
  end if;

  v_delegate_pct:=public.alin_setting_numeric('delegate_profit_percent',75);

  if o.fulfillment_type='home_delivery' then
    v_collector_role:='delegate';
    v_collector_id:=v_delegate_id;
    if v_collector_id is null then raise exception 'طلب التوصيل غير مرتبط بمندوب'; end if;

    -- IMPORTANT: courier_fee is independent from what the student pays.
    -- Fallback to the legacy percentage only for old orders that have no snapshot.
    v_delegate:=round(greatest(coalesce(
      o.courier_fee,
      v_delivery*least(greatest(v_delegate_pct,0),100)/100
    ),0));
    v_library:=0;
  else
    if o.kind='book' then
      raise exception 'الاستلام المباشر للكتب غير مفعل في النسخة الحالية من مسار المورد';
    end if;
    v_collector_role:='library';
    v_collector_id:=v_library_id;
    if v_collector_id is null then raise exception 'طلب الاستلام غير مرتبط بمكتبة'; end if;
    v_library:=least(
      greatest(v_merchandise-v_teacher,0),
      round(v_merchandise*least(greatest(v_library_pct,0),100)/100)
    );
  end if;

  if o.kind='book' then
    v_admin:=greatest(v_platform_merchandise + (v_delivery-v_delegate),0);
  else
    v_admin:=greatest(v_total-v_teacher-v_library-v_delegate,0);
  end if;

  v_debt:=greatest(v_total-case when v_collector_role='library' then v_library else v_delegate end,0);

  v_ledger_id:='LG'||replace(extensions.gen_random_uuid()::text,'-','');
  insert into public.ledger(
    id,order_id,order_number,title,total,merchandise_total,delivery_fee,alin,admin,teacher,teacher_id,library,library_id,
    delegate,courier,delegate_id,courier_id,collector_role,collector_id,collector_debt,delivery_type,status,settlement_status,
    finance_version,is_current,note,supplier,supplier_id,supplier_type,supplier_name,supplier_key,supplier_settlement_status
  ) values (
    v_ledger_id,o.id,o.order_number,o.title,v_total,v_merchandise,v_delivery,v_admin,v_admin,v_teacher,v_teacher_id,v_library,v_library_id,
    v_delegate,v_delegate,v_delegate_id,v_delegate_id,v_collector_role,v_collector_id,v_debt,v_collector_role,'pending','pending',
    case when o.kind='book' then '4.2-books-independent-courier-fee' else '4.2.1-independent-courier-fee' end,
    true,
    case
      when o.kind='booklet' then
        'قيد مالي ذري — نسب الملزمة مثبتة عند إنشاء الطلب: منصة '||v_platform_pct||'%، مدرس '||v_teacher_pct||'%، مكتبة '||v_library_pct||'%'
      when o.kind='book' then
        'قيد كتاب مستقل — قيمة الكتاب فقط: منصة '||v_platform_pct||'%، مورد '||o.book_supplier_share_percent||'%؛ أجرة المندوب مستقلة'
      else 'قيد مالي ذري من الطلب المكتمل — أجرة المندوب مستقلة'
    end,
    v_supplier,v_supplier_id,v_supplier_type,v_supplier_name,
    case when o.kind='book' and v_supplier>0 then coalesce(nullif(v_supplier_id,''),'name:'||lower(coalesce(v_supplier_name,'غير محدد'))) else null end,
    case when o.kind='book' and v_supplier>0 then 'pending' else 'settled' end
  )
  on conflict(order_id) do nothing
  returning id into v_ledger_id;

  if v_ledger_id is null then
    select * into l from public.ledger where order_id=o.id;
    return jsonb_build_object(
      'ledger_id',l.id,'order_id',o.id,'total',l.total,'admin',l.admin,
      'teacher',l.teacher,'library',l.library,'delegate',l.delegate,
      'supplier',coalesce(l.supplier,0),'supplier_id',l.supplier_id,
      'supplier_type',l.supplier_type,'supplier_name',l.supplier_name,
      'collector_debt',l.collector_debt,'frozen',true
    );
  end if;

  perform set_config('alin.internal_order_transition','on',true);
  update public.orders set
    settlement_done=true,
    settlement_cancelled=false,
    settlement_at=coalesce(settlement_at,now()),
    settlement_party=v_collector_role,
    platform_profit=v_admin,
    teacher_profit=v_teacher,
    library_profit=v_library,
    delegate_profit=v_delegate,
    courier_profit=v_delegate,
    book_supplier_profit=case when kind='book' then v_supplier else book_supplier_profit end,
    book_platform_merchandise_profit=case when kind='book' then v_platform_merchandise else book_platform_merchandise_profit end,
    cash_collected_by=v_collector_role,
    cash_collected_at=coalesce(cash_collected_at,now()),
    library_cash_collected=case when v_collector_role='library' then v_total else 0 end,
    delegate_cash_collected=case when v_collector_role='delegate' then v_total else 0 end,
    finance_version=case when kind='book' then '4.2-books-independent-courier-fee' else '4.2.1-independent-courier-fee' end
  where id=o.id;
  perform set_config('alin.internal_order_transition','off',true);

  return jsonb_build_object(
    'ledger_id',v_ledger_id,'order_id',o.id,'total',v_total,'admin',v_admin,
    'teacher',v_teacher,'library',v_library,'delegate',v_delegate,
    'supplier',v_supplier,'supplier_id',v_supplier_id,'supplier_type',v_supplier_type,'supplier_name',v_supplier_name,
    'collector_debt',v_debt,
    'shares',case
      when o.kind='booklet' then jsonb_build_object('platform',v_platform_pct,'teacher',v_teacher_pct,'library',v_library_pct)
      when o.kind='book' then jsonb_build_object('platform',v_platform_pct,'supplier',o.book_supplier_share_percent)
      else null
    end
  );
end
$function$;

commit;
