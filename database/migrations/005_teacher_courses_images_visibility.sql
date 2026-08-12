alter table public.teacher_courses
  add column if not exists cover_image_path text;

create table if not exists public.teacher_courses_settings (
  id text primary key default 'main' check (id = 'main'),
  section_visible boolean not null default true,
  updated_by text references public.accounts(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.teacher_courses_settings (id,section_visible) values ('main',true) on conflict (id) do nothing;
alter table public.teacher_courses_settings enable row level security;
drop policy if exists teacher_courses_settings_public_read on public.teacher_courses_settings;
create policy teacher_courses_settings_public_read on public.teacher_courses_settings for select to anon,authenticated using (true);
drop policy if exists teacher_courses_settings_admin_update on public.teacher_courses_settings;
create policy teacher_courses_settings_admin_update on public.teacher_courses_settings for update to authenticated using (public.alin_is_admin()) with check (public.alin_is_admin());
grant select on public.teacher_courses_settings to anon,authenticated;
grant update on public.teacher_courses_settings to authenticated;
