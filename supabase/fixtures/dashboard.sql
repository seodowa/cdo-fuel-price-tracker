-- Dashboard data for local development and the e2e tests. Load after empty.sql:
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/fixtures/empty.sql -f supabase/fixtures/dashboard.sql
-- Brands and product names are real. Stations, streets and prices are made up.
--
-- Dates are relative to today in Manila, so the fixture works on any day. w is this week's
-- Monday, always between today - 6 and today. A report dated w or later gets no shift (shifts
-- dated w apply only to reports before w), so most prices below show as entered. Reports with
-- an age of 8 days or more are older than w, so this week's shift applies and they show "est.".
--
-- Ranked stations: 15 gasoline (3 pages of 5), 10 diesel (2 pages), 8 kerosene (2 pages).

begin;

create temp table fixture_day on commit drop as
select
  (now() at time zone 'Asia/Manila')::date as today,
  date_trunc('week', (now() at time zone 'Asia/Manila')::date)::date as w;

insert into public.brand (name)
values ('Petron'), ('Shell'), ('Caltex'), ('Seaoil'), ('Phoenix'), ('Unioil'), ('Cleanfuel');

insert into public.fuel_product (brand_id, category_id, name)
select b.id, c.id, v.product
from (values
  ('Petron', 'gasoline', 'Xtra Advance'),
  ('Petron', 'gasoline', 'XCS'),
  ('Petron', 'diesel', 'Diesel Max'),
  ('Petron', 'diesel', 'Turbo Diesel'),
  ('Petron', 'kerosene', 'Kerosene'),
  ('Shell', 'gasoline', 'FuelSave Gasoline'),
  ('Shell', 'gasoline', 'V-Power Gasoline'),
  ('Shell', 'diesel', 'FuelSave Diesel'),
  ('Shell', 'diesel', 'V-Power Diesel'),
  ('Shell', 'kerosene', 'Kerosene'),
  ('Caltex', 'gasoline', 'Silver with Techron'),
  ('Caltex', 'gasoline', 'Platinum with Techron'),
  ('Caltex', 'diesel', 'Diesel with Techron'),
  ('Caltex', 'kerosene', 'Kerosene'),
  ('Seaoil', 'gasoline', 'Extreme U'),
  ('Seaoil', 'gasoline', 'Extreme 95'),
  ('Seaoil', 'diesel', 'Exceed Diesel'),
  ('Seaoil', 'kerosene', 'Kerosene'),
  ('Phoenix', 'gasoline', 'Super Regular 91'),
  ('Phoenix', 'gasoline', 'Premium 95'),
  ('Phoenix', 'diesel', 'Diesel'),
  ('Unioil', 'gasoline', 'Euro 5 Gasoline 91'),
  ('Unioil', 'diesel', 'Euro 5 Diesel'),
  ('Cleanfuel', 'gasoline', 'Unleaded 91'),
  ('Cleanfuel', 'diesel', 'Diesel')
) as v (brand, category, product)
join public.brand b on b.name = v.brand
join public.fuel_category c on c.name = v.category;

insert into public.station (brand_id, barangay_id, name, street_address)
select b.id, g.id, v.station, v.street
from (values
  ('Petron', 'Lapasan', 'Petron Lapasan', 'Claro M. Recto Ave'),
  ('Petron', 'Macasandig', 'Petron Macasandig', 'Macasandig Rd'),
  ('Petron', 'Bulua', 'Petron Bulua', 'National Highway'),
  ('Petron', 'Agusan', 'Petron Agusan', 'Butuan-Cagayan Rd'),
  ('Shell', 'Carmen', 'Shell Carmen', 'Masterson Ave'),
  ('Shell', 'Gusa', 'Shell Gusa', 'Gusa Highway'),
  ('Shell', 'Kauswagan', 'Shell Kauswagan', 'Kauswagan Rd'),
  ('Caltex', 'Puerto', 'Caltex Puerto', 'Puerto Highway'),
  ('Caltex', 'Iponan', 'Caltex Iponan', 'Iponan Rd'),
  ('Seaoil', 'Cugman', 'Seaoil Cugman', 'Cugman Highway'),
  ('Seaoil', 'Consolacion', 'Seaoil Consolacion', 'Velez St'),
  ('Phoenix', 'Camaman-an', 'Phoenix Camaman-an', 'Camaman-an Rd'),
  ('Phoenix', 'Bugo', 'Phoenix Bugo', 'Bugo Highway'),
  ('Unioil', 'Balulang', 'Unioil Balulang', 'Balulang Rd'),
  ('Cleanfuel', 'Patag', 'Cleanfuel Patag', 'Patag Rd')
) as v (brand, barangay, station, street)
join public.brand b on b.name = v.brand
join public.barangay g on g.name = v.barangay;

-- age: days before today; null means dated w (shown as entered, never shifted)
create temp table fixture_price (station text, product text, price numeric, age int) on commit drop;
insert into fixture_price values
  -- Gasoline, 15 stations. Petron Lapasan sells two gasolines; only Xtra Advance is ranked.
  ('Petron Lapasan', 'Xtra Advance', 62.45, null),
  ('Petron Lapasan', 'XCS', 68.10, null),
  ('Petron Macasandig', 'Xtra Advance', 62.60, 0),          -- "Reported today"
  ('Petron Bulua', 'Xtra Advance', 63.50, 12),              -- "12 days ago · est.", 63.50 - 0.85
  ('Petron Agusan', 'Xtra Advance', 62.90, null),
  ('Shell Carmen', 'FuelSave Gasoline', 62.85, null),
  ('Shell Gusa', 'FuelSave Gasoline', 63.05, 0),
  ('Shell Kauswagan', 'V-Power Gasoline', 68.40, null),
  ('Caltex Puerto', 'Silver with Techron', 62.30, null),
  ('Caltex Iponan', 'Platinum with Techron', 67.85, 9),     -- est., 67.85 - 0.70
  ('Seaoil Cugman', 'Extreme 95', 63.80, null),
  ('Seaoil Consolacion', 'Extreme U', 61.95, null),
  ('Phoenix Camaman-an', 'Premium 95', 63.40, null),
  ('Phoenix Bugo', 'Super Regular 91', 61.70, 8),           -- est., 61.70 - 0.65 = cheapest
  ('Unioil Balulang', 'Euro 5 Gasoline 91', 61.80, null),
  ('Cleanfuel Patag', 'Unleaded 91', 61.20, null),
  -- Diesel, 10 stations
  ('Petron Lapasan', 'Diesel Max', 56.20, null),
  ('Petron Macasandig', 'Turbo Diesel', 58.90, null),
  ('Petron Bulua', 'Diesel Max', 55.10, 12),                -- est., 55.10 + 1.20; the future +5.00 never applies
  ('Shell Carmen', 'FuelSave Diesel', 56.55, null),
  ('Shell Gusa', 'V-Power Diesel', 59.40, 0),
  ('Caltex Puerto', 'Diesel with Techron', 56.40, null),
  ('Seaoil Cugman', 'Exceed Diesel', 55.80, null),
  ('Phoenix Camaman-an', 'Diesel', 55.45, null),
  ('Unioil Balulang', 'Euro 5 Diesel', 55.35, null),
  ('Cleanfuel Patag', 'Diesel', 54.90, 15),                 -- est., 54.90 + 1.20
  -- Kerosene, 8 stations
  ('Petron Lapasan', 'Kerosene', 70.95, null),
  ('Petron Macasandig', 'Kerosene', 71.20, null),
  ('Petron Agusan', 'Kerosene', 71.50, 9),                  -- est., 71.50 + 0.40
  ('Shell Carmen', 'Kerosene', 72.30, null),
  ('Shell Kauswagan', 'Kerosene', 72.10, null),
  ('Caltex Puerto', 'Kerosene', 71.80, null),
  ('Caltex Iponan', 'Kerosene', 72.60, 0),
  ('Seaoil Consolacion', 'Kerosene', 70.60, null);

insert into public.station_product (station_id, product_id, brand_id)
select s.id, p.id, s.brand_id
from fixture_price f
join public.station s on s.name = f.station
join public.fuel_product p on p.name = f.product and p.brand_id = s.brand_id;

insert into public.price_report (station_product_id, price, observed_on)
select sp.id, f.price, case when f.age is null then d.w else d.today - f.age end
from fixture_price f
cross join fixture_day d
join public.station s on s.name = f.station
join public.fuel_product p on p.name = f.product and p.brand_id = s.brand_id
join public.station_product sp on sp.station_id = s.id and sp.product_id = p.id;

-- This week's shifts, all dated w. Gasoline: every brand rolls back 0.60 to 0.85. Diesel: every
-- brand +1.20. Kerosene: up for some brands, down for others ("Mixed"). The extra Petron diesel
-- +5.00 is dated in the future and must change nothing.
insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
select b.id, c.id, v.amount, d.w + v.days_after_w, 'fixture:dashboard.sql', now(), 'fixture'
from (values
  ('Petron', 'gasoline', -0.85, 0),
  ('Shell', 'gasoline', -0.60, 0),
  ('Caltex', 'gasoline', -0.70, 0),
  ('Seaoil', 'gasoline', -0.75, 0),
  ('Phoenix', 'gasoline', -0.65, 0),
  ('Unioil', 'gasoline', -0.80, 0),
  ('Cleanfuel', 'gasoline', -0.60, 0),
  ('Petron', 'diesel', 1.20, 0),
  ('Shell', 'diesel', 1.20, 0),
  ('Caltex', 'diesel', 1.20, 0),
  ('Seaoil', 'diesel', 1.20, 0),
  ('Phoenix', 'diesel', 1.20, 0),
  ('Unioil', 'diesel', 1.20, 0),
  ('Cleanfuel', 'diesel', 1.20, 0),
  ('Petron', 'kerosene', 0.40, 0),
  ('Shell', 'kerosene', -0.30, 0),
  ('Caltex', 'kerosene', 0.40, 0),
  ('Seaoil', 'kerosene', -0.30, 0)
) as v (brand, category, amount, days_after_w)
cross join fixture_day d
join public.brand b on b.name = v.brand
join public.fuel_category c on c.name = v.category;

-- Future shift: today + 3 is always after w
insert into public.price_shift (brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor)
select b.id, c.id, 5.00, d.today + 3, 'fixture:dashboard.sql', now(), 'fixture'
from fixture_day d
join public.brand b on b.name = 'Petron'
join public.fuel_category c on c.name = 'diesel';

commit;
