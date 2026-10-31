begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into public.province (name) values ('Test Province R');
insert into public.city (province_id, name)
  select id, 'Test City R' from public.province where name = 'Test Province R';
insert into public.barangay (city_id, name)
  select id, 'Test Barangay R' from public.city where name = 'Test City R';
insert into public.brand (name) values ('Test Brand R');
insert into public.fuel_category (name) values ('gasoline') on conflict (lower(name)) do nothing;
insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, 'R Gas' from public.brand b, public.fuel_category c
  where b.name = 'Test Brand R' and c.name = 'gasoline';
insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'R Station', 'R Street' from public.brand b, public.barangay g
  where b.name = 'Test Brand R' and g.name = 'Test Barangay R';
insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s join public.fuel_product p on p.brand_id = s.brand_id
  where s.name = 'R Station';

insert into auth.users (id, email) values ('00000000-0000-4000-8000-000000000041', 'test-reader@example.test');
insert into public.price_report (station_product_id, price, observed_on, submitted_by)
  select id, 60.00, (now() at time zone 'Asia/Manila')::date - 7, '00000000-0000-4000-8000-000000000041'
  from public.station_product where station_id = (select id from public.station where name = 'R Station');
insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 1.00, (now() at time zone 'Asia/Manila')::date - 2, 'https://example.test/shift', now(), 'test'
  from public.brand b, public.fuel_category c where b.name = 'Test Brand R' and c.name = 'gasoline';

select set_config('test.brand', (select id::text from public.brand where name = 'Test Brand R'), true);
select set_config('test.station', (select id::text from public.station where name = 'R Station'), true);

create function pg_temp.sees(q text) returns boolean language plpgsql as $$
declare
  r boolean;
begin
  execute 'select exists (' || q || ')' into r;
  return r;
exception when insufficient_privilege or undefined_table then
  return false;
end;
$$;

create function pg_temp.public_reads(who text) returns setof text language plpgsql as $$
begin
  return next ok(pg_temp.sees($q$ select id, name from public.province where name = 'Test Province R' $q$), who || ' reads province');
  return next ok(pg_temp.sees($q$ select id, province_id, name from public.city where name = 'Test City R' $q$), who || ' reads city');
  return next ok(pg_temp.sees($q$ select id, city_id, name from public.barangay where name = 'Test Barangay R' $q$), who || ' reads barangay');
  return next ok(pg_temp.sees($q$ select id, name from public.brand where id = current_setting('test.brand')::bigint $q$), who || ' reads brand');
  return next ok(pg_temp.sees($q$ select id, name from public.fuel_category where name = 'gasoline' $q$), who || ' reads fuel_category');
  return next ok(pg_temp.sees($q$ select id, brand_id, category_id, name from public.fuel_product where brand_id = current_setting('test.brand')::bigint $q$), who || ' reads fuel_product');
  return next ok(pg_temp.sees($q$ select * from public.station where id = current_setting('test.station')::bigint $q$), who || ' reads station');
  return next ok(pg_temp.sees($q$ select * from public.station_product where station_id = current_setting('test.station')::bigint $q$), who || ' reads station_product');
  return next ok(pg_temp.sees($q$ select * from public.price_shift where brand_id = current_setting('test.brand')::bigint $q$), who || ' reads price_shift');
  return next ok(pg_temp.sees($q$ select * from public.current_price where station_id = current_setting('test.station')::bigint $q$), who || ' reads current_price');
  return next ok(pg_temp.sees($q$ select id, station_product_id, price, observed_on from public.price_report where price = 60.00 $q$), who || ' reads price_report public columns');
  return next throws_ok($q$ select submitted_by from public.price_report $q$, '42501', null, who || ' cannot read price_report.submitted_by');
end;
$$;

set local role anon;
select * from pg_temp.public_reads('FR-022: anon');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000041","role":"authenticated"}', true);
select * from pg_temp.public_reads('FR-022: authenticated');
reset role;

select columns_are('public', 'current_price',
  array['station_product_id', 'station_id', 'product_id', 'price', 'reported_at', 'shifted_at', 'is_estimate'],
  'FR-022: current_price exposes exactly the public columns');

select * from finish();
rollback;
