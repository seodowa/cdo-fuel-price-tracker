# Data Model: Database Schema

All tables live in `public` with RLS enabled. Every id is `bigint generated always as identity`
unless noted. Every foreign key is `on delete restrict` (FR-004) except the account-deletion
keys listed in research R19 (D22). Domains are defined in
`research.md` R6. Text bounds follow R11.

## Location

| Table | Fields | Constraints |
|---|---|---|
| `province` | `id`, `name text not null` | unique `lower(name)` |
| `city` | `id`, `province_id → province`, `name text not null` | unique `(province_id, lower(name))` |
| `barangay` | `id`, `city_id → city`, `name text not null` | unique `(city_id, lower(name))` |

## Fuel reference data

| Table | Fields | Constraints |
|---|---|---|
| `brand` | `id`, `name text not null` | unique `lower(name)` |
| `fuel_category` | `id`, `name text not null` | unique `lower(name)`. Seed: diesel, gasoline, kerosene |
| `fuel_product` | `id`, `brand_id → brand`, `category_id → fuel_category`, `name text not null` | unique `(brand_id, lower(name))`, unique `(id, brand_id)` |

## Stations

| Table | Fields | Constraints |
|---|---|---|
| `station` | `id`, `brand_id → brand`, `barangay_id → barangay`, `name text not null`, `street_address text not null`, `latitude latitude null`, `longitude longitude null` | unique `(brand_id, barangay_id, lower(street_address))` (FR-007), unique `(id, brand_id)`, check `(latitude is null) = (longitude is null)` |
| `station_product` | `id`, `station_id`, `product_id`, `brand_id` | unique `(station_id, product_id)`, FK `(station_id, brand_id) → station(id, brand_id)`, FK `(product_id, brand_id) → fuel_product(id, brand_id)` (FR-009) |

No city or province column on `station` (FR-006).

The lat/lng pair check is a plan addition accepted as D21.

## Prices

| Table | Fields | Constraints |
|---|---|---|
| `price_report` | `id`, `station_product_id → station_product`, `price price_php not null`, `observed_on date not null`, `submitted_by uuid null → profile on delete set null` | unique `(station_product_id, observed_on)` (FR-010, D15, D16). Null only after the submitter's account is deleted |
| `price_shift` | `id`, `brand_id → brand`, `category_id → fuel_category`, `amount shift_php not null`, `effective_on date not null`, `source_ref text not null`, `fetched_at timestamptz not null`, `extractor text not null` | unique `(brand_id, category_id, effective_on)` (FR-012) |

The first report of a station product is its baseline. Later reports are overrides. The report
with the latest `observed_on` is the anchor.

### View `current_price` (`security_invoker = true`)

| Column | Meaning |
|---|---|
| `station_product_id`, `station_id`, `product_id` | identity |
| `price` | anchor price + sum of applied shifts |
| `reported_at` | anchor `observed_on` |
| `shifted_at` | latest applied `effective_on`, or null |
| `is_estimate` | `shifted_at is not null` |

Derivation rule: `research.md` R5. No submitter column.

## Accounts and moderation

| Table | Fields | Constraints |
|---|---|---|
| `profile` | `id uuid` PK `→ auth.users(id) on delete cascade`, `is_admin boolean not null default false`, `banned_at timestamptz null`, `created_at timestamptz not null default now()` | row created by trigger on `auth.users` (R3) |
| `admin_log` | `id`, `admin_id uuid null → profile on delete set null`, `action text not null`, `target_table text not null`, `target_id text not null`, `created_at timestamptz not null default now()` | check `action in ('approve','reject','ban','unban','create','update','delete')` |

### `submission`

| Field | Type | Set by |
|---|---|---|
| `id` | bigint identity | database |
| `submitted_by` | `uuid not null → profile on delete cascade`, default `auth.uid()` | trigger forces `auth.uid()` |
| `kind` | `text not null` check `in ('station','price','correction')` | client |
| `status` | `text not null default 'pending'` check `in ('pending','approved','rejected','withdrawn')` | trigger, then status update |
| `created_at` | `timestamptz not null default now()` | database |
| `decided_by` | `uuid null → profile on delete set null` | trigger |
| `decided_at` | `timestamptz null` | trigger |
| `name`, `brand_id → brand`, `barangay_id → barangay`, `street_address`, `latitude latitude`, `longitude longitude` | station kind | client |
| `price price_php`, `observed_on date` | price and correction kinds | client |
| `station_id → station`, `product_id → fuel_product` | price kind | client |
| `price_report_id → price_report` | correction kind | client |

Checks:
- Per kind, exactly the kind's fields are non-null (one `check` per kind). Station kind:
  `name`, `brand_id`, `barangay_id`, `street_address` set, coordinates optional. Price kind:
  `station_id`, `product_id`, `price`, `observed_on`. Correction kind: `price_report_id`, `price`,
  `observed_on`.
- `(status = 'pending') = (decided_at is null)`.
- `decided_by is null or status in ('approved','rejected')`. The trigger always sets `decided_by` on
  approve and reject. The check allows null because deleting the admin's account sets it null (D22).

Index: `(submitted_by, created_at)` for the daily limit.

### Submission state transitions

```text
insert (non-admin) -> pending
insert (admin)     -> approved (applied and logged at once)
pending -> approved   admin only, applies, logs 'approve'
pending -> rejected   admin only, logs 'reject'
pending -> withdrawn  submitter only
approved, rejected, withdrawn -> (no change allowed)
```

### Application on approval

| Kind | Effect |
|---|---|
| `station` | insert `station` from the submission fields |
| `price` | insert `station_product` if missing (R17), then insert `price_report` (`submitted_by` copied) |
| `correction` | update target `price_report` `price` and `observed_on` in place |

## Access summary

| Table | anon | authenticated | admin (authenticated + `is_admin`) | service_role |
|---|---|---|---|---|
| location, brand, category, product | read | read | read, insert, update, delete (logged) | all |
| `station`, `station_product` | read | read | read | all |
| `price_report` | read without `submitted_by` | same | same | all |
| `price_shift` | read | read | read | all (only writer, FR-025) |
| `current_price` | read | read | read | read |
| `submission` | none | read own, insert (not banned), withdraw own pending | read all, approve, reject | all |
| `profile` | none | read own | read all, update `banned_at` (logged) | all |
| `admin_log` | none | none | read | all |
