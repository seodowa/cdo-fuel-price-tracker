# Contract: Data API (Supabase PostgREST over `public`)

The later SvelteKit features call these tables and the view through supabase-js. No RPC functions
exist (research R1). Field types and checks are in `data-model.md`.

## Reads

| Object | Role | Columns returned | Rows |
|---|---|---|---|
| `current_price` | anon, authenticated | `station_product_id, station_id, product_id, price, reported_at, shifted_at, is_estimate` | station products with at least one price report |
| `province`, `city`, `barangay`, `brand`, `fuel_category`, `fuel_product`, `station`, `station_product`, `price_shift` | anon, authenticated | all | all |
| `price_report` | anon, authenticated | `id, station_product_id, price, observed_on` (selecting `submitted_by` or `*` fails with 42501) | all |
| `submission` | authenticated | all | own rows; admins all |
| `profile` | authenticated | all | own row; admins all |
| `admin_log` | authenticated admin | all | all |

## Writes

| Action | Role | Call | Allowed columns |
|---|---|---|---|
| Submit station | authenticated, not banned | `insert into submission` | `kind='station', name, brand_id, barangay_id, street_address, latitude, longitude` |
| Submit price | authenticated, not banned | `insert into submission` | `kind='price', station_id, product_id, price, observed_on` |
| Submit correction | authenticated, not banned | `insert into submission` | `kind='correction', price_report_id, price, observed_on` |
| Withdraw | submitter, row pending | `update submission set status='withdrawn' where id=…` | `status` |
| Approve / reject | admin, row pending | `update submission set status='approved'` or `status='rejected'` | `status` |
| Ban / unban | admin | `update profile set banned_at = now()` or `banned_at = null` | `banned_at` |
| Manage reference data | admin | insert, update, delete on `province, city, barangay, brand, fuel_category, fuel_product` | all except `id` |
| Record shift | service_role only | `insert into price_shift` | `brand_id, category_id, amount, effective_on, source_ref, fetched_at, extractor` |

Any column outside "Allowed columns" fails with 42501. `submitted_by`, `status` on insert,
`decided_by` and `decided_at` are set by the database.

## Errors

| SQLSTATE | Meaning |
|---|---|
| 42501 | role, RLS or column grant refused the action (anonymous submit, non-admin approve, shift by user) |
| 23514 | range or shape check failed (price, shift, coordinates, text bounds, kind fields) |
| 23502 | required field missing (for example shift source fields) |
| 23505 | duplicate (station, price report per date, shift per brand/category/date, names) |
| 23503 | referenced row missing, or delete of a referenced row refused |
| P0001 | trigger refusal. Message is one of `banned`, `daily_limit`, `duplicate_station`, `brand_mismatch`, `future_date`, `not_pending`, `not_allowed` |

Clients show a plain message per code and never show raw database text (SECURITY.md 7).
