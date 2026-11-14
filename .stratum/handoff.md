# Handoff — 2026-11-14 21:42

## Goal
Build 002 public dashboard (ranking, adjustment card, header, theme) from the design handoff.

## Where we are
Feature specs/002-public-dashboard, lane full, phase build, task T010 next. 17 of 50 tasks ticked.
Working mode changed this session: Claude writes the code, one test+code pair at a time, in the main
session (no st-test/st-build agents). Claude stops after each pair with a per-task summary
("T0xx title" headings). The user reviews, Claude ticks on the user's OK, and the user commits.
Frontend first: pure functions in src/lib/dashboard-functions.ts before backend work.

Done this session: T002, T037-T040, T042-T045 ticked (shell); T018 error page with a Roadblock
component (src/lib/components/Roadblock.svelte, SVG sign showing the status code); T006-T009
joinRows and ageLabel with Vitest tests in src/lib/dashboard-functions.spec.ts.
Shell test (3) in tests/e2e/shell.e2e.ts was tightened (title, h1, exact "Coming soon").
Playwright Chromium is installed on this machine (other machines: npx playwright install chromium).

## Decisions made
- D23. 404 shows "Page not found" with a Dashboard link, other errors keep the message and "Try again" (reloading a wrong link fails again). In decisions.md.
- D24. Error page shows an SVG roadblock with the status code on a yellow diamond sign (gives the code a place; labelled "Error <code>"). In decisions.md.
- Error page "Try again" uses page.url.href, not resolve() (resolve only takes known routes and would double the base path). One ESLint line disable with the reason.
- ageLabel shows "Reported today" for a future date. No validation for invalid dates (they come from a Postgres date column).
- Code comments never cite decision codes (D23, R8, FR-014). Write the reason in words.
- .stratum/handoff.md is tracked in git so work can continue on another machine; the rest of .stratum/ stays ignored.

## Open questions
- Q1. CSP setup before first deploy (OPEN-QUESTIONS.md, a hardening spec later).
- Q2. tasks.md T018 text still says resolve(); fix in the Close phase (user's call).

## Blockers
- none

## Next step
T010 + T011: write failing rankStations tests in src/lib/dashboard-functions.spec.ts (research R5), then implement rankStations. Then T012-T015 (paginate, averageCents, formatCents, barPercent, pickFuel), then T028-T031. Backend (T001, T004, T016, T017, T019, T020) comes after.
<!-- st-facts:start -->
## Facts (2026-11-14 21:44:40 +0800)
- Branch: development
- Phase: build | Lane: full | Feature: 002-public-dashboard
- Tasks: 17/50

Last 5 commits:
```
3bc044b feat: implement joinRow function with its respective test
13ff9ba feat: implement error pages with illustration
28f52db feat: add title and headings to Analytics and Contribute page + tests
45dd965 feat: add focus-visible and reduced motion accessibility rules
69ee68c feat: add dashboard scaffolding + unit and e2e tests
```

Uncommitted files:
```
 M .gitignore
 M specs/002-public-dashboard/tasks.md
 M src/lib/dashboard-functions.spec.ts
 M src/lib/dashboard-functions.ts
?? .stratum/handoff.md
```
<!-- st-facts:end -->
