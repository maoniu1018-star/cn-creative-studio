-- CN Booking Studio: secure owner onboarding RPC
-- Run AFTER schema.sql and the RLS policy setup have succeeded.

create or replace function public.create_business_for_current_user(
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
  v_user_id uuid := auth.uid();
  v_business_id uuid;
  v_slug text := lower(trim(p_slug));
begin
  if v_user_id is null then
    raise exception '請先登入';
  end if;

  if length(trim(p_name)) < 2 or length(trim(p_name)) > 80 then
    raise exception '店家名稱需為 2 至 80 個字';
  end if;

  if v_slug !~ '^[a-z0-9][a-z0-9-]{2,39}$' then
    raise exception '網址代稱需為 3 至 40 個英數字或連字號，且以英數字開頭';
  end if;

  insert into public.businesses (name, slug, description)
  values (trim(p_name), v_slug, coalesce(trim(p_description), ''))
  returning id into v_business_id;

  insert into public.business_members (business_id, user_id, role)
  values (v_business_id, v_user_id, 'owner');

  return v_business_id;
exception
  when unique_violation then
    raise exception '這個網址代稱已被使用，請換一個';
end;
$$;

revoke all on function public.create_business_for_current_user(text,text,text) from public;
grant execute on function public.create_business_for_current_user(text,text,text) to authenticated;
