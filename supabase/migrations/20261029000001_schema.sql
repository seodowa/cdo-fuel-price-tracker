create domain public.price_php as numeric(6,2) check (value between 20 and 200);
create domain public.shift_php as numeric(5,2) check (value between -20 and 20);
create domain public.latitude as numeric(9,6) check (value between 4 and 22);
create domain public.longitude as numeric(9,6) check (value between 116 and 127);

create table public.province (
  id bigint generated always as identity primary key,
  name text not null check (btrim(name) <> '' and length(name) <= 100)
);
create unique index province_name_key on public.province (lower(name));

create table public.city (
  id bigint generated always as identity primary key,
  province_id bigint not null references public.province on delete restrict,
  name text not null check (btrim(name) <> '' and length(name) <= 100)
);
create unique index city_province_name_key on public.city (province_id, lower(name));

create table public.barangay (
  id bigint generated always as identity primary key,
  city_id bigint not null references public.city on delete restrict,
  name text not null check (btrim(name) <> '' and length(name) <= 100)
);
create unique index barangay_city_name_key on public.barangay (city_id, lower(name));

create table public.brand (
  id bigint generated always as identity primary key,
  name text not null check (btrim(name) <> '' and length(name) <= 100)
);
create unique index brand_name_key on public.brand (lower(name));

create table public.fuel_category (
  id bigint generated always as identity primary key,
  name text not null check (btrim(name) <> '' and length(name) <= 100)
);
create unique index fuel_category_name_key on public.fuel_category (lower(name));

create table public.fuel_product (
  id bigint generated always as identity primary key,
  brand_id bigint not null references public.brand on delete restrict,
  category_id bigint not null references public.fuel_category on delete restrict,
  name text not null check (btrim(name) <> '' and length(name) <= 100),
  unique (id, brand_id)
);
create unique index fuel_product_brand_name_key on public.fuel_product (brand_id, lower(name));

create table public.station (
  id bigint generated always as identity primary key,
  brand_id bigint not null references public.brand on delete restrict,
  barangay_id bigint not null references public.barangay on delete restrict,
  name text not null check (btrim(name) <> '' and length(name) <= 100),
  street_address text not null check (btrim(street_address) <> '' and length(street_address) <= 200),
  latitude public.latitude,
  longitude public.longitude,
  unique (id, brand_id),
  check ((latitude is null) = (longitude is null))
);
create unique index station_brand_barangay_street_key on public.station (brand_id, barangay_id, lower(street_address));

create table public.station_product (
  id bigint generated always as identity primary key,
  station_id bigint not null,
  product_id bigint not null,
  brand_id bigint not null,
  unique (station_id, product_id),
  foreign key (station_id, brand_id) references public.station (id, brand_id) on delete restrict,
  foreign key (product_id, brand_id) references public.fuel_product (id, brand_id) on delete restrict
);

create table public.profile (
  id uuid primary key references auth.users (id) on delete cascade,
  is_admin boolean not null default false,
  banned_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.price_report (
  id bigint generated always as identity primary key,
  station_product_id bigint not null references public.station_product on delete restrict,
  price public.price_php not null,
  observed_on date not null,
  submitted_by uuid references public.profile on delete set null,
  unique (station_product_id, observed_on)
);

create table public.price_shift (
  id bigint generated always as identity primary key,
  brand_id bigint not null references public.brand on delete restrict,
  category_id bigint not null references public.fuel_category on delete restrict,
  amount public.shift_php not null,
  effective_on date not null,
  source_ref text not null check (btrim(source_ref) <> '' and length(source_ref) <= 2048),
  fetched_at timestamptz not null,
  extractor text not null check (btrim(extractor) <> '' and length(extractor) <= 100),
  unique (brand_id, category_id, effective_on)
);

create table public.admin_log (
  id bigint generated always as identity primary key,
  admin_id uuid references public.profile on delete set null,
  action text not null check (action in ('approve', 'reject', 'ban', 'unban', 'create', 'update', 'delete')),
  target_table text not null,
  target_id text not null,
  created_at timestamptz not null default now()
);

alter table public.province enable row level security;
alter table public.city enable row level security;
alter table public.barangay enable row level security;
alter table public.brand enable row level security;
alter table public.fuel_category enable row level security;
alter table public.fuel_product enable row level security;
alter table public.station enable row level security;
alter table public.station_product enable row level security;
alter table public.price_report enable row level security;
alter table public.price_shift enable row level security;
alter table public.profile enable row level security;
alter table public.admin_log enable row level security;

revoke all on
  public.province, public.city, public.barangay, public.brand, public.fuel_category,
  public.fuel_product, public.station, public.station_product, public.price_report,
  public.price_shift, public.profile, public.admin_log
from anon, authenticated;

create schema private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select is_admin from public.profile where id = auth.uid()), false)
$$;

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profile (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

revoke execute on all functions in schema private from public;
grant execute on function private.is_admin() to authenticated;
