-- CN Booking Studio: multi-tenant foundation for Supabase
-- Run this file in Supabase SQL Editor. Public users can view active storefronts/services
-- and create bookings, but cannot read customer booking records.

create extension if not exists pgcrypto;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text not null default '',
  timezone text not null default 'Asia/Taipei',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'owner' check (role in ('owner','staff')),
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text not null default '',
  duration_minutes integer not null default 60 check (duration_minutes between 5 and 720),
  price numeric(10,2),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, id)
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  service_id uuid not null,
  customer_name text not null check (char_length(customer_name) between 1 and 80),
  customer_contact text not null check (char_length(customer_contact) between 1 and 100),
  appointment_date date not null,
  start_time time not null,
  notes text not null default '' check (char_length(notes) <= 1000),
  status text not null default 'pending' check (status in ('pending','confirmed','cancelled','completed')),
  created_at timestamptz not null default now(),
  constraint bookings_service_belongs_to_business
    foreign key (business_id, service_id) references public.services(business_id, id),
  constraint bookings_not_in_past check (
    appointment_date >= (now() at time zone 'Asia/Taipei')::date
  )
);

-- A time slot can only have one live booking per business. Cancelled bookings release it.
create unique index if not exists bookings_unique_live_slot
  on public.bookings (business_id, appointment_date, start_time)
  where status in ('pending','confirmed');

create index if not exists services_business_active_idx on public.services(business_id, is_active);
create index if not exists bookings_business_date_idx on public.bookings(business_id, appointment_date);

alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;

-- Storefront and service catalogue are public only when active.
drop policy if exists "public can view active businesses" on public.businesses;
create policy "public can view active businesses"
on public.businesses for select to anon, authenticated
using (is_active = true);

drop policy if exists "members can view their businesses" on public.businesses;
create policy "members can view their businesses"
on public.businesses for select to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = businesses.id and m.user_id = auth.uid()
));

drop policy if exists "members can manage their businesses" on public.businesses;
create policy "members can manage their businesses"
on public.businesses for update to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = businesses.id and m.user_id = auth.uid() and m.role = 'owner'
))
with check (exists (
  select 1 from public.business_members m
  where m.business_id = businesses.id and m.user_id = auth.uid() and m.role = 'owner'
));

drop policy if exists "members can view memberships" on public.business_members;
create policy "members can view memberships"
on public.business_members for select to authenticated
using (user_id = auth.uid());

drop policy if exists "public can view active services" on public.services;
create policy "public can view active services"
on public.services for select to anon, authenticated
using (is_active = true and exists (
  select 1 from public.businesses b where b.id = services.business_id and b.is_active = true
));

drop policy if exists "members can view all services" on public.services;
create policy "members can view all services"
on public.services for select to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = services.business_id and m.user_id = auth.uid()
));

drop policy if exists "members can insert services" on public.services;
create policy "members can insert services"
on public.services for insert to authenticated
with check (exists (
  select 1 from public.business_members m
  where m.business_id = services.business_id and m.user_id = auth.uid()
));

drop policy if exists "members can update services" on public.services;
create policy "members can update services"
on public.services for update to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = services.business_id and m.user_id = auth.uid()
))
with check (exists (
  select 1 from public.business_members m
  where m.business_id = services.business_id and m.user_id = auth.uid()
));

drop policy if exists "members can delete services" on public.services;
create policy "members can delete services"
on public.services for delete to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = services.business_id and m.user_id = auth.uid()
));

-- Public booking creation only. No public SELECT policy: customer data stays private.
drop policy if exists "public can create pending bookings" on public.bookings;
create policy "public can create pending bookings"
on public.bookings for insert to anon, authenticated
with check (
  status = 'pending'
  and appointment_date >= (now() at time zone 'Asia/Taipei')::date
  and exists (
    select 1 from public.businesses b
    where b.id = bookings.business_id and b.is_active = true
  )
  and exists (
    select 1 from public.services s
    where s.id = bookings.service_id
      and s.business_id = bookings.business_id
      and s.is_active = true
  )
);

drop policy if exists "members can view business bookings" on public.bookings;
create policy "members can view business bookings"
on public.bookings for select to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = bookings.business_id and m.user_id = auth.uid()
));

drop policy if exists "members can update business bookings" on public.bookings;
create policy "members can update business bookings"
on public.bookings for update to authenticated
using (exists (
  select 1 from public.business_members m
  where m.business_id = bookings.business_id and m.user_id = auth.uid()
))
with check (exists (
  select 1 from public.business_members m
  where m.business_id = bookings.business_id and m.user_id = auth.uid()
));

-- IMPORTANT:
-- 1) Create the first business and its owner membership using the Supabase SQL Editor
--    after the owner has registered; do not expose the service_role key in frontend code.
-- 2) This starter schema does not yet implement opening hours, holidays, staff calendars,
--    payment, messaging, or automated reminders.
