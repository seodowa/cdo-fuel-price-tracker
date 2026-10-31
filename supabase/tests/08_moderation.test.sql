begin;
create extension if not exists pgtap with schema extensions;
select plan(44);

insert into public.province (name) values ('Mod Province');
insert into public.city (province_id, name)
  select id, 'Mod City' from public.province where name = 'Mod Province';
insert into public.barangay (city_id, name)
  select id, 'Mod Barangay' from public.city where name = 'Mod City';
insert into public.brand (name) values ('Mod Brand'), ('Mod Brand Used');
insert into public.fuel_category (name) values ('Mod Category');
insert into public.fuel_product (brand_id, category_id, name)
  select b.id, c.id, 'Mod Product' from public.brand b, public.fuel_category c
  where b.name = 'Mod Brand' and c.name = 'Mod Category';
insert into public.station (brand_id, barangay_id, name, street_address)
  select b.id, g.id, 'Mod Used Station', 'Used Street' from public.brand b, public.barangay g
  where b.name = 'Mod Brand Used' and g.name = 'Mod Barangay';

insert into auth.users (id, email) values
  ('00000000-0000-4000-8000-000000000081', 'test-mod-admin@example.test'),
  ('00000000-0000-4000-8000-000000000082', 'test-mod-user@example.test'),
  ('00000000-0000-4000-8000-000000000083', 'test-mod-target@example.test'),
  ('00000000-0000-4000-8000-000000000084', 'test-mod-banned-admin@example.test');
update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000081';
update public.profile set is_admin = true, banned_at = now() where id = '00000000-0000-4000-8000-000000000084';

select set_config('test.admin', '00000000-0000-4000-8000-000000000081', true);
select set_config('test.target', '00000000-0000-4000-8000-000000000083', true);
select set_config('test.province', (select id::text from public.province where name = 'Mod Province'), true);
select set_config('test.city', (select id::text from public.city where name = 'Mod City'), true);
select set_config('test.barangay', (select id::text from public.barangay where name = 'Mod Barangay'), true);
select set_config('test.brand', (select id::text from public.brand where name = 'Mod Brand'), true);
select set_config('test.used_brand', (select id::text from public.brand where name = 'Mod Brand Used'), true);
select set_config('test.fuel_category', (select id::text from public.fuel_category where name = 'Mod Category'), true);
select set_config('test.fuel_product', (select id::text from public.fuel_product where name = 'Mod Product'), true);

create function pg_temp.s(k text) returns text language sql as $$
  select current_setting('test.' || k, true)
$$;

create function pg_temp.login(u text) returns void language plpgsql as $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000000000' || u, 'role', 'authenticated')::text, true);
end;
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

create function pg_temp.n(q text) returns text language plpgsql as $$
declare
  c int;
begin
  execute q;
  get diagnostics c = row_count;
  return c::text;
exception when others then
  return sqlstate;
end;
$$;

create function pg_temp.refused(q text) returns text language plpgsql as $$
declare
  c int;
begin
  execute q;
  get diagnostics c = row_count;
  return case when c = 0 then 'refused' else c || ' rows' end;
exception
  when insufficient_privilege then return 'refused';
  when others then return sqlstate;
end;
$$;

create function pg_temp.ins(t text, nm text) returns text language sql as $$
  select format('insert into public.%I (%sname) values (%s%L)', t,
    case t when 'city' then 'province_id, ' when 'barangay' then 'city_id, '
      when 'fuel_product' then 'brand_id, category_id, ' else '' end,
    case t when 'city' then pg_temp.s('province') || ', ' when 'barangay' then pg_temp.s('city') || ', '
      when 'fuel_product' then pg_temp.s('brand') || ', ' || pg_temp.s('fuel_category') || ', ' else '' end,
    nm)
$$;

create function pg_temp.crud(t text) returns text language plpgsql as $$
declare
  new_id bigint;
  u int;
  d int;
begin
  execute pg_temp.ins(t, 'Mod New ' || t) || ' returning id' into new_id;
  execute format('update public.%I set name = %L where id = %s', t, 'Mod Renamed ' || t, new_id);
  get diagnostics u = row_count;
  execute format('delete from public.%I where id = %s', t, new_id);
  get diagnostics d = row_count;
  perform set_config('test.new_' || t, new_id::text, true);
  return u || ',' || d;
exception when others then
  return sqlstate;
end;
$$;

create function pg_temp.user_crud(t text) returns text language sql as $$
  select concat_ws(' ',
    pg_temp.refused(pg_temp.ins(t, 'Mod Hack ' || t)),
    pg_temp.refused(format('update public.%I set name = %L where id = %s', t, 'Mod Hacked ' || t, pg_temp.s(t))),
    pg_temp.refused(format('delete from public.%I where id = %s', t, pg_temp.s(t))))
$$;

create function pg_temp.log(t text, target text) returns text language sql as $$
  select pg_temp.rows(format($q$ select string_agg(action || ':' || (admin_id = %L::uuid) || ':' || (created_at is not null),
    ';' order by id) from public.admin_log where target_table = %L and target_id = %L $q$, pg_temp.s('admin'), t, target))
$$;

create function pg_temp.q_station(street text) returns text language sql as $$
  select format('insert into public.submission (kind, name, brand_id, barangay_id, street_address) values (%L, %L, %s, %s, %L)',
    'station', 'Mod Sub Station', pg_temp.s('used_brand'), pg_temp.s('barangay'), street)
$$;

select pg_temp.login('82');
select is(pg_temp.user_crud('province'), 'refused refused refused', 'FR-024 scenario 3: regular user cannot insert, update or delete a province');
select is(pg_temp.user_crud('city'), 'refused refused refused', 'FR-024 scenario 3: regular user cannot insert, update or delete a city');
select is(pg_temp.user_crud('barangay'), 'refused refused refused', 'FR-024 scenario 3: regular user cannot insert, update or delete a barangay');
select is(pg_temp.user_crud('brand'), 'refused refused refused', 'FR-024 scenario 3: regular user cannot insert, update or delete a brand');
select is(pg_temp.user_crud('fuel_category'), 'refused refused refused', 'FR-024 scenario 3: regular user cannot insert, update or delete a fuel category');
select is(pg_temp.user_crud('fuel_product'), 'refused refused refused', 'FR-024 scenario 3: regular user cannot insert, update or delete a fuel product');
select is(pg_temp.refused(format('update public.profile set banned_at = now() where id = %L', pg_temp.s('target'))),
  'refused', 'FR-026 scenario 3: regular user cannot ban another user');
select is(pg_temp.refused($q$ update public.profile set banned_at = null where id = '00000000-0000-4000-8000-000000000082' $q$),
  'refused', 'FR-026: regular user cannot update their own profile');
select throws_ok($q$ update public.profile set is_admin = true where id = '00000000-0000-4000-8000-000000000082' $q$,
  '42501', null, 'R2: regular user cannot set is_admin');

select pg_temp.login('84');
select is(pg_temp.user_crud('brand'), 'refused refused refused', 'R2: banned admin cannot manage reference data');
select is(pg_temp.refused(format('update public.profile set banned_at = now() where id = %L', pg_temp.s('target'))),
  'refused', 'R2: banned admin cannot ban');
select is(pg_temp.rows('select count(*) from public.admin_log'), '(0)', 'R2: banned admin reads no admin_log rows');
select is(pg_temp.rows('select id from public.profile'), '(00000000-0000-4000-8000-000000000084)',
  'R2: banned admin reads only their own profile');

select pg_temp.login('81');
select is(pg_temp.crud('province'), '1,1', 'FR-024: admin inserts, updates and deletes a province');
select is(pg_temp.crud('city'), '1,1', 'FR-024: admin inserts, updates and deletes a city');
select is(pg_temp.crud('barangay'), '1,1', 'FR-024: admin inserts, updates and deletes a barangay');
select is(pg_temp.crud('brand'), '1,1', 'FR-024: admin inserts, updates and deletes a brand');
select is(pg_temp.crud('fuel_category'), '1,1', 'FR-024: admin inserts, updates and deletes a fuel category');
select is(pg_temp.crud('fuel_product'), '1,1', 'FR-024: admin inserts, updates and deletes a fuel product');
select throws_ok(format('delete from public.brand where id = %s', pg_temp.s('used_brand')),
  '23503', null, 'FR-004 scenario 5: admin cannot delete a brand with stations');
select throws_ok($q$ update public.profile set is_admin = false where id = '00000000-0000-4000-8000-000000000081' $q$,
  '42501', null, 'R2: admin cannot update is_admin');
reset role;

select is(pg_temp.log('province', pg_temp.s('new_province')), '(create:true:true;update:true:true;delete:true:true)',
  'FR-027: province create, update and delete each write one admin_log row');
select is(pg_temp.log('city', pg_temp.s('new_city')), '(create:true:true;update:true:true;delete:true:true)',
  'FR-027: city create, update and delete each write one admin_log row');
select is(pg_temp.log('barangay', pg_temp.s('new_barangay')), '(create:true:true;update:true:true;delete:true:true)',
  'FR-027: barangay create, update and delete each write one admin_log row');
select is(pg_temp.log('brand', pg_temp.s('new_brand')), '(create:true:true;update:true:true;delete:true:true)',
  'FR-027: brand create, update and delete each write one admin_log row');
select is(pg_temp.log('fuel_category', pg_temp.s('new_fuel_category')), '(create:true:true;update:true:true;delete:true:true)',
  'FR-027: fuel category create, update and delete each write one admin_log row');
select is(pg_temp.log('fuel_product', pg_temp.s('new_fuel_product')), '(create:true:true;update:true:true;delete:true:true)',
  'FR-027: fuel product create, update and delete each write one admin_log row');

select pg_temp.login('81');
select is(pg_temp.n(format('update public.profile set banned_at = now() where id = %L', pg_temp.s('target'))),
  '1', 'FR-026: admin bans a user');
select pg_temp.login('83');
select throws_ok(pg_temp.q_station('Ban Street'), 'P0001', 'banned', 'FR-026 scenario 1: banned user''s next submission is refused');
select pg_temp.login('81');
select is(pg_temp.n(format('update public.profile set banned_at = null where id = %L', pg_temp.s('target'))),
  '1', 'FR-026: admin clears the ban');
select pg_temp.login('83');
select lives_ok(pg_temp.q_station('Unban Street'), 'FR-026 scenario 2: unbanned user submits again');
reset role;
select is(pg_temp.log('profile', pg_temp.s('target')), '(ban:true:true;unban:true:true)',
  'FR-027 scenarios 1 and 2: ban and unban each write one admin_log row');

select set_config('request.jwt.claims', '', true);
select set_config('test.logs', (select count(*)::text from public.admin_log), true);
select is((select string_agg(pg_temp.crud(t), ' ')
  from unnest(array['province', 'city', 'barangay', 'brand', 'fuel_category', 'fuel_product']) t),
  '1,1 1,1 1,1 1,1 1,1 1,1', 'FR-027: postgres changes reference data');
select is((select count(*)::text from public.admin_log), pg_temp.s('logs'),
  'FR-027: reference data changes without auth.uid() write no admin_log row');

select pg_temp.login('82');
select ok(pg_temp.rows('select count(*) from public.admin_log') ~ '^(\(0\)|error 42501)',
  'FR-027: regular user cannot read admin_log');
select throws_ok($q$ update public.admin_log set action = 'ban' $q$, '42501', null, 'FR-027: regular user cannot update admin_log');
select throws_ok($q$ delete from public.admin_log $q$, '42501', null, 'FR-027: regular user cannot delete admin_log');

select pg_temp.login('81');
select is(pg_temp.rows('select count(*) from public.admin_log'), '(' || pg_temp.s('logs') || ')',
  'FR-027: admin reads every admin_log row');
select throws_ok($q$ update public.admin_log set action = 'ban' $q$, '42501', null, 'FR-027: admin cannot update admin_log');
select throws_ok($q$ delete from public.admin_log $q$, '42501', null, 'FR-027: admin cannot delete admin_log');
reset role;

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok('select count(*) from public.admin_log', '42501', null, 'FR-027: anon cannot read admin_log');
select throws_ok($q$ insert into public.province (name) values ('Mod Anon Province') $q$, '42501', null, 'FR-024: anon cannot insert a province');
select throws_ok($q$ update public.province set name = 'Mod Anon Renamed' $q$, '42501', null, 'FR-024: anon cannot update a province');
select throws_ok($q$ delete from public.province $q$, '42501', null, 'FR-024: anon cannot delete a province');
reset role;

select * from finish();
rollback;
