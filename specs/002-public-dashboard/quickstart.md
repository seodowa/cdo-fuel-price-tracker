# Quickstart: Public Dashboard

Proves SC-001 to SC-003 (Vitest), the D14 smoke flows (Playwright), SC-005 (no flash), SC-006
(no third-party requests) and SC-007 / SC-008 (by eye and keyboard).

## Prerequisites

1. Docker running and the local Supabase stack from 001 (`specs/001-database-schema/quickstart.md`):
   ```sh
   supabase start
   supabase db reset
   ```
2. `.env` in the repository root (copy `.env.example`). Values from `supabase status`:
   `SUPABASE_URL` = API URL (`http://127.0.0.1:54321`), `SUPABASE_PUBLISHABLE_KEY` = publishable key,
   `SUPABASE_DB_URL` = DB URL (host `127.0.0.1`, used only by the e2e fixtures, D21).
3. `npm install` (includes `@supabase/supabase-js`, D15). `psql` on the PATH.

## Run

```sh
npm run check          # svelte-check, strict TypeScript
npm run lint           # prettier + eslint
npm run test:unit -- --run   # Vitest: src/lib/dashboard.spec.ts, src/routes/page.server.spec.ts
npm run test:e2e       # Playwright: build, preview on :4173, src/routes/dashboard.e2e.ts and shell.e2e.ts
```

The e2e run truncates price tables in the local database (`supabase/fixtures/empty.sql`). Run
`supabase db reset` afterwards for a clean database.

## Expected

| Step        | Expected                                                                                                                                                                                                                   |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| check, lint | no errors                                                                                                                                                                                                                  |
| Vitest      | every case in both spec files passes                                                                                                                                                                                       |
| Playwright  | empty state, ranking, pagination, fuel switch, unknown fuel falls back, prices without JS, adjustment card, first-visit mode follows the device, invalid saved value ignored, saved mode kept after reload with app JS blocked, mobile menu, Coming soon pages, no third-party requests: all pass |

## By hand

1. `psql "$SUPABASE_DB_URL" -f supabase/fixtures/dashboard.sql` (after loading `.env` into the shell),
   then `npm run dev` and open http://localhost:5173.
2. Side by side with `design_handoff_fuel_price_dashboard/design_files/Fuel Price Dashboard.dc.html`
   and `… Mobile.dc.html`, in dark and light, at 1280px and 390px (SC-007).
3. DevTools Network: every request goes to the app origin (SC-006).
4. Tab through the page: every control is reachable and shows a focus ring (SC-008).
5. Turn on "reduce motion" in the OS: tab underline no longer animates.
6. Switch the OS between dark and light with no saved choice (clear site data): the app follows it, also with JavaScript disabled.
7. Stop Supabase (`supabase stop`) and reload: the error page shows (FR-014), and "Try again" works after `supabase start`.
8. Block site data for localhost: the app follows the device and the toggle still switches the open page.
9. SC-004: on a phone-sized window, find the cheapest station for a chosen fuel within 10 seconds with at most one tap.
