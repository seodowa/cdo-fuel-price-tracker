-- Clears every price-related table so a fixture can be loaded fresh. Local database only.
-- Keeps the seed's provinces, cities, barangays and fuel categories.
truncate public.price_shift, public.price_report, public.station_product, public.station,
  public.fuel_product, public.brand restart identity cascade;
