begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

create function pg_temp.d(n int) returns date language sql as $$
  select (now() at time zone 'Asia/Manila')::date + n
$$;

insert into public.province (name) values ('Test Province X');
insert into public.city (province_id, name)
  select id, 'Test City X' from public.province where name = 'Test Province X';
insert into public.barangay (city_id, name)
  select id, 'Test Barangay X' from public.city where name = 'Test City X';
insert into public.fuel_category (name) values ('gasoline'), ('diesel')
  on conflict (lower(name)) do nothing;

create function pg_temp.sp(b text, cat text, p text) returns bigint language plpgsql as $$
declare
  bid bigint;
  pid bigint;
  sid bigint;
  spid bigint;
begin
  insert into public.brand (name) values (b) on conflict (lower(name)) do nothing;
  select id into bid from public.brand where name = b;
  insert into public.fuel_product (brand_id, category_id, name)
    select bid, id, p from public.fuel_category where name = cat
    returning id into pid;
  insert into public.station (brand_id, barangay_id, name, street_address)
    select bid, id, p || ' Station', p || ' Street' from public.barangay where name = 'Test Barangay X'
    returning id into sid;
  insert into public.station_product (station_id, product_id, brand_id)
    values (sid, pid, bid) returning id into spid;
  return spid;
end;
$$;

create function pg_temp.spid(p text) returns bigint language sql as $$
  select sp.id from public.station_product sp join public.fuel_product fp on fp.id = sp.product_id
  where fp.name = p
$$;

create function pg_temp.report(p text, price numeric, n int) returns void language sql as $$
  insert into public.price_report (station_product_id, price, observed_on)
  values (pg_temp.spid(p), price, pg_temp.d(n))
$$;

create function pg_temp.shift(b text, cat text, amount numeric, n int) returns void language sql as $$
  insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
  select br.id, fc.id, amount, pg_temp.d(n), 'https://example.test/shift', now(), 'test'
  from public.brand br, public.fuel_category fc where br.name = b and fc.name = cat
$$;

create function pg_temp.cp(p text) returns table (price numeric, reported_at date, shifted_at date, is_estimate boolean)
language sql as $$
  select price::numeric, reported_at, shifted_at, is_estimate
  from public.current_price where station_product_id = pg_temp.spid(p)
$$;

select pg_temp.sp('Test Brand S1', 'gasoline', 'S1 Gas');
select pg_temp.report('S1 Gas', 60.00, -14);
select pg_temp.shift('Test Brand S1', 'gasoline', 1.20, -8);
select pg_temp.shift('Test Brand S1', 'gasoline', -0.50, -1);

select pg_temp.sp('Test Brand S2', 'gasoline', 'S2 Gas');
select pg_temp.report('S2 Gas', 60.00, -14);
select pg_temp.shift('Test Brand S2', 'gasoline', 1.20, -8);
select pg_temp.report('S2 Gas', 61.00, -5);
select pg_temp.shift('Test Brand S2', 'gasoline', 0.30, -2);

select pg_temp.sp('Test Brand S3', 'gasoline', 'S3 Gas');
select pg_temp.report('S3 Gas', 58.00, -3);

select pg_temp.sp('Test Brand S4', 'gasoline', 'S4 Gas One');
select pg_temp.sp('Test Brand S4', 'gasoline', 'S4 Gas Two');
select pg_temp.report('S4 Gas One', 60.00, -10);
select pg_temp.report('S4 Gas Two', 65.00, -10);
select pg_temp.shift('Test Brand S4', 'gasoline', 1.00, -4);

select pg_temp.sp('Test Brand S5A', 'gasoline', 'S5A Gas');
select pg_temp.sp('Test Brand S5B', 'gasoline', 'S5B Gas');
select pg_temp.report('S5A Gas', 60.00, -10);
select pg_temp.report('S5B Gas', 60.00, -10);
select pg_temp.shift('Test Brand S5A', 'gasoline', 2.00, -4);

select pg_temp.sp('Test Brand E1', 'diesel', 'E1 Diesel');

select pg_temp.sp('Test Brand E2', 'diesel', 'E2 Diesel');
select pg_temp.report('E2 Diesel', 60.00, -6);
select pg_temp.shift('Test Brand E2', 'diesel', 1.00, -6);

select pg_temp.sp('Test Brand E3', 'diesel', 'E3 Diesel');
select pg_temp.report('E3 Diesel', 60.00, -6);
select pg_temp.shift('Test Brand E3', 'diesel', 1.00, 1);

select pg_temp.sp('Test Brand E4', 'diesel', 'E4 Diesel');
select pg_temp.report('E4 Diesel', 195.00, -6);
select pg_temp.shift('Test Brand E4', 'diesel', 10.00, -2);

select results_eq(
  $$ select * from pg_temp.cp('S1 Gas') $$,
  $$ values (60.70::numeric, pg_temp.d(-14), pg_temp.d(-1), true) $$,
  'FR-014/FR-015 scenario 1: report plus two later shifts'
);

select results_eq(
  $$ select * from pg_temp.cp('S2 Gas') $$,
  $$ values (61.30::numeric, pg_temp.d(-5), pg_temp.d(-2), true) $$,
  'FR-014 scenario 2: later report becomes the anchor and older shifts are ignored'
);

select results_eq(
  $$ select * from pg_temp.cp('S3 Gas') $$,
  $$ values (58.00::numeric, pg_temp.d(-3), null::date, false) $$,
  'FR-015 scenario 3: no shift gives the report price, no shifted_at, not an estimate'
);

select results_eq(
  $$ select price::numeric from public.current_price
     where station_product_id in (pg_temp.spid('S4 Gas One'), pg_temp.spid('S4 Gas Two'))
     order by price $$,
  $$ values (61.00::numeric), (66.00::numeric) $$,
  'FR-014 scenario 4: one shift moves both gasoline products of a brand'
);

select results_eq(
  $$ select * from pg_temp.cp('S5A Gas') union all select * from pg_temp.cp('S5B Gas') $$,
  $$ values (62.00::numeric, pg_temp.d(-10), pg_temp.d(-4), true),
            (60.00::numeric, pg_temp.d(-10), null::date, false) $$,
  'FR-014 scenario 5: brand A shift leaves brand B unchanged'
);

select is_empty(
  $$ select * from pg_temp.cp('E1 Diesel') $$,
  'FR-014 edge: station product without a report has no row'
);

select results_eq(
  $$ select * from pg_temp.cp('E2 Diesel') $$,
  $$ values (60.00::numeric, pg_temp.d(-6), null::date, false) $$,
  'FR-014 edge: shift on the anchor date is not applied'
);

select results_eq(
  $$ select * from pg_temp.cp('E3 Diesel') $$,
  $$ values (60.00::numeric, pg_temp.d(-6), null::date, false) $$,
  'FR-014 edge: shift dated tomorrow is not applied'
);

select results_eq(
  $$ select * from pg_temp.cp('E4 Diesel') $$,
  $$ values (205.00::numeric, pg_temp.d(-6), pg_temp.d(-2), true) $$,
  'FR-014 edge: computed price above 200 is returned unchecked'
);

select isnt_empty(
  $$ select 1 from public.current_price $$,
  'SC-002: current_price has rows to trace'
);

select is_empty(
  $$ select cp.station_product_id from public.current_price cp
     where (select count(*) from public.price_report pr
            where pr.station_product_id = cp.station_product_id
              and pr.observed_on = cp.reported_at) <> 1 $$,
  'SC-002: every current_price row traces to exactly one price_report'
);

select * from finish();
rollback;
