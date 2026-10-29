# Research: Database Schema

Inputs: `spec.md`, `decisions.md` (D1 to D16), constitution 1.0.0, `SECURITY.md`. No product code
exists yet. The repository has no `supabase/` directory and no `package.json`.

Open decisions were answered as D17 to D21 in `decisions.md`.

## R1. Write path: table writes with RLS, column grants and triggers

- Decision: clients write with plain table operations (PostgREST insert and update). RLS policies
  decide who may write, column-level grants decide which columns a role may set, and trigger
  functions in a non-exposed `private` schema do validation, approval, application and logging.
  No callable functions (RPC) are exposed in `public`.
- Rationale: constitution V prefers RLS and constraints over custom code. Column grants stop mass
  assignment (a user cannot set `status`, `submitted_by` or `decided_*`). SECURITY DEFINER
  functions callable through the API are flagged by the Supabase advisor, which SC-006 must keep
  clean. Trigger functions are not callable through the API.
- Alternatives: SECURITY DEFINER RPC functions per action (`submit_price`, `approve_submission`).
  Clear signatures, but adds callable privileged functions to the exposed schema.

## R2. Admin flag

- Decision: `profile.is_admin boolean not null default false`. Only the service role (SQL editor or
  server process) sets it. No grant on that column to `anon` or `authenticated`. No in-app "make
  admin" action, since no FR asks for one.
- Rationale: matches the spec assumption ("set only by an existing admin or the server process")
  with the smaller of the two paths. Answers checklist CHK002.
- Alternatives: JWT custom claim through an auth hook. More moving parts and a stale claim until
  token refresh.

## R3. Profile creation

- Decision: an AFTER INSERT trigger on `auth.users` (function `private.handle_new_user`, SECURITY
  DEFINER, `search_path = ''`) inserts the `profile` row. Users read only their own profile and
  cannot update it. Admins read all profiles and may update only `banned_at`.
- Rationale: standard Supabase pattern. The user never writes their own profile.

## R4. Public reads without submitter identity

- Decision: `price_report.submitted_by` is kept (FR-010) but hidden by column grants: `anon` and
  `authenticated` get `select` on every `price_report` column except `submitted_by`. The
  `current_price` view is `security_invoker = true` and reads only granted columns.
- Rationale: a SECURITY DEFINER view is flagged by the advisor (lint `security_definer_view`).
  Column grants keep RLS in force and hide the column for every API role.
- Alternatives: drop `submitted_by` from `price_report` and trace through `submission`. Breaks the
  FR-010 wording.

## R5. Current price derivation (FR-014, FR-015)

- Decision: view `public.current_price`, one row per station product that has at least one price
  report. Anchor = the price report with the latest `observed_on` (unique per station product, so no
  tie). Applied shifts = `price_shift` rows with the product's brand and category,
  `effective_on > anchor.observed_on` and `effective_on <= (now() at time zone 'Asia/Manila')::date`.
  Columns: `price = anchor.price + coalesce(sum(amount), 0)`, `reported_at = anchor.observed_on`,
  `shifted_at = max(effective_on)` or null, `is_estimate = shifted_at is not null`.
- Station products with no report produce no row, so a missing price is never shown as 0.
- The computed price is not range-checked (spec edge case).
- Tests use dates relative to Manila today (for example anchor = today minus 14) so the view needs
  no clock hook.

## R6. Value checks as domains

- Decision: domains in `public` hold the ranges once and are reused by live tables and
  `submission` (FR-020 needs the same checks at submission time):
  - `price_php`: `numeric(6,2)` check `value between 20 and 200`
  - `shift_php`: `numeric(4,2)` check `value between -20 and 20`
  - `latitude`: `numeric(9,6)` check `value between 4 and 22`
  - `longitude`: `numeric(9,6)` check `value between 116 and 127`
- Rationale: one definition per range (DRY) using a native Postgres feature.

## R7. Brand match for station products (FR-009)

- Decision: `station_product` carries `brand_id`. Composite foreign keys `(station_id, brand_id)`
  to `station(id, brand_id)` and `(product_id, brand_id)` to `fuel_product(id, brand_id)`. Both
  parents get `unique (id, brand_id)`.
- Rationale: a constraint, not a trigger. A mismatch cannot be stored by any role.

## R8. Approval and application

- Decision:
  - BEFORE INSERT trigger on `submission`: forces `submitted_by = auth.uid()`, refuses banned
    accounts, locks the submitter's profile row and refuses a 21st submission that Manila day for
    non-admins (FR-019), runs submission-time checks that a constraint cannot express (FR-007
    duplicate station, FR-009 brand match, `observed_on` not in the future), and for admins sets
    `status = 'approved'` (FR-017b).
  - BEFORE UPDATE trigger: only `pending` rows change. `approved`/`rejected` need an admin.
    `withdrawn` needs the submitter. Sets `decided_by` and `decided_at`.
  - AFTER INSERT and AFTER UPDATE trigger: when the row is `approved`, applies it (insert station,
    insert price report, or update the target price report in place) and writes `admin_log`.
    `rejected` writes `admin_log`. `withdrawn` writes nothing.
  - If application fails (duplicate station created meanwhile, duplicate price report date,
    missing target), the statement errors and the submission stays `pending` (answers CHK011).
- Rationale: one apply path for admin auto-approval and normal approval.

## R9. Rate limit concurrency

- Decision: the BEFORE INSERT trigger runs `select ... from profile where id = auth.uid() for
  update` before counting, so two parallel inserts by one account cannot both pass the count of 19.
- Index: `submission (submitted_by, created_at)`.

## R10. Correction contents

- Decision: a correction carries a new `price` and `observed_on` (both required, the client
  prefills the current values). Approval updates the target price report in place (constitution I).
- Rationale: a wrong date is as harmful as a wrong price, since it moves the anchor and the shifts
  applied. Two columns already exist on `submission` for the price kind.

## R11. Text bounds

- Decision: names 1 to 100 characters, `street_address` 1 to 200, `source_ref` 1 to 2048,
  `extractor` 1 to 100, all with `btrim(x) <> ''`. Uniqueness on names and street address uses
  `lower(...)` unique indexes so case variants are duplicates.
- Rationale: SECURITY.md section 3 requires length checks. The spec gives no limits, so these are
  plan choices.

## R12. Grants baseline

- Decision: each migration that creates tables runs `revoke all ... from anon, authenticated` on
  them, then grants only what the access rules need. `service_role` keeps its default access.
- Rationale: Supabase default privileges grant all on new `public` tables to `anon` and
  `authenticated`. RLS already denies, but explicit grants are defence in depth and fix the column
  rules of R4 and R1.

## R13. Admin log

- Decision: `admin_log (id, admin_id, action, target_table, target_id text, created_at)`. Actions:
  `approve`, `reject`, `ban`, `unban`, `create`, `update`, `delete`. Written only by SECURITY
  DEFINER trigger functions. Reference-data triggers log only when `auth.uid()` is not null, so
  seed and migrations do not create log rows. Admins read it. Nobody updates or deletes it through
  the API.

## R14. Tests

- Decision: pgTAP files in `supabase/tests/`, run by `supabase test db`. Each file is one
  transaction ending in `rollback` and creates its own invented fixtures (users through
  `insert into auth.users (id, email)`, invented brands, stations and barangays). Role switching:
  `set local role authenticated` plus `set_config('request.jwt.claims', '{"sub":"<uuid>","role":"authenticated"}', true)`;
  `set local role anon`; `set local role service_role`.
- Only `02_seed.test.sql` depends on seed rows.

## R15. Tooling (D17, D18)

- Decision: the user installs the Supabase CLI system-wide. Setup task T001 records the exact
  `supabase --version` output in `quickstart.md` as the pinned version. No `package.json` in this
  feature. Docker Engine runs the local stack (the user is in the `docker` group). The daemon is
  disabled today, so it is started with `sudo systemctl enable --now docker`. Podman is not used.
- The Postgres major version is the one `supabase init` writes to `supabase/config.toml`
  (`[db] major_version`). Views with `security_invoker` need 15 or later.

## R16. Seed barangay names (D19)

- Decision: the user provides the official list of the 80 Cagayan de Oro barangay names. The seed
  task waits for that list and does not draft names. `02_seed.test.sql` checks the count is 80.

## R17. Station products come from approved price submissions (D20)

- Decision: a `price` submission names `station_id` and `product_id`. At submission time the
  BEFORE INSERT trigger refuses a product of another brand (FR-009, FR-020). On approval the apply
  step inserts `station_product (station_id, product_id, brand_id)` with
  `on conflict (station_id, product_id) do nothing`, then inserts the `price_report`. The
  composite foreign keys (R7) still refuse a brand mismatch.
- A price for a station still pending approval cannot be submitted, since `station_id` must exist.

## R18. Plan extras (D21)

- Accepted: `observed_on` not after Manila today (R8), latitude and longitude both set or both
  null, text bounds (R11), case-insensitive uniqueness (R11).
