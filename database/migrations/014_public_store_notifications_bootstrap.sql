drop policy if exists notifications_public_read on public.notifications;
create policy notifications_public_read on public.notifications
for select to anon
using (
  status='active'
  and account_id is null
  and role in ('all','student')
  and (expires_at is null or expires_at>=now())
);

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
coupons as (select coalesce(jsonb_agg(to_jsonb(c) order by c.created_at desc),'[]'::jsonb) value from public.coupons c where c.bound_student_id is null),
notifications as (
  select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc),'[]'::jsonb) value
  from (
    select * from public.notifications n
    where n.status='active'
      and n.account_id is null
      and n.role in ('all','student')
      and (n.expires_at is null or n.expires_at>=now())
    order by n.created_at desc
    limit 100
  ) n
)
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
  'notifications',(select value from notifications)
);
$function$;
