begin;
create extension if not exists pgtap with schema extensions;
select plan(44);

create function pg_temp.d(n int) returns date language sql as $$
  select (now() at time zone 'Asia/Manila')::date + n
$$;

create function pg_temp.s(k text) returns text language sql as $$
  select current_setting('test.' || k)
$$;

insert into public.province (name) values ('Test Province A');
insert into public.city (province_id, name)
  select id, 'Test City A' from public.province where name = 'Test Province A';
insert into public.barangay (city_id, name)
  select id, 'Test Barangay A' from public.city where name = 'Test City A';
insert into public.brand (name) values ('Test Brand A1');
insert into public.fuel_category (name) values ('gasoline'), ('diesel') on conflict (lower(name)) do nothing;
insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, b.name || ' ' || initcap(c.name) from public.brand b, public.fuel_category c
  where b.name = 'Test Brand A1' and c.name in ('gasoline', 'diesel');
insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'A1 Station', 'A1 Street' from public.brand b, public.barangay g
  where b.name = 'Test Brand A1' and g.name = 'Test Barangay A';
insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s join public.fuel_product p on p.brand_id = s.brand_id
  where s.name = 'A1 Station' and p.name = 'Test Brand A1 Gasoline';
insert into public.price_report (station_product_id, price, observed_on)
  select id, 60.00, pg_temp.d(-7) from public.station_product
  where station_id = (select id from public.station where name = 'A1 Station');

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000061', 'test-appr-a@example.test'),
  ('00000000-0000-4000-8000-000000000062', 'test-appr-b@example.test'),
  ('00000000-0000-4000-8000-000000000069', 'test-appr-admin@example.test');
update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000069';

select set_config('test.admin', '00000000-0000-4000-8000-000000000069', true);
select set_config('test.brand1', (select id::text from public.brand where name = 'Test Brand A1'), true);
select set_config('test.brgy', (select id::text from public.barangay where name = 'Test Barangay A'), true);
select set_config('test.station', (select id::text from public.station where name = 'A1 Station'), true);
select set_config('test.gas', (select id::text from public.fuel_product where name = 'Test Brand A1 Gasoline'), true);
select set_config('test.diesel', (select id::text from public.fuel_product where name = 'Test Brand A1 Diesel'), true);
select set_config('test.gas_sp', (select id::text from public.station_product
  where product_id = pg_temp.s('gas')::bigint), true);
select set_config('test.report', (select id::text from public.price_report
  where station_product_id = pg_temp.s('gas_sp')::bigint), true);

create function pg_temp.login(u text) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000000000' || u, 'role', 'authenticated')::text, true);
end;
$$;

create function pg_temp.q_station(street text) returns text language sql as $$
  select format('insert into public.submission (kind, name, brand_id, barangay_id, street_address) values (%L, %L, %s, %s, %L)',
    'station', 'Sub Station', pg_temp.s('brand1'), pg_temp.s('brgy'), street)
$$;

create function pg_temp.q_price(p numeric, day int, product text default null) returns text language sql as $$
  select format('insert into public.submission (kind, station_id, product_id, price, observed_on) values (%L, %s, %s, %s, %L)',
    'price', pg_temp.s('station'), coalesce(product, pg_temp.s('gas')), p, pg_temp.d(day))
$$;

create function pg_temp.q_corr(p numeric, day int) returns text language sql as $$
  select format('insert into public.submission (kind, price_report_id, price, observed_on) values (%L, %s, %s, %L)',
    'correction', pg_temp.s('report'), p, pg_temp.d(day))
$$;

create function pg_temp.rows(q text) returns text language plpgsql as $$
declare
  r text;
begin
  execute 'select coalesce(string_agg(t::text, '';''), '''') from (' || q || ') t' into r;
  return r;
exception when others then
  return 'error ' || sqlstate || ' ' || sqlerrm;
end;
$$;

create function pg_temp.admin_stations(n int) returns void language plpgsql as $$
begin
  for i in 1..n loop
    execute pg_temp.q_station('Admin Street ' || i);
  end loop;
end;
$$;

create function pg_temp.live() returns text language sql as $$
  select md5(concat_ws('|',
    (select string_agg(s::text, ',' order by s.id) from public.station s),
    (select string_agg(sp::text, ',' order by sp.id) from public.station_product sp),
    (select string_agg(pr::text, ',' order by pr.id) from public.price_report pr),
    (select string_agg(c::text, ',' order by c.station_product_id) from public.current_price c)))
$$;

select pg_temp.login('61');
select lives_ok(pg_temp.q_station('S1 Street'), 'FR-018: user submits a station');
select lives_ok(pg_temp.q_price(65.55, -1, pg_temp.s('diesel')), 'FR-018: user submits a price for a product the station lacks');
select lives_ok(pg_temp.q_price(61.50, -2), 'FR-018: user submits a price for an existing station product');
select lives_ok(pg_temp.q_corr(59.90, -6), 'FR-018: user submits a correction');
select throws_ok($q$ update public.submission set status = 'approved' where street_address = 'S1 Street' $q$,
  'P0001', 'not_allowed', 'FR-024: non-admin cannot approve');
select throws_ok($q$ update public.submission set status = 'rejected' where street_address = 'S1 Street' $q$,
  'P0001', 'not_allowed', 'FR-024: non-admin cannot reject');

select pg_temp.login('62');
select lives_ok(pg_temp.q_station('B Street'), 'FR-024: second user submits a station');

select pg_temp.login('69');
select is(pg_temp.rows($q$ select count(distinct submitted_by) from public.submission
  where submitted_by in ('00000000-0000-4000-8000-000000000061', '00000000-0000-4000-8000-000000000062') $q$),
  '(2)', 'FR-024: admin reads every user''s submissions');
select lives_ok($q$ update public.submission set status = 'approved' where street_address = 'S1 Street' $q$,
  'FR-018: admin approves the station submission');
select lives_ok($q$ update public.submission set status = 'approved' where product_id = $q$ || pg_temp.s('diesel'),
  'FR-018: admin approves the price for a missing station product');
select lives_ok($q$ update public.submission set status = 'approved' where price = 61.50 $q$,
  'FR-018: admin approves the price for an existing station product');
reset role;
select set_config('test.reports', (select count(*)::text from public.price_report), true);
select pg_temp.login('69');
select lives_ok($q$ update public.submission set status = 'approved' where kind = 'correction' $q$,
  'FR-018: admin approves the correction');
reset role;

select is(pg_temp.rows(format($q$ select name, street_address from public.station
  where brand_id = %s and barangay_id = %s and street_address = 'S1 Street' $q$, pg_temp.s('brand1'), pg_temp.s('brgy'))),
  '("Sub Station","S1 Street")', 'FR-018: approved station exists');
select is(pg_temp.rows(format($q$ select count(*) from public.station_product where station_id = %s and product_id = %s $q$,
  pg_temp.s('station'), pg_temp.s('diesel'))), '(1)', 'FR-018: approval creates the missing station product (D20)');
select is(pg_temp.rows(format($q$ select count(*) from public.station_product where station_id = %s $q$, pg_temp.s('station'))),
  '(2)', 'FR-018: approval adds no station product when one exists');
select is(pg_temp.rows(format($q$ select pr.price, pr.observed_on, pr.submitted_by from public.price_report pr
  join public.station_product sp on sp.id = pr.station_product_id where sp.product_id = %s $q$, pg_temp.s('diesel'))),
  format('(65.55,%s,00000000-0000-4000-8000-000000000061)', pg_temp.d(-1)),
  'FR-018: approved price report exists with submitted_by copied');
select is(pg_temp.rows(format($q$ select price, reported_at from public.current_price where product_id = %s $q$, pg_temp.s('diesel'))),
  format('(65.55,%s)', pg_temp.d(-1)), 'Scenario 2: current_price reflects the approved baseline');
select is(pg_temp.rows(format($q$ select price, reported_at from public.current_price where station_product_id = %s $q$, pg_temp.s('gas_sp'))),
  format('(61.50,%s)', pg_temp.d(-2)), 'Scenario 2: current_price reflects the approved override');
select is(pg_temp.rows(format($q$ select price, observed_on, (select count(*) from public.price_report)
  from public.price_report where id = %s $q$, pg_temp.s('report'))),
  format('(59.90,%s,%s)', pg_temp.d(-6), pg_temp.s('reports')),
  'Scenario 3: correction updates the target price report in place and adds no price report');
select is(pg_temp.rows($q$ select status, decided_by = current_setting('test.admin')::uuid, decided_at is not null
  from public.submission where submitted_by = '00000000-0000-4000-8000-000000000061' order by kind, id $q$),
  '(approved,t,t);(approved,t,t);(approved,t,t);(approved,t,t)', 'FR-024: approval sets decided_by and decided_at');
select is(pg_temp.rows($q$ select l.admin_id = current_setting('test.admin')::uuid, l.action, l.target_table, l.created_at is not null
  from public.admin_log l join public.submission s on l.target_id = s.id::text
  where l.target_table = 'submission' and s.street_address = 'S1 Street' $q$),
  '(t,approve,submission,t)', 'FR-027: approval writes one admin_log row');

select set_config('test.live', pg_temp.live(), true);
select pg_temp.login('61');
select lives_ok(pg_temp.q_price(66.66, -3), 'Scenario 4: user submits a price to reject');
select pg_temp.login('69');
select lives_ok($q$ update public.submission set status = 'rejected' where price = 66.66 $q$,
  'Scenario 4: admin rejects the price');
select lives_ok($q$ update public.submission set status = 'rejected' where street_address = 'B Street' $q$,
  'Scenario 4: admin rejects the station');
reset role;
select is(pg_temp.live() || pg_temp.rows($q$ select count(*) from public.submission where status = 'rejected' $q$),
  pg_temp.s('live') || '(2)', 'Scenario 4: rejection leaves live rows and current_price unchanged');
select is(pg_temp.rows($q$ select status, decided_by = current_setting('test.admin')::uuid, decided_at is not null,
  (select count(*) from public.admin_log l where l.target_table = 'submission' and l.target_id = s.id::text
    and l.action = 'reject' and l.admin_id = current_setting('test.admin')::uuid and l.created_at is not null)
  from public.submission s where price = 66.66 or street_address = 'B Street' order by id $q$),
  '(rejected,t,t,1);(rejected,t,t,1)', 'FR-024, FR-027: rejection sets decided_by, decided_at and writes one admin_log row');

select pg_temp.login('69');
select throws_ok($q$ update public.submission set status = 'rejected' where street_address = 'S1 Street' $q$,
  'P0001', 'not_pending', 'FR-024: an approved submission cannot change');
select throws_ok($q$ update public.submission set status = 'approved' where street_address = 'B Street' $q$,
  'P0001', 'not_pending', 'FR-024: a rejected submission cannot change');

select pg_temp.login('61');
select lives_ok(pg_temp.q_station('S2 Street'), 'CHK011: user submits a station');
select lives_ok(pg_temp.q_price(63.33, -4), 'CHK011: user submits a price');
reset role;
insert into public.station (brand_id, barangay_id, name, street_address)
  values (pg_temp.s('brand1')::bigint, pg_temp.s('brgy')::bigint, 'Meanwhile Station', 's2 street');
insert into public.price_report (station_product_id, price, observed_on)
  values (pg_temp.s('gas_sp')::bigint, 64.00, pg_temp.d(-4));
select pg_temp.login('69');
select throws_ok($q$ update public.submission set status = 'approved' where street_address = 'S2 Street' $q$,
  '23505', null, 'CHK011: approving a station duplicated meanwhile fails');
select throws_ok($q$ update public.submission set status = 'approved' where price = 63.33 $q$,
  '23505', null, 'CHK011: approving a price report for an existing date fails');
reset role;
select is(pg_temp.rows($q$ select status, decided_by, decided_at from public.submission
  where street_address = 'S2 Street' or price = 63.33 order by id $q$),
  '(pending,,);(pending,,)', 'CHK011: failed approvals stay pending');

select pg_temp.login('69');
select lives_ok(pg_temp.q_price(62.00, -5), 'FR-017b: admin submits a price');
reset role;
select is(pg_temp.rows($q$ select s.status, s.decided_by = s.submitted_by, s.decided_at is not null,
  (select count(*) from public.admin_log l where l.target_table = 'submission' and l.target_id = s.id::text
    and l.action = 'approve' and l.admin_id = s.submitted_by)
  from public.submission s where s.submitted_by = current_setting('test.admin')::uuid and s.price = 62.00 $q$),
  '(approved,t,t,1)', 'FR-017b: admin submission is stored approved and logged as approve');
select is(pg_temp.rows(format($q$ select price, submitted_by from public.price_report
  where station_product_id = %s and observed_on = %L $q$, pg_temp.s('gas_sp'), pg_temp.d(-5))),
  '(62.00,00000000-0000-4000-8000-000000000069)', 'FR-017b: admin submission is applied at once');
select pg_temp.login('69');
select lives_ok($q$ select pg_temp.admin_stations(21) $q$, 'FR-017b: admin makes 21 more submissions without daily_limit');
reset role;

insert into auth.users (id, email) values ('00000000-0000-4000-8000-000000000068', 'test-appr-banned@example.test');
update public.profile set is_admin = true, banned_at = now() where id = '00000000-0000-4000-8000-000000000068';
select pg_temp.login('61');
select lives_ok(pg_temp.q_price(67.77, -9), 'FR-024: user submits a price for a banned admin to decide');
select lives_ok(pg_temp.q_price(68.88, -10), 'FR-017a: user submits a price for an admin to withdraw');
select pg_temp.login('68');
select is(pg_temp.rows($q$ select count(*) from public.submission
  where submitted_by = '00000000-0000-4000-8000-000000000061' $q$),
  '(0)', 'FR-024: banned admin cannot read another user''s submissions');
select lives_ok($q$ update public.submission set status = 'approved' where price = 67.77 $q$,
  'FR-024: banned admin approve attempt');
select lives_ok($q$ update public.submission set status = 'rejected' where price = 67.77 $q$,
  'FR-024: banned admin reject attempt');
select pg_temp.login('69');
select throws_ok($q$ update public.submission set status = 'withdrawn' where price = 68.88 $q$,
  'P0001', 'not_allowed', 'FR-017a: admin cannot withdraw another user''s submission');
reset role;
select is(pg_temp.rows($q$ select status, decided_by, decided_at from public.submission where price in (67.77, 68.88) order by id $q$),
  '(pending,,);(pending,,)', 'FR-024: banned admin decisions and admin withdrawal leave the submission pending');

select * from finish();
rollback;