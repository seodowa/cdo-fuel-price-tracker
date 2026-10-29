---
description: "Task list for the database schema feature"
---

# Tasks: Database Schema

**Input**: `specs/001-database-schema/` (plan.md, spec.md, research.md, data-model.md, contracts/data-api.md, quickstart.md)

**Tests**: required (constitution IV). Every test task comes before the build task it covers and must fail before that build exists. Run tests with `supabase test db`.

**Security**: tasks tagged **SEC** touch access rules, sign-in, the data model, contracts or personal data. Review them against plan.md "Security notes" and `SECURITY.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: touches no file another open task touches
- All paths are relative to the repository root

---

## Phase 1: Setup

- [ ] T001 Confirm `docker info` works (start with `sudo systemctl enable --now docker`, D18) and `supabase --version` works (D17). Write the exact version into the "Pinned version" line of `specs/001-database-schema/quickstart.md`
- [ ] T002 Run `supabase init` to create `supabase/config.toml` (and the CLI's own `supabase/.gitignore`). Confirm `[db] major_version` in `supabase/config.toml` is 15 or later. No `package.json` (D17)

---

## Phase 2: Foundational (blocks every story)

**Purpose**: all tables, domains, constraints, RLS enabled with no policies, explicit revokes, profile creation, `private.is_admin()`, seed.

- [ ] T003 [P] SEC Write failing pgTAP tests in `supabase/tests/01_schema.test.sql` (begin, `plan(n)`, invented fixtures, rollback) for:
  - FR-001/FR-002: province, city, barangay exist with parents; unique `lower(name)` for province, `(province_id, lower(name))` for city, `(city_id, lower(name))` for barangay; "Poblacion" allowed in two cities, refused twice in one city, also refused as "poblacion" (D21)
  - FR-003: brand unique `lower(name)`; fuel_category unique `lower(name)`; fuel_product unique `(brand_id, lower(name))`
  - FR-004: deleting a referenced province, city, barangay, brand, category or product raises 23503 (`on delete restrict`)
  - FR-006/FR-007: station requires `name`, `brand_id`, `barangay_id`, `street_address`; has no city or province column (`hasnt_column`); unique `(brand_id, barangay_id, lower(street_address))`
  - FR-008: `latitude` domain "`numeric(9,6)` check `value between 4 and 22`", `longitude` domain "`numeric(9,6)` check `value between 116 and 127`"; null pair allowed; one coordinate without the other refused (D21)
  - FR-009: station_product with a product of another brand raises 23503 (composite FKs `(station_id, brand_id)`, `(product_id, brand_id)`)
  - FR-010/FR-011: price_report unique `(station_product_id, observed_on)`; `price_php` "`numeric(6,2)` check `value between 20 and 200`": 6.50 and 650.00 refused, 20.00 and 200.00 accepted
  - FR-012/FR-013: price_shift unique `(brand_id, category_id, effective_on)`; `source_ref`, `fetched_at`, `extractor` not null; `shift_php` "`numeric(4,2)` check `value between -20 and 20`": 120.00 refused
  - Text bounds (D21, R11): names 1 to 100, `street_address` 1 to 200, `source_ref` 1 to 2048, `extractor` 1 to 100, blank (`btrim(x) = ''`) refused
  - FR-021: every table in `public` has `relrowsecurity = true`; as `anon` and `authenticated`, insert into `price_shift`, `price_report`, `station`, `station_product`, `profile`, `admin_log` raises 42501 (FR-025 deny part)
  - R3: inserting an invented `auth.users (id, email)` creates a `profile` row with `is_admin = false`, `banned_at` null
- [ ] T004 [P] Write failing pgTAP tests in `supabase/tests/02_seed.test.sql` for FR-005: province "Misamis Oriental" exists; city "Cagayan de Oro" belongs to it; exactly 80 barangays belong to Cagayan de Oro; `fuel_category` names are exactly diesel, gasoline, kerosene
- [ ] T005 SEC Build `supabase/migrations/20261029000001_schema.sql` per `specs/001-database-schema/data-model.md` and research R2, R3, R6, R7, R11, R12, R13: domains `price_php`, `shift_php`, `latitude`, `longitude`; tables `province`, `city`, `barangay`, `brand`, `fuel_category`, `fuel_product`, `station`, `station_product`, `price_report`, `price_shift`, `profile`, `admin_log` with every FK `on delete restrict`; `alter table ... enable row level security` on each; `revoke all on <each table> from anon, authenticated`; schema `private` (`revoke all from public`, `grant usage to authenticated`); `private.is_admin()` (SECURITY DEFINER, stable, `set search_path = ''`, execute granted to `authenticated` only); `private.handle_new_user()` trigger after insert on `auth.users`. Makes T003 pass
- [ ] T006 Build `supabase/seed.sql`: province Misamis Oriental, city Cagayan de Oro, categories diesel, gasoline, kerosene, and the 80 barangays. **Blocked until the user provides the official list of 80 names (D19). Do not draft or guess names.** Makes T004 pass
- [ ] T007 Run `supabase db reset` then `supabase test db`. `supabase/tests/01_schema.test.sql` and `supabase/tests/02_seed.test.sql` pass

**Checkpoint**: schema installs on an empty database in one step (SC-005).

---

## Phase 3: User Story 1 - Read current prices (P1) MVP

**Goal**: anyone reads computed prices with `reported_at`, `shifted_at`, `is_estimate`, and no submitter identity.

**Independent Test**: as `postgres`, insert invented brands, stations, station products, price reports and shifts dated relative to Manila today (R5), then read `current_price` as `anon`.

- [ ] T008 [P] [US1] Write failing pgTAP tests in `supabase/tests/03_current_price.test.sql` for FR-014/FR-015: scenario 1 (60.00 at today-14, +1.20 at today-8, -0.50 at today-1 gives 60.70, `reported_at` today-14, `shifted_at` today-1, `is_estimate` true); scenario 2 (later report 61.00 then +0.30 gives 61.30, older shifts ignored); scenario 3 (no shift: price equals report, `shifted_at` null, `is_estimate` false); scenario 4 (two gasoline products of one brand move together); scenario 5 (brand A shift leaves brand B unchanged); edge cases: no report gives no row, shift on the anchor date not applied, shift dated tomorrow not applied, computed price above 200 returned unchecked
- [ ] T009 [P] [US1] SEC Write failing pgTAP tests in `supabase/tests/04_public_read.test.sql` for FR-022: as `anon` and as `authenticated`, select succeeds on `province`, `city`, `barangay`, `brand`, `fuel_category`, `fuel_product`, `station`, `station_product`, `price_shift`, `current_price`, and on `price_report (id, station_product_id, price, observed_on)`; `select submitted_by from price_report` raises 42501; `current_price` columns are exactly `station_product_id, station_id, product_id, price, reported_at, shifted_at, is_estimate` (`columns_are`)
- [ ] T010 [US1] SEC Build `supabase/migrations/20261029000002_public_read.sql`: `grant select` and `create policy ... for select to anon, authenticated using (true)` on the nine public tables; on `price_report` grant select on `(id, station_product_id, price, observed_on)` only plus the same select policy; `create view public.current_price with (security_invoker = true)` per research R5 with `grant select` to `anon, authenticated`. Makes T008 and T009 pass
- [ ] T011 [US1] Run `supabase test db`; `supabase/tests/03_current_price.test.sql` and `supabase/tests/04_public_read.test.sql` pass, earlier files still pass

**Checkpoint**: US1 works with prices loaded by `postgres`.

---

## Phase 4: User Story 2 - Submit price data for approval (P1)

**Goal**: signed-in users submit stations, prices and corrections; admins approve or reject; approval applies.

**Independent Test**: invented users and an invented admin (`is_admin` set as `postgres`) submit, withdraw, approve and reject, then check live rows and `current_price`.

- [ ] T012 [P] [US2] SEC Write failing pgTAP tests in `supabase/tests/05_submissions.test.sql`:
  - FR-016: authenticated user inserts each kind; row has `status = 'pending'` and `submitted_by = auth.uid()`; setting `status`, `submitted_by`, `decided_by` or `decided_at` in the insert raises 42501
  - FR-017: pending, rejected and withdrawn submissions leave `station`, `price_report`, `station_product` and `current_price` unchanged (scenario 1)
  - FR-017a: submitter sets own pending row to `withdrawn`; updating any other column raises 42501; another user cannot withdraw it; a withdrawn row cannot change again (`not_pending`)
  - FR-019: 20 submissions in the Manila day succeed, the 21st raises P0001 `daily_limit`; pending, approved, rejected and withdrawn all count; a submission created yesterday Manila time does not count
  - FR-020: kind fields per `data-model.md` ("Per kind, exactly the kind's fields are non-null") else 23514; price 6.50 or 650.00 raises 23514 (scenario 7); missing brand or barangay raises 23503 (scenario 8); product of another brand raises P0001 `brand_mismatch`; station duplicating a live one by brand, barangay and `lower(street_address)` raises P0001 `duplicate_station`; `observed_on` after Manila today raises P0001 `future_date` (D21)
  - FR-023: user A sees only own submissions with status, never user B's (scenario 9); user reads own `profile` only
  - FR-026 (submit side): a user with `banned_at` set (by `postgres`) is refused
  - Scenario 6: `anon` insert into `submission` raises 42501
- [ ] T013 [P] [US2] SEC Write failing pgTAP tests in `supabase/tests/06_approval.test.sql`:
  - FR-018: admin approves a station submission and the station exists; approves a price submission and `station_product` (created if missing, D20) and `price_report` exist with `submitted_by` copied, `current_price` reflects it (scenario 2); approves a correction and the target `price_report` holds the new `price` and `observed_on` with the same id and no new row (scenario 3)
  - Rejection leaves live rows and prices unchanged (scenario 4)
  - Approval failure keeps the row pending: station duplicated meanwhile, price report for an existing `(station_product_id, observed_on)`
  - FR-017b: an admin's own submission is stored as `approved`, applied at once, logged as `approve`, and not counted (admin makes 21 submissions without `daily_limit`)
  - FR-024: non-admin setting `approved` or `rejected` raises P0001 `not_allowed`; admin reads all submissions; changing an approved or rejected row raises `not_pending`; `decided_by` and `decided_at` set on decision
  - FR-027 (approval side): approve and reject each write one `admin_log` row with `admin_id`, `action`, `target_table = 'submission'`, `target_id`, `created_at`
- [ ] T014 [US2] SEC Build `supabase/migrations/20261029000003_submissions.sql` per `specs/001-database-schema/data-model.md` "submission" and research R8, R9, R10, R17: table `submission` with checks `kind in ('station','price','correction')`, `status in ('pending','approved','rejected','withdrawn')`, one per-kind field check, `(status = 'pending') = (decided_at is null)`, `(status in ('approved','rejected')) = (decided_by is not null)`; index `(submitted_by, created_at)`; RLS enabled; `revoke all from anon, authenticated`; grants `select`, `insert (kind, name, brand_id, barangay_id, street_address, latitude, longitude, station_id, product_id, price_report_id, price, observed_on)`, `update (status)` to `authenticated`; policies: select own or `(select private.is_admin())`, insert with check `submitted_by = (select auth.uid())` and not banned, update own pending or admin; SECURITY DEFINER trigger functions in `private` with `set search_path = ''`: BEFORE INSERT (force submitter, ban check, profile row `for update`, daily limit, brand match, duplicate station, future date, admin auto-approve), BEFORE UPDATE (transitions, decided fields), AFTER INSERT OR UPDATE (apply on approved, log approve and reject); `profile` select policy own or admin with `grant select on profile to authenticated`. Makes T012 and T013 pass
- [ ] T015 [US2] Run `supabase test db`; `supabase/tests/05_submissions.test.sql` and `supabase/tests/06_approval.test.sql` pass, earlier files still pass

**Checkpoint**: US1 and US2 work together. Prices flow from submission to `current_price`.

---

## Phase 5: User Story 3 - Record weekly shifts (P2)

**Goal**: only the server process records shifts. Invalid shifts change no price.

**Note**: `price_shift` and its checks are built in T005 because US1 needs them. FR-012, FR-013 and the deny part of FR-025 are tested first in T003. This phase adds end-to-end checks of the acceptance scenarios. It has no build task. If a check fails, fix `supabase/migrations/20261029000001_schema.sql` (not yet released) and record why.

- [ ] T016 [US3] SEC Write pgTAP tests in `supabase/tests/07_shifts.test.sql` for FR-025 and US3 scenarios 1 to 5: as `service_role`, a +1.20 shift with `source_ref`, `fetched_at`, `extractor` is stored and moves every product of that brand and category in `current_price`; +120.00 raises 23514 and `current_price` is unchanged; missing source fields raise 23502; a duplicate brand, category and date raises 23505; as `authenticated` user and as admin, insert raises 42501
- [ ] T017 [US3] Run `supabase test db`; `supabase/tests/07_shifts.test.sql` passes, earlier files still pass

---

## Phase 6: User Story 4 - Moderate accounts and reference data (P3)

**Goal**: admins manage reference data and bans, every admin action logged.

**Independent Test**: invented admin and users add reference data, ban and unban, then read `admin_log`.

- [ ] T018 [US4] SEC Write failing pgTAP tests in `supabase/tests/08_moderation.test.sql`:
  - FR-024: admin inserts, updates and deletes rows in `province`, `city`, `barangay`, `brand`, `fuel_category`, `fuel_product`; regular user gets 42501 or zero affected rows for each (scenario 3)
  - FR-026: admin sets `banned_at`, the user's next submission is refused (scenario 1); admin clears it, the user submits again (scenario 2); regular user cannot update any `profile`, admin cannot update `is_admin` (42501)
  - FR-027: ban, unban, and each reference-data create, update and delete write one `admin_log` row with `admin_id`, `action`, `target_table`, `target_id`, `created_at`; changes made as `postgres` (no `auth.uid()`) write none; regular user and `anon` cannot read `admin_log`; admin can; nobody can update or delete `admin_log` through `authenticated`
  - FR-004 scenario 5: admin deleting a brand with stations raises 23503
- [ ] T019 [US4] SEC Build `supabase/migrations/20261029000004_moderation.sql`: `grant insert, update, delete` on the six reference tables to `authenticated` with admin-only policies using `(select private.is_admin())`; `grant update (banned_at) on profile to authenticated` with an admin-only update policy; `grant select on admin_log to authenticated` with an admin-only select policy; SECURITY DEFINER logging triggers in `private` with `set search_path = ''` (reference data `create`/`update`/`delete` only when `auth.uid()` is not null; `ban`/`unban` on `banned_at` change). Makes T018 pass
- [ ] T020 [US4] Run `supabase test db`; `supabase/tests/08_moderation.test.sql` passes, earlier files still pass

---

## Phase 7: Polish

- [ ] T021 SEC Follow `specs/001-database-schema/quickstart.md` end to end on a fresh `supabase db reset`: all tests pass, `supabase db lint` clean, Security Advisor clean (SC-006). Fix findings in the matching file under `supabase/migrations/` and note any accepted advisor item with its reason in `specs/001-database-schema/research.md`

---

## Dependencies and execution order

- Phase 1, then Phase 2, then stories in order US1, US2, US3, US4. Each migration builds on the previous one.
- T006 is blocked on the user's barangay list (D19). T005 and later tasks do not wait for it, but T007 needs it to pass `02_seed`.
- US2 depends on US1 (approval is checked through `current_price`). US3 depends on US1. US4 depends on US2 (ban effect on submissions, approval logging pattern).
- Within each story: test tasks, then the build task, then the run task.

## Parallel opportunities

- T003 with T004
- T008 with T009
- T012 with T013

## Implementation strategy

1. MVP: Phases 1 to 3 (schema, seed, `current_price`). Prices load only as `postgres`.
2. Add US2 for crowdsourced input. Add US3 checks. Add US4 moderation.
3. Close with T021.

## Summary

21 tasks: Setup 2, Foundational 5, US1 4, US2 4, US3 2, US4 3, Polish 1.
