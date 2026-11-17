# Handoff — 2026-11-16 15:08

## Goal

Build 002 public dashboard (ranking, adjustment card, header, theme) from the design handoff.

## Where we are

Feature specs/002-public-dashboard, lane full, phase build, task T012 next. 19 of 50 tasks ticked.
Working mode: Claude writes the code, one test+code pair at a time, in the main session (no
st-test/st-build agents). Claude stops after each pair with a per-task summary ("T0xx title"
headings). The user reviews, Claude ticks on the user's OK, and the user commits.
The user implemented T010 + T011 themselves as a one-off. That does not change the working mode
above, and it is not saved as a memory.
Frontend first: pure functions in src/lib/dashboard-functions.ts before backend work.

Done this session:

- T010 + T011 ticked. rankStations in src/lib/dashboard-functions.ts: a Map<stationId, PriceRow>
  keeps each station's cheapest product (tie: product name that sorts first), then one comparator
  sorts by cents, newer reportedAt, brand, "{street}, {barangay}", then ranks from 1.
- Tests in src/lib/dashboard-functions.spec.ts use a `row(overrides)` PriceRow helper and a mixed
  `rows` fixture. The same-station tie test runs both input orders (it caught a bug where any
  non-zero localeCompare replaced the stored row).
- Commit 0dc477a holds the T010 tests and an earlier rankStations state. The final implementation,
  the tasks.md ticks and this handoff are still uncommitted.
- `npm run format` was run on the whole repo. Besides the T010/T011 files, it changed only
  formatting (table padding in spec docs, quote style, line endings) in app.css, Roadblock.svelte,
  +error.svelte, analytics and contribute pages, shell.e2e.ts, contracts/dashboard.md,
  decisions.md, quickstart.md and tasks.md. Suggested split: one commit for T011 + tasks.md ticks,
  one `style: apply prettier formatting` commit for the rest. The user decides.

Check state: 18/18 unit tests pass, ESLint clean, Prettier clean. `npm run check` has one expected
error: src/routes/page.server.spec.ts (from 69ee68c) imports ./+page.server.ts, which T016/T017
will create.

## Decisions made

- No new decisions this session.

## Open questions

- Q1. CSP setup before first deploy (OPEN-QUESTIONS.md, a hardening spec later).
- Q2. tasks.md T018 text still says resolve(); fix in the Close phase (user's call).

## Blockers

- none

## Next step

User commits the work above. Then T012 + T013: failing tests for paginate, averageCents,
formatCents and barPercent (cases listed in T012), then implement them (page size 10,
`Math.round(sum / count)`, `(c / 100).toFixed(2)`, `Math.round(cents / highestCents * 100)`).
Then T014 + T015 (pickFuel), then T028-T031. Backend (T001, T004, T016, T017, T019, T020) comes
after. Run vitest from the repo root; running it from specs/ fails and creates a stray
.svelte-kit folder.

<!-- st-facts:start -->

## Facts (2026-11-17 20:48:23 +0800)

- Branch: development
- Phase: build | Lane: full | Feature: 002-public-dashboard
- Tasks: 21/50

Last 5 commits:

```
d8d1f00 feat: add station ranking card with pagination
0a95b81 feat: Implement paginate, averageCents, formatCents, barPercent
72136d6 feat: finish implementing rankStations() + updated unit tests
0dc477a feat: write unit tests for rankStations
16c7782 feat: implement ageLabel function + tests
```

Uncommitted files:

```

```

<!-- st-facts:end -->
