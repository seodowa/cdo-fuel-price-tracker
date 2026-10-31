begin;
create extension if not exists pgtap with schema extensions;
select plan(54);

create function pg_temp.d(n int) returns date language sql as $$
  select (now() at time zone 'Asia/Manila')::date + n
$$;

create function pg_temp.s(k text) returns text language sql as $$
  select current_setting('test.' || k)
$$;

insert into public.province (name) values ('Test Province T');
insert into public.city (province_id, name)
  select id, 'Test City T' from public.province where name = 'Test Province T';
insert into public.barangay (city_id, name)
  select id, 'Test Barangay T' from public.city where name = 'Test City T';
insert into public.brand (name) values ('Test Brand T1'), ('Test Brand T2');
insert into public.fuel_category (name) values ('gasoline') on conflict (lower(name)) do nothing;
insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, b.name || ' Gas' from public.brand b, public.fuel_category c
  where b.name in ('Test Brand T1', 'Test Brand T2') and c.name = 'gasoline';
insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'T1 Station', 'T1 Street' from public.brand b, public.barangay g
  where b.name = 'Test Brand T1' and g.name = 'Test Barangay T';
insert into public.station_product (station_id, product_id, brand_id)
  select s.id, p.id, s.brand_id from public.station s join public.fuel_product p on p.brand_id = s.brand_id
  where s.name = 'T1 Station';
insert into public.price_report (station_product_id, price, observed_on)
  select id, 60.00, pg_temp.d(-7) from public.station_product
  where station_id = (select id from public.station where name = 'T1 Station');

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000051', 'test-sub-a@example.test'),
  ('00000000-0000-4000-8000-000000000052', 'test-sub-b@example.test'),
  ('00000000-0000-4000-8000-000000000053', 'test-sub-c@example.test'),
  ('00000000-0000-4000-8000-000000000054', 'test-sub-d@example.test'),
  ('00000000-0000-4000-8000-000000000055', 'test-sub-e@example.test'),
  ('00000000-0000-4000-8000-000000000059', 'test-sub-admin@example.test');
update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000059';
update public.profile set banned_at = now() where id = '00000000-0000-4000-8000-000000000055';

select set_config('test.brand1', (select id::text from public.brand where name = 'Test Brand T1'), true);
select set_config('test.brgy', (select id::text from public.barangay where name = 'Test Barangay T'), true);
select set_config('test.station', (select id::text from public.station where name = 'T1 Station'), true);
select set_config('test.product1', (select id::text from public.fuel_product where name = 'Test Brand T1 Gas'), true);
select set_config('test.product2', (select id::text from public.fuel_product where name = 'Test Brand T2 Gas'), true);
select set_config('test.report', (select pr.id::text from public.price_report pr
  join public.station_product sp on sp.id = pr.station_product_id
  where sp.station_id = pg_temp.s('station')::bigint), true);

create function pg_temp.login(u text) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000000000' || u, 'role', 'authenticated')::text, true);
end;
$$;

create function pg_temp.q_station(street text, col text default null, val text default null,
  brand text default null, brgy text default null) returns text language sql as $$
  select format('insert into public.submission (kind, name, brand_id, barangay_id, street_address%s) values (%L, %L, %s, %s, %L%s)',
    coalesce(', ' || col, ''), 'station', 'Sub Station', coalesce(brand, pg_temp.s('brand1')),
    coalesce(brgy, pg_temp.s('brgy')), street, coalesce(', ' || val, ''))
$$;

create function pg_temp.q_price(p numeric, day int, col text default null, val text default null,
  product text default null) returns text language sql as $$
  select format('insert into public.submission (kind, station_id, product_id, price, observed_on%s) values (%L, %s, %s, %s, %L%s)',
    coalesce(', ' || col, ''), 'price', pg_temp.s('station'), coalesce(product, pg_temp.s('product1')),
    p, pg_temp.d(day), coalesce(', ' || val, ''))
$$;

create function pg_temp.q_corr(p numeric, col text default null, val text default null) returns text language sql as $$
  select format('insert into public.submission (kind, price_report_id, price, observed_on%s) values (%L, %s, %s, %L%s)',
    coalesce(', ' || col, ''), 'correction', pg_temp.s('report'), p, pg_temp.d(-1), coalesce(', ' || val, ''))
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

create function pg_temp.try(q text) returns void language plpgsql as $$
begin
  execute q;
exception when others then
  null;
end;
$$;

create function pg_temp.submit_n(n int) returns void language plpgsql as $$
begin
  for i in 1..n loop
    execute pg_temp.q_price(61.00, -1);
  end loop;
end;
$$;

create function pg_temp.seed_yesterday(u text, n int) returns void language plpgsql as $$
begin
  alter table public.submission disable trigger user;
  insert into public.submission (submitted_by, kind, station_id, product_id, price, observed_on, created_at)
    select ('00000000-0000-4000-8000-0000000000' || u)::uuid, 'price', pg_temp.s('station')::bigint,
      pg_temp.s('product1')::bigint, 61.00, pg_temp.d(-2), now() - interval '1 day'
    from generate_series(1, n);
  alter table public.submission enable trigger user;
end;
$$;

create function pg_temp.live() returns text language sql as $$
  select md5(concat_ws('|',
    (select string_agg(s::text, ',' order by s.id) from public.station s),
    (select string_agg(sp::text, ',' order by sp.id) from public.station_product sp),
    (select string_agg(pr::text, ',' order by pr.id) from public.price_report pr),
    (select string_agg(c::text, ',' order by c.station_product_id) from public.current_price c)))
$$;

select set_config('test.live', pg_temp.live(), true);

select pg_temp.login('51');
select lives_ok(pg_temp.q_station('A Street'), 'FR-016: user submits a station');
select lives_ok(pg_temp.q_price(61.11, -1), 'FR-016: user submits a price');
select lives_ok(pg_temp.q_corr(62.22), 'FR-016: user submits a correction');
select is(pg_temp.rows($q$ select kind, status, submitted_by = auth.uid() from public.submission order by kind $q$),
  '(correction,pending,t);(price,pending,t);(station,pending,t)',
  'FR-016: each submission is pending and owned by auth.uid()');
select throws_ok(pg_temp.q_price(61.00, -1, 'status', quote_literal('approved')), '42501', null,
  'FR-016: insert cannot set status');
select throws_ok(pg_temp.q_price(61.00, -1, 'submitted_by', quote_literal('00000000-0000-4000-8000-000000000052')), '42501', null,
  'FR-016: insert cannot set submitted_by');
select throws_ok(pg_temp.q_price(61.00, -1, 'decided_by', quote_literal('00000000-0000-4000-8000-000000000059')), '42501', null,
  'FR-016: insert cannot set decided_by');
select throws_ok(pg_temp.q_price(61.00, -1, 'decided_at', quote_literal(now()::text)), '42501', null,
  'FR-016: insert cannot set decided_at');

select lives_ok(pg_temp.q_price(63.33, -1), 'FR-017a: user submits a price to withdraw');
select lives_ok($q$ update public.submission set status = 'withdrawn' where price = 63.33 $q$,
  'FR-017a: submitter withdraws own pending submission');
select is(pg_temp.rows($q$ select status from public.submission where price = 63.33 $q$), '(withdrawn)',
  'FR-017a: submission is withdrawn');
select throws_ok($q$ update public.submission set price = 65.00 where price = 61.11 $q$, '42501', null,
  'FR-017a: submitter cannot update a column other than status');
select pg_temp.try($q$ update public.submission set status = 'pending' where price = 63.33 $q$);
select is(pg_temp.rows($q$ select status from public.submission where price = 63.33 $q$), '(withdrawn)',
  'FR-017a: submitter cannot change a withdrawn submission');
select throws_ok($q$ delete from public.submission where submitted_by = auth.uid() $q$, '42501', null,
  'SC-003: submitter cannot delete own submission');
select is(pg_temp.rows($q$ select id from public.profile $q$), '(00000000-0000-4000-8000-000000000051)',
  'FR-023: user reads own profile only');

select pg_temp.login('52');
select lives_ok(pg_temp.q_price(64.44, -1), 'FR-016: second user submits a price');
select pg_temp.try($q$ update public.submission set status = 'withdrawn' where price = 61.11 $q$);
select is(pg_temp.rows($q$ select count(*) from public.submission where submitted_by = '00000000-0000-4000-8000-000000000051' $q$), '(0)',
  'FR-023: user B sees none of user A''s submissions');
select is(pg_temp.rows($q$ select price, status from public.submission $q$), '(64.44,pending)',
  'FR-023: user B sees own submission with status');

select pg_temp.login('59');
select lives_ok($q$ update public.submission set status = 'rejected' where price = 64.44 $q$,
  'FR-017: admin rejects a submission');
select throws_ok($q$ update public.submission set status = 'approved' where price = 63.33 $q$, 'P0001', 'not_pending',
  'FR-017a: a withdrawn submission cannot change again');
select is(pg_temp.rows($q$ select status from public.submission where price = 61.11 $q$), '(pending)',
  'FR-017a: another user cannot withdraw a submission');
reset role;

select is(pg_temp.live(), pg_temp.s('live'),
  'FR-017: pending, rejected and withdrawn submissions leave station, station_product, price_report and current_price unchanged');

select pg_temp.login('51');
select throws_ok(pg_temp.q_station('A2 Street', 'price', '61.00'), '23514', null,
  'FR-020: station kind with a price field raises 23514');
select throws_ok(format('insert into public.submission (kind, name, brand_id, barangay_id) values (%L, %L, %s, %s)',
  'station', 'Sub Station', pg_temp.s('brand1'), pg_temp.s('brgy')), '23514', null,
  'FR-020: station kind without street_address raises 23514');
select throws_ok(format('insert into public.submission (kind, station_id, product_id, price) values (%L, %s, %s, 61.00)',
  'price', pg_temp.s('station'), pg_temp.s('product1')), '23514', null,
  'FR-020: price kind without observed_on raises 23514');
select throws_ok(pg_temp.q_price(61.00, -1, 'name', quote_literal('Extra')), '23514', null,
  'FR-020: price kind with a station field raises 23514');
select throws_ok(format('insert into public.submission (kind, price_report_id, observed_on) values (%L, %s, %L)',
  'correction', pg_temp.s('report'), pg_temp.d(-1)), '23514', null,
  'FR-020: correction kind without price raises 23514');
select throws_ok(pg_temp.q_corr(61.00, 'station_id', pg_temp.s('station')), '23514', null,
  'FR-020: correction kind with a price-kind field raises 23514');
select throws_ok(pg_temp.q_price(6.50, -1), '23514', null, 'FR-020: price 6.50 raises 23514');
select throws_ok(pg_temp.q_price(650.00, -1), '23514', null, 'FR-020: price 650.00 raises 23514');
select throws_ok(pg_temp.q_corr(650.00), '23514', null, 'FR-020: correction price 650.00 raises 23514');
select throws_ok(pg_temp.q_station('A3 Street', brand => '-1'), '23503', null,
  'FR-020: missing brand raises 23503');
select throws_ok(pg_temp.q_station('A4 Street', brgy => '-1'), '23503', null,
  'FR-020: missing barangay raises 23503');
select throws_ok(pg_temp.q_price(61.00, -1, product => pg_temp.s('product2')), 'P0001', 'brand_mismatch',
  'FR-020: product of another brand raises brand_mismatch');
select throws_ok(pg_temp.q_station('t1 STREET'), 'P0001', 'duplicate_station',
  'FR-020: station duplicating a live one raises duplicate_station');
select throws_ok(pg_temp.q_price(61.00, 1), 'P0001', 'future_date',
  'FR-020: observed_on after Manila today raises future_date');
select lives_ok(pg_temp.q_price(61.00, 0), 'FR-020: observed_on of Manila today is accepted');
reset role;

select lives_ok($q$ select pg_temp.seed_yesterday('53', 20) $q$, 'FR-019: 20 submissions exist from yesterday Manila time');
select pg_temp.login('53');
select lives_ok($q$ select pg_temp.submit_n(20) $q$, 'FR-019: yesterday does not count, 20 submissions today succeed');
select throws_ok(pg_temp.q_price(61.00, -1), 'P0001', 'daily_limit', 'FR-019: 21st submission today raises daily_limit');
select throws_ok(pg_temp.q_station('C Street'), 'P0001', 'daily_limit', 'FR-019: limit covers every kind');

select pg_temp.login('54');
select lives_ok(pg_temp.q_station('D1 Street'), 'FR-019: user D submits a station to approve');
select lives_ok(pg_temp.q_station('D2 Street'), 'FR-019: user D submits a station to reject');
select lives_ok(pg_temp.q_station('D3 Street'), 'FR-019: user D submits a station to withdraw');
select lives_ok($q$ update public.submission set status = 'withdrawn' where street_address = 'D3 Street' $q$,
  'FR-019: user D withdraws one');
select pg_temp.login('59');
select lives_ok($q$ update public.submission set status = 'approved' where street_address = 'D1 Street' $q$,
  'FR-019: admin approves one of user D''s');
select lives_ok($q$ update public.submission set status = 'rejected' where street_address = 'D2 Street' $q$,
  'FR-019: admin rejects one of user D''s');
select pg_temp.login('54');
select lives_ok($q$ select pg_temp.submit_n(17) $q$, 'FR-019: user D reaches 20 submissions');
select is(pg_temp.rows($q$ select status, count(*) from public.submission group by status order by status $q$),
  '(approved,1);(pending,17);(rejected,1);(withdrawn,1)',
  'FR-019: user D has pending, approved, rejected and withdrawn submissions');
select throws_ok(pg_temp.q_price(61.00, -1), 'P0001', 'daily_limit',
  'FR-019: pending, approved, rejected and withdrawn all count toward the limit');

select pg_temp.login('55');
select throws_ok(pg_temp.q_price(61.00, -1), 'P0001', 'banned', 'FR-026: banned user cannot submit');
reset role;

set local role anon;
select throws_ok(pg_temp.q_price(61.00, -1), '42501', null, 'Scenario 6: anon cannot insert a submission');
select throws_ok($q$ select * from public.submission $q$, '42501', null, 'SC-003: anon cannot read submission');
select throws_ok($q$ select * from public.profile $q$, '42501', null, 'SC-003: anon cannot read profile');
reset role;

select * from finish();
rollback;
