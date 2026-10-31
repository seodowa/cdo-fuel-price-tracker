grant select on
  public.province, public.city, public.barangay, public.brand, public.fuel_category,
  public.fuel_product, public.station, public.station_product, public.price_shift
to anon, authenticated;

grant select (id, station_product_id, price, observed_on) on public.price_report to anon, authenticated;

create policy public_read on public.province for select to anon, authenticated using (true);
create policy public_read on public.city for select to anon, authenticated using (true);
create policy public_read on public.barangay for select to anon, authenticated using (true);
create policy public_read on public.brand for select to anon, authenticated using (true);
create policy public_read on public.fuel_category for select to anon, authenticated using (true);
create policy public_read on public.fuel_product for select to anon, authenticated using (true);
create policy public_read on public.station for select to anon, authenticated using (true);
create policy public_read on public.station_product for select to anon, authenticated using (true);
create policy public_read on public.price_shift for select to anon, authenticated using (true);
create policy public_read on public.price_report for select to anon, authenticated using (true);

create view public.current_price with (security_invoker = true) as
select
  sp.id as station_product_id,
  sp.station_id,
  sp.product_id,
  r.price + coalesce(s.total, 0) as price,
  r.observed_on as reported_at,
  s.shifted_at,
  s.shifted_at is not null as is_estimate
from public.station_product sp
join public.fuel_product fp on fp.id = sp.product_id
cross join lateral (
  select pr.price, pr.observed_on
  from public.price_report pr
  where pr.station_product_id = sp.id
  order by pr.observed_on desc
  limit 1
) r
cross join lateral (
  select sum(ps.amount) as total, max(ps.effective_on) as shifted_at
  from public.price_shift ps
  where ps.brand_id = sp.brand_id
    and ps.category_id = fp.category_id
    and ps.effective_on > r.observed_on
    and ps.effective_on <= (now() at time zone 'Asia/Manila')::date
) s;

revoke all on public.current_price from anon, authenticated;
grant select on public.current_price to anon, authenticated;
