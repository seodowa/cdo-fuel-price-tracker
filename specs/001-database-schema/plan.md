# Implementation Plan: Database Schema

**Branch**: `feat/database-schema` | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-database-schema/spec.md`

**Status**: Phase 0 and Phase 1 complete. Open decisions resolved as D17 to D21.

## Summary

Build the Supabase Postgres data layer: location, brand, fuel and station tables, price reports and
weekly shifts, a computed `current_price` view, a submission and approval flow, bans, and an admin
log. All rules sit in the database: domains and constraints for ranges, composite foreign keys for
brand match, RLS and column grants for access, and trigger functions in a non-exposed `private`
schema for rate limits, approval and logging (research R1). Delivered as versioned migrations, a
seed file and pgTAP tests. No SvelteKit code.

## Technical Context

**Language/Version**: SQL (PL/pgSQL) on Supabase local Postgres. Major version comes from the CLI
default in `supabase/config.toml`, 15 or later required (R15).

**Primary Dependencies**: Supabase CLI, installed system-wide and pinned in quickstart.md (D17), Docker Engine (D18), pgTAP (bundled with the Supabase
Postgres image, enabled in tests).

**Storage**: Supabase Postgres.

**Testing**: pgTAP through `supabase test db`.

**Target Platform**: Supabase (local stack for development and tests).

**Project Type**: data layer of a web app.

**Performance Goals**: none stated. One city, tens of brands, hundreds of stations.

**Constraints**: Supabase security advisor clean (SC-006). One-step install on an empty database
(SC-005).

**Scale/Scope**: 13 tables and 1 view.

## Constitution Check

| Principle | Status | How |
|---|---|---|
| I. Prices derived | Pass | `current_price` computed on read (R5). Baselines, overrides and shifts are separate rows. Corrections update in place (R10). `reported_at` and `shifted_at` give price age. |
| II. External data untrusted | Pass | Shift schema, ranges and non-null source fields (`source_ref`, `fetched_at`, `extractor`) are constraints. Failed inserts change nothing. Fetcher and failed-shift review are out of scope (spec Assumptions, `OPEN-QUESTIONS.md`). |
| III. Server enforces rules | Pass | RLS on every table, deny by default (FR-021). Ranges in domains. Rate limit in a trigger. Admin actions restricted and logged. |
| IV. Test first | Pass with justified deviations (D24) | Every FR has a pgTAP test task before its build task (tasks.md). Two deviations, listed in Complexity Tracking. |
| V. Simplest thing | Pass | No RPC layer, no history table, no custom claim. Supabase CLI approved by the user (D17). |
| Security constraints | Pass | No secrets in this feature. Service-role key unused by the code here. Test fixtures invented. |

Re-check after Phase 1 design: no new violations. Complexity Tracking is empty.

## Security notes

Every task in these areas needs review against `SECURITY.md`:

1. Access rules: RLS policies and column grants on all tables (FR-021 to FR-027). Risk: a missing
   `revoke` leaves Supabase default grants in place (R12).
2. Sign-in: `auth.users` trigger creating `profile` (R3). SECURITY DEFINER with `search_path = ''`.
3. Data model: every migration.
4. Contracts: the table and column interface the SvelteKit feature will call (`contracts/data-api.md`).
5. Personal data: `submitted_by` on `price_report` and `submission`, `profile` rows. Hidden from
   public by column grants (R4). Account deletion cascades to profile and submissions and nulls
   the identity on price reports and the admin log (R19, FR-028).
6. Privileged code: every `private` trigger function is SECURITY DEFINER, owned by `postgres`, with
   `search_path = ''` and fully qualified names. `private` schema usage granted to `authenticated`
   only, execute only on `private.is_admin()`.
7. External service: none at runtime. `price_shift` is the landing table for a future fetcher.
8. Secrets and minors' data: none.

## Checklist answers (`checklists/security.md`)

- CHK002: R2, R3. CHK003: FR-017a, withdraw yes, edit no. CHK004: column grants (R1).
- CHK005: R4. CHK006: FR-028 and R19 (D22).
- CHK007: one report per station product per date (D16), so no tie. CHK008: future shifts wait (R5).
- CHK009: computed price unchecked (spec edge case). CHK010: date.
- CHK011: approval errors and the submission stays pending (R8). CHK012: FR-017b.

## Project Structure

### Documentation (this feature)

```text
specs/001-database-schema/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── data-api.md
└── tasks.md
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                  # from supabase init
├── migrations/
│   ├── 20261029000001_schema.sql                # tables, domains, constraints, RLS on, revokes, profile trigger, admin_log, private.is_admin
│   ├── 20261029000002_public_read.sql           # public read grants and policies, current_price view
│   ├── 20261029000003_submissions.sql           # submission table, triggers, policies, profile read
│   └── 20261029000004_moderation.sql            # admin reference-data writes, ban, logging triggers
├── seed.sql                                     # Misamis Oriental, Cagayan de Oro, 80 barangays (list from user, D19), 3 categories
└── tests/
    ├── 01_schema.test.sql
    ├── 02_seed.test.sql
    ├── 03_current_price.test.sql
    ├── 04_public_read.test.sql
    ├── 05_submissions.test.sql
    ├── 06_approval.test.sql
    ├── 07_shifts.test.sql
    ├── 08_moderation.test.sql
    └── 09_account_deletion.test.sql
```

**Structure Decision**: Supabase CLI default layout. One migration per story increment so each
story installs and tests on its own.

**Rollback**: nothing is deployed, so rollback is `supabase db reset` on the local stack.

## Complexity Tracking

Deviations from constitution IV, acknowledged by the user (D24):

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| T016 (`07_shifts.test.sql`) is not required to fail first | `price_shift` is built in T005 because US1 needs it, and its FR-012, FR-013 and FR-025 tests fail first in T003. T016 only re-checks the US3 scenarios end to end | Moving `price_shift` into US3 would block US1, the MVP |
| Playwright smoke tests (view prices, submit baseline, submit override) are deferred | This feature has no screens (D2), so there is no flow to drive | Writing them now would test UI that does not exist. The screen features must add them |

## Validate

Date: 2026-10-29. Verdict: CONDITIONAL

| Check | Verdict | Findings |
|-------|---------|----------|
| 1. Setup and dependencies | CONCERN | F5 |
| 2. Test coverage per requirement | CONCERN | F1, F3, F8 |
| 3. Breaking changes | CONCERN | F6 |
| 4. Security and privacy | CONCERN | F4, F14 |

F1. tasks.md:102, contracts/data-api.md:38, research.md:66 `shift_php` is `numeric(4,2)`, so +120.00 fails with 22003 (numeric field overflow) before the range check, not 23514. Verified on local Postgres 18. -> Make the domain `numeric(5,2)` so out-of-range shifts reach the check and return 23514 as the contract says.
F3. tasks.md:41 SC-003 needs every forbidden action tested. Tests cover inserts only. Missing: update and delete on `price_report`, `station`, `station_product`, `price_shift` as `authenticated` and admin. Select on `submission` and `profile` as `anon`. Delete on `submission` as its submitter. -> Add these cases to T003, T012 and T018.
F4. plan.md:63-65, data-model.md:60 `on delete restrict` from `profile` to `auth.users` blocks account deletion. SECURITY.md section 6 requires support for deletion. -> User decision: accept the deferral and record it in OPEN-QUESTIONS.md, or define deletion now.
F5. quickstart.md:12 The installed CLI is `2.123.0-beta.15`, a beta build. Docker 29.9.2 is active and the user is in the `docker` group. No Supabase images are pulled yet, so the first `supabase start` needs network access. -> User decision: pin this beta in T001 or install a stable release first.
F6. plan.md:117 There is no rollback note for the migrations. -> Add one line: nothing is deployed, so rollback is `supabase db reset` on the local stack.
F8. tasks.md:125, quickstart.md:26 SC-006 is checked by hand in Studio. The installed CLI has `supabase db advisors`. -> Use `supabase db advisors` in T021 and quickstart so the check is scripted and repeatable.
F14. plan.md:66-68, tasks.md:44 Postgres grants EXECUTE on new functions to PUBLIC by default. No task revokes it in `private`. -> Add `revoke execute on all functions in schema private from public` in T005, then grant execute on `private.is_admin()` to `authenticated`.
