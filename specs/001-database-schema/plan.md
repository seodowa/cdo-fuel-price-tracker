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

**Scale/Scope**: 13 objects: 12 tables and 1 view.

## Constitution Check

| Principle | Status | How |
|---|---|---|
| I. Prices derived | Pass | `current_price` computed on read (R5). Baselines, overrides and shifts are separate rows. Corrections update in place (R10). `reported_at` and `shifted_at` give price age. |
| II. External data untrusted | Pass | Shift schema, ranges and non-null source fields (`source_ref`, `fetched_at`, `extractor`) are constraints. Failed inserts change nothing. Fetcher and failed-shift review are out of scope (spec Assumptions, `OPEN-QUESTIONS.md`). |
| III. Server enforces rules | Pass | RLS on every table, deny by default (FR-021). Ranges in domains. Rate limit in a trigger. Admin actions restricted and logged. |
| IV. Test first | Pass | Every FR has a pgTAP test task before its build task (tasks.md). Playwright smoke tests belong to the screen features, since no flow is user-facing yet. |
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
   public by column grants (R4). Account deletion is blocked by `on delete restrict` until a later
   feature defines deletion (finding in the plan report).
6. Privileged code: every `private` trigger function is SECURITY DEFINER, owned by `postgres`, with
   `search_path = ''` and fully qualified names. `private` schema usage granted to `authenticated`
   only, execute only on `private.is_admin()`.
7. External service: none at runtime. `price_shift` is the landing table for a future fetcher.
8. Secrets and minors' data: none.

## Checklist answers (`checklists/security.md`)

- CHK002: R2, R3. CHK003: FR-017a, withdraw yes, edit no. CHK004: column grants (R1).
- CHK005: R4. CHK006: not defined, deletion blocked by restrict (finding).
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
    └── 08_moderation.test.sql
```

**Structure Decision**: Supabase CLI default layout. One migration per story increment so each
story installs and tests on its own.

## Complexity Tracking

None.
