# Grill decisions: database schema

- D1: Weekly shifts keyed on brand and category (see DECISIONS.md 2026-10-28). Rejected: category only.
- D2 (Q1): Feature is database only: tables, constraints, RLS, current-price view, seed data, pgTAP tests. Rejected: including SvelteKit view/submit flows.
- D3 (Q2): Admins manage brands, products, categories and locations (seeded). Signed-in users may add stations using existing brands and barangays. Rejected: admin-only stations, users add anything.
- D4 (Q3): Any signed-in user may correct a baseline or override, with a daily submission limit per account. Rejected: submitter or admin only.
- D5 (Q4): Every user submission (new station, baseline, override, correction) waits as pending until an admin approves it; approval applies it to the live record. Rejected: no approval, approval for stations only.
- D6 (Q5): 20 submissions per account per day, pending or decided, enforced in the database. Rejected: 5, 50.
- D7 (Q6): CHECK constraints: prices 20 to 200 PHP per liter, shifts -20 to +20 PHP. Rejected: tight bounds (40-120, ±10).
- D8 (Q7): Current-price view returns price, reported_at, shifted_at and is_estimate (true when a shift applied since the anchor). Rejected: price and age only.
- D9 (Q8): Seed Misamis Oriental, Cagayan de Oro and its 80 barangays only; more areas added later as rows. Rejected: all of Misamis Oriental now.
- D10 (Q9): Public sees prices and dates, no user IDs. Users see only their own submissions and status. Admins see all. Enforced by RLS. Rejected: public submitter names.
- D11 (Q10): Drop zip_code from city. Rejected: keep nullable zip_code.
- D12 (Q11): Station has required street_address and nullable latitude/longitude numeric(9,6), CHECK-bounded to the Philippines (lat 4-22, lng 116-127). Unique on brand, barangay, street_address. Rejected: address only, no address.
- D13 (Q12): profile table with banned_at; RLS blocks submissions from banned accounts; admins set/clear it, logged. Rejected: no bans.
- D14 (Q13): Done = migrations apply on fresh local Supabase, seed loads, pgTAP passes (price math, CHECK ranges, RLS per table, daily limit, approval apply), Supabase security advisor clean. Rejected: skip advisor.
- D15: Index baselines and overrides on (station_product_id, observed_on); shifts use the FR-012 unique index on (brand_id, category_id, effective_on). History is computed from these rows, no history table. For the plan.
