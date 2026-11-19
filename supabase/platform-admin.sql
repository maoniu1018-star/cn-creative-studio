-- CN Booking Studio: platform owner/admin controls
-- Run once in Supabase SQL Editor after schema.sql and onboarding.sql.
-- This seeds the Auth user UUID shown in the project Users screen for maoniu1018@gmail.com.

create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;

drop policy if exists "platform admins can view own admin record" on public.platform_admins;
create policy "platform admins can view own admin record"
on public.platform_admins for select to authenticated
using (user_id = auth.uid());

insert into public.platform_admins(user_id)
values ('1a65a439-1945-4c0d-9fff-2b0f81e12a3e')
on conflict (user_id) do nothing;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.platform_admins
    where user_id = auth.uid()
  );
$$;

create or replace function public.admin_list_businesses()
returns table(id uuid, name text, slug text, description text, is_active boolean)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.is_platform_admin() then
    raise exception '只有平台管理員可以查看店家清單';
  end if;
  return query
    select b.id, b.name, b.slug, b.description, b.is_active
    from public.businesses b
    order by b.created_at desc;
end;
$$;

create or replace function public.admin_create_business(
  p_name text,
  p_slug text,
  p_description text default ''
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business_id uuid;
  v_slug text := lower(trim(p_slug));
begin
  if not public.is_platform_admin() then
    raise exception '只有平台管理員可以建立店家';
  end if;
  if length(trim(p_name)) < 2 or length(trim(p_name)) > 80 then
    raise exception '店家名稱需為 2 至 80 個字';
  end if;
  if v_slug !~ '^[a-z0-9][a-z0-9-]{2,39}$' then
    raise exception '網址代稱需為 3 至 40 個英數字或連字號，且以英數字開頭';
  end if;

  insert into public.businesses(name, slug, description)
  values (trim(p_name), v_slug, coalesce(trim(p_description), ''))
  returning id into v_business_id;

  insert into public.business_members(business_id, user_id, role)
  values (v_business_id, auth.uid(), 'owner');
  return v_business_id;
exception
  when unique_violation then
    raise exception '這個網址代稱已被使用，請換一個';
end;
$$;

revoke all on function public.is_platform_admin() from public;
revoke all on function public.admin_list_businesses() from public;
revoke all on function public.admin_create_business(text,text,text) from public;
grant execute on function public.is_platform_admin() to authenticated;
grant execute on function public.admin_list_businesses() to authenticated;
grant execute on function public.admin_create_business(text,text,text) to authenticated;
