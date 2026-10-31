begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

create function pg_temp.d(n int) returns date language sql as $$
  select (now() at time zone 'Asia/Manila')::date + n
$$;

insert into public.province (name) values ('Test Province S');
insert into public.city (province_id, name)
  select id, 'Test City S' from public.province where name = 'Test Province S';
insert into public.barangay (city_id, name)
  select id, 'Test Barangay S' from public.city where name = 'Test City S';
insert into public.brand (name) values ('Test Brand S1'), ('Test Brand S2');
insert into public.fuel_category (name) values ('gasoline'), ('diesel') on conflict (lower(name)) do nothing;
insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, b.name || ' ' || initcap(c.name) from public.brand b, public.fuel_category c
  where b.name in ('Test Brand S1', 'Test Brand S2') and c.name in ('gasoline', 'diesel');
insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, v.name, v.name || ' Street'
  from (values ('Test Brand S1', 'S1a Station'), ('Test Brand S1', 'S1b Station'), ('Test Brand S2', 'S2 Station')) v(brand, name)
  join public.brand b on b.name = v.brand
  cross join public.barangay g where g.name = 'Test Barangay S';
insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s join public.fuel_product p on p.brand_id = s.brand_id
  where s.name in ('S1a Station', 'S1b Station', 'S2 Station');
insert into public.price_report (station_product_id, price, observed_on)
  select sp.id, 60.00, pg_temp.d(-7) from public.station_product sp
  join public.station s on s.id = sp.station_id where s.name in ('S1a Station', 'S1b Station', 'S2 Station');

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000071', 'test-shift-user@example.test'),
  ('00000000-0000-4000-8000-000000000079', 'test-shift-admin@example.test');
update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000079';

create function pg_temp.prices() returns text language sql as $$
  select string_agg(s.name || ' ' || p.name || ' ' || cp.price, '; ' order by s.name, p.name)
  from public.current_price cp
  join public.station s on s.id = cp.station_id
  join public.fuel_product p on p.id = cp.product_id
  where s.name in ('S1a Station', 'S1b Station', 'S2 Station')
$$;

create function pg_temp.q_shift(amount text, src text, fetched text, extr text, day int default -1) returns text language sql as $$
  select format('insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
    select b.id, c.id, %s, %L, %s, %s, %s from public.brand b, public.fuel_category c
    where b.name = %L and c.name = %L',
    amount, pg_temp.d(day), src, fetched, extr, 'Test Brand S1', 'gasoline')
$$;

create function pg_temp.login(u text) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000000000' || u, 'role', 'authenticated')::text, true);
end;
$$;

set local role service_role;

select lives_ok(pg_temp.q_shift('1.20', quote_literal('https://example.test/advisory'), 'now()', quote_literal('test-extractor')),
  'service role records a +1.20 shift with its source');

select is((select count(*)::int from public.price_shift ps join public.brand b on b.id = ps.brand_id
  where b.name = 'Test Brand S1' and ps.amount = 1.20 and ps.source_ref = 'https://example.test/advisory'
    and ps.fetched_at is not null and ps.extractor = 'test-extractor'), 1,
  'the shift is stored with source_ref, fetched_at and extractor');

select is(pg_temp.prices(),
  'S1a Station Test Brand S1 Diesel 60.00; S1a Station Test Brand S1 Gasoline 61.20; '
  || 'S1b Station Test Brand S1 Diesel 60.00; S1b Station Test Brand S1 Gasoline 61.20; '
  || 'S2 Station Test Brand S2 Diesel 60.00; S2 Station Test Brand S2 Gasoline 60.00',
  'the shift moves every gasoline product of that brand and nothing else');

select throws_ok(pg_temp.q_shift('120.00', quote_literal('https://example.test/bad'), 'now()', quote_literal('test-extractor'), -2),
  '23514', null, 'a +120.00 shift is refused');

select is(pg_temp.prices(),
  'S1a Station Test Brand S1 Diesel 60.00; S1a Station Test Brand S1 Gasoline 61.20; '
  || 'S1b Station Test Brand S1 Diesel 60.00; S1b Station Test Brand S1 Gasoline 61.20; '
  || 'S2 Station Test Brand S2 Diesel 60.00; S2 Station Test Brand S2 Gasoline 60.00',
  'the refused shift changes no price');

select throws_ok(pg_temp.q_shift('0.50', 'null', 'now()', quote_literal('test-extractor'), -3),
  '23502', null, 'a shift without source_ref is refused');
select throws_ok(pg_temp.q_shift('0.50', quote_literal('https://example.test/a'), 'null', quote_literal('test-extractor'), -3),
  '23502', null, 'a shift without fetched_at is refused');
select throws_ok(pg_temp.q_shift('0.50', quote_literal('https://example.test/a'), 'now()', 'null', -3),
  '23502', null, 'a shift without extractor is refused');

select throws_ok(pg_temp.q_shift('0.30', quote_literal('https://example.test/dup'), 'now()', quote_literal('test-extractor')),
  '23505', null, 'a second shift for the same brand, category and date is refused');

reset role;

select pg_temp.login('71');
select throws_ok(pg_temp.q_shift('0.40', quote_literal('https://example.test/u'), 'now()', quote_literal('test-extractor'), -4),
  '42501', null, 'a signed-in user cannot record a shift');
reset role;

select pg_temp.login('79');
select throws_ok(pg_temp.q_shift('0.40', quote_literal('https://example.test/u'), 'now()', quote_literal('test-extractor'), -4),
  '42501', null, 'an admin cannot record a shift through the public interface');
reset role;

select is((select count(*)::int from public.price_shift ps join public.brand b on b.id = ps.brand_id
  where b.name = 'Test Brand S1'), 1, 'only the valid shift was stored');

select * from finish();
rollback;
