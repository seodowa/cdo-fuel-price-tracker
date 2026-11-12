# Research: Public Dashboard

Inputs: `spec.md`, `decisions.md` (D1 to D22), `checklists/ux.md`, the design handoff README and
`.dc.html` files, the 001 migrations and contract, constitution 1.0.0, `SECURITY.md`,
`WCAG-TEXT-ALTERNATIVES.md`. Installed versions checked in `node_modules`: `@sveltejs/kit` 3.2.0,
`svelte` 5.57.3, `vitest` 4.1.12, `@playwright/test` 1.65.0, `vite` 8.3.8. Supabase CLI 2.122.0
and `psql` are on the system.

Open decisions were answered as D15 to D19 in `decisions.md`.

## R1. Reading the data (D15)

- Decision: `@supabase/supabase-js` 2.119.0, created in `src/routes/+page.server.ts` with
  `createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, { auth: { persistSession: false } })`.
  No session is ever set, so one module-level client is safe on the server. Each query returns
  `{ data, error }`.
- Wave 1, in parallel (`Promise.all`):
  1. `from('current_price').select('station_id, product_id, price, reported_at, is_estimate')`
  2. `from('station').select('id, street_address, brand(name), barangay(name)')` (simple FKs, so
     PostgREST embeds them)
  3. `from('fuel_product').select('id, name, category_id')`
  4. `from('fuel_category').select('id, name').order('name')`
     Wave 2, one per category, in parallel:
     `from('price_shift').select('brand_id, amount, effective_on').eq('category_id', id).lte('effective_on', today).order('effective_on', { ascending: false }).limit(1000)`
- Any response with `error`, or with exactly 1000 rows (`max_rows`, `supabase/config.toml:18`),
  is a load failure, so a truncated list never produces a wrong ranking.
  `ponytail: 1000-row ceiling per request, add .range() paging when a city passes ~250 stations x 4 products`.
- The `current_price` view is not embedded. Its `station_id` comes from a composite FK
  (`supabase/migrations/20261029000001_schema.sql:73-74`), so PostgREST cannot infer the
  relationship, through the client or not. `joinRows` joins in TypeScript with `Map`s.
- No generated `Database` types: the client returns untyped rows, and the loader passes them to
  `joinRows`, whose parameter types are the shapes in `data-model.md`. Generating types
  (`supabase gen types`) is skipped until a second caller needs them.
- Rationale: spec says no data-layer change, so no new view. Per-category shift queries keep the
  "latest week" right when one fuel has not shifted for months.
- Docs: https://supabase.com/docs/reference/javascript/select (embedding, filters, `order`, `limit`).

## R2. Where state lives, and behaviour without JavaScript (CHK013)

- Decision: `+page.server.ts` returns all rows and the shift summary. It does not read
  `url.searchParams`, so SvelteKit does not rerun it when only the query string changes. The page
  reads `fuel` and `page` from `page.url.searchParams` (`$app/state`) and derives the ranking with
  `$derived`. The query value is stored as `pageParam` so it does not shadow `page` from
  `$app/state`. Fuel buttons and Prev / Next are `<a>` links with `data-sveltekit-noscroll`.
- Without JS, the links are full page loads and the server renders the chosen fuel and page.
- `pickFuel(param, categories)` (pure, tested) returns `param` only when it exactly matches a
  category name, otherwise `gasoline`. `paginate` clamps `page` to 1 .. page count.
- Rationale: one data fetch per visit, shareable URLs, works without JS, no store.
- Docs: SvelteKit "Loading data > Rerunning load functions", "$app/state".

## R3. Today in Asia/Manila

- Decision: the load function computes `today` once:
  `new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Manila' }).format(new Date())` gives
  `YYYY-MM-DD`. It is sent to the page and passed to the pure functions, so server and browser
  render the same labels (no hydration mismatch) and tests pass a fixed date.

## R4. Money (CHK005)

- Decision: PostgREST returns `numeric` as a JSON number. Convert once to integer centavos
  (`Math.round(price * 100)`). Compare, sum and average in centavos. City average =
  `Math.round(sum / count)` (half up). Display `(c / 100).toFixed(2)` with the `₱` prefix. Shift
  amounts use the same rule.
- Rationale: avoids float sums like 62.45 + 60.85 drifting at the centavo (SC-001).

## R5. Ranking and "Cheapest in CDO" (FR-003, FR-008, CHK008)

- Decision: `rankStations(rows, category)`:
  1. keep rows of that category,
  2. per station keep the cheapest product (tie: product name, `localeCompare`),
  3. sort by price ascending, then `reportedAt` descending, then brand, then location
     (`localeCompare(…, 'en')`),
  4. number ranks from 1.
     "Cheapest in CDO" is `rankStations(rows, c)[0]` for each category, so both use the same order.
- Bars: `barPercent(cents, highestCents)` = `Math.round(cents / highestCents * 100)`, where the
  highest is the last ranked row (all pages). Pure and tested. The
  first-ranked row uses `--accent`, the rest `--mid` (mock).
- A fuel with no ranked station shows "No prices reported yet" in the ranking and in that fuel's
  row of "Cheapest in CDO". With no prices at all, every place shows it (FR-013).
- Location (D16): ranking rows show "{street address}, {barangay}" under the brand. "Cheapest in
  CDO" rows show "{brand} · {barangay} · {age}" plus " · est." (D17), with the product name beside
  the price as in the ranking. The tie-break "location" key is "{street address}, {barangay}".
- Pagination: `paginate(ranked, pageParam)` returns `{ rows, page, pages }`. 10 per page. `pages`
  is at least 1. A missing, non-numeric or out-of-range `pageParam` is clamped to 1 .. pages.
- City average: `averageCents(ranked)` over all ranked rows (all pages), R4 rounding. `null` when
  there are none.

## R6. Price adjustment summary (FR-009 to FR-011, CHK006, CHK009)

- Decision: `summarizeShifts(shifts)` for one category, where shifts are already limited to
  `effective_on <= today` by the query:
  1. none: `{ kind: 'none' }` ("No adjustment recorded yet").
  2. latest = max `effective_on`. Week = Monday to Sunday holding it, computed on the date string
     with `Date.UTC` (a date has no time zone, the Manila week is the calendar week).
  3. Per brand, net = sum of its amounts in that week. Brands with no shift that week are left out.
     A brand normally has one shift per week. The sum matches the mock's "Change per litre vs.
     previous week".
  4. All nets 0: `no-change`. All ≥ 0: `increase`. All ≤ 0: `rollback`. Otherwise `mixed`.
  5. For increase and rollback: `min` and `max` of absolute nets. Equal: one amount. A 0 beside
     non-zero values makes the range start at ₱0.00.
  6. Returns `latest` as `asOf`.
- Text: increase "▲ +₱1.20" / "Increase", rollback "▼ −₱0.60 – ₱0.85" / "Rollback" (U+2212 minus,
  U+2013 dash, smaller first), mixed "Mixed", no change "No change", none "No adjustment recorded
  yet". Mixed, no change and none have no arrow and no amount and use the neutral `--muted` on
  `--soft` style.
- "As of" date: the latest `asOf` across fuels, formatted with
  `Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })`
  on `Date.UTC(y, m - 1, d)`. Fixed format in every locale. Hidden when no fuel has a shift.
- Future shifts are excluded by the query (`effective_on=lte.{today}`), matching the view.

## R7. Age label (FR-004, FR-005, D5, CHK011)

- Decision: `ageLabel(reportedAt, today)` counts calendar days between two `YYYY-MM-DD` strings
  with `Date.UTC`: 0 "Reported today", 1 "Yesterday", n "n days ago". `· est.` is appended as text
  when `isEstimate` is true. Legend under the ranking: "est. = reported price plus weekly
  adjustments since then".
- A page left open past midnight keeps its labels until the next load. Accepted, the data is
  daily and a reload fixes it.

## R8. Mode (FR-018, FR-019, D7, D18, CHK007)

- Tokens (D18): `src/app.css` is rewritten so each colour token is defined once on `:root` as
  `light-dark(<light value>, <dark value>)`, with `color-scheme: light dark` on `:root`,
  `[data-theme='light'] { color-scheme: light }` and `[data-theme='dark'] { color-scheme: dark }`.
  `light-dark()` picks the value from the element's `color-scheme`, so with no `data-theme` the
  device setting wins, with or without JS. `--h: 190` stays.
- Shadows: `light-dark()` accepts only colours, so `--shadow` and `--raised` get their own rules,
  in this order (equal specificity, so later wins):
  1. `:root` dark values (`none`, `0 8px 24px #0006`),
  2. `@media (prefers-color-scheme: light) { :root { light values } }`,
  3. `[data-theme='dark'] { dark values }`, `[data-theme='light'] { light values }`.
- Inline script: the first thing in `<head>` of `src/app.html`. Inside `try`, read
  `localStorage.getItem('theme')`. If it is `light` or `dark`, set
  `document.documentElement.dataset.theme` to it. Otherwise do nothing. It runs before the body is
  parsed, so there is no flash.
- Toggle in `Header.svelte`: current mode = `dataset.theme`, or, when unset,
  `matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'`. Click sets the other
  mode on `dataset.theme` and saves it to `localStorage` inside `try` (blocked storage still
  switches the open page).
- Toggle glyph and label: both "☀ Switch to light mode" and "☾ Switch to dark mode" spans are in
  the markup. CSS shows one: the default shows "to light", `@media (prefers-color-scheme: light)`
  shows "to dark", then `[data-theme='dark'] …` and `[data-theme='light'] …` override (they have
  higher specificity than the media rules). Server HTML is right on first paint, no `$state`.
- Without JS, the mode follows the device and the toggle does nothing (it needs `localStorage`).
- Tests (CHK007, SC-005): Playwright, with requests to `/_app/` aborted so no Svelte code runs:
  (a) `emulateMedia({ colorScheme: 'light' })` and `'dark'` give different body background colours
  (FR-018), (b) after saving `light` with the toggle and reloading under a dark device,
  `html[data-theme="light"]` is set and the body colour matches the light one (FR-019).
- Docs: MDN "light-dark()", MDN "color-scheme".

## R9. Environment variables in SvelteKit 3

- Finding: Kit 3 deprecates `$env/static/*` and `$env/dynamic/*` (warning in
  `node_modules/@sveltejs/kit/src/runtime/env/static/private.js`). Variables are declared in
  `src/env.ts` with `defineEnvVars` from `@sveltejs/kit/env` and imported from `$app/env/private`
  (server only) or `$app/env/public`.
- Decision: `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, both private (only the server uses them
  in 002). Each has a function schema that throws on an empty value, so a missing `.env` fails at
  start, not at the first request. `vite preview` loads `.env` (`preview/index.js:53`), so the
  Playwright web server sees them.
- Docs: https://svelte.dev/docs/kit/environment-variables

## R10. Imports and links in SvelteKit 3

- `$lib` is removed in Kit 3. Use `#lib` (Node subpath import in `package.json`, `"#lib/*":
"./src/lib/*"`). The mapping adds no extension, and the generated tsconfig sets
  `allowImportingTsExtensions`, so import `#lib/dashboard.ts` with the extension. Confirm with
  `npm run check` in the first task that uses it.
- `eslint-plugin-svelte` recommended config enables `svelte/no-navigation-without-resolve`. Build
  hrefs with `resolve()` from `$app/paths`, for example `resolve('/analytics')` and the query
  links of R2.

## R11. Load errors (FR-014, D12)

- Decision: wrap the queries and `joinRows` in `try`. On any failure (a query returns `error`, the
  client throws, a response hits the 1000-row cap, `joinRows` throws on a missing station or
  product) log `console.error` with the table name and error code (no key), then, outside the
  `try`, call
  `error(503, "Prices couldn't load. Try again later.")` from `@sveltejs/kit`. Calling `error()`
  inside the `try` would be caught by our own `catch`.

## R12. Header, mobile menu and breakpoint (FR-015, FR-017, CHK001, CHK010)

- Breakpoint: `768px`. At or above, the header shows tabs inline (mock desktop: 72px tall,
  `padding: 0 40px`). Below, it shows the menu button (mock mobile: 60px, `padding: 0 16px`) and
  ranking rows switch to the mobile grid (bar under the price). The cards already stack below
  about 900px through the mock's `repeat(auto-fit, minmax(min(100%, 420px), 1fr))`.
- Menu: native popover. `<button popovertarget="site-menu" aria-label="Menu">` and
  `<nav id="site-menu" popover>`. The browser gives open, close, Escape, outside click, focus
  return and the expanded state. `afterNavigate(() => menu?.hidePopover())` closes it after a tab
  is chosen. Burger ☰ / close ✕ swap with `:has(#site-menu:popover-open)`. Works without JS.
- All of this lives in `src/lib/components/Header.svelte` (the user's file), rendered once by
  `src/routes/+layout.svelte`. The existing
  `const tabs = [...]` array and its `{#each}` stay. For the mobile menu, the `{#each}` is wrapped in
  `{#snippet tabLinks()}` and rendered in both the desktop `<nav>` and the popover `<nav>`. The
  active tab comes from `page.url.pathname` (`$app/state`).
- App name: "CDO Fuel Price Tracker", the mock's "/ CDO" suffix dropped. On phones the name may
  wrap to two lines (`min-width: 0`, buttons `flex: none`), so the menu button never leaves the
  screen.
- Docs: MDN "Popover API", Svelte "{#snippet}", SvelteKit "$app/navigation afterNavigate".

## R13. Fonts (FR-021, D13)

- Done by the user: 9 latin-subset `.woff2` files in `static/fonts/`:
  `inter-v20-latin/inter-v20-latin-{regular,500,600}.woff2`,
  `montserrat-v31-latin/montserrat-v31-latin-{500,600,700}.woff2`,
  `roboto-v51-latin/roboto-v51-latin-{regular,500,700}.woff2`, each folder with its SIL OFL 1.1
  `OFL.txt`. One `@font-face` per file in `src/app.css` with `font-display: swap`, and
  `body { font-family: 'Inter', sans-serif }`.
- Headings Montserrat, prices Roboto, as in the mock.

## R14. Accessibility (FR-022, FR-023, CHK012, CHK015 to CHK018)

- Contrast, computed from the handoff OKLCH tokens (WCAG 2 formula):

  | Pair                                     | Dark        | Light       |
  | ---------------------------------------- | ----------- | ----------- |
  | ink on card                              | 14.40       | 13.43       |
  | muted on card ("est.", legend, location) | 7.05        | 7.73        |
  | muted on bg                              | 8.04        | 6.83        |
  | accent on card (cheapest prices)         | 9.30        | 5.44        |
  | on-accent on accent (selected fuel)      | 10.37       | 6.05        |
  | up on card / up on up-bg                 | 6.34 / 5.14 | 6.35 / 4.89 |
  | down on card / down on down-bg           | 9.12 / 6.98 | 6.74 / 5.39 |
  | muted on soft (neutral adjustment box)   | 5.63        | 6.14        |

  All pass 4.5:1. Disabled Prev / Next at 35% opacity are inactive controls and exempt.

- Bars (CHK015): `aria-hidden="true"`. The row's price text and the footer line "City avg ₱… · bars
  scaled to highest price" carry the same information (WCAG 1.1.1 decoration case).
- ▲ ▼ glyphs: `aria-hidden="true"`, the word "Increase" or "Rollback" and the signed amount are the
  text (FR-010). Logo mark: `aria-hidden`. Mode and menu buttons: `aria-label` (R8, R12).
- Selected state (CHK016): fuel links `aria-current="true"`, active tab `aria-current="page"`.
- Reduced motion (CHK017): `@media (prefers-reduced-motion: reduce) { * { transition: none } }` in
  `app.css`.
- Focus: `:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px }`. All controls
  are `<a>` or `<button>`, so they are keyboard reachable.
- Headings: visually hidden `<h1>` "Fuel prices in Cagayan de Oro" on the Dashboard; card titles
  are `<h2>`. `.visually-hidden` utility in `app.css`.
- Long names (CHK012): text cells get `min-width: 0` and `overflow-wrap: anywhere`.

## R15. Other pages and texts (FR-016, CHK002, CHK004, CHK014)

- `src/routes/analytics/+page.svelte` and `src/routes/contribute/+page.svelte`: `<h1>` with the tab
  name and `<p>Coming soon</p>`.
- `<svelte:head><title>`: "Dashboard · CDO Fuel Price Tracker", "Analytics · CDO Fuel Price
  Tracker", "Contribute · CDO Fuel Price Tracker". Error page: "Error · CDO Fuel Price Tracker".
- `src/routes/+error.svelte`: shows `page.error?.message` and a "Try again" link to the current
  URL. It renders inside the root layout, so the tabs stay as the way back.

## R16. Playwright data (D14)

- Decision: two SQL files run with `psql` against the local stack (`SUPABASE_DB_URL` from `.env`,
  host `127.0.0.1` only) from the e2e file through
  `execFileSync('psql', [url, '-v', 'ON_ERROR_STOP=1', '-f', file])`. Arguments go as an array,
  never as one concatenated shell string (SECURITY.md 3):
  - `supabase/fixtures/empty.sql`: `truncate public.price_shift, public.price_report,
public.station_product, public.station, public.fuel_product, public.brand restart identity
cascade;` (cascade also clears `submission` and `admin_log` rows that point at them).
  - `supabase/fixtures/dashboard.sql`: invented brands, 12 gasoline stations, diesel at some,
    kerosene at none, a two-product gasoline station (62.45 and 68.10), one report dated today, one
    dated 12 days ago with a later shift. Dates relative to `(now() at time zone 'Asia/Manila')::date`.
- Tests run serially: empty state first, then the fixture, then the rest. The server reads the
  database on every request, so swapping data between tests needs no restart.
- The helper loads `.env` with Node's `process.loadEnvFile('.env')` (Node 24, no dependency), reads
  `SUPABASE_DB_URL`, and throws unless `new URL(url).hostname === '127.0.0.1'` (D21). No password
  in code.
- Shift dates in the fixture: every shift is dated `w = date_trunc('week', today)::date` (this
  week's Monday in Manila). `w` is always between `today - 6` and `today`, so on every weekday the
  shifts are in the past, they form the latest week, the `today - 12` report is older than them
  (the 001 view applies shifts with `effective_on > observed_on`, so it gets "est."), and the
  `today` report is not older (no "est."). A last-week Monday would fall on `today - 12` or
  `today - 13` at weekends and break scenario 6. One diesel shift is dated `today + 3` and must
  change neither prices nor the card.
- Rationale: `psql` is installed and used in 001's quickstart. No new dependency. The service-role
  key stays out of the test code. `supabase/fixtures/` is outside `supabase/tests/`, so
  `supabase test db` ignores it.

## R17. Content Security Policy (D19)

- Decision: no CSP in 002. `OPEN-QUESTIONS.md` (2026-11-12) requires it before the first deploy, in
  a hardening spec after 003. Facts for that spec: SvelteKit 3.2.0 supports
  `nonce="%sveltekit.nonce%"` on inline scripts in `app.html` when `kit.csp` is set, and the bar
  widths are SSR `style="…"` attributes that will need `style-src-attr` handling.
