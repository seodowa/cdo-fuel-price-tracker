---
description: 'Task list for the public dashboard feature'
---

# Tasks: Public Dashboard

**Input**: `specs/002-public-dashboard/` (plan.md, spec.md, research.md, data-model.md,
contracts/dashboard.md, quickstart.md, decisions.md D1 to D19)

**Who builds**: the user, by hand (learning project). Each task is one small step. "Learn" points
at the doc section that explains it. Agents explain and review, they do not write the code.

**Tests**: required (constitution IV). Every test task comes before the build task it covers and
must fail first. Unit: `npm run test:unit -- --run`. E2E: `npm run test:e2e` (needs
`supabase start` and `.env`). Before calling a task done: `npm run check` and `npm run lint` pass.

**Security**: tasks tagged **SEC** touch secrets, contracts, an external service or the inline
script. Review them against plan.md "Security notes" and `SECURITY.md`.

**Commits**: typed title-only, for example `feat: add station ranking`, `test: add ranking tests`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: touches no file another open task touches
- Paths are relative to the repository root

---

## Phase 1: Setup

- [ ] T001 SEC Create `.env.example` with the names only: `SUPABASE_URL=` and `SUPABASE_PUBLISHABLE_KEY=`. Then create `.env` (ignored by `.gitignore`, never committed) with the values from `supabase status` (API URL `http://127.0.0.1:54321` and the publishable key). Never use the service-role key
- [ ] T002 [P] Delete the scaffold samples `src/lib/vitest-examples/` (both files) and `src/routes/page.svelte.e2e.ts`
- [ ] T003 [P] Download the latin-subset `.woff2` files into `static/fonts/`: `inter-400.woff2`, `inter-500.woff2`, `inter-600.woff2`, `montserrat-500.woff2`, `montserrat-600.woff2`, `montserrat-700.woff2`, `roboto-400.woff2`, `roboto-500.woff2`, `roboto-700.woff2`, plus the SIL `OFL.txt` (all three families are OFL 1.1). Only these weights (D13). Learn: research R13

---

## Phase 2: Foundational (blocks every story)

- [ ] T004 SEC Create `src/env.ts`: `export const variables = defineEnvVars({ SUPABASE_URL: {...}, SUPABASE_PUBLISHABLE_KEY: {...} })` from `@sveltejs/kit/env`, both private (no `public: true`), each with a `schema` function that throws when the value is empty. Run `npm run dev` once without `.env` to see the start-up error, then with it. Learn: https://svelte.dev/docs/kit/environment-variables (SvelteKit 3: `$env/*` is deprecated, research R9)
- [ ] T005 Create `src/lib/dashboard.ts` with types only, copied from `data-model.md`: the source row types (`CurrentPriceRow`, `StationRow`, `ProductRow`, `CategoryRow`, `ShiftRow`), `PriceRow` (`stationId`, `brand`, `street`, `barangay`, `product`, `category`, `cents`, `reportedAt`, `isEstimate`), `RankedRow` (`PriceRow & { rank: number }`), `Page`, and `Adjustment` as a union on `kind` (`'none' | 'no-change' | 'mixed' | 'increase' | 'rollback'`). Export them all. `npm run check` passes. Learn: TypeScript handbook "Discriminated unions"

**Checkpoint**: env and types ready.

---

## Phase 3: User Story 1 - Find where fuel is cheapest (Priority: P1) MVP

**Goal**: ranked stations per fuel, cheapest per fuel, ages, "est.", average, pagination, empty
and error states.

**Independent test**: load `supabase/fixtures/dashboard.sql`, open `/`, compare with
hand-computed values. `src/routes/dashboard.e2e.ts` passes.

### Pure functions (test first)

- [ ] T006 [US1] Write failing tests in `src/lib/dashboard.spec.ts` for `joinRows(prices, stations, products, categories)` (contract): one invented `current_price` row joins to brand, street, barangay, product and category names; `price` 62.45 becomes `cents` 6245; `is_estimate` and `reported_at` carried over; a price whose `station_id` has no station throws; same for a missing product. Import with `import { joinRows } from './dashboard.ts'`. Run, see it fail. Learn: https://vitest.dev/guide/ (describe, it, expect, toThrow)
- [ ] T007 [US1] Implement `joinRows` in `src/lib/dashboard.ts`: build `Map`s by id, map each price row, `Math.round(price * 100)` for cents (research R4), throw an `Error` on a missing lookup. T006 passes
- [ ] T008 [US1] Write failing tests for `ageLabel(reportedAt, today)` in `src/lib/dashboard.spec.ts`: same day "Reported today"; one day "Yesterday"; 12 days "12 days ago"; across a month end (`'2026-02-27'` to `'2026-03-01'` is "2 days ago"); across a year end
- [ ] T009 [US1] Implement `ageLabel` in `src/lib/dashboard.ts` with `Date.UTC` on the `YYYY-MM-DD` parts and a whole-day difference (research R7). T008 passes
- [ ] T010 [US1] Write failing tests for `rankStations(rows, category)` in `src/lib/dashboard.spec.ts` (research R5): a station with Xtra Advance 91 at 6245 and Blaze 95 at 6810 appears once at 6245 with product "Xtra Advance 91" (scenario 3); a diesel-only station is absent from the kerosene ranking; order cheapest first; equal prices order by newer `reportedAt`, then brand, then "{street}, {barangay}"; two products of one station at the same price keep the one with the smaller product name; ranks are 1, 2, 3…; no rows gives `[]`
- [ ] T011 [US1] Implement `rankStations` in `src/lib/dashboard.ts`: filter by category, keep the cheapest product per `stationId`, sort with one comparator (`localeCompare(…, 'en')` for text), add `rank`. T010 passes
- [ ] T012 [US1] Write failing tests in `src/lib/dashboard.spec.ts` for `paginate(ranked, pageParam)`: 12 rows and `null` give 10 rows, page 1, pages 2 (scenario 1); `'2'` gives 2 rows (scenario 2); `'abc'`, `'0'` and `'9'` clamp to 1, 1 and 2; `[]` gives `{ rows: [], page: 1, pages: 1 }`. For `averageCents(ranked)`: `[6245, 6085]` gives 6165; `[6245, 6246]` gives 6246 (half up); `[]` gives `null`. For `formatCents`: 6245 gives `"62.45"`, 6000 gives `"60.00"`
- [ ] T013 [US1] Implement `paginate` (page size 10, D11), `averageCents` (`Math.round(sum / count)`) and `formatCents` (`(c / 100).toFixed(2)`) in `src/lib/dashboard.ts`. T012 passes

### Load function (test first)

- [ ] T014 [US1] SEC Write failing tests in `src/routes/page.server.spec.ts` for `load` from `./+page.server.ts`. Mock `$app/env/private` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` set to invented values) and `@supabase/supabase-js` with `vi.mock`: `createClient` returns `{ from(table) }`, and `from` returns a builder object whose `select`, `eq`, `lte`, `order` and `limit` return itself and whose `then(resolve)` resolves a per-table `{ data, error }` you set in each test. Cases: (a) `current_price` returns `{ data: null, error: { code: 'X' } }`: `load` rejects and `isHttpError(e, 503)` is true with `e.body.message === "Prices couldn't load. Try again later."` (FR-014); (b) `current_price` returns 1000 rows: same 503 (research R1); (c) valid invented rows: result has `today` matching `/^\d{4}-\d{2}-\d{2}$/`, `categories` `['diesel', 'gasoline', 'kerosene']` and joined `rows`. Call `load({} as Parameters<typeof load>[0])`. Learn: https://vitest.dev/guide/mocking (vi.mock), `isHttpError` in https://svelte.dev/docs/kit/@sveltejs-kit
- [ ] T015 [US1] SEC Create `src/routes/+page.server.ts`: module-level `createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: false } })` with values from `$app/env/private`; `export const load: PageServerLoad` that computes `today` (research R3), runs wave 1 of research R1 with `Promise.all`, checks each `error` and the 1000-row cap, calls `joinRows`, and returns `{ today, categories, rows }` (category names only). Wrap in `try`, `console.error` the table and error code (never the key), call `error(503, "Prices couldn't load. Try again later.")` after the `catch` (research R11). Do not read `url` in `load` (research R2). Import `joinRows` from `#lib/dashboard.ts` and confirm with `npm run check` (research R10). T014 passes. Learn: https://svelte.dev/docs/kit/load (Page data, Errors, Rerunning load functions), https://supabase.com/docs/reference/javascript/select
- [ ] T016 [P] [US1] Create `src/routes/+error.svelte`: `<svelte:head><title>Error · CDO Fuel Price Tracker</title>`, `<h1>` with `page.error?.message` from `$app/state`, and a "Try again" link to `page.url.pathname + page.url.search` built with `resolve()` from `$app/paths` (research R10, R15). Learn: https://svelte.dev/docs/kit/errors

### E2E smoke (test first)

- [ ] T017 [P] [US1] SEC Create `supabase/fixtures/empty.sql`: `truncate public.price_shift, public.price_report, public.station_product, public.station, public.fuel_product, public.brand restart identity cascade;` (research R16). Local database only
- [ ] T018 [P] [US1] Create `supabase/fixtures/dashboard.sql` with invented data, dates relative to `(now() at time zone 'Asia/Manila')::date`, barangays and categories looked up by name from the seed: two invented brands with gasoline and diesel products (one brand also has "Xtra Advance 91" and "Blaze 95" gasoline products); 12 stations with gasoline prices so the ranking has 2 pages; one station with Xtra Advance 91 at 62.45 and Blaze 95 at 68.10 (scenario 3); one gasoline report dated today with no later shift (scenario 5); one report dated today minus 12 with a shift for that brand and category dated today minus 5 (scenario 6); diesel prices at a few stations; no kerosene prices. Each `price_shift` needs `source_ref`, `fetched_at` and `extractor` (001 contract). Run it once by hand with `psql` and check `select * from current_price`
- [ ] T019 [US1] Write failing Playwright tests in `src/routes/dashboard.e2e.ts` with `test.describe.configure({ mode: 'serial' })` and a helper that runs `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -v ON_ERROR_STOP=1 -f <file>` through `execSync` (local URL only). Tests, in order: (1) after `empty.sql`: the ranking and "Cheapest in CDO" read "No prices reported yet" (FR-013); (2) after `dashboard.sql`, no sign-in: Gasoline link has `aria-current="true"`, the ranking list (`getByRole('list', { name: 'Station ranking' })`) has 10 items, "Page 1 of 2" shows, the first price equals the hand-computed cheapest (FR-001, FR-002, FR-006); (3) the two-product station appears once with "62.45" and "Xtra Advance 91" (FR-003); (4) a row reads "Reported today" without "est.", another "12 days ago · est.", and the legend text is visible (FR-004, FR-005); (5) "City avg ₱…" equals the hand-computed average (FR-007); (6) Next shows 2 items and no Next link remains (scenario 2); (7) Diesel link re-ranks and gets `aria-current` (scenario 4); (8) the "Cheapest in CDO" region shows each fuel with brand, barangay, product, age and "est." where it applies, and kerosene reads "No prices reported yet" (FR-008); (9) with `page.route('**/_app/**', (r) => r.abort())` the ranking is in the HTML and clicking Next still reaches page 2 (FR-012, CHK013). Run `npm run test:e2e`, see them fail. Learn: https://playwright.dev/docs/locators, https://playwright.dev/docs/network#abort-requests

### UI

- [ ] T020 [US1] Start `src/routes/+page.svelte`: `let { data }: PageProps = $props()`; read `fuel` and `page` from `page.url.searchParams` (`$app/state`), fall back to `gasoline` when `fuel` is not in `data.categories`; `$derived` values for `ranked = rankStations(data.rows, fuel)`, `current = paginate(ranked, …)` and `average = averageCents(ranked)`. Add `<svelte:head><title>Dashboard · CDO Fuel Price Tracker</title>` and a visually hidden `<h1>Fuel prices in Cagayan de Oro</h1>`. Learn: https://svelte.dev/docs/svelte/$derived, https://svelte.dev/docs/kit/$app-state
- [ ] T021 [US1] In `src/routes/+page.svelte` add the ranking card: `<h2>Station ranking</h2>`; one link per category with `href={resolve('/?fuel=' + c)}`, `data-sveltekit-noscroll`, `aria-current={c === fuel ? 'true' : undefined}`, label via CSS `text-transform: capitalize`; then `<ol aria-label="Station ranking">` with one `<li>` per row: rank, brand, "{street}, {barangay} · {ageLabel(row.reportedAt, data.today)}" plus " · est." when `isEstimate`, the bar (`aria-hidden="true"`, inner width `Math.round(cents / highest * 100)%`, `--accent` for rank 1 and `--mid` for the rest), and "₱{formatCents}" with the product name beside it. Learn: research R5, R14
- [ ] T022 [US1] In `src/routes/+page.svelte` add under the list: the legend "est. = reported price plus weekly adjustments since then", the footer "City avg ₱{formatCents(average)} · bars scaled to highest price", and pagination: "‹ Prev" and "Next ›" as links (`resolve('/?fuel=' + fuel + '&page=' + n)`, `data-sveltekit-noscroll`) only when available, otherwise a `<span>` at 0.35 opacity, with "Page N of M" between. When `ranked` is empty, show "No prices reported yet" in place of the list and footer (FR-013)
- [ ] T023 [US1] In `src/routes/+page.svelte` add the "Cheapest in CDO" card as `<section aria-labelledby>` with `<h2>`: for each category, `rankStations(data.rows, c)[0]` (same comparator, CHK008); show the fuel name, "{brand} · {barangay} · {age}" plus " · est." (D16, D17), and "₱{price}" with the product name beside it in `--accent`; "No prices reported yet" when there is none
- [ ] T024 [US1] Style the Dashboard in a `<style>` block in `src/routes/+page.svelte` from the inline styles of `design_handoff_fuel_price_dashboard/design_files/Fuel Price Dashboard.dc.html` (lines 24 to 50): container `padding: 32px 40px 48px; max-width: 1280px`, grid `repeat(auto-fit, minmax(min(100%, 420px), 1fr))` gap 20px, card radius 14px with `background: var(--card)` and `box-shadow: var(--shadow)`, row grid `24px minmax(110px, 170px) minmax(60px, 1fr) 76px`, chip styles for the fuel links; `min-width: 0` and `overflow-wrap: anywhere` on text cells (CHK012). Use the tokens from `src/app.css`, never raw colours
- [ ] T025 [US1] Run `npm run test:unit -- --run`, `npm run test:e2e`, `npm run check`, `npm run lint`. All of T019 passes

**Checkpoint**: US1 works on its own (MVP). Commit.

---

## Phase 4: User Story 2 - See this week's price adjustment (Priority: P2)

**Goal**: the adjustment card per fuel.

**Independent test**: Vitest cases for scenarios 1 to 4 and the edge cases pass, and the card
matches the fixture by hand.

- [ ] T026 [US2] Write failing tests in `src/lib/dashboard.spec.ts` for `summarizeShifts(shifts)` (research R6), with invented brand ids: every brand +1.20 on `2026-10-27` gives `increase`, 120 to 120, `asOf` `'2026-10-27'` (scenario 1); -0.85 and -0.60 in one week give `rollback`, 60 to 85 (scenario 2); +0.40 and -0.30 give `mixed` (scenario 3); `[]` gives `none` (scenario 4); all 0.00 give `no-change`; 0.00 and +0.50 give `increase`, 0 to 50; a brand whose only shift is in the previous week is left out; a Sunday (`2026-11-01`) and the next Monday (`2026-11-02`) fall in different weeks; one brand with two shifts in the latest week counts as their sum (F6)
- [ ] T027 [US2] Implement `summarizeShifts` in `src/lib/dashboard.ts`: latest date, its Monday with `Date.UTC` and `getUTCDay()`, filter to that Monday..Sunday, per-brand sums in cents with a `Map`, then the kind and min/max of absolute values. T026 passes
- [ ] T028 [US2] Write failing tests for `formatAdjustment(a)` and `formatDate(d)` in `src/lib/dashboard.spec.ts`: increase 120..120 gives `{ arrow: '▲', amount: '+₱1.20', word: 'Increase' }`; rollback 60..85 gives `{ arrow: '▼', amount: '−₱0.60 – ₱0.85', word: 'Rollback' }` (U+2212 minus, U+2013 dash); mixed gives `{ arrow: '', amount: '', word: 'Mixed' }`; `no-change` gives word "No change"; `none` gives word "No adjustment recorded yet"; `formatDate('2026-10-27')` gives `'Oct 27, 2026'` (FR-010, FR-011, CHK006)
- [ ] T029 [US2] Implement `formatAdjustment` and `formatDate` (`Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })`) in `src/lib/dashboard.ts`. T028 passes
- [ ] T030 [US2] SEC Add failing cases to `src/routes/page.server.spec.ts`: with invented `price_shift` rows per category the result has `adjustments` in category order with the expected kinds; a `price_shift` error gives the same 503
- [ ] T031 [US2] SEC Extend `load` in `src/routes/+page.server.ts` with wave 2 of research R1 (one `price_shift` query per category id, `.lte('effective_on', today)`, `.limit(1000)`, same error and cap checks) and return `adjustments: { category, adjustment: summarizeShifts(…) }[]`. T030 passes
- [ ] T032 [US2] In `src/routes/+page.svelte` add the adjustment card before "Cheapest in CDO" (mock lines 29 to 36): "PRICE ADJUSTMENT", "As of {formatDate(latest asOf)}" only when some fuel has an `asOf`, "Change per litre vs. previous week", then per fuel a 42px box with the arrow (`aria-hidden="true"`), the fuel name and word, and the amount. Increase uses `--up` on `--up-bg`, rollback `--down` on `--down-bg`, the rest `--muted` on `--soft`
- [ ] T033 [US2] Run all unit tests, `npm run check`, `npm run lint`; load `supabase/fixtures/dashboard.sql` and compare the card with hand-computed values (SC-002)

**Checkpoint**: US1 and US2 work. Commit.

---

## Phase 5: User Story 3 - Any screen and any light (Priority: P2)

**Goal**: header, tabs, mobile menu, mode that follows the device and remembers the toggle, fonts,
Coming soon pages.

**Independent test**: `src/routes/shell.e2e.ts` passes. Check by eye at 1280px and 390px in both
modes.

- [ ] T034 [P] [US3] Write failing Playwright tests in `src/routes/shell.e2e.ts`: (1) at 1280px the banner shows "CDO Fuel Price Tracker", links Dashboard, Analytics, Contribute and a "Switch to … mode" button, and no "Log in" or "Sign up" text (FR-015); (2) `/analytics` and `/contribute` show "Coming soon" and their tab has `aria-current="page"` (FR-016); (3) at 390px the tabs are hidden, the "Menu" button opens a list of the three links, Escape closes it, choosing Analytics navigates and closes it (FR-017, CHK010); (4) at 390px the Dashboard cards share the same left edge (stacked, FR-017); (5) with `/_app/` aborted, `emulateMedia({ colorScheme: 'light' })` and `'dark'` give different `body` background colours (FR-018, D18); (6) under a dark device, click the toggle, reload with `/_app/` aborted: `html` has `data-theme="light"` and the body colour equals the light one from (5) (FR-019, SC-005); (7) every request during a Dashboard load goes to `localhost:4173` (FR-021, SC-006); (8) Tab from the top reaches the tabs and the toggle in order, and the toggle's accessible name changes after a click (FR-022, FR-023). Run, see them fail
- [ ] T035 [US3] Rewrite the colour tokens in `src/app.css` (your file) with `light-dark()` (D18, research R8): `:root { color-scheme: light dark; --h: 190; --bg: light-dark(oklch(0.875 0.012 var(--h)), oklch(0.19 0.02 var(--h))); … }` for every colour token, light value first; `[data-theme='light'] { color-scheme: light }`, `[data-theme='dark'] { color-scheme: dark }`; then `--shadow` and `--raised`: dark values on `:root`, light values in `@media (prefers-color-scheme: light) { :root { … } }`, then dark values on `[data-theme='dark']` and light values on `[data-theme='light']`, in that order. Values: design handoff README "Design Tokens". Learn: MDN `light-dark()`, MDN `color-scheme`
- [ ] T036 [US3] SEC Add the inline script as the first child of `<head>` in `src/app.html`: inside `try`, `const t = localStorage.getItem('theme')`; if `t === 'light' || t === 'dark'` set `document.documentElement.dataset.theme = t`. Nothing else (D18). Static text only
- [ ] T037 [US3] Add to `src/app.css`: one `@font-face` per file in `static/fonts/` (`font-display: swap`, `url('/fonts/inter-400.woff2') format('woff2')`); `body { font-family: Inter, sans-serif }`; `:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px }`; `@media (prefers-reduced-motion: reduce) { *, *::before, *::after { transition: none !important } }` (CHK017); a `.visually-hidden` utility; the toggle label rules of research R8 (`.to-light` / `.to-dark` shown by default, by `@media (prefers-color-scheme: light)`, and by `[data-theme]`). Learn: MDN `@font-face`, research R13, R14
- [ ] T038 [US3] Fill in `src/lib/components/Header.svelte` (your file, already rendered by `src/routes/+layout.svelte`): `<header>` with the logo mark (`aria-hidden="true"`) and "CDO Fuel Price Tracker"; a `{#snippet tabs()}` with three links (`resolve('/')`, `resolve('/analytics')`, `resolve('/contribute')`), `aria-current="page"` when `page.url.pathname` matches; render it in a `<nav aria-label="Main">`. Underline from the mock (line 15): `background-image: linear-gradient(var(--accent), var(--accent))`, `background-size: 0% 2px` growing to `100% 2px` on hover with `transition: background-size .28s ease, color .2s`; active tab full underline and `--ink`, others `--muted` (US3 scenario 6). Header 72px, `padding: 0 40px`, bottom border `var(--line)`. Learn: https://svelte.dev/docs/svelte/snippet
- [ ] T039 [US3] Add the mode toggle to `src/lib/components/Header.svelte`: a `<button type="button">` holding `<span class="to-light">☀<span class="visually-hidden">Switch to light mode</span></span>` and the `to-dark` twin with ☾ (glyphs `aria-hidden="true"`); `onclick` reads the current mode (`dataset.theme`, else `matchMedia('(prefers-color-scheme: dark)')`), sets the other on `document.documentElement.dataset.theme` and saves it with `localStorage.setItem('theme', …)` inside `try` (research R8). 38px square, radius 10px, border `var(--line)`
- [ ] T040 [US3] Add the mobile menu to `src/lib/components/Header.svelte`: `<button type="button" popovertarget="site-menu" aria-label="Menu">` with ☰ and ✕ (`aria-hidden`, swapped by `:has(#site-menu:popover-open)`); `<nav id="site-menu" popover aria-label="Main" bind:this={menu}>` rendering `{@render tabs()}`; `afterNavigate(() => menu?.hidePopover())`. Below 768px hide the inline nav, show the button, header 60px with `padding: 0 16px`, popover `inset: 60px 0 auto 0; margin: 0` (mock mobile lines 12 to 23). The name gets `min-width: 0` so it wraps and never pushes the button off screen. Learn: MDN "Using the Popover API", https://svelte.dev/docs/kit/$app-navigation#afterNavigate
- [ ] T041 [P] [US3] Create `src/routes/analytics/+page.svelte`: `<svelte:head><title>Analytics · CDO Fuel Price Tracker</title>`, `<h1>Analytics</h1>`, `<p>Coming soon</p>` (FR-016)
- [ ] T042 [P] [US3] Create `src/routes/contribute/+page.svelte`: same with "Contribute"
- [ ] T043 [US3] In `src/routes/+page.svelte` add `@media (max-width: 767px)`: container `padding: 20px 16px 36px`, grid gap 16px, ranking card `padding: 20px 16px`, row grid `22px minmax(0, 1fr) auto` with the bar on its own line `grid-column: 2 / 4`, height 8px (mock mobile lines 30 to 48)
- [ ] T044 [US3] Run `npm run test:e2e`, `npm run check`, `npm run lint`. All of T034 passes

**Checkpoint**: all stories work. Commit.

---

## Phase 6: Polish

- [ ] T045 Compare side by side with `Fuel Price Dashboard.dc.html` and `Fuel Price Dashboard Mobile.dc.html` (handoff Teal palette) in dark and light at 1280px and 390px. Fix spacing, type and colour differences in `src/routes/+page.svelte` and `src/lib/components/Header.svelte` (FR-020, SC-007)
- [ ] T046 By hand: Tab through every page with a visible focus ring; turn on OS "reduce motion" and confirm the underline does not animate; check "est.", legend and muted text with the DevTools contrast checker in both modes (FR-022, SC-008, CHK017, CHK018)
- [ ] T047 Run the whole `specs/002-public-dashboard/quickstart.md`, then `supabase db reset` to clear the e2e data

---

## FR to test map

| FR     | Test task (before build) | Build task             |
| ------ | ------------------------ | ---------------------- |
| FR-001 | T019 (2)                 | T015, T020             |
| FR-002 | T019 (2), (7)            | T021                   |
| FR-003 | T010, T019 (3)           | T011, T021             |
| FR-004 | T008, T019 (4)           | T009, T021             |
| FR-005 | T019 (4)                 | T022                   |
| FR-006 | T012, T019 (2), (6)      | T013, T022             |
| FR-007 | T012, T019 (5)           | T013, T021, T022       |
| FR-008 | T010, T019 (8)           | T023                   |
| FR-009 | T026                     | T027, T032             |
| FR-010 | T028                     | T029, T032             |
| FR-011 | T026, T028               | T027, T029, T032       |
| FR-012 | T019 (9)                 | T015, T020             |
| FR-013 | T019 (1), (8)            | T022, T023             |
| FR-014 | T014 (a), (b), T030      | T015, T016, T031       |
| FR-015 | T034 (1)                 | T038, T039             |
| FR-016 | T034 (2)                 | T041, T042             |
| FR-017 | T034 (3), (4)            | T040, T043             |
| FR-018 | T034 (5)                 | T035                   |
| FR-019 | T034 (6)                 | T036, T039             |
| FR-020 | by eye, T045 (D14)       | T024, T035, T037, T038 |
| FR-021 | T034 (7)                 | T003, T037             |
| FR-022 | T034 (8), T046           | T037                   |
| FR-023 | T034 (1), (8)            | T021, T032, T039, T040 |

## Dependencies

- Setup (T001 to T003) then Foundational (T004, T005), then stories.
- US1 (T006 to T025) is the MVP. US2 adds to `dashboard.ts`, `+page.server.ts` and `+page.svelte`,
  so it follows US1. US3 touches `app.css`, `app.html`, `Header.svelte` and new routes, so T034 to
  T042 can start after Foundational. T043 waits for T024.
- Inside a story: each test task before its build task, as listed.

## Parallel examples

- Setup: T002 and T003.
- US1: T016, T017 and T018 while the pure functions are in progress.
- US3: T034, T041 and T042 together. T035 to T040 touch shared files, one at a time.

## Implementation strategy

1. MVP: Phases 1 to 3. Stop and check the ranking against the fixture.
2. Add US2 (adjustment card).
3. Add US3 (shell, mode, mobile). Until then the page uses the current dark tokens and default font.
4. Polish against the mocks.
