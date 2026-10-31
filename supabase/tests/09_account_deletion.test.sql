begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create function pg_temp.d(n int) returns date language sql as $$
  select (now() at time zone 'Asia/Manila')::date + n
$$;

create function pg_temp.s(k text) returns text language sql as $$
  select current_setting('test.' || k)
$$;

insert into public.province (name) values ('Test Province X');
insert into public.city (province_id, name)
  select id, 'Test City X' from public.province where name = 'Test Province X';
insert into public.barangay (city_id, name)
  select id, 'Test Barangay X' from public.city where name = 'Test City X';
insert into public.brand (name) values ('Test Brand X');
insert into public.fuel_category (name) values ('gasoline') on conflict (lower(name)) do nothing;
insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, 'Test Brand X Gas' from public.brand b, public.fuel_category c
  where b.name = 'Test Brand X' and c.name = 'gasoline';
insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'X Station', 'X Street' from public.brand b, public.barangay g
  where b.name = 'Test Brand X' and g.name = 'Test Barangay X';
insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s join public.fuel_product p on p.brand_id = s.brand_id
  where s.name = 'X Station';

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000091', 'test-del-u@example.test'),
  ('00000000-0000-4000-8000-000000000092', 'test-del-v@example.test'),
  ('00000000-0000-4000-8000-000000000099', 'test-del-admin@example.test');
update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000099';

select set_config('test.station', (select id::text from public.station where name = 'X Station'), true);
select set_config('test.product', (select id::text from public.fuel_product where name = 'Test Brand X Gas'), true);
select set_config('test.sp', (select id::text from public.station_product
  where station_id = pg_temp.s('station')::bigint), true);

create function pg_temp.login(u text) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000000000' || u, 'role', 'authenticated')::text, true);
end;
$$;

create function pg_temp.q_price(p numeric, day int) returns text language sql as $$
  select format('insert into public.submission (kind, station_id, product_id, price, observed_on) values (%L, %s, %s, %s, %L)',
    'price', pg_temp.s('station'), pg_temp.s('product'), p, pg_temp.d(day))
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

select pg_temp.login('91');
select lives_ok(pg_temp.q_price(61.50, -1), 'FR-028: user U submits a price');
select lives_ok(pg_temp.q_price(62.50, -1), 'FR-028: user U submits a price left pending');
select pg_temp.login('92');
select lives_ok(pg_temp.q_price(60.50, -2), 'FR-028: user V submits a price');
select pg_temp.login('99');
select lives_ok($q$ update public.submission set status = 'approved' where price = 61.50 $q$,
  'FR-028: admin A approves U''s price');
select lives_ok($q$ update public.submission set status = 'approved' where price = 60.50 $q$,
  'FR-028: admin A approves V''s price');
reset role;

select is(pg_temp.rows($q$ select submitted_by = '00000000-0000-4000-8000-000000000091' from public.price_report where price = 61.50 $q$),
  '(t)', 'FR-028: U''s approved price report carries U as submitter');
create temp table current_before as
  select * from public.current_price where station_product_id = pg_temp.s('sp')::bigint;
select is(pg_temp.rows($q$ select price from current_before $q$), '(61.50)',
  'FR-028: current_price shows U''s approved price before deletion');

select lives_ok($q$ delete from auth.users where id = '00000000-0000-4000-8000-000000000091' $q$,
  'FR-028: deleting U from auth.users succeeds');
select is(pg_temp.rows($q$ select count(*) from public.profile where id = '00000000-0000-4000-8000-000000000091' $q$),
  '(0)', 'FR-028: U''s profile is deleted');
select is(pg_temp.rows($q$ select count(*) from public.submission where submitted_by = '00000000-0000-4000-8000-000000000091' $q$),
  '(0)', 'FR-028: all U''s submissions are deleted');
select is(pg_temp.rows($q$ select submitted_by is null from public.price_report where price = 61.50 $q$),
  '(t)', 'FR-028: U''s price report remains with submitted_by null');
select results_eq(
  format('select * from public.current_price where station_product_id = %s', pg_temp.s('sp')),
  'select * from current_before',
  'FR-028: current_price is unchanged after deleting U');

select lives_ok($q$ delete from auth.users where id = '00000000-0000-4000-8000-000000000099' $q$,
  'FR-028: deleting admin A from auth.users succeeds');
select is(pg_temp.rows($q$ select action, admin_id is null from public.admin_log where target_table = 'submission' order by id $q$),
  '(approve,t);(approve,t)', 'FR-028: A''s admin_log rows remain with admin_id null');
select is(pg_temp.rows($q$ select status, decided_by is null, decided_at is not null from public.submission
  where submitted_by = '00000000-0000-4000-8000-000000000092' $q$),
  '(approved,t,t)', 'FR-028: submissions A decided stay approved with decided_by null');

set local role anon;
select throws_ok($q$ select submitted_by from public.price_report $q$, '42501', null,
  'R4: anon still cannot read price_report.submitted_by');
reset role;

select * from finish();
rollback;
