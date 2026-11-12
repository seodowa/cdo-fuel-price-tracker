---
description: "Task list for the public dashboard feature"
---

# Tasks: Public Dashboard

**Input**: `specs/002-public-dashboard/` (plan.md, spec.md, research.md, data-model.md,
contracts/dashboard.md, quickstart.md, decisions.md D1 to D22)

**Who builds**: the user, by hand (learning project). Each task is one small step. "Learn" points
at the doc section that explains it. Agents explain and review, they do not write the code.

**Tests**: required (constitution IV). Every test task comes before the build task it covers and
must fail first. Unit: `npm run test:unit -- --run`. E2E: `npm run test:e2e` (needs
`supabase start` and `.env`). Before calling a task done: `npm run check` and `npm run lint` pass.

**Security**: tasks tagged **SEC** touch secrets, contracts, an external service, fixtures that
write to the database, or the inline script. Review them against plan.md "Security notes" and
`SECURITY.md`.

**Built ahead**: the user built the header (logo, tabs, active state, underline, desktop sizes),
the font files and the `@font-face` rules before the tests in commit `a749934`. Those items are
marked done below. Their tests (T037) are still written. They pass for the parts already built and
must fail for the parts not built yet (mode toggle, mobile menu, Coming soon text). The hover
underline is checked by eye (T048).

**Commits**: typed title-only, for example `feat: add station ranking`, `test: add ranking tests`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: touches no file another open task touches
- Paths are relative to the repository root

---

## Phase 1: Setup

- [ ] T001 SEC Create `.env.example` with the names only: `SUPABASE_URL=`, `SUPABASE_PUBLISHABLE_KEY=` and `SUPABASE_DB_URL=`. Then create `.env` (ignored by `.gitignore`, never committed) with the values from `supabase status`: API URL, publishable key, and DB URL (local database, used only by the e2e fixtures, D21). Never use the service-role key
- [ ] T002 [P] Delete the scaffold samples `src/lib/vitest-examples/` (both files) and `src/routes/page.svelte.e2e.ts`
- [x] T003 [P] Self-hosted fonts in `static/fonts/` (D13): `inter-v20-latin/inter-v20-latin-{regular,500,600}.woff2`, `montserrat-v31-latin/montserrat-v31-latin-{500,600,700}.woff2`, `roboto-v51-latin/roboto-v51-latin-{regular,500,700}.woff2`, with an `OFL.txt` in each folder. The 9 `@font-face` blocks and `body { font-family: 'Inter', sans-serif }` are in `src/app.css`

---

## Phase 2: Foundational (blocks every story)

- [ ] T004 SEC Create `src/env.ts`: `export const variables = defineEnvVars({ SUPABASE_URL: {...}, SUPABASE_PUBLISHABLE_KEY: {...} })` from `@sveltejs/kit/env`, both private (no `public: true`), each with a `schema` function that throws when the value is empty. `SUPABASE_DB_URL` is not declared here: the app never uses it, only the e2e helper does. Run `npm run dev` once without `.env` to see the start-up error, then with it. Learn: https://svelte.dev/docs/kit/environment-variables (SvelteKit 3: `$env/*` is deprecated, research R9)
- [ ] T005 Create `src/lib/dashboard.ts` with types only, copied from `data-model.md`: the source row types (`CurrentPriceRow`, `StationRow`, `ProductRow`, `CategoryRow`, `ShiftRow`), `PriceRow` (`stationId`, `brand`, `street`, `barangay`, `product`, `category`, `cents`, `reportedAt`, `isEstimate`), `RankedRow` (`PriceRow & { rank: number }`), `Page`, and `Adjustment` as a union on `kind` (`'none' | 'no-change' | 'mixed' | 'increase' | 'rollback'`). Export them all. `npm run check` passes. Learn: TypeScript handbook "Discriminated unions"

**Checkpoint**: env and types ready.

---

## Phase 3: User Story 1 - Find where fuel is cheapest (Priority: P1) MVP

**Goal**: ranked stations per fuel, cheapest per fuel, ages, "est.", average, pagination, empty
and error states.

**Independent test**: load `supabase/fixtures/dashboard.sql`, open `/`, compare with
hand-computed values. `src/routes/dashboard.e2e.ts` passes.

### Pure functions (test first)

- [ ] T006 [US1] Write failing tests in `src/lib/dashboard.spec.ts` for `joinRows(prices, stations, products, categories)` (contract): one invented `current_price` row joins to brand, street, barangay, product and category names; `price` 62.45 becomes `cents` 6245; `is_estimate` and `reported_at` carried over; a price whose `station_id` has no station throws; a price whose `product_id` has no product throws; a product whose `category_id` has no category throws. Import with `import { joinRows } from './dashboard.ts'`. Run, see it fail. Learn: https://vitest.dev/guide/ (describe, it, expect, toThrow)
- [ ] T007 [US1] Implement `joinRows` in `src/lib/dashboard.ts`: build `Map`s by id, map each price row, `Math.round(price * 100)` for cents (research R4), throw an `Error` on any missing lookup. T006 passes
- [ ] T008 [US1] Write failing tests for `ageLabel(reportedAt, today)` in `src/lib/dashboard.spec.ts`: same day "Reported today"; one day "Yesterday"; 12 days "12 days ago"; across a month end (`'2026-02-27'` to `'2026-03-01'` is "2 days ago"); across a year end
- [ ] T009 [US1] Implement `ageLabel` in `src/lib/dashboard.ts` with `Date.UTC` on the `YYYY-MM-DD` parts and a whole-day difference (research R7). T008 passes
- [ ] T010 [US1] Write failing tests for `rankStations(rows, category)` in `src/lib/dashboard.spec.ts` (research R5): a station with Xtra Advance 91 at 6245 and Blaze 95 at 6810 appears once at 6245 with product "Xtra Advance 91" (scenario 3); a diesel-only station is absent from the kerosene ranking; order cheapest first; equal prices order by newer `reportedAt`, then brand, then "{street}, {barangay}"; two products of one station at the same price keep the one with the smaller product name; ranks are 1, 2, 3…; no rows gives `[]`
- [ ] T011 [US1] Implement `rankStations` in `src/lib/dashboard.ts`: filter by category, keep the cheapest product per `stationId`, sort with one comparator (`localeCompare(…, 'en')` for text), add `rank`. T010 passes
- [ ] T012 [US1] Write failing tests in `src/lib/dashboard.spec.ts` for `paginate(ranked, pageParam)`: 12 rows and `null` give 10 rows, page 1, pages 2 (scenario 1); `'2'` gives 2 rows (scenario 2); `'abc'`, `'0'` and `'9'` clamp to 1, 1 and 2; `[]` gives `{ rows: [], page: 1, pages: 1 }`. For `averageCents(ranked)`: `[6245, 6085]` gives 6165; `[6245, 6246]` gives 6246 (half up); `[]` gives `null`. For `formatCents`: 6245 gives `"62.45"`, 6000 gives `"60.00"`. For `barPercent(cents, highestCents)`: 6810 of 6810 gives 100, 6245 of 6810 gives 92, 3405 of 6810 gives 50 (FR-007)
- [ ] T013 [US1] Implement `paginate` (page size 10, D11), `averageCents` (`Math.round(sum / count)`) `formatCents` (`(c / 100).toFixed(2)`) and `barPercent` (`Math.round(cents / highestCents * 100)`) in `src/lib/dashboard.ts`. T012 passes
- [ ] T014 [US1] Write failing tests in `src/lib/dashboard.spec.ts` for `pickFuel(param, categories)` with categories `['diesel', 'gasoline', 'kerosene']`: `null` gives `'gasoline'` (FR-002 default); `'diesel'` gives `'diesel'`; an unknown value such as `'petrol'` or `'<script>'` gives `'gasoline'`; `'DIESEL'` gives `'gasoline'` (exact match only)
- [ ] T015 [US1] Implement `pickFuel` in `src/lib/dashboard.ts`: return `param` when `categories.includes(param)`, otherwise `'gasoline'`. T014 passes

### Load function (test first)

- [ ] T016 [US1] SEC Write failing tests in `src/routes/page.server.spec.ts` for `load` from `./+page.server.ts`. Mock `$app/env/private` (invented `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`) and `@supabase/supabase-js` with `vi.mock`. The fake `createClient` returns `{ from(table) }`. `from` pushes a call record `{ table, select: null, eq: [], lte: [], limit: null }` into a `calls` array and returns a builder whose `select(cols)`, `eq(col, v)`, `lte(col, v)`, `order(...)` and `limit(n)` store their arguments on that record and return the builder, and whose `then(resolve)` resolves the `{ data, error }` you set per table in each test. Cases: (a) valid invented rows, with `vi.useFakeTimers({ toFake: ['Date'] })` and `vi.setSystemTime(new Date('2026-11-11T17:00:00Z'))`: result has `today === '2026-11-12'` (Asia/Manila, not UTC, research R3; call `vi.useRealTimers()` after), `categories` `['diesel', 'gasoline', 'kerosene']` and joined `rows`; (b) the `select` strings recorded for `current_price`, `station`, `fuel_product` and `fuel_category` equal the exact strings in `contracts/dashboard.md` "Data reads", and no call targets any other table (no `price_report`, `submission`, `profile`, `admin_log`); (c) `current_price` returns `{ data: null, error: { code: 'X' } }`: `load` rejects and `isHttpError(e, 503)` is true with `e.body.message === "Prices couldn't load. Try again later."` (FR-014); (d) one case per read (`current_price`, `station`, `fuel_product`, `fuel_category`) returning exactly 1000 rows: same 503 (research R1). Call `load({} as Parameters<typeof load>[0])`. Learn: https://vitest.dev/guide/mocking (vi.mock), `isHttpError` in https://svelte.dev/docs/kit/@sveltejs-kit
- [ ] T017 [US1] SEC Create `src/routes/+page.server.ts`: module-level `createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: false } })` with values from `$app/env/private`; `export const load: PageServerLoad` that computes `today` (research R3), runs wave 1 of research R1 with `Promise.all`, checks each `error` and the 1000-row cap, calls `joinRows`, and returns `{ today, categories, rows }` (category names only). Wrap in `try`, `console.error` the table and error code (never the key), call `error(503, "Prices couldn't load. Try again later.")` after the `catch` (research R11). Do not read `url` in `load` (research R2). Import from `#lib/dashboard.ts` and confirm with `npm run check` (research R10). T016 passes. Learn: https://svelte.dev/docs/kit/load (Page data, Errors, Rerunning load functions), https://supabase.com/docs/reference/javascript/select
- [ ] T018 [P] [US1] Create `src/routes/+error.svelte`: `<svelte:head><title>Error · CDO Fuel Price Tracker</title>`, `<h1>` with `page.error?.message` from `$app/state`, and a "Try again" link to `page.url.pathname + page.url.search` built with `resolve()` from `$app/paths` (research R10, R15). Checked by hand in T049 (D22). Learn: https://svelte.dev/docs/kit/errors

### E2E smoke (test first)

- [ ] T019 [P] [US1] SEC Create `supabase/fixtures/empty.sql`: `truncate public.price_shift, public.price_report, public.station_product, public.station, public.fuel_product, public.brand restart identity cascade;` (research R16). Local database only
- [ ] T020 [P] [US1] Create `supabase/fixtures/dashboard.sql` with invented data. Let `today` = `(now() at time zone 'Asia/Manila')::date` and `w` = `date_trunc('week', today)::date` (Monday of this week, always between `today - 6` and `today`, so the dates below work on every weekday, research R16). Barangays and categories are looked up by name from the seed. Contents: two invented brands A and B with gasoline, diesel and kerosene products (brand A also has "Xtra Advance 91" and "Blaze 95" gasoline products); 12 stations with gasoline prices so the ranking has 2 pages; one of those 12 is a brand A station with Xtra Advance 91 at 62.45 and Blaze 95 at 68.10 (scenario 3); one gasoline report dated `today` (scenario 5, not shifted because no shift is dated after today); one gasoline report dated `today - 12` at another brand A station (scenario 6: `today - 12 < w`, so the brand A gasoline shift on `w` applies); diesel prices at a few stations; no kerosene prices. Shifts, all dated `w` (each with `source_ref`, `fetched_at`, `extractor`, 001 contract): gasoline A −0.85, B −0.60; diesel A +1.20, B +1.20; kerosene A +0.40, B −0.30; and one future diesel shift A +5.00 on `today + 3` that must change nothing. Run it once by hand with `psql "$SUPABASE_DB_URL" -f …` and check `select * from current_price`
- [ ] T021 [US1] SEC Write failing Playwright tests in `src/routes/dashboard.e2e.ts` with `test.describe.configure({ mode: 'serial' })`. Helper: `process.loadEnvFile('.env')`, read `SUPABASE_DB_URL`, throw unless `new URL(url).hostname === '127.0.0.1'` (D21), then `execFileSync('psql', [url, '-v', 'ON_ERROR_STOP=1', '-f', file])` from `node:child_process` (arguments as an array, never a concatenated command string, SECURITY.md 3). Tests, in order: (1) after `empty.sql`: the ranking and "Cheapest in CDO" read "No prices reported yet" (FR-013); (2) after `dashboard.sql`, no sign-in: Gasoline link has `aria-current="true"`, the ranking list (`getByRole('list', { name: 'Station ranking' })`) has 10 items, "Page 1 of 2" shows, the first price equals the hand-computed cheapest (FR-001, FR-002, FR-006); (3) the two-product station appears once with "Xtra Advance 91" and its hand-computed price (FR-003); (4) a row reads "Reported today" without "est.", another "12 days ago · est.", and the legend text is visible (FR-004, FR-005); (5) "City avg ₱…" equals the hand-computed average (FR-007); (6) Next shows 2 items and no Next link remains (scenario 2); (7) Diesel link re-ranks and gets `aria-current` (scenario 4); (8) `/?fuel=petrol` shows Gasoline selected (FR-002); (9) the "Cheapest in CDO" region shows each fuel with brand, barangay, product, age and "est." where it applies, and kerosene reads "No prices reported yet" (FR-008); (10) with `page.route('**/_app/**', (r) => r.abort())` the ranking is in the HTML and clicking Next still reaches page 2 (FR-012, CHK013); (11) every ranking bar (`.bar`) has `aria-hidden="true"` (FR-023, CHK015). Run `npm run test:e2e`, see them fail. Learn: https://playwright.dev/docs/locators, https://playwright.dev/docs/network#abort-requests, Node `process.loadEnvFile` and `child_process.execFileSync`

### UI

- [ ] T022 [US1] Start `src/routes/+page.svelte`: `let { data }: PageProps = $props()`; `const fuel = $derived(pickFuel(page.url.searchParams.get('fuel'), data.categories))` and `const pageParam = $derived(page.url.searchParams.get('page'))` (named `pageParam` so it does not shadow `page` from `$app/state`); `$derived` values for `ranked = rankStations(data.rows, fuel)`, `current = paginate(ranked, pageParam)` and `average = averageCents(ranked)`. Add `<svelte:head><title>Dashboard · CDO Fuel Price Tracker</title>` and a visually hidden `<h1>Fuel prices in Cagayan de Oro</h1>`. Learn: https://svelte.dev/docs/svelte/$derived, https://svelte.dev/docs/kit/$app-state
- [ ] T023 [US1] In `src/routes/+page.svelte` add the ranking card: `<h2>Station ranking</h2>`; one link per category with `href={resolve('/?fuel=' + c)}`, `data-sveltekit-noscroll`, `aria-current={c === fuel ? 'true' : undefined}`, label via CSS `text-transform: capitalize`; then `<ol aria-label="Station ranking">` with one `<li>` per row: rank, brand, "{street}, {barangay} · {ageLabel(row.reportedAt, data.today)}" plus " · est." when `isEstimate`, the bar (`class="bar"`, `aria-hidden="true"`, inner width `barPercent(row.cents, highest)%` where `highest` is the last ranked row's `cents`, `--accent` for rank 1 and `--mid` for the rest), and "₱{formatCents}" with the product name beside it. Learn: research R5, R14
- [ ] T024 [US1] In `src/routes/+page.svelte` add under the list: the legend "est. = reported price plus weekly adjustments since then", the footer "City avg ₱{formatCents(average)} · bars scaled to highest price", and pagination: "‹ Prev" and "Next ›" as links (`resolve('/?fuel=' + fuel + '&page=' + n)`, `data-sveltekit-noscroll`) only when available, otherwise a `<span>` at 0.35 opacity, with "Page N of M" between. When `ranked` is empty, show "No prices reported yet" in place of the list and footer (FR-013)
- [ ] T025 [US1] In `src/routes/+page.svelte` add the "Cheapest in CDO" card as `<section aria-labelledby>` with `<h2>`: for each category, `rankStations(data.rows, c)[0]` (same comparator, CHK008); show the fuel name, "{brand} · {barangay} · {age}" plus " · est." (D16, D17), and "₱{price}" with the product name beside it in `--accent`; "No prices reported yet" when there is none
- [ ] T026 [US1] Style the Dashboard in a `<style>` block in `src/routes/+page.svelte` from the inline styles of `design_handoff_fuel_price_dashboard/design_files/Fuel Price Dashboard.dc.html` (lines 24 to 50): container `padding: 32px 40px 48px; max-width: 1280px`, grid `repeat(auto-fit, minmax(min(100%, 420px), 1fr))` gap 20px, card radius 14px with `background: var(--card)` and `box-shadow: var(--shadow)`, row grid `24px minmax(110px, 170px) minmax(60px, 1fr) 76px`, chip styles for the fuel links; `min-width: 0` and `overflow-wrap: anywhere` on text cells (CHK012). Use the tokens from `src/app.css`, never raw colours
- [ ] T027 [US1] Run `npm run test:unit -- --run`, `npm run test:e2e`, `npm run check`, `npm run lint`. All of T021 passes

**Checkpoint**: US1 works on its own (MVP). Commit.

---

## Phase 4: User Story 2 - See this week's price adjustment (Priority: P2)

**Goal**: the adjustment card per fuel.

**Independent test**: Vitest cases for scenarios 1 to 4 and the edge cases pass, and the
Playwright card cases (T034) pass on the fixture.

- [ ] T028 [US2] Write failing tests in `src/lib/dashboard.spec.ts` for `summarizeShifts(shifts)` (research R6), with invented brand ids: every brand +1.20 on `2026-10-27` gives `increase`, 120 to 120, `asOf` `'2026-10-27'` (scenario 1); -0.85 and -0.60 in one week give `rollback`, 60 to 85 (scenario 2); +0.40 and -0.30 give `mixed` (scenario 3); `[]` gives `none` (scenario 4); all 0.00 give `no-change`; 0.00 and +0.50 give `increase`, 0 to 50; a brand whose only shift is in the previous week is left out; a Sunday (`2026-11-01`) and the next Monday (`2026-11-02`) fall in different weeks; one brand with two shifts in the latest week counts as their sum (research R6)
- [ ] T029 [US2] Implement `summarizeShifts` in `src/lib/dashboard.ts`: latest date, its Monday with `Date.UTC` and `getUTCDay()`, filter to that Monday..Sunday, per-brand sums in cents with a `Map`, then the kind and min/max of absolute values. T028 passes
- [ ] T030 [US2] Write failing tests for `formatAdjustment(a)` and `formatDate(d)` in `src/lib/dashboard.spec.ts`: increase 120..120 gives `{ arrow: '▲', amount: '+₱1.20', word: 'Increase' }`; rollback 60..85 gives `{ arrow: '▼', amount: '−₱0.60 – ₱0.85', word: 'Rollback' }` (U+2212 minus, U+2013 dash); mixed gives `{ arrow: '', amount: '', word: 'Mixed' }`; `no-change` gives word "No change"; `none` gives word "No adjustment recorded yet"; `formatDate('2026-10-27')` gives `'Oct 27, 2026'` (FR-010, FR-011, CHK006)
- [ ] T031 [US2] Implement `formatAdjustment` and `formatDate` (`Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })`) in `src/lib/dashboard.ts`. T030 passes
- [ ] T032 [US2] SEC Add failing cases to `src/routes/page.server.spec.ts`, using the recorded calls of T016: (a) there is one `price_shift` call per category, each with `select` exactly `'brand_id, amount, effective_on'`, `eq` `['category_id', <that category's id>]`, `lte` `['effective_on', result.today]` and `limit` 1000 (spec edge case: future shifts are not shown); (b) with invented shift rows per category the result has `adjustments` in category order with the expected kinds; (c) a `price_shift` error gives the 503; (d) a `price_shift` response of 1000 rows gives the 503
- [ ] T033 [US2] SEC Extend `load` in `src/routes/+page.server.ts` with wave 2 of research R1 (one `price_shift` query per category id, `.eq('category_id', id)`, `.lte('effective_on', today)`, `.order('effective_on', { ascending: false })`, `.limit(1000)`, same error and cap checks) and return `adjustments: { category, adjustment: summarizeShifts(…) }[]`. T032 passes
- [ ] T034 [US2] Add failing Playwright cases to `src/routes/dashboard.e2e.ts` (D22): extend test (1) of T021 (runs right after `empty.sql`) so the "Price adjustment" region shows "No adjustment recorded yet" for all three fuels and no "As of"; add a new test (12) that runs `dashboard.sql` again first, then checks: Diesel shows "▲", "+₱1.20" and "Increase" (and not "+₱6.20", so the future shift is ignored); Gasoline shows "▼", "−₱0.60 – ₱0.85" and "Rollback"; Kerosene shows "Mixed" with no "▲" or "▼"; "As of" shows the date of `w` (this week's Monday in Manila, computed in the test) formatted like "Oct 27, 2026"; every arrow element has `aria-hidden="true"` (FR-009 to FR-011, FR-023)
- [ ] T035 [US2] In `src/routes/+page.svelte` add the adjustment card as `<section aria-labelledby>` with heading "Price adjustment" (shown uppercase by CSS), before "Cheapest in CDO" (mock lines 29 to 36): "As of {formatDate(latest asOf)}" only when some fuel has an `asOf`, "Change per litre vs. previous week", then per fuel a 42px box with the arrow (`aria-hidden="true"`), the fuel name and word, and the amount. Increase uses `--up` on `--up-bg`, rollback `--down` on `--down-bg`, the rest `--muted` on `--soft`
- [ ] T036 [US2] Run all unit tests, `npm run test:e2e`, `npm run check`, `npm run lint`. T032 and T034 pass

**Checkpoint**: US1 and US2 work. Commit.

---

## Phase 5: User Story 3 - Any screen and any light (Priority: P2)

**Goal**: header, tabs, mobile menu, mode that follows the device and remembers the toggle,
Coming soon pages.

**Independent test**: `src/routes/shell.e2e.ts` passes. Check by eye at 1280px and 390px in both
modes.

- [ ] T037 [P] [US3] Write Playwright tests in `src/routes/shell.e2e.ts` (cases 1 and part of 8 pass already because the header was built ahead; the rest must fail now): (1) at 1280px the banner shows "CDO Fuel Price Tracker", links Dashboard, Analytics, Contribute, and no "Log in" or "Sign up" text (FR-015); (2) the banner has a "Switch to … mode" button (FR-015); (3) `/analytics` and `/contribute` show "Coming soon" and their tab has `aria-current="page"` (FR-016); (4) at 390px the inline tabs are hidden, the "Menu" button opens a list of the three links, Escape closes it, choosing Analytics navigates and closes it (FR-017, CHK010); (5) at 390px the Dashboard cards share the same left edge (stacked, FR-017); (6) with `/_app/` aborted, `emulateMedia({ colorScheme: 'light' })` and `'dark'` give different `body` background colours (FR-018, D18); (7) under a dark device, click the toggle, reload with `/_app/` aborted: `html` has `data-theme="light"` and the body colour equals the light one from (6) (FR-019, SC-005); (8) with `localStorage.theme = 'blue'` set by `page.addInitScript` and `/_app/` aborted, `html` has no `data-theme` and the body colour follows the emulated device (T039 value check); (9) every request during a Dashboard load goes to `localhost:4173` (FR-021, SC-006); (10) Tab from the top reaches the logo, the tabs and the toggle in order, and the toggle's accessible name changes after a click (FR-022, FR-023). Run, see the unbuilt cases fail
- [ ] T038 [US3] Rewrite the colour tokens in `src/app.css` (your file) with `light-dark()` (D18, research R8): `:root { color-scheme: light dark; --h: 190; --bg: light-dark(oklch(0.875 0.012 var(--h)), oklch(0.19 0.02 var(--h))); … }` for every colour token, light value first; `[data-theme='light'] { color-scheme: light }`, `[data-theme='dark'] { color-scheme: dark }`; then `--shadow` and `--raised`: dark values on `:root`, light values in `@media (prefers-color-scheme: light) { :root { … } }`, then dark values on `[data-theme='dark']` and light values on `[data-theme='light']`, in that order. Keep every token name (`Header.svelte` uses them). Values: design handoff README "Design Tokens". Learn: MDN `light-dark()`, MDN `color-scheme`
- [ ] T039 [US3] SEC Add the inline script as the first child of `<head>` in `src/app.html`: inside `try`, `const t = localStorage.getItem('theme')`; if `t === 'light' || t === 'dark'` set `document.documentElement.dataset.theme = t`. Nothing else (D18). Static text only
- [ ] T040 [US3] Add to `src/app.css`: `:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px }`; `@media (prefers-reduced-motion: reduce) { *, *::before, *::after { transition: none !important } }` (CHK017); a `.visually-hidden` utility; the toggle label rules of research R8 (`.to-light` / `.to-dark` shown by default, by `@media (prefers-color-scheme: light)`, and by `[data-theme]`). Learn: research R8, R14
- [x] T041 [US3] Header base in `src/lib/components/Header.svelte` (built in `a749934`): logo link with the mark (`aria-hidden="true"`) and "CDO Fuel Price Tracker"; `const tabs = [...]` with `resolve()` hrefs rendered by `{#each}` in `<nav aria-label="Main">`; `aria-current="page"` from `page.url.pathname`; underline that grows on hover, full on the active tab with `--ink`, `--muted` otherwise (US3 scenario 6); 72px height, 40px padding, Montserrat logo, Inter tabs, bottom border `var(--line)`
- [ ] T042 [US3] Add the mode toggle to `src/lib/components/Header.svelte` where the `TODO: theme toggle button` comment is: a `<button type="button">` holding `<span class="to-light">☀<span class="visually-hidden">Switch to light mode</span></span>` and the `to-dark` twin with ☾ (glyphs `aria-hidden="true"`); `onclick` reads the current mode (`dataset.theme`, else `matchMedia('(prefers-color-scheme: dark)')`), sets the other on `document.documentElement.dataset.theme` and saves it with `localStorage.setItem('theme', …)` inside `try` (research R8). 38px square, radius 10px, border `var(--line)`, `flex: none`
- [ ] T043 [US3] Add the mobile menu to `src/lib/components/Header.svelte` where the `TODO: mobile menu button` comment is. Wrap the existing `{#each tabs …}` in `{#snippet tabLinks()}` and render it with `{@render tabLinks()}` in the existing `<nav aria-label="Main">` and in a new `<nav id="site-menu" popover aria-label="Main" bind:this={menu}>`. Add `<button type="button" popovertarget="site-menu" aria-label="Menu">` with ☰ and ✕ (`aria-hidden`, swapped by `:has(#site-menu:popover-open)`); `afterNavigate(() => menu?.hidePopover())`. Below 768px hide the inline nav, show the button, header 60px with `padding: 0 16px`, popover `inset: 60px 0 auto 0; margin: 0`, links stacked (mock mobile lines 12 to 23). Give the logo `min-width: 0` so the name wraps and never pushes the buttons off screen. Learn: MDN "Using the Popover API", https://svelte.dev/docs/svelte/snippet, https://svelte.dev/docs/kit/$app-navigation#afterNavigate
- [ ] T044 [P] [US3] Fill in the existing empty `src/routes/analytics/+page.svelte`: `<svelte:head><title>Analytics · CDO Fuel Price Tracker</title>`, `<h1>Analytics</h1>`, `<p>Coming soon</p>` (FR-016)
- [ ] T045 [P] [US3] Fill in the existing empty `src/routes/contribute/+page.svelte`: same with "Contribute"
- [ ] T046 [US3] In `src/routes/+page.svelte` add `@media (max-width: 767px)`: container `padding: 20px 16px 36px`, grid gap 16px, ranking card `padding: 20px 16px`, row grid `22px minmax(0, 1fr) auto` with the bar on its own line `grid-column: 2 / 4`, height 8px (mock mobile lines 30 to 48)
- [ ] T047 [US3] Run `npm run test:e2e`, `npm run check`, `npm run lint`. All of T037 passes

**Checkpoint**: all stories work. Commit.

---

## Phase 6: Polish

- [ ] T048 Compare side by side with `Fuel Price Dashboard.dc.html` and `Fuel Price Dashboard Mobile.dc.html` (Teal palette) in dark and light at 1280px and 390px, including the tab hover underline. At 320px the app name wraps and the mode and menu buttons stay fully on screen (spec edge case). Fix spacing, type and colour differences in `src/routes/+page.svelte` and `src/lib/components/Header.svelte` (FR-020, SC-007, US3 scenario 6)
- [ ] T049 By hand (D22): (a) Tab through every page, every control shows a focus ring (FR-022, SC-008); (b) OS "reduce motion" on: the underline does not animate (CHK017); (c) DevTools contrast checker on "est.", legend and muted text in both modes (CHK018); (d) error page: `supabase stop`, reload `/`, see "Prices couldn't load. Try again later." and a working "Try again" link after `supabase start` (FR-014, T018); (e) blocked storage: block site data for localhost in the browser, the app follows the device and the toggle still switches the open page (spec edge case); (f) SC-004: on a phone-sized window, time finding the cheapest station for a chosen fuel from a cold load, at most one tap to change fuel, under 10 seconds
- [ ] T050 Run the whole `specs/002-public-dashboard/quickstart.md`, then `supabase db reset` to clear the e2e data

---

## FR to test map

| FR | Test task (before build) | Build task |
|---|---|---|
| FR-001 | T021 (2) | T017, T022 |
| FR-002 | T014, T021 (2), (7), (8) | T015, T022, T023 |
| FR-003 | T010, T021 (3) | T011, T023 |
| FR-004 | T008, T021 (4) | T009, T023 |
| FR-005 | T021 (4) | T024 |
| FR-006 | T012, T021 (2), (6) | T013, T024 |
| FR-007 | T012 (`averageCents`, `barPercent`), T021 (5) | T013, T023, T024 |
| FR-008 | T010, T021 (9) | T025 |
| FR-009 | T028, T034 (T021 (1) extended, (12)) | T029, T035 |
| FR-010 | T030, T034 | T031, T035 |
| FR-011 | T028, T030, T034 | T029, T031, T035 |
| FR-012 | T021 (10) | T017, T022 |
| FR-013 | T021 (1), (9) | T024, T025 |
| FR-014 | T016 (c), (d), T032 (c), (d); page by hand T049 (d) | T017, T018, T033 |
| FR-015 | T037 (1), (2) | T041 (built ahead), T042 |
| FR-016 | T037 (3) | T044, T045 |
| FR-017 | T037 (4), (5) | T043, T046 |
| FR-018 | T037 (6), (8) | T038, T039 |
| FR-019 | T037 (7), (8) | T039, T042 |
| FR-020 | by eye, T048 (D14) | T026, T038, T041 |
| FR-021 | T037 (9) | T003 (done) |
| FR-022 | T037 (10), T049 (a) to (c) | T040 |
| FR-023 | T021 (11), T034, T037 (2), (4), (10) | T023, T035, T042, T043 |

Contract reads (columns, filters, tables): T016 (b), T032 (a) before T017 and T033.

## Dependencies

- Setup (T001, T002) then Foundational (T004, T005), then stories.
- US1 (T006 to T027) is the MVP. US2 adds to `dashboard.ts`, `+page.server.ts`, `+page.svelte` and
  `dashboard.e2e.ts`, so it follows US1. US3 touches `app.css`, `app.html`, `Header.svelte` and the
  two Coming soon pages, so T037 to T045 can start after Foundational. T046 waits for T026.
- Inside a story: each test task before its build task, as listed.

## Parallel examples

- Setup: T002 alone (T003 done).
- US1: T018, T019 and T020 while the pure functions are in progress.
- US3: T037, T044 and T045 together. T038 to T043 touch shared files, one at a time.

## Implementation strategy

1. MVP: Phases 1 to 3. Stop and check the ranking against the fixture.
2. Add US2 (adjustment card).
3. Add US3 (mode, mobile menu, Coming soon). Until then the page uses the current dark tokens.
4. Polish against the mocks and run the by-hand checks.
