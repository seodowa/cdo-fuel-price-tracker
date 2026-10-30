begin;
create extension if not exists pgtap with schema extensions;
select plan(124);

select has_table('public', t, t) from unnest(array[
  'province', 'city', 'barangay', 'brand', 'fuel_category', 'fuel_product',
  'station', 'station_product', 'price_report', 'price_shift', 'profile', 'admin_log'
]) as t;

select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0,
  'FR-021: every public table has RLS enabled'
);

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000001', 'test-user@example.test'),
  ('00000000-0000-4000-8000-000000000002', 'test-admin@example.test');

select lives_ok($$ update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000002' $$,
  'fixture: admin flag set by postgres');

select lives_ok($$ insert into public.province (name) values ('Test Province A'), ('Test Province B') $$, 'fixture: provinces');
select throws_ok($$ insert into public.province (name) values ('test province a') $$, '23505', null, 'FR-002: province name unique ignoring case');

select lives_ok($$ insert into public.city (province_id, name)
  select id, 'Test City A' from public.province where name = 'Test Province A'
  union all select id, 'Test City B' from public.province where name = 'Test Province A'
  union all select id, 'Test City A' from public.province where name = 'Test Province B' $$,
  'FR-001: cities belong to a province; same city name allowed in another province');
select throws_ok($$ insert into public.city (province_id, name)
  select id, 'TEST CITY A' from public.province where name = 'Test Province A' $$,
  '23505', null, 'FR-002: city name unique per province ignoring case');

select lives_ok($$ insert into public.barangay (city_id, name)
  select c.id, 'Poblacion' from public.city c join public.province p on p.id = c.province_id
    where p.name = 'Test Province A' and c.name in ('Test City A', 'Test City B') $$,
  'FR-002: Poblacion allowed in two cities');
select throws_ok($$ insert into public.barangay (city_id, name)
  select c.id, 'Poblacion' from public.city c join public.province p on p.id = c.province_id
    where p.name = 'Test Province A' and c.name = 'Test City A' $$,
  '23505', null, 'FR-002: Poblacion refused twice in one city');
select throws_ok($$ insert into public.barangay (city_id, name)
  select c.id, 'poblacion' from public.city c join public.province p on p.id = c.province_id
    where p.name = 'Test Province A' and c.name = 'Test City A' $$,
  '23505', null, 'FR-002: poblacion refused in a city that has Poblacion');
select lives_ok($$ insert into public.barangay (city_id, name)
  select c.id, 'Test Barangay A' from public.city c join public.province p on p.id = c.province_id
    where p.name = 'Test Province A' and c.name = 'Test City A' $$, 'fixture: barangay');

select lives_ok($$ insert into public.brand (name) values ('Test Brand A'), ('Test Brand B') $$, 'fixture: brands');
select throws_ok($$ insert into public.brand (name) values ('TEST BRAND A') $$, '23505', null, 'FR-003: brand name unique ignoring case');
select lives_ok($$ insert into public.fuel_category (name) values ('test fuel') $$, 'fixture: category');
select throws_ok($$ insert into public.fuel_category (name) values ('Test Fuel') $$, '23505', null, 'FR-003: category name unique ignoring case');
select lives_ok($$ insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, 'Test Diesel' from public.brand b, public.fuel_category c
    where b.name in ('Test Brand A', 'Test Brand B') and c.name = 'test fuel' $$,
  'FR-003: same product name allowed under two brands');
select throws_ok($$ insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, 'TEST DIESEL' from public.brand b, public.fuel_category c
    where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23505', null, 'FR-003: product name unique per brand ignoring case');

select hasnt_column('public', 'station', 'city_id', 'FR-006: station has no city_id');
select hasnt_column('public', 'station', 'city', 'FR-006: station has no city');
select hasnt_column('public', 'station', 'province_id', 'FR-006: station has no province_id');
select hasnt_column('public', 'station', 'province', 'FR-006: station has no province');

select lives_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'Test Station A', '1 Test Street' from public.brand b, public.barangay g
    where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$, 'fixture: station without coordinates');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'Test Station Dup', '1 TEST STREET' from public.brand b, public.barangay g
    where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23505', null, 'FR-007: station unique by brand, barangay and street ignoring case');
select throws_ok($$ insert into public.station (barangay_id, name, street_address)
  select id, 'Test Station N', '2 Test Street' from public.barangay where name = 'Test Barangay A' $$,
  '23502', null, 'FR-006: station requires brand_id');
select throws_ok($$ insert into public.station (brand_id, name, street_address)
  select id, 'Test Station N', '2 Test Street' from public.brand where name = 'Test Brand A' $$,
  '23502', null, 'FR-006: station requires barangay_id');
select throws_ok($$ insert into public.station (brand_id, barangay_id, street_address)
  select b.id, g.id, '2 Test Street' from public.brand b, public.barangay g
    where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23502', null, 'FR-006: station requires name');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name)
  select b.id, g.id, 'Test Station N' from public.brand b, public.barangay g
    where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23502', null, 'FR-006: station requires street_address');

select domain_type_is('public', 'latitude', 'numeric(9,6)', 'FR-008: latitude is numeric(9,6)');
select domain_type_is('public', 'longitude', 'numeric(9,6)', 'FR-008: longitude is numeric(9,6)');
select lives_ok($$ select 4::public.latitude, 22::public.latitude $$, 'FR-008: latitude 4 and 22 accepted');
select throws_ok($$ select 3.999999::public.latitude $$, '23514', null, 'FR-008: latitude below 4 refused');
select throws_ok($$ select 22.000001::public.latitude $$, '23514', null, 'FR-008: latitude above 22 refused');
select lives_ok($$ select 116::public.longitude, 127::public.longitude $$, 'FR-008: longitude 116 and 127 accepted');
select throws_ok($$ select 115.999999::public.longitude $$, '23514', null, 'FR-008: longitude below 116 refused');
select throws_ok($$ select 127.000001::public.longitude $$, '23514', null, 'FR-008: longitude above 127 refused');
select lives_ok($$ insert into public.station (brand_id, barangay_id, name, street_address, latitude, longitude)
  select b.id, g.id, 'Test Station B', '3 Test Street', 8.4542, 124.6319 from public.brand b, public.barangay g
    where b.name = 'Test Brand B' and g.name = 'Test Barangay A' $$, 'FR-008: station with both coordinates');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address, latitude)
  select b.id, g.id, 'Test Station L', '4 Test Street', 8.4542 from public.brand b, public.barangay g
    where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23514', null, 'FR-008: latitude without longitude refused');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address, longitude)
  select b.id, g.id, 'Test Station L', '4 Test Street', 124.6319 from public.brand b, public.barangay g
    where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23514', null, 'FR-008: longitude without latitude refused');

select lives_ok($$ insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s join public.fuel_product p on p.brand_id = s.brand_id
    where s.name = 'Test Station A' $$, 'fixture: station product of same brand');
select throws_ok($$ insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s, public.fuel_product p join public.brand b on b.id = p.brand_id
    where s.name = 'Test Station A' and b.name = 'Test Brand B' $$,
  '23503', null, 'FR-009: product of another brand refused (product side)');
select throws_ok($$ insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, p.brand_id from public.station s, public.fuel_product p join public.brand b on b.id = p.brand_id
    where s.name = 'Test Station A' and b.name = 'Test Brand B' $$,
  '23503', null, 'FR-009: product of another brand refused (station side)');

select domain_type_is('public', 'price_php', 'numeric(6,2)', 'FR-011: price_php is numeric(6,2)');
select lives_ok($$ insert into public.price_report (station_product_id, price, observed_on)
  select id, 50.00, date '2026-01-01' from public.station_product $$, 'fixture: price report');
select throws_ok($$ insert into public.price_report (station_product_id, price, observed_on)
  select id, 51.00, date '2026-01-01' from public.station_product $$,
  '23505', null, 'FR-010: one price report per station product and date');
select throws_ok($$ insert into public.price_report (station_product_id, price, observed_on)
  select id, 6.50, date '2026-01-02' from public.station_product $$, '23514', null, 'FR-011: price 6.50 refused');
select throws_ok($$ insert into public.price_report (station_product_id, price, observed_on)
  select id, 650.00, date '2026-01-02' from public.station_product $$, '23514', null, 'FR-011: price 650.00 refused');
select lives_ok($$ insert into public.price_report (station_product_id, price, observed_on)
  select id, 20.00, date '2026-01-03' from public.station_product $$, 'FR-011: price 20.00 accepted');
select lives_ok($$ insert into public.price_report (station_product_id, price, observed_on)
  select id, 200.00, date '2026-01-04' from public.station_product $$, 'FR-011: price 200.00 accepted');

select domain_type_is('public', 'shift_php', 'numeric(5,2)', 'FR-013: shift_php is numeric(5,2)');
select lives_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 1.20, date '2026-01-05', 'https://example.test/shift', now(), 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  'fixture: price shift');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-05', 'https://example.test/shift', now(), 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23505', null, 'FR-012: one shift per brand, category and date');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 120.00, date '2026-01-06', 'https://example.test/shift', now(), 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'FR-013: shift 120.00 refused');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-07', now(), 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23502', null, 'FR-013: shift requires source_ref');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, extractor)
  select b.id, c.id, 0.50, date '2026-01-07', 'https://example.test/shift', 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23502', null, 'FR-013: shift requires fetched_at');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at)
  select b.id, c.id, 0.50, date '2026-01-07', 'https://example.test/shift', now()
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23502', null, 'FR-013: shift requires extractor');

select lives_ok($$ insert into public.brand (name) values (repeat('b', 100)) $$, 'R11: name of 100 chars accepted');
select throws_ok($$ insert into public.province (name) values ('  ') $$, '23514', null, 'R11: blank province name refused');
select throws_ok($$ insert into public.province (name) values (repeat('p', 101)) $$, '23514', null, 'R11: province name over 100 refused');
select throws_ok($$ insert into public.city (province_id, name) select id, '  ' from public.province where name = 'Test Province A' $$,
  '23514', null, 'R11: blank city name refused');
select throws_ok($$ insert into public.city (province_id, name) select id, repeat('c', 101) from public.province where name = 'Test Province A' $$,
  '23514', null, 'R11: city name over 100 refused');
select throws_ok($$ insert into public.barangay (city_id, name) select id, '  ' from public.city where name = 'Test City B' $$,
  '23514', null, 'R11: blank barangay name refused');
select throws_ok($$ insert into public.barangay (city_id, name) select id, repeat('g', 101) from public.city where name = 'Test City B' $$,
  '23514', null, 'R11: barangay name over 100 refused');
select throws_ok($$ insert into public.brand (name) values ('') $$, '23514', null, 'R11: empty brand name refused');
select throws_ok($$ insert into public.brand (name) values (repeat('b', 101)) $$, '23514', null, 'R11: brand name over 100 refused');
select throws_ok($$ insert into public.fuel_category (name) values ('  ') $$, '23514', null, 'R11: blank category name refused');
select throws_ok($$ insert into public.fuel_category (name) values (repeat('f', 101)) $$, '23514', null, 'R11: category name over 100 refused');
select throws_ok($$ insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, '  ' from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'R11: blank product name refused');
select throws_ok($$ insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, repeat('d', 101) from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'R11: product name over 100 refused');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, '  ', '5 Test Street' from public.brand b, public.barangay g where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23514', null, 'R11: blank station name refused');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, repeat('s', 101), '5 Test Street' from public.brand b, public.barangay g where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23514', null, 'R11: station name over 100 refused');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'Test Station T', '  ' from public.brand b, public.barangay g where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23514', null, 'R11: blank street_address refused');
select throws_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'Test Station T', repeat('a', 201) from public.brand b, public.barangay g where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  '23514', null, 'R11: street_address over 200 refused');
select lives_ok($$ insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'Test Station T', repeat('a', 200) from public.brand b, public.barangay g where b.name = 'Test Brand A' and g.name = 'Test Barangay A' $$,
  'R11: street_address of 200 chars accepted');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-08', '  ', now(), 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'R11: blank source_ref refused');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-08', repeat('u', 2049), now(), 'test-extractor'
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'R11: source_ref over 2048 refused');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-08', 'https://example.test/shift', now(), '  '
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'R11: blank extractor refused');
select throws_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-08', 'https://example.test/shift', now(), repeat('e', 101)
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  '23514', null, 'R11: extractor over 100 refused');
select lives_ok($$ insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select b.id, c.id, 0.50, date '2026-01-08', repeat('u', 2048), now(), repeat('e', 100)
    from public.brand b, public.fuel_category c where b.name = 'Test Brand A' and c.name = 'test fuel' $$,
  'R11: source_ref of 2048 and extractor of 100 chars accepted');

select throws_ok($$ delete from public.province where name = 'Test Province A' $$, '23503', null, 'FR-004: referenced province not deleted');
select throws_ok($$ delete from public.city where name = 'Test City A' $$, '23503', null, 'FR-004: referenced city not deleted');
select throws_ok($$ delete from public.barangay where name = 'Test Barangay A' $$, '23503', null, 'FR-004: referenced barangay not deleted');
select throws_ok($$ delete from public.brand where name = 'Test Brand A' $$, '23503', null, 'FR-004: referenced brand not deleted');
select throws_ok($$ delete from public.fuel_category where name = 'test fuel' $$, '23503', null, 'FR-004: referenced category not deleted');
select throws_ok($$ delete from public.fuel_product p using public.brand b where b.id = p.brand_id and b.name = 'Test Brand A' $$,
  '23503', null, 'FR-004: referenced product not deleted');

set local role anon;
select throws_ok($$ insert into public.price_shift (amount) values (1) $$, '42501', null, 'FR-025: anon cannot insert price_shift');
select throws_ok($$ insert into public.price_report (price) values (50) $$, '42501', null, 'FR-021: anon cannot insert price_report');
select throws_ok($$ insert into public.station (name) values ('x') $$, '42501', null, 'FR-021: anon cannot insert station');
select throws_ok($$ insert into public.station_product (brand_id) values (1) $$, '42501', null, 'FR-021: anon cannot insert station_product');
select throws_ok($$ insert into public.profile (id) values ('00000000-0000-4000-8000-000000000009') $$, '42501', null, 'FR-021: anon cannot insert profile');
select throws_ok($$ insert into public.admin_log (action) values ('ban') $$, '42501', null, 'FR-021: anon cannot insert admin_log');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select throws_ok($$ insert into public.price_shift (amount) values (1) $$, '42501', null, 'FR-025: user cannot insert price_shift');
select throws_ok($$ insert into public.price_report (price) values (50) $$, '42501', null, 'FR-021: user cannot insert price_report');
select throws_ok($$ insert into public.station (name) values ('x') $$, '42501', null, 'FR-021: user cannot insert station');
select throws_ok($$ insert into public.station_product (brand_id) values (1) $$, '42501', null, 'FR-021: user cannot insert station_product');
select throws_ok($$ insert into public.profile (id) values ('00000000-0000-4000-8000-000000000009') $$, '42501', null, 'FR-021: user cannot insert profile');
select throws_ok($$ insert into public.admin_log (action) values ('ban') $$, '42501', null, 'FR-021: user cannot insert admin_log');
select throws_ok($$ update public.price_report set price = 60 $$, '42501', null, 'SC-003: user cannot update price_report');
select throws_ok($$ delete from public.price_report $$, '42501', null, 'SC-003: user cannot delete price_report');
select throws_ok($$ update public.station set name = 'x' $$, '42501', null, 'SC-003: user cannot update station');
select throws_ok($$ delete from public.station $$, '42501', null, 'SC-003: user cannot delete station');
select throws_ok($$ update public.station_product set brand_id = 1 $$, '42501', null, 'SC-003: user cannot update station_product');
select throws_ok($$ delete from public.station_product $$, '42501', null, 'SC-003: user cannot delete station_product');
select throws_ok($$ update public.price_shift set amount = 1 $$, '42501', null, 'SC-003: user cannot update price_shift');
select throws_ok($$ delete from public.price_shift $$, '42501', null, 'SC-003: user cannot delete price_shift');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select throws_ok($$ update public.price_report set price = 60 $$, '42501', null, 'SC-003: admin cannot update price_report');
select throws_ok($$ delete from public.price_report $$, '42501', null, 'SC-003: admin cannot delete price_report');
select throws_ok($$ update public.station set name = 'x' $$, '42501', null, 'SC-003: admin cannot update station');
select throws_ok($$ delete from public.station $$, '42501', null, 'SC-003: admin cannot delete station');
select throws_ok($$ update public.station_product set brand_id = 1 $$, '42501', null, 'SC-003: admin cannot update station_product');
select throws_ok($$ delete from public.station_product $$, '42501', null, 'SC-003: admin cannot delete station_product');
select throws_ok($$ update public.price_shift set amount = 1 $$, '42501', null, 'SC-003: admin cannot update price_shift');
select throws_ok($$ delete from public.price_shift $$, '42501', null, 'SC-003: admin cannot delete price_shift');
reset role;

select results_eq(
  $$ select is_admin, banned_at is null from public.profile where id = '00000000-0000-4000-8000-000000000001' $$,
  $$ values (false, true) $$,
  'R3: new auth user gets a profile with is_admin false and no ban'
);

select * from finish();
rollback;
