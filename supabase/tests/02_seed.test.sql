begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

select is(
  (select count(*)::int from public.province where name = 'Misamis Oriental'),
  1,
  'FR-005: province Misamis Oriental is seeded'
);

select is(
  (select count(*)::int from public.city c join public.province p on p.id = c.province_id
    where c.name = 'Cagayan de Oro' and p.name = 'Misamis Oriental'),
  1,
  'FR-005: city Cagayan de Oro belongs to Misamis Oriental'
);

select is(
  (select count(*)::int from public.barangay b join public.city c on c.id = b.city_id
    join public.province p on p.id = c.province_id
    where c.name = 'Cagayan de Oro' and p.name = 'Misamis Oriental'),
  80,
  'FR-005: Cagayan de Oro has exactly 80 barangays'
);

select results_eq(
  $$ select name from public.fuel_category order by name $$,
  $$ values ('diesel'::text), ('gasoline'), ('kerosene') $$,
  'FR-005: fuel categories are exactly diesel, gasoline, kerosene'
);

select * from finish();
rollback;
