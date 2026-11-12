# Feature Specification: Public Dashboard

**Feature Branch**: `feat/public-dashboard`

**Created**: 2026-11-11

**Status**: Draft

**Input**: User description: "UI from design_handoff_fuel_price_dashboard/, first part: the public Dashboard with the shared layout, theme and responsive shell." Grilling decisions D1 to D14 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

This feature is the first of three UI specs (D1): 002 public views, 003 sign-in and Contribute,
004 admin. Analytics comes later in its own spec (D2). It reads the data layer from
`specs/001-database-schema` and changes nothing in it.

### User Story 1 - Find where fuel is cheapest (Priority: P1)

Any visitor, without signing in, opens the Dashboard and sees stations in Cagayan de Oro ranked by
price for one fuel (diesel, gasoline or kerosene). They switch fuel, page through the ranking, see
the cheapest station per fuel, and see how old each price is and whether it is an estimate.

**Why this priority**: answering "where is fuel cheapest right now" is the product.

**Independent Test**: load invented stations, products, price reports and shifts, open the
Dashboard, and compare the ranking, the cheapest card and the age labels with hand-computed
values.

**Acceptance Scenarios**:

1. **Given** 12 invented stations with gasoline prices, **When** a visitor opens the Dashboard,
   **Then** gasoline is selected, stations 1 to 10 are listed from cheapest to most expensive, and
   the page reads "Page 1 of 2".
2. **Given** the ranking on page 1, **When** the visitor selects Next, **Then** stations 11 and 12
   are shown and Next is unavailable.
3. **Given** a station selling Xtra Advance 91 at 62.45 and Blaze 95 at 68.10, **When** gasoline
   is selected, **Then** the station appears once at 62.45 with "Xtra Advance 91" beside the price.
4. **Given** the gasoline ranking, **When** the visitor selects Diesel, **Then** the list re-ranks
   by diesel price and the diesel selection is highlighted.
5. **Given** a price reported today with no shift applied, **When** it is shown, **Then** its row
   reads "Reported today" and has no "est." label.
6. **Given** a price reported 12 days ago with a later shift applied, **When** it is shown,
   **Then** its row reads "12 days ago · est.", and a legend under the ranking explains "est.".
7. **Given** invented prices, **When** the Dashboard loads, **Then** "Cheapest in CDO" shows, for
   each of diesel, gasoline and kerosene, the lowest price with its station, product, report age
   and, when a shift applied, "est." (for example "Petron · Lapasan · 2 days ago · est.").
8. **Given** the selected fuel, **When** the ranking is shown, **Then** a line under it shows the
   city average of the ranked prices, and each row's bar is scaled to the highest ranked price.
9. **Given** no approved prices exist, **When** a visitor opens the Dashboard, **Then** the ranking
   and "Cheapest in CDO" read "No prices reported yet".
10. **Given** the price data cannot be loaded, **When** a visitor opens the Dashboard, **Then** an
    error page reads "Prices couldn't load. Try again later." and no prices are shown.

---

### User Story 2 - See this week's price adjustment (Priority: P2)

A visitor sees whether each fuel went up or down in the latest weekly adjustment, and by how much.

**Why this priority**: the weekly adjustment is the news people check, but the ranking is useful
without it.

**Independent Test**: load invented shifts for several brands, open the Dashboard, and compare the
adjustment card with hand-computed values.

**Acceptance Scenarios**:

1. **Given** every brand's latest diesel shift is +1.20 on Oct 27, **When** the card is shown,
   **Then** Diesel reads "▲ +₱1.20" and "Increase", and the card reads "As of Oct 27, 2026".
2. **Given** latest gasoline shifts of -0.85 and -0.60 from two brands in the same week, **When**
   the card is shown, **Then** Gasoline reads "▼ −₱0.60 – ₱0.85" and "Rollback".
3. **Given** latest kerosene shifts of +0.40 and -0.30 from two brands in the same week, **When**
   the card is shown, **Then** Kerosene reads "Mixed" with no arrow.
4. **Given** no shifts exist for a fuel, **When** the card is shown, **Then** that fuel reads "No
   adjustment recorded yet".

---

### User Story 3 - Use the app comfortably on any screen and in any light (Priority: P2)

A visitor uses the app on a phone or a computer, in dark or light mode. The app follows their
device's mode on the first visit and remembers their choice afterwards. The header shows the app
name, the tabs and the mode toggle.

**Why this priority**: most visitors check prices on a phone, and the shell is shared by every
later screen.

**Independent Test**: open the Dashboard at phone and desktop widths with the device set to dark
and to light, use the toggle, reload, and visit each tab.

**Acceptance Scenarios**:

1. **Given** a first-time visitor whose device is set to light, **When** they open the app,
   **Then** it shows in light mode. With the device set to dark, it shows in dark mode.
2. **Given** a visitor who switches to dark mode, **When** they reload or return later on the same
   browser, **Then** the app opens in dark mode with no flash of the other mode.
3. **Given** a desktop width, **When** the app opens, **Then** the header shows "CDO Fuel Price
   Tracker", the Dashboard, Analytics and Contribute tabs, and the mode toggle, with no sign-in
   controls.
4. **Given** a phone width, **When** the visitor opens the menu button, **Then** the three tabs
   are listed, and the Dashboard cards stack in one column.
5. **Given** any width, **When** the visitor opens Analytics or Contribute, **Then** that page
   reads "Coming soon".
6. **Given** a tab, **When** the visitor hovers it, **Then** its underline grows from left to
   right. The active tab has a full underline and full-contrast text.

### Edge Cases

- A station with no approved price for the selected fuel is not ranked for that fuel and never
  shown as 0.
- A station that sells diesel but not kerosene appears in the diesel ranking only.
- Stations with equal prices are ordered by most recent report first, then by brand name, then by
  location. The same order breaks ties in "Cheapest in CDO".
- Fewer than 11 ranked stations show one page with Prev and Next unavailable.
- The latest week for a fuel is the Monday-to-Sunday week (Asia/Manila) that holds the most recent
  shift for that fuel. Only brands with a shift in that week count. Brands that did not shift that
  week are left out.
- A shift of 0.00 means no change. If every counted shift is 0.00, the fuel reads "No change"
  with no arrow. If zero shifts sit beside shifts in one direction, the range starts at ₱0.00 and
  takes that direction.
- A shift dated in the future is not shown on the card until its effective date, matching the
  data layer.
- Report ages are counted in calendar days in Asia/Manila: "Reported today", "Yesterday", then
  "N days ago".
- If the visitor's browser blocks saved settings, the mode follows the device each visit and the
  toggle still works for the open page.
- The app name wraps or shrinks on narrow phones and never pushes the menu button off screen.

## Requirements *(mandatory)*

### Functional Requirements

**Station ranking**

- **FR-001**: The Dashboard MUST be readable by anyone without signing in.
- **FR-002**: The Dashboard MUST let the visitor choose diesel, gasoline or kerosene, with gasoline
  selected first, and MUST highlight the selected fuel.
- **FR-003**: The ranking MUST list stations from cheapest to most expensive for the selected fuel,
  using each station's cheapest product in that fuel category, and MUST show that product's name
  beside the price (D3).
- **FR-004**: Each ranking row MUST show the rank, brand, location, price, report age and, when a
  shift applied, the "est." label as text (D5).
- **FR-005**: A legend under the ranking MUST explain that "est." means the reported price plus
  weekly adjustments since then.
- **FR-006**: The ranking MUST show 10 stations per page with Prev and Next controls and a "Page N
  of M" label (D11).
- **FR-007**: The ranking MUST show the city average of the ranked prices for the selected fuel and
  a bar per row scaled to the highest ranked price.
- **FR-008**: "Cheapest in CDO" MUST show, for each fuel, the lowest price with its brand,
  barangay, product, report age and, when a shift applied, the "est." label (D3, D16, D17).

**Price adjustment**

- **FR-009**: The adjustment card MUST show, for each fuel, the latest week's shifts across
  brands: one amount when all agree, a range when they differ in one direction, "Mixed" when
  directions differ, and "No adjustment recorded yet" when none exist (D4).
- **FR-010**: Each fuel on the card MUST show direction as both a symbol (▲ or ▼) and a word
  ("Increase" or "Rollback"), never by color alone.
- **FR-011**: The card MUST show the most recent effective date of the shifts it summarizes.

**States**

- **FR-012**: The Dashboard MUST arrive with its prices already in the page, with no loading state
  on first view (D12).
- **FR-013**: With no approved prices, the ranking and "Cheapest in CDO" MUST read "No prices
  reported yet".
- **FR-014**: If price data cannot be loaded, the app MUST show an error page reading "Prices
  couldn't load. Try again later." and MUST NOT show old or zero prices.

**Shell, theme and layout**

- **FR-015**: The header MUST show the name "CDO Fuel Price Tracker", the Dashboard, Analytics and
  Contribute tabs, and the mode toggle. It MUST NOT show sign-in controls (D8, D9, D10).
- **FR-016**: Analytics and Contribute MUST each open their own page reading "Coming soon" (D8).
- **FR-017**: At phone width, the tabs MUST move into a menu opened by a button, and the Dashboard
  cards MUST stack in one column.
- **FR-018**: On the first visit, the mode MUST follow the device's dark or light setting (D7).
- **FR-019**: The mode toggle MUST switch between dark and light, and the choice MUST be
  remembered on that browser and applied before the page is shown.
- **FR-020**: The app MUST use the Teal palette only, with the colors, type, spacing and
  interactions of the design handoff (D6).
- **FR-021**: The app MUST NOT load fonts or other files from third-party servers (D13).

**Accessibility**

- **FR-022**: All text MUST meet 4.5:1 contrast in both modes, and every control MUST be usable
  by keyboard with a visible focus indicator.
- **FR-023**: Every non-text element that carries meaning (bars, ▲ ▼ symbols, the mode and menu
  buttons) MUST have a text alternative, following `WCAG-TEXT-ALTERNATIVES.md`.

### Key Entities

This feature reads the 001 entities and adds none.

- **Current price** (from 001): a station product's computed price with its report date, latest
  shift date and estimate flag.
- **Station, brand, fuel product, fuel category, barangay** (from 001): give each price its
  station name, brand, product name, fuel and location.
- **Shift** (from 001): a brand's weekly amount for a fuel category, with its effective date.
- **Mode preference**: the visitor's dark or light choice, kept only in their own browser.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of test cases, the ranking order, displayed prices, product names, city
  average and "Cheapest in CDO" match hand-computed values to the centavo.
- **SC-002**: In 100% of test cases, the adjustment card matches the hand-computed amount, range,
  "Mixed", "No change" or empty text for each fuel.
- **SC-003**: Every displayed price shows its age, and every estimate shows the "est." label, in
  100% of test cases.
- **SC-004**: A visitor on a phone finds the cheapest station for a chosen fuel within 10 seconds
  of opening the app, with at most one tap to change fuel.
- **SC-005**: A returning visitor's chosen mode shows on 100% of reloads with no visible flash of
  the other mode.
- **SC-006**: The visitor's browser makes no requests to third-party servers when loading the app.
- **SC-007**: Side-by-side review against the design handoff shows no visible differences in
  color, type or spacing in dark and light, at desktop and phone widths.
- **SC-008**: All text passes 4.5:1 contrast in both modes, and every control is reachable and
  usable by keyboard alone.

## Assumptions

- The data layer from 001 is built and its public read access returns current prices, stations,
  products and shifts without sign-in. This feature changes no tables, rules or functions.
- Sign-in, the user menu and Contribute come in 003. Admin screens come in 004. Analytics comes in
  its own later spec once price history exists (D1, D2).
- The palette options, sample data and photo upload in the handoff are design-tool material, not
  features (D6).
- Behavior not decided in the grill follows the design handoff, which is the source of truth for
  look and layout.
- The user implements this feature by hand as a learning project. Agents write the plan and tasks,
  explain each task, review the user's code and run the checks, but do not write the app code
  unless asked.
- Test data uses invented stations, brands and prices.
