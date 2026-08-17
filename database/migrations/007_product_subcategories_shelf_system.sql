-- ALIN v4.2.0 — product subcategories/shelves, complete reproducible migration.

create table if not exists public.product_subcategories (
  id text primary key default ('PSC' || replace(extensions.gen_random_uuid()::text,'-','')),
  parent_category_id text not null references public.categories(id) on delete cascade,
  name text not null,
  status text not null default 'active' check (status in ('active','inactive')),
  sort_order integer not null default 10 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists product_subcategories_parent_name_unique
  on public.product_subcategories(parent_category_id, lower(name));
create index if not exists product_subcategories_parent_status_sort_idx
  on public.product_subcategories(parent_category_id,status,sort_order,name);

alter table public.products
  add column if not exists subcategory_id text references public.product_subcategories(id) on delete set null;
create index if not exists products_subcategory_id_idx on public.products(subcategory_id) where subcategory_id is not null;

alter table public.product_subcategories enable row level security;

drop policy if exists product_subcategories_public_read on public.product_subcategories;
create policy product_subcategories_public_read on public.product_subcategories
for select to anon using (status='active');

drop policy if exists product_subcategories_authenticated_read on public.product_subcategories;
create policy product_subcategories_authenticated_read on public.product_subcategories
for select to authenticated using (status='active' or public.alin_is_admin());

drop policy if exists product_subcategories_admin_insert on public.product_subcategories;
create policy product_subcategories_admin_insert on public.product_subcategories
for insert to authenticated with check (public.alin_is_admin());

drop policy if exists product_subcategories_admin_update on public.product_subcategories;
create policy product_subcategories_admin_update on public.product_subcategories
for update to authenticated using (public.alin_is_admin()) with check (public.alin_is_admin());

drop policy if exists product_subcategories_admin_delete on public.product_subcategories;
create policy product_subcategories_admin_delete on public.product_subcategories
for delete to authenticated using (public.alin_is_admin());

grant select on public.product_subcategories to anon,authenticated;
grant insert,update,delete on public.product_subcategories to authenticated;

-- Realtime is optional; add the table only when the publication exists and it is not already present.
do $block$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime')
     and not exists(
       select 1 from pg_publication_tables
       where pubname='supabase_realtime' and schemaname='public' and tablename='product_subcategories'
     ) then
    execute 'alter publication supabase_realtime add table public.product_subcategories';
  end if;
exception when insufficient_privilege then null;
end
$block$;
