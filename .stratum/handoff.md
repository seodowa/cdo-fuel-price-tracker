# Handoff — 2026-11-16 00:05

## Goal
Build 002 public dashboard (ranking, adjustment card, header, theme) from the design handoff.

## Where we are
Feature specs/002-public-dashboard, lane full, phase build, T010 + T011 in progress. 17 of 50 tasks ticked.
Working mode: Claude writes the code, one test+code pair at a time, in the main session (no
st-test/st-build agents). Claude stops after each pair with a per-task summary ("T0xx title"
headings). The user reviews, Claude ticks on the user's OK, and the user commits.
Exception for T010 + T011 only: the user is implementing these themselves. Claude describes, helps
with fixtures and tests on request, and reviews. Do not save this as a memory or standing rule.
Frontend first: pure functions in src/lib/dashboard-functions.ts before backend work.

Done this session (uncommitted):
- T010 tests written in src/lib/dashboard-functions.spec.ts: a `row(overrides)` PriceRow helper and
  a mixed `rows` fixture (stations 1-4, gasoline/diesel/kerosene), plus 7 rankStations tests:
  gasoline ranking (scenario 3, diesel station absent, cheapest first, ranks 1-3), kerosene only,
  ties by newer reportedAt, brand, "{street}, {barangay}", same-station same-price product name,
  and `[]` for no rows.
- Test run: 6 rankStations tests fail as intended, 12 others pass. The `[]` test already passes
  against the stub.
- src/lib/dashboard-functions.ts has a user-written stub `rankStations` that maps every row to
  rank 1. The user will replace it with the real implementation (T011).

Known nits in the spec file before commit:
- Line 4 `import { PriceRow }` should be `import type { PriceRow }` (npm run check may fail).
- The user's first two rankStations blocks use double quotes and miss semicolons; run
  `npm run format`.
- Gasoline test expects `{ ...rows[4] }`, `rows[2]`, `rows[0]`, so reordering `rows` breaks it.

## Decisions made
- No new decisions this session.

## Open questions
- Q1. CSP setup before first deploy (OPEN-QUESTIONS.md, a hardening spec later).
- Q2. tasks.md T018 text still says resolve(); fix in the Close phase (user's call).

## Blockers
- none

## Next step
User implements rankStations (T011, research R5): filter by category, keep the cheapest product per
stationId (tie: smaller product name), sort with one comparator (cents asc, reportedAt desc, brand,
"{street}, {barangay}", localeCompare(…, 'en')), add rank from 1, don't mutate the input. Then run
`npm run test:unit -- --run`, `npm run check`, `npm run lint`, `npm run format`. Claude reviews,
ticks T010 + T011 on the user's OK, the user commits. Then T012-T015 (paginate, averageCents,
formatCents, barPercent, pickFuel), then T028-T031. Backend (T001, T004, T016, T017, T019, T020)
comes after.
Run vitest from the repo root; running it from specs/ fails and creates a stray .svelte-kit folder.
<!-- st-facts:start -->
## Facts (2026-11-16 00:05:34 +0800)
- Branch: development
- Phase: build | Lane: full | Feature: 002-public-dashboard
- Tasks: 17/50

Last 5 commits:
```
16c7782 feat: implement ageLabel function + tests
3bc044b feat: implement joinRow function with its respective test
13ff9ba feat: implement error pages with illustration
28f52db feat: add title and headings to Analytics and Contribute page + tests
45dd965 feat: add focus-visible and reduced motion accessibility rules
```

Uncommitted files:
```
 M src/lib/dashboard-functions.spec.ts
 M src/lib/dashboard-functions.ts
 M .stratum/handoff.md
```
<!-- st-facts:end -->
