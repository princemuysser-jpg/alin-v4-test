-- ALIN v4.2.0 — product models/designs with code, image, independent stock and order snapshot.
-- Isolated to retail products; existing orders remain unchanged.

create table if not exists public.product_variants (
  id text primary key default ('PV' || replace(extensions.gen_random_uuid()::text,'-','')),
  product_id text not null references public.products(id) on delete cascade,
  code text not null,
  name text not null,
  image_path text,
  stock numeric not null default 0 check (stock >= 0),
  status text not null default 'active' check (status in ('active','inactive')),
  sort_order integer not null default 10 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_variants_code_not_blank check (length(btrim(code)) between 1 and 40),
  constraint product_variants_name_not_blank check (length(btrim(name)) between 1 and 120)
);

create unique index if not exists product_variants_product_code_unique
  on public.product_variants(product_id, lower(btrim(code)));
create index if not exists product_variants_product_status_sort_idx
  on public.product_variants(product_id,status,sort_order,code);

alter table public.product_variants enable row level security;

drop policy if exists product_variants_public_read on public.product_variants;
create policy product_variants_public_read on public.product_variants
for select to anon using (status='active');

drop policy if exists product_variants_authenticated_read on public.product_variants;
create policy product_variants_authenticated_read on public.product_variants
for select to authenticated using (status='active' or public.alin_is_admin());

drop policy if exists product_variants_admin_insert on public.product_variants;
create policy product_variants_admin_insert on public.product_variants
for insert to authenticated with check (public.alin_is_admin());

drop policy if exists product_variants_admin_update on public.product_variants;
create policy product_variants_admin_update on public.product_variants
for update to authenticated using (public.alin_is_admin()) with check (public.alin_is_admin());

grant select on public.product_variants to anon,authenticated;
grant insert,update on public.product_variants to authenticated;
revoke delete on public.product_variants from anon,authenticated;

create or replace function public.alin_set_product_variant_updated_at()
returns trigger language plpgsql set search_path to 'public','pg_temp' as $function$
begin
  new.updated_at:=now();
  return new;
end $function$;

drop trigger if exists product_variants_updated_at on public.product_variants;
create trigger product_variants_updated_at
before update on public.product_variants
for each row execute function public.alin_set_product_variant_updated_at();

create or replace function public.alin_recompute_product_variant_stock(p_product_id text)
returns void language plpgsql security definer set search_path to 'public','pg_temp' as $function$
declare v_exists boolean; v_total numeric;
begin
  if nullif(btrim(coalesce(p_product_id,'')),'') is null then return; end if;
  select exists(select 1 from public.product_variants where product_id=p_product_id),
         coalesce(sum(stock) filter(where status='active'),0)
  into v_exists,v_total
  from public.product_variants where product_id=p_product_id;
  if v_exists then
    update public.products set stock=v_total,updated_at=now() where id=p_product_id;
  end if;
end $function$;

create or replace function public.alin_sync_product_variant_stock()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $function$
begin
  if tg_op='DELETE' then
    perform public.alin_recompute_product_variant_stock(old.product_id);
    return old;
  end if;
  perform public.alin_recompute_product_variant_stock(new.product_id);
  if tg_op='UPDATE' and old.product_id is distinct from new.product_id then
    perform public.alin_recompute_product_variant_stock(old.product_id);
  end if;
  return new;
end $function$;

drop trigger if exists product_variants_sync_product_stock on public.product_variants;
create trigger product_variants_sync_product_stock
after insert or update or delete on public.product_variants
for each row execute function public.alin_sync_product_variant_stock();

alter table public.orders
  add column if not exists product_variant_id text,
  add column if not exists product_variant_code text,
  add column if not exists product_variant_name text,
  add column if not exists product_variant_image_path text;
create index if not exists orders_product_variant_id_idx on public.orders(product_variant_id) where product_variant_id is not null;

create or replace function public.alin_protect_product_variant_snapshot()
returns trigger language plpgsql security definer set search_path to 'public','pg_temp' as $function$
begin
  if current_setting('request.jwt.claim.role',true)='service_role'
     or current_setting('alin.internal_order_transition',true)='on' then return new; end if;
  if old.product_variant_id is distinct from new.product_variant_id
     or old.product_variant_code is distinct from new.product_variant_code
     or old.product_variant_name is distinct from new.product_variant_name
     or old.product_variant_image_path is distinct from new.product_variant_image_path then
    raise exception 'تصميم المنتج المثبت على الطلب لا يمكن تغييره بعد إنشاء الطلب';
  end if;
  return new;
end $function$;

drop trigger if exists orders_protect_product_variant_snapshot on public.orders;
create trigger orders_protect_product_variant_snapshot
before update on public.orders
for each row execute function public.alin_protect_product_variant_snapshot();

create or replace function public.alin_public_store_bootstrap()
returns jsonb
language sql
stable
set search_path to 'public','pg_temp'
as $function$
with
settings_obj as (
  select jsonb_build_object('storeType','booklet')
    || coalesce((select s.data from public.alin_public_settings s where s.key='__main__' or s.id='main' order by case when s.key='__main__' then 0 else 1 end limit 1),'{}'::jsonb)
    || coalesce((select jsonb_object_agg(s.key,to_jsonb(s.value)) from public.alin_public_settings s where s.key is not null and s.key<>'__main__'),'{}'::jsonb) as value
),
teachers as (select coalesce(jsonb_agg(to_jsonb(a) order by a.name),'[]'::jsonb) value from public.alin_public_accounts a where a.role='teacher'),
libraries as (select coalesce(jsonb_agg(to_jsonb(a) order by a.name),'[]'::jsonb) value from public.alin_public_accounts a where a.role='library'),
delivery_areas as (select coalesce(jsonb_agg(to_jsonb(d) order by d.sort_order nulls last,d.name),'[]'::jsonb) value from public.delivery_areas d),
categories as (select coalesce(jsonb_agg(to_jsonb(c) order by c.sort_order nulls last,c.created_at),'[]'::jsonb) value from public.categories c),
product_subcategories as (select coalesce(jsonb_agg(to_jsonb(s) order by s.parent_category_id,s.sort_order,s.name),'[]'::jsonb) value from public.product_subcategories s where s.status='active'),
product_variants as (select coalesce(jsonb_agg(to_jsonb(v) order by v.product_id,v.sort_order,v.code),'[]'::jsonb) value from public.product_variants v where v.status='active'),
booklets as (select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at desc),'[]'::jsonb) value from public.alin_public_booklets b),
products as (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc),'[]'::jsonb) value from public.products p),
banners as (select coalesce(jsonb_agg(to_jsonb(b) order by b.sort_order nulls last,b.created_at desc),'[]'::jsonb) value from public.banners b),
coupons as (select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at desc),'[]'::jsonb) value from public.coupons c)
select jsonb_build_object(
  'settings',(select value from settings_obj),
  'accounts',jsonb_build_object('all','[]'::jsonb,'teachers',(select value from teachers),'libraries',(select value from libraries),'couriers','[]'::jsonb,'accountants','[]'::jsonb),
  'deliveryAreas',(select value from delivery_areas),
  'categories',(select value from categories),
  'productSubcategories',(select value from product_subcategories),
  'productVariants',(select value from product_variants),
  'booklets',(select value from booklets),
  'products',(select value from products),
  'banners',(select value from banners),
  'coupons',(select value from coupons),
  'notifications','[]'::jsonb
);
$function$;

create or replace function public.alin_create_store_orders_guarded(
  p_items jsonb,
  p_customer jsonb,
  p_fulfillment jsonb default '{}'::jsonb,
  p_coupon_code text default null,
  p_request_key text default null,
  p_device_id text default null
)
returns table(order_number text,order_id text)
language plpgsql security definer set search_path=public,extensions,pg_temp as $function$
declare
  v_request_key text:=lower(btrim(coalesce(p_request_key,'')));
  v_device text:=btrim(coalesce(p_device_id,''));
  v_name text:=btrim(coalesce(p_customer->>'name',''));
  v_phone text:=translate(btrim(coalesce(p_customer->>'phone','')),'٠١٢٣٤٥٦٧٨٩','0123456789');
  v_notes text:=left(btrim(coalesce(p_customer->>'notes','')),1000);
  v_phone_hash text; v_device_hash text; v_payload_hash text;
  v_request_id uuid; v_existing public.checkout_requests%rowtype;
  v_count integer; v_result jsonb:='[]'::jsonb;
  v_fulfillment text; v_library_id text; v_area_id text; v_area public.delivery_areas%rowtype;
  v_delivery_fee numeric:=0; v_landmark text; v_lat numeric; v_lng numeric; v_accuracy integer;
  v_coupon public.coupons%rowtype; v_coupon_value numeric:=0; v_fixed_remaining numeric:=0; v_coupon_applied boolean:=false; v_cart_subtotal numeric:=0;
  v_item jsonb; v_kind text; v_item_id text; v_qty integer; v_title text; v_price numeric; v_stock numeric;
  v_unit_price numeric; v_pack_price numeric; v_pack_size integer; v_purchase_type text; v_stock_units numeric;
  v_variant_id text; v_variant_code text; v_variant_name text; v_variant_image text; v_variant_stock numeric; v_has_variants boolean;
  v_subtotal numeric; v_discount numeric; v_total numeric; v_index integer:=0; v_id text; v_number text;
  v_student_id text;
begin
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'السلة فارغة'; end if;
  if jsonb_array_length(p_items)>30 then raise exception 'عدد عناصر السلة أكبر من الحد المسموح'; end if;
  v_phone:=regexp_replace(v_phone,'[^0-9+]','','g');
  if length(v_name)<2 or length(v_name)>120 then raise exception 'اكتب اسم الطالب بصورة صحيحة'; end if;
  if v_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'اكتب رقم هاتف صحيح'; end if;
  if v_request_key !~ '^[a-z0-9-]{20,80}$' then raise exception 'رمز تأكيد الطلب غير صالح. حدّث الصفحة وحاول مجدداً'; end if;
  if length(v_device)<16 or length(v_device)>160 then raise exception 'تعذر التحقق من جهاز الطلب'; end if;

  v_phone_hash:=encode(extensions.digest('alin-phone-v4:'||v_phone,'sha256'),'hex');
  v_device_hash:=encode(extensions.digest('alin-device-v4:'||v_device,'sha256'),'hex');
  v_payload_hash:=encode(extensions.digest(jsonb_build_object('items',p_items,'customer',jsonb_build_object('name',v_name,'phone',v_phone,'notes',v_notes),'fulfillment',p_fulfillment,'coupon',lower(btrim(coalesce(p_coupon_code,''))))::text,'sha256'),'hex');

  insert into public.checkout_requests(request_key,device_hash,phone_hash,payload_hash,status)
  values(v_request_key,v_device_hash,v_phone_hash,v_payload_hash,'pending')
  on conflict(request_key) do nothing returning id into v_request_id;

  if v_request_id is null then
    select * into v_existing from public.checkout_requests where request_key=v_request_key for update;
    if v_existing.payload_hash<>v_payload_hash then raise exception 'رمز الطلب مستخدم لمحتوى مختلف'; end if;
    if v_existing.status='completed' and jsonb_typeof(v_existing.result)='array' then
      return query select x.order_number,x.order_id from jsonb_to_recordset(v_existing.result) x(order_number text,order_id text); return;
    end if;
    if v_existing.created_at>now()-interval '2 minutes' then raise exception 'الطلب نفسه قيد المعالجة. انتظر لحظات'; end if;
    update public.checkout_requests set device_hash=v_device_hash,phone_hash=v_phone_hash,payload_hash=v_payload_hash,status='pending',result=null,created_at=now(),completed_at=null where id=v_existing.id returning id into v_request_id;
  end if;

  select count(*) into v_count from public.checkout_requests where phone_hash=v_phone_hash and created_at>now()-interval '5 minutes';
  if v_count>4 then raise exception 'تم إرسال طلبات كثيرة لهذا الرقم. انتظر خمس دقائق'; end if;
  select count(*) into v_count from public.checkout_requests where device_hash=v_device_hash and created_at>now()-interval '5 minutes';
  if v_count>8 then raise exception 'تم إرسال طلبات كثيرة من هذا الجهاز. انتظر خمس دقائق'; end if;

  v_fulfillment:=lower(btrim(coalesce(p_fulfillment->>'fulfillment_type',p_fulfillment->>'delivery_type','')));
  if v_fulfillment in ('pickup','library') then
    v_fulfillment:='pickup'; v_library_id:=btrim(coalesce(p_fulfillment->>'library_id',p_fulfillment->>'pickup_library_id',''));
    if v_library_id='' then raise exception 'اختر مكتبة الاستلام'; end if;
    if not exists(select 1 from public.accounts a where a.id=v_library_id and a.role='library' and a.status='active' and a.deleted_at is null and a.is_open and a.open_status='open') then raise exception 'المكتبة المختارة غير متاحة حالياً'; end if;
  elsif v_fulfillment in ('home_delivery','courier','delivery') then
    v_fulfillment:='home_delivery'; if not public.alin_setting_boolean('delivery_enabled',true) then raise exception 'خدمة التوصيل متوقفة مؤقتاً'; end if;
    v_area_id:=btrim(coalesce(p_fulfillment->>'delivery_area',''));
    select * into v_area from public.delivery_areas d where d.status='active' and d.active and (d.id=v_area_id or lower(d.name)=lower(v_area_id)) limit 1;
    if not found then raise exception 'منطقة التوصيل غير معتمدة'; end if;
    v_delivery_fee:=v_area.delivery_fee; v_landmark:=left(btrim(coalesce(p_fulfillment->>'delivery_landmark','')),300);
    begin v_lat:=nullif(p_fulfillment->>'delivery_latitude','')::numeric; exception when others then v_lat:=null; end;
    begin v_lng:=nullif(p_fulfillment->>'delivery_longitude','')::numeric; exception when others then v_lng:=null; end;
    begin v_accuracy:=nullif(p_fulfillment->>'delivery_location_accuracy','')::integer; exception when others then v_accuracy:=null; end;
    if v_lat is null and v_landmark='' then raise exception 'حدد الموقع أو اكتب أقرب نقطة دالة'; end if;
    if v_lat is not null and (v_lng is null or v_lat not between -90 and 90 or v_lng not between -180 and 180) then raise exception 'إحداثيات الموقع غير صحيحة'; end if;
  else raise exception 'اختر طريقة استلام صحيحة'; end if;

  select id into v_student_id from public.student_profiles where phone=v_phone limit 1;

  if p_coupon_code is not null and btrim(p_coupon_code)<>'' then
    select * into v_coupon from public.coupons c where lower(c.code)=lower(btrim(p_coupon_code)) for update;
    if not found or v_coupon.status<>'active' or (v_coupon.starts_at is not null and v_coupon.starts_at>now()) or (v_coupon.expires_at is not null and v_coupon.expires_at<now()) then raise exception 'الكوبون غير صالح أو منتهي'; end if;
    if v_coupon.max_uses>0 and v_coupon.used_count>=v_coupon.max_uses then raise exception 'انتهى عدد استخدامات الكوبون'; end if;
    v_coupon_value:=v_coupon.discount_value; if v_coupon.discount_type='fixed' then v_fixed_remaining:=v_coupon_value; end if;
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_index:=v_index+1;
    v_kind:=lower(btrim(coalesce(v_item->>'kind',''))); v_item_id:=btrim(coalesce(v_item->>'id',''));
    v_purchase_type:=lower(btrim(coalesce(v_item->>'purchase_type','unit')));
    v_variant_id:=nullif(btrim(coalesce(v_item->>'variant_id','')),''); v_variant_code:=null; v_variant_name:=null; v_variant_image:=null; v_variant_stock:=null; v_has_variants:=false;
    begin v_qty:=greatest(1,least(50,coalesce((v_item->>'qty')::integer,1))); exception when others then v_qty:=1; end;
    if v_item_id='' then raise exception 'عنصر غير صالح في السلة'; end if;

    if v_kind in ('booklet','booklets','booklet_product','ملزمة','ملازم') then
      select b.title,b.price into v_title,v_price from public.booklets b where b.id=v_item_id and b.status='published' and b.publish_status='published' and b.deleted_at is null;
      if not found then raise exception 'الملزمة غير متاحة حالياً'; end if;
      v_kind:='booklet'; v_purchase_type:='unit'; v_pack_size:=null; v_stock_units:=v_qty; v_variant_id:=null;
    else
      select coalesce(p.title,p.name),coalesce(p.unit_price,p.sale_price,p.price),p.pack_price,p.pack_size,p.stock
      into v_title,v_unit_price,v_pack_price,v_pack_size,v_stock
      from public.products p where p.id=v_item_id and p.status='published' and p.deleted_at is null for update;
      if not found then raise exception 'المنتج غير متاح حالياً'; end if;

      if v_purchase_type='pack' then
        if coalesce(v_pack_price,0)<=0 or coalesce(v_pack_size,0)<2 then raise exception 'سعر الباكيت غير متاح لهذا المنتج'; end if;
        v_price:=v_pack_price; v_stock_units:=v_qty*v_pack_size;
      else
        v_purchase_type:='unit'; v_price:=v_unit_price; v_pack_size:=null; v_stock_units:=v_qty;
      end if;
      if coalesce(v_price,0)<0 then raise exception 'سعر المنتج غير صالح'; end if;

      select exists(select 1 from public.product_variants where product_id=v_item_id) into v_has_variants;
      if v_has_variants then
        if v_variant_id is null then raise exception 'اختر تصميم المنتج: %',v_title; end if;
        select pv.code,pv.name,pv.image_path,pv.stock into v_variant_code,v_variant_name,v_variant_image,v_variant_stock
        from public.product_variants pv where pv.id=v_variant_id and pv.product_id=v_item_id and pv.status='active' for update;
        if not found then raise exception 'التصميم المختار غير متاح لهذا المنتج'; end if;
        if v_variant_stock<v_stock_units then raise exception 'الكمية غير متوفرة للتصميم %: %',coalesce(v_variant_code,v_variant_name),v_title; end if;
      else
        v_variant_id:=null;
        if v_stock<v_stock_units then raise exception 'الكمية غير متوفرة: %',v_title; end if;
      end if;

      select case p.type when 'stationery' then 'stationery' when 'gift' then 'gift' else 'product' end into v_kind from public.products p where p.id=v_item_id;
      if v_fulfillment='pickup' then raise exception 'القرطاسية والهدايا متاحة بالتوصيل إلى البيت فقط'; end if;
    end if;

    v_subtotal:=v_price*v_qty; v_cart_subtotal:=v_cart_subtotal+v_subtotal; v_discount:=0;
    if p_coupon_code is not null and btrim(p_coupon_code)<>'' and (v_coupon.applies_to in ('all','') or v_coupon.applies_to=v_kind or (v_coupon.applies_to='product' and v_kind<>'booklet')) then
      if v_coupon.discount_type='percent' then
        v_discount:=round(v_subtotal*least(v_coupon_value,100)/100); if v_coupon.max_discount>0 then v_discount:=least(v_discount,v_coupon.max_discount); end if;
      else v_discount:=least(v_subtotal,v_fixed_remaining); v_fixed_remaining:=greatest(v_fixed_remaining-v_discount,0); end if;
    end if;
    v_total:=greatest(v_subtotal-v_discount,0)+case when v_index=1 then v_delivery_fee else 0 end; if v_discount>0 then v_coupon_applied:=true; end if;

    v_id:='O'||replace(extensions.gen_random_uuid()::text,'-','');
    v_number:='AL-'||to_char(clock_timestamp(),'YYMMDDHH24MISS')||'-'||lpad(v_index::text,2,'0')||'-'||substr(replace(extensions.gen_random_uuid()::text,'-',''),1,4);

    insert into public.orders(
      id,order_number,kind,item_id,title,student_id,student_name,student_phone,qty,unit_price,discount,total,coupon_code,
      status,assignment_status,status_history,payment_status,payment_method,fulfillment_type,delivery_type,
      library_id,pickup_library_id,delivery_area_id,delivery_area,delivery_landmark,delivery_fee,
      delivery_latitude,delivery_longitude,delivery_location_url,delivery_location_accuracy,delivery_location_source,
      notes,purchase_type,pack_size,stock_units,product_variant_id,product_variant_code,product_variant_name,product_variant_image_path,
      checkout_request_key,checkout_group_id,stock_reserved
    ) values (
      v_id,v_number,v_kind,v_item_id,v_title,v_student_id,v_name,v_phone,v_qty,v_price,v_discount,v_total,nullif(btrim(p_coupon_code),''),
      'new','pending_admin',jsonb_build_array(jsonb_build_object('status','new','at',now(),'by','secure_checkout')),
      'cod_pending',case when v_fulfillment='pickup' then 'cash_at_library' else 'cash_to_courier' end,v_fulfillment,
      case when v_fulfillment='pickup' then 'library' else 'courier' end,
      v_library_id,v_library_id,case when v_fulfillment='home_delivery' then v_area.id else null end,
      case when v_fulfillment='home_delivery' then v_area.name else null end,v_landmark,case when v_index=1 then v_delivery_fee else 0 end,
      v_lat,v_lng,case when v_lat is not null then 'https://www.google.com/maps?q='||v_lat::text||','||v_lng::text else null end,
      v_accuracy,case when v_lat is not null then 'student_device' else 'landmark' end,
      nullif(v_notes,''),v_purchase_type,v_pack_size,v_stock_units,v_variant_id,v_variant_code,v_variant_name,v_variant_image,
      v_request_key,v_request_id::text,v_kind<>'booklet'
    );

    insert into public.order_timeline(order_id,status,actor_role,meta)
    values(v_id,'new','store',jsonb_build_object('request_key',v_request_key,'purchase_type',v_purchase_type,'stock_units',v_stock_units,'variant_id',v_variant_id,'variant_code',v_variant_code));

    if v_kind<>'booklet' then
      if v_variant_id is not null then
        update public.product_variants set stock=stock-v_stock_units where id=v_variant_id and product_id=v_item_id and stock>=v_stock_units;
        if not found then raise exception 'نفدت كمية التصميم أثناء تأكيد الطلب: %',v_title; end if;
      else
        update public.products set stock=stock-v_stock_units where id=v_item_id and stock>=v_stock_units;
        if not found then raise exception 'نفدت الكمية أثناء تأكيد الطلب: %',v_title; end if;
      end if;
    end if;

    v_result:=v_result||jsonb_build_array(jsonb_build_object('order_number',v_number,'order_id',v_id));
  end loop;

  if v_coupon.id is not null then
    if v_coupon.min_order>0 and v_cart_subtotal<v_coupon.min_order then raise exception 'قيمة السلة أقل من الحد المطلوب للكوبون'; end if;
    if not v_coupon_applied then raise exception 'الكوبون لا ينطبق على عناصر السلة'; end if;
    update public.coupons set used_count=used_count+1,usage_count=usage_count+1 where id=v_coupon.id;
  end if;

  update public.checkout_requests set status='completed',result=v_result,completed_at=now() where id=v_request_id;
  return query select x.order_number,x.order_id from jsonb_to_recordset(v_result) x(order_number text,order_id text);
end $function$;

create or replace function public.alin_order_transition_atomic(p_order_id text,p_status text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'public','extensions','pg_temp' as $function$
declare
  o public.orders%rowtype; v_updated public.orders%rowtype;
  v_role text:=public.alin_current_role(); v_account text:=public.alin_current_account_id();
  v_target text:=lower(btrim(coalesce(p_status,''))); v_source text; v_allowed boolean:=false;
  v_now timestamptz:=now(); v_finance jsonb; v_restore_units numeric;
begin
  select * into o from public.orders where id=p_order_id for update;
  if not found then raise exception 'الطلب غير موجود'; end if;
  v_source:=lower(btrim(coalesce(o.status,'new')));
  if v_source='delivered' then v_source:='completed'; end if; if v_source='out_delivery' then v_source:='out_for_delivery'; end if; if v_source='canceled' then v_source:='cancelled'; end if;
  if v_target='delivered' then v_target:='completed'; end if; if v_target='out_delivery' then v_target:='out_for_delivery'; end if; if v_target='canceled' then v_target:='cancelled'; end if;
  if v_target not in ('new','pending_admin','assigned','accepted','picked_up','out_for_delivery','processing','printing','ready','completed','cancelled','rejected') then raise exception 'حالة الطلب المطلوبة غير صحيحة'; end if;
  if v_source='completed' and v_target='completed' then v_finance:=public.alin_upsert_order_finance_atomic(o.id); select * into v_updated from public.orders where id=o.id; return jsonb_build_object('ok',true,'status','completed','order',to_jsonb(v_updated),'finance',v_finance,'idempotent',true); end if;
  if v_source='completed' then raise exception 'الطلب المكتمل لا يرجع لحالة سابقة'; end if;
  if v_source in ('cancelled','rejected') then raise exception 'الطلب الملغي أو المرفوض لا يمكن تحديثه'; end if;

  if public.alin_is_finance_staff() then v_allowed:=true;
  elsif v_role='library' and v_account in (o.library_id,o.pickup_library_id) then
    v_allowed:=(v_source in ('new','pending','pending_admin','accepted') and v_target in ('processing','cancelled')) or (v_source in ('processing','printing') and v_target in ('ready','cancelled')) or (v_source='ready' and v_target in ('completed','cancelled'));
  elsif v_role='courier' and v_account in (o.courier_id,o.delegate_id) then
    v_allowed:=(v_source in ('new','pending','pending_admin','assigned') and v_target in ('accepted','rejected')) or (v_source='accepted' and v_target='picked_up') or (v_source='picked_up' and v_target='out_for_delivery') or (v_source='out_for_delivery' and v_target='completed');
  end if;
  if not v_allowed then raise exception 'غير مسموح بانتقال الطلب من الحالة % إلى % لهذا الحساب',v_source,v_target; end if;
  if v_target in ('cancelled','rejected') and nullif(btrim(coalesce(p_reason,'')),'') is null then raise exception 'اكتب سبب الإلغاء أو الرفض'; end if;
  if v_source=v_target then return jsonb_build_object('ok',true,'status',v_target,'order',to_jsonb(o),'idempotent',true); end if;

  if v_target in ('cancelled','rejected') and o.stock_reserved and o.stock_restored_at is null and o.kind<>'booklet' then
    v_restore_units:=coalesce(o.stock_units,o.qty);
    if o.product_variant_id is not null then
      update public.product_variants set stock=stock+v_restore_units where id=o.product_variant_id and product_id=o.item_id;
      if not found then raise exception 'تعذر استرجاع مخزون تصميم المنتج للطلب %',o.order_number; end if;
    else
      update public.products set stock=stock+v_restore_units where id=o.item_id;
    end if;
  end if;

  perform set_config('alin.internal_order_transition','on',true);
  update public.orders set
    status=v_target,
    assignment_status=case when v_target='assigned' then 'assigned' when v_target='accepted' then 'accepted' when v_target='completed' then 'completed' when v_target='cancelled' then 'cancelled' when v_target='rejected' then 'rejected' else assignment_status end,
    status_history=coalesce(status_history,'[]'::jsonb)||jsonb_build_array(jsonb_build_object('status',v_target,'at',v_now,'by',coalesce(v_account,'system'),'role',coalesce(v_role,'system'),'reason',nullif(btrim(coalesce(p_reason,'')),''))),
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
  where id=o.id returning * into v_updated;
  perform set_config('alin.internal_order_transition','off',true);

  insert into public.order_timeline(order_id,status,actor_id,actor_role,reason)
  values(o.id,v_target,v_account,coalesce(v_role,'system'),nullif(btrim(coalesce(p_reason,'')),''));

  if v_target='completed' then
    v_finance:=public.alin_upsert_order_finance_atomic(o.id); select * into v_updated from public.orders where id=o.id;
  elsif v_target in ('cancelled','rejected') then
    update public.ledger set status='cancelled',settlement_status='cancelled',is_current=false,note=coalesce(note,'')||' | ألغي الطلب قبل التسوية',updated_at=v_now where order_id=o.id and status<>'settled';
  end if;
  return jsonb_build_object('ok',true,'status',v_target,'order',to_jsonb(v_updated),'finance',v_finance);
end $function$;

-- Make model changes visible across devices when Realtime is enabled.
do $block$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='product_variants') then
    alter publication supabase_realtime add table public.product_variants;
  end if;
end $block$;
