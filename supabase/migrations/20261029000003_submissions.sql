create table public.submission (
  id bigint generated always as identity primary key,
  submitted_by uuid not null references public.profile on delete cascade,
  kind text not null check (kind in ('station', 'price', 'correction')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'withdrawn')),
  created_at timestamptz not null default now(),
  decided_by uuid references public.profile on delete set null,
  decided_at timestamptz,
  name text check (btrim(name) <> '' and length(name) <= 100),
  brand_id bigint references public.brand on delete restrict,
  barangay_id bigint references public.barangay on delete restrict,
  street_address text check (btrim(street_address) <> '' and length(street_address) <= 200),
  latitude public.latitude,
  longitude public.longitude,
  station_id bigint references public.station on delete restrict,
  product_id bigint references public.fuel_product on delete restrict,
  price_report_id bigint references public.price_report on delete restrict,
  price public.price_php,
  observed_on date,
  check ((latitude is null) = (longitude is null)),
  check (kind <> 'station' or (
    num_nonnulls(name, brand_id, barangay_id, street_address) = 4
    and num_nonnulls(station_id, product_id, price_report_id, price, observed_on) = 0)),
  check (kind <> 'price' or (
    num_nonnulls(station_id, product_id, price, observed_on) = 4
    and num_nonnulls(name, brand_id, barangay_id, street_address, latitude, longitude, price_report_id) = 0)),
  check (kind <> 'correction' or (
    num_nonnulls(price_report_id, price, observed_on) = 3
    and num_nonnulls(name, brand_id, barangay_id, street_address, latitude, longitude, station_id, product_id) = 0)),
  check ((status = 'pending') = (decided_at is null)),
  check (decided_by is null or status in ('approved', 'rejected'))
);

create index submission_submitted_by_created_at_idx on public.submission (submitted_by, created_at);

alter table public.submission enable row level security;
revoke all on public.submission from anon, authenticated;
grant select on public.submission to authenticated;
grant insert (kind, name, brand_id, barangay_id, street_address, latitude, longitude,
  station_id, product_id, price_report_id, price, observed_on) on public.submission to authenticated;
grant update (status) on public.submission to authenticated;

create policy own_or_admin_read on public.submission for select to authenticated
  using (submitted_by = (select auth.uid()) or (select private.is_admin()));

create policy own_insert on public.submission for insert to authenticated
  with check (
    submitted_by = (select auth.uid())
    and not exists (
      select 1 from public.profile p where p.id = (select auth.uid()) and p.banned_at is not null));

create policy own_pending_or_admin_update on public.submission for update to authenticated
  using ((submitted_by = (select auth.uid()) and status = 'pending') or (select private.is_admin()))
  with check (submitted_by = (select auth.uid()) or (select private.is_admin()));

grant select on public.profile to authenticated;
create policy own_or_admin_read on public.profile for select to authenticated
  using (id = (select auth.uid()) or (select private.is_admin()));

create function private.submission_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profile;
begin
  new.submitted_by := auth.uid();

  select * into p from public.profile where id = new.submitted_by for update;

  if p.banned_at is not null then
    raise exception 'banned';
  end if;

  if not coalesce(p.is_admin, false) and (
    select count(*) from public.submission s
    where s.submitted_by = new.submitted_by
      and s.created_at >= ((now() at time zone 'Asia/Manila')::date)::timestamp at time zone 'Asia/Manila'
  ) >= 20 then
    raise exception 'daily_limit';
  end if;

  if new.kind = 'price' and exists (
    select 1 from public.station s, public.fuel_product fp
    where s.id = new.station_id and fp.id = new.product_id and s.brand_id <> fp.brand_id
  ) then
    raise exception 'brand_mismatch';
  end if;

  if new.kind = 'station' and exists (
    select 1 from public.station s
    where s.brand_id = new.brand_id and s.barangay_id = new.barangay_id
      and lower(s.street_address) = lower(new.street_address)
  ) then
    raise exception 'duplicate_station';
  end if;

  if new.observed_on > (now() at time zone 'Asia/Manila')::date then
    raise exception 'future_date';
  end if;

  if p.is_admin then
    new.status := 'approved';
    new.decided_by := new.submitted_by;
    new.decided_at := now();
  end if;

  return new;
end;
$$;

create function private.submission_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> 'pending' then
    raise exception 'not_pending';
  end if;

  if new.status = 'withdrawn' then
    if old.submitted_by is distinct from auth.uid() then
      raise exception 'not_allowed';
    end if;
    new.decided_at := now();
  else
    if not private.is_admin() then
      raise exception 'not_allowed';
    end if;
    new.decided_by := auth.uid();
    new.decided_at := now();
  end if;

  return new;
end;
$$;

create function private.submission_after_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'approved' then
    if new.kind = 'station' then
      insert into public.station (brand_id, barangay_id, name, street_address, latitude, longitude)
      values (new.brand_id, new.barangay_id, new.name, new.street_address, new.latitude, new.longitude);
    elsif new.kind = 'price' then
      insert into public.station_product (station_id, product_id, brand_id)
      select s.id, new.product_id, s.brand_id from public.station s where s.id = new.station_id
      on conflict (station_id, product_id) do nothing;

      insert into public.price_report (station_product_id, price, observed_on, submitted_by)
      select sp.id, new.price, new.observed_on, new.submitted_by from public.station_product sp
      where sp.station_id = new.station_id and sp.product_id = new.product_id;
    else
      update public.price_report set price = new.price, observed_on = new.observed_on
      where id = new.price_report_id;
    end if;
  end if;

  insert into public.admin_log (admin_id, action, target_table, target_id)
  values (new.decided_by, case new.status when 'approved' then 'approve' else 'reject' end, 'submission', new.id::text);

  return null;
end;
$$;

create trigger submission_before_insert
  before insert on public.submission
  for each row execute function private.submission_before_insert();

create trigger submission_before_update
  before update on public.submission
  for each row when (old.status is distinct from new.status)
  execute function private.submission_before_update();

create trigger submission_after_insert
  after insert on public.submission
  for each row when (new.status = 'approved')
  execute function private.submission_after_decision();

create trigger submission_after_update
  after update on public.submission
  for each row when (old.status is distinct from new.status and new.status in ('approved', 'rejected'))
  execute function private.submission_after_decision();

revoke execute on all functions in schema private from public;
grant execute on function private.is_admin() to authenticated;
