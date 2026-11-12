# Implementation Plan: Public Dashboard

**Branch**: `feat/public-dashboard` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-public-dashboard/spec.md`, grill decisions D1 to D22
in `decisions.md`, design handoff in `design_handoff_fuel_price_dashboard/`.

**Status**: Phase 0 and Phase 1 complete. Open decisions answered as D15 to D19. Inspect fixes applied (D20 to D22). `tasks.md` written.

## Summary

Build the public Dashboard and the shared app shell in SvelteKit. A server load function
(`+page.server.ts`) reads `current_price`, `station`, `fuel_product`, `fuel_category` and
`price_shift` from the 001 data layer with `@supabase/supabase-js` and the publishable key (D15).
It joins them into flat price rows and summarizes the latest week of shifts per fuel. The page
derives the ranking, "Cheapest in CDO", the city average, pagination and age labels with pure,
Vitest-tested functions in `src/lib/dashboard.ts`. The selected fuel and page live in the URL
(`?fuel=diesel&page=2`), so they work without JavaScript and need no refetch. `Header.svelte`
holds the name, tabs, mobile menu (native popover) and mode toggle. Colour tokens use CSS
`light-dark()`, so the first visit follows the device even without JavaScript. A small inline
script in `app.html` applies only a saved choice (D18). Fonts are self-hosted. No database change.

## Technical Context

**Language/Version**: TypeScript 6.0.3 (strict), Svelte 5.57.3 (runes forced on in
`vite.config.ts`), SvelteKit 3.2.0, Vite 8.3.8.

**Primary Dependencies**: `@supabase/supabase-js` 2.119.0 (runtime, approved D15). `@supabase/ssr`
waits for 003. Dev: `vitest` 4.1.12, `@playwright/test` 1.65.0, adapter-auto.

**Storage**: Supabase Postgres from 001, read only through PostgREST with the anon role
(`specs/001-database-schema/contracts/data-api.md`). Visitor mode choice in `localStorage['theme']`.

**Testing**: Vitest (`src/**/*.spec.ts`, node environment) for the pure functions and the load
function's failure path. Playwright (`**/*.e2e.ts`, runs `npm run build && npm run preview` on
port 4173) against the local Supabase stack with invented fixtures loaded by `psql` (research R16).

**Target Platform**: evergreen browsers with `light-dark()`, popover, `:has()` and OKLCH (all
Baseline 2024). Server: Node via adapter-auto.

**Project Type**: web app (SvelteKit, server-rendered).

**Performance Goals**: prices in the first HTML response (FR-012). One load makes 7 PostgREST
requests, 4 then 3 in parallel (R1).

**Constraints**: no third-party requests from the browser (FR-021). No other new dependency. No
change to `supabase/migrations`. PostgREST `max_rows = 1000` (`supabase/config.toml:18`).

**Scale/Scope**: one city, hundreds of stations, 3 fuels, tens of brands. 3 routes, layout, header,
error page.

## Constitution Check

| Principle                   | Status             | How                                                                                                                                                                                                                   |
| --------------------------- | ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I. Prices derived           | Pass               | Prices come only from the `current_price` view. Ranking rows and "Cheapest in CDO" rows show report age and "est." (FR-004, FR-008, D17). The "City avg" line shows no age (D20): it is an aggregate of the ranked prices, each shown with its own age beside it, not one station's price                                                                              |
| II. External data untrusted | Pass               | No third-party data. Fonts self-hosted (D13). Supabase URL and key from server env                                                                                                                                    |
| III. Server enforces rules  | Pass               | Read only, anon role, RLS from 001. No writes, no sign-in                                                                                                                                                             |
| IV. Test first              | Pass               | Vitest tests first for every pure function and the load failure path. Playwright smoke for "view prices" and the shell (D14). RLS unchanged, so no new pgTAP. FR-020 (visual match) is checked by eye, as D14 decided |
| V. Simplest thing           | Pass               | One dependency, approved (D15). Platform first: URL state, popover, `light-dark()`, CSS icon swap, `text-transform` for fuel labels                                                                                   |
| Security constraints        | Pass, CSP deferred | Publishable key read on the server only. Invented fixtures. CSP deferred to a hardening spec before the first deploy (D19, `OPEN-QUESTIONS.md` 2026-11-12)                                                            |

Re-check after Phase 1 design: no violation. Complexity Tracking is empty.

## Security notes

Tasks tagged **SEC** in `tasks.md` need review against `SECURITY.md`:

1. Secrets (T001, T004, T017, T021): `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are declared private in
   `src/env.ts` and read from `$app/env/private` (server only, R9). `.env` stays ignored.
   `.env.example` lists names only. The service-role key is never used. `SUPABASE_DB_URL` (local
   database URL) lives only in `.env` and is read only by the e2e helper (D21).
2. External service (T016, T017, T032, T033): the Supabase client is created in `+page.server.ts` with
   `auth: { persistSession: false }`. No session, so one shared server client cannot leak a user.
   Production URL must be HTTPS. Failures are logged on the server without the key and shown as
   the fixed FR-014 message, never raw database text (SECURITY.md 7, 8).
3. Contracts (T016, T017, T032, T033): tests assert the exact columns, tables and filters; only the columns in `contracts/dashboard.md`. Never `price_report`,
   `submission`, `profile`, `admin_log`.
4. Inline script (T039, tested by T037 (8)): static text in `app.html`. Reads `localStorage.theme`, accepts only `light`
   or `dark`. No user data reaches HTML. CSP deferred (D19).
5. Personal data: none read or stored. `localStorage` holds only `light` or `dark`.
6. Fixtures (T019, T020, T021): `supabase/fixtures/*.sql` truncate tables. The e2e helper reads
   `SUPABASE_DB_URL` from `.env` and refuses any host other than `127.0.0.1` (D21). No password in
   code (SECURITY.md 2).
7. Access rules, sign-in, data model, minors' data: not touched.

## Checklist answers (`checklists/ux.md`)

| Item   | Answer                                                                                                          |
| ------ | --------------------------------------------------------------------------------------------------------------- |
| CHK001 | Breakpoint 768px for header and row layout. Cards stack through the mock grid (R12)                             |
| CHK002 | `<h1>` with the tab name and "Coming soon". Header tabs are the way back (R15)                                  |
| CHK003 | Ranking: "street address, barangay". Cheapest: "Brand · Barangay" (D16, R5)                                     |
| CHK004 | `<title>` per page (R15)                                                                                        |
| CHK005 | Average in integer centavos, rounded half up (R4)                                                               |
| CHK006 | Fixed `en-US` short month, "Oct 27, 2026", in every locale (R6)                                                 |
| CHK007 | Playwright blocks the app JS, reloads, checks `html[data-theme]` and the body colour (R8)                       |
| CHK008 | One comparator serves the ranking and "Cheapest in CDO" (R5)                                                    |
| CHK009 | Shift summary returns `no-change`, Vitest case (R6)                                                             |
| CHK010 | Native popover: open, Escape, outside click, close on tab choice, focus return (R12)                            |
| CHK011 | Ages use the Manila date at load time. A page left open past midnight keeps its labels until reload (R7)        |
| CHK012 | Text wraps (`overflow-wrap: anywhere`, `min-width: 0`) (R14)                                                    |
| CHK013 | Fuel and page are links and work without JS. Mode follows the device without JS (D18). The toggle needs JS (R8) |
| CHK014 | Error page shows the FR-014 message and a "Try again" link. Header stays (R15)                                  |
| CHK015 | Bars `aria-hidden`. Price text and "bars scaled to highest price" carry the same information (R14)              |
| CHK016 | Fuel link `aria-current="true"`, active tab `aria-current="page"` (R14)                                         |
| CHK017 | `prefers-reduced-motion: reduce` turns off transitions (R14)                                                    |
| CHK018 | Every text token pair computed at 4.89:1 or higher in both modes (R14)                                          |

## Project Structure

### Documentation (this feature)

```text
specs/002-public-dashboard/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── dashboard.md
├── decisions.md
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
.env.example                         # names only: SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, SUPABASE_DB_URL
src/
├── app.html                         # inline script: apply saved theme (D18)
├── app.css                          # @font-face and body font done; tokens to rewrite with light-dark() (D18); focus, reduced motion
├── env.ts                           # defineEnvVars (Kit 3, R9)
├── lib/
│   ├── components/Header.svelte     # exists (user's file, a749934): logo, tabs, underline done; toggle and mobile menu to add
│   ├── dashboard.ts                 # types and pure functions (incl. pickFuel)
│   └── dashboard.spec.ts            # Vitest, written first
└── routes/
    ├── +layout.svelte               # exists: imports app.css, renders <Header />
    ├── +error.svelte                # FR-014
    ├── +page.server.ts              # load
    ├── page.server.spec.ts          # Vitest, load failure path (FR-014)
    ├── +page.svelte                 # Dashboard cards
    ├── analytics/+page.svelte       # exists, empty: Coming soon
    ├── contribute/+page.svelte      # exists, empty: Coming soon
    ├── dashboard.e2e.ts             # Playwright: US1
    └── shell.e2e.ts                 # Playwright: US3
static/fonts/                        # done: inter-v20-latin/, montserrat-v31-latin/, roboto-v51-latin/, each with 3 .woff2 + OFL.txt
supabase/fixtures/
├── empty.sql
└── dashboard.sql
```

Removed: `src/routes/page.svelte.e2e.ts` and `src/lib/vitest-examples/` (scaffold samples).

**Structure Decision**: SvelteKit default layout. Pure logic in one `src/lib/dashboard.ts` so it is
tested without a browser or database. The header is one component because the user created it.
The three cards stay in `+page.svelte` because nothing else uses them.

**Rollback**: nothing is deployed. Revert the commits. No migration.

## Complexity Tracking

Empty.

## Validate

Date: 2026-11-12. Verdict: CONDITIONAL

| Check                     | Verdict | Findings   |
| ------------------------- | ------- | ---------- |
| 1. Setup and dependencies | PASS    | none       |
| 2. Test coverage          | CONCERN | F1, F3, F6 |
| 3. Breaking changes       | PASS    | none       |
| 4. Security and privacy   | CONCERN | F2         |

Check 1: `@supabase/supabase-js` 2.119.0, Node 24.15.0 (`process.loadEnvFile` present), Supabase
CLI 2.122.0, `psql` 18.6, Docker 29.9.3, Playwright Chromium installed, `defineEnvVars` in Kit.
Local stack runs. `.env` and `.env.example` are missing, covered by T001. Check 3: no schema
change. The scaffold files T002 deletes have no callers. Earlier F1, F2, F10, F11 and F13 are
resolved (T014/T015 and T037 (8), recorded mock calls in T016/T032, T006 and T016 (d), D21, D22).

F1. tasks.md:83 (T020) `w` (last week's Monday) falls on `today - 12` on Saturdays and `today - 13` on Sundays (Manila). The 001 view applies only shifts with `effective_on > observed_on`, so the brand A gasoline shift does not apply to the 12-day report and T021 (4) "12 days ago · est." fails every weekend (checked in psql) -> st-plan: set `w = date_trunc('week', today)::date` (this week's Monday, always `>= today - 6`) and put both brands' shifts on `w`, or date that report at `w - 1` and assert its computed age. Update T034 "As of" and R16 to match. Different dates in one week stay covered by T028.
F2. tasks.md:84 (T021), research.md:254 The e2e helper builds the `psql` command by string concatenation (`execSync('psql "' + url + '" …')`). SECURITY.md:39 forbids shell commands built by concatenation -> st-plan: `execFileSync('psql', [url, '-v', 'ON_ERROR_STOP=1', '-f', file])`.
F3. tasks.md:76 (T016 (a)) `today` is only checked against `/^\d{4}-\d{2}-\d{2}$/`. A UTC date passes, yet would shift every age label and the shift filter by one day from 00:00 to 08:00 Manila -> st-plan: add a case with `vi.useFakeTimers()` and `vi.setSystemTime(new Date('2026-11-11T17:00:00Z'))` expecting `today` `'2026-11-12'`.
F6. tasks.md:89 (T023) Bar width `Math.round(cents / highest * 100)` (FR-007) has no test. T021 (5) checks only the average -> st-plan: assert in T021 that the most expensive ranked row's bar is 100% wide, or move the formula into `dashboard.ts` with a Vitest case.
