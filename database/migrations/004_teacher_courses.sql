create table if not exists public.teacher_courses (
  id text primary key default ('CRS' || replace(extensions.gen_random_uuid()::text,'-','')),
  teacher_id text not null references public.accounts(id) on delete cascade,
  teacher_name text not null,
  teacher_avatar_path text,
  title text not null,
  subject text not null,
  grade text,
  start_date date not null,
  schedule_text text,
  mode text not null default 'حضوري' check (mode in ('حضوري','أونلاين','حضوري وأونلاين')),
  location text,
  price numeric(14,2) not null default 0 check (price >= 0),
  seats integer check (seats is null or seats >= 0),
  contact_phone text,
  details text,
  status text not null default 'pending' check (status in ('draft','pending','published','rejected','hidden')),
  admin_note text,
  approved_by text references public.accounts(id) on delete set null,
  approved_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists teacher_courses_teacher_idx on public.teacher_courses(teacher_id,created_at desc);
create index if not exists teacher_courses_public_idx on public.teacher_courses(status,start_date,created_at desc);

alter table public.teacher_courses enable row level security;

drop policy if exists teacher_courses_public_read on public.teacher_courses;
create policy teacher_courses_public_read on public.teacher_courses
for select to anon
using (status='published');

drop policy if exists teacher_courses_authenticated_read on public.teacher_courses;
create policy teacher_courses_authenticated_read on public.teacher_courses
for select to authenticated
using (
  status='published'
  or public.alin_is_admin()
  or teacher_id=public.alin_current_account_id()
);

drop policy if exists teacher_courses_teacher_insert on public.teacher_courses;
create policy teacher_courses_teacher_insert on public.teacher_courses
for insert to authenticated
with check (
  public.alin_current_role()='teacher'
  and teacher_id=public.alin_current_account_id()
  and status in ('draft','pending')
);

drop policy if exists teacher_courses_teacher_update on public.teacher_courses;
create policy teacher_courses_teacher_update on public.teacher_courses
for update to authenticated
using (
  public.alin_current_role()='teacher'
  and teacher_id=public.alin_current_account_id()
  and status in ('draft','pending','rejected')
)
with check (
  teacher_id=public.alin_current_account_id()
  and status in ('draft','pending')
);

drop policy if exists teacher_courses_teacher_delete on public.teacher_courses;
create policy teacher_courses_teacher_delete on public.teacher_courses
for delete to authenticated
using (
  public.alin_current_role()='teacher'
  and teacher_id=public.alin_current_account_id()
  and status in ('draft','pending','rejected')
);

drop policy if exists teacher_courses_admin_insert on public.teacher_courses;
create policy teacher_courses_admin_insert on public.teacher_courses
for insert to authenticated
with check (public.alin_is_admin());

drop policy if exists teacher_courses_admin_update on public.teacher_courses;
create policy teacher_courses_admin_update on public.teacher_courses
for update to authenticated
using (public.alin_is_admin())
with check (public.alin_is_admin());

drop policy if exists teacher_courses_admin_delete on public.teacher_courses;
create policy teacher_courses_admin_delete on public.teacher_courses
for delete to authenticated
using (public.alin_is_admin());

drop trigger if exists teacher_courses_updated on public.teacher_courses;
create trigger teacher_courses_updated before update on public.teacher_courses
for each row execute function public.alin_set_updated_at();

grant select on public.teacher_courses to anon;
grant select,insert,update,delete on public.teacher_courses to authenticated;
