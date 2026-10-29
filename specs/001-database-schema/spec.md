# Feature Specification: Database Schema

**Feature Branch**: `feat/database-schema`

**Created**: 2026-10-29

**Status**: Draft

**Input**: User description: "Database schema for the fuel price tracker, following the 2026-10-28 entries in DECISIONS.md (locations, brands, fuel categories and products, station products, baselines, shifts per brand and category, overrides, computed current price)." Grilling decisions D1 to D14 are in `decisions.md`.

## User Scenarios & Testing *(mandatory)*

This feature delivers the data layer only (D2). Screens come in later features. Each story is tested
directly against the data layer.

### User Story 1 - Read current prices (Priority: P1)

Anyone, signed in or not, reads the current price of every fuel product at every station. Each
price is computed from the latest approved baseline or override plus every weekly shift for that
brand and fuel category published since then. Each price says when it was last reported, when it
was last shifted, and whether it is an estimate.

**Why this priority**: showing prices is the product. Every other story feeds this one.

**Independent Test**: load invented stations, products, baselines, overrides and shifts, then
read current prices and compare them with hand-computed values.

**Acceptance Scenarios**:

1. **Given** a station product with a baseline of 60.00 on Oct 1 and brand gasoline shifts of
   +1.20 (Oct 7) and -0.50 (Oct 14), **When** anyone reads prices on Oct 15, **Then** the price
   is 60.70, reported Oct 1, shifted Oct 14, marked as an estimate.
2. **Given** the same product with an approved override of 61.00 on Oct 15 and a +0.30 shift on
   Oct 21, **When** anyone reads prices on Oct 22, **Then** the price is 61.30, reported Oct 15,
   shifted Oct 21, marked as an estimate.
3. **Given** a baseline with no later shift, **When** anyone reads prices, **Then** the price
   equals the baseline and is not marked as an estimate.
4. **Given** two gasoline products of one brand at one station, **When** one gasoline shift is
   published for that brand, **Then** both prices move by the shift amount.
5. **Given** a shift for brand A, **When** prices are read, **Then** stations of brand B are
   unchanged.
6. **Given** an anonymous reader, **When** they read prices, **Then** no submitter identity is
   returned.

---

### User Story 2 - Submit price data for approval (Priority: P1)

A signed-in user submits a new station, a baseline, a branch override or a correction to an
existing baseline or override. The submission waits as pending. An admin approves or rejects it.
Approval applies it: a new station, baseline or override becomes a live record, and a correction
updates the existing record in place. Rejection changes nothing live.

**Why this priority**: without submissions there are no baselines, so no prices to show.

**Independent Test**: as invented users and an invented admin, submit, approve and reject, then
check live records and current prices.

**Acceptance Scenarios**:

1. **Given** a signed-in user, **When** they submit a baseline, **Then** it is stored as pending
   and current prices do not change.
2. **Given** a pending baseline, **When** an admin approves it, **Then** it becomes the live
   baseline and current prices reflect it.
3. **Given** a pending correction to a live override, **When** an admin approves it, **Then** the
   existing override record holds the corrected value and no new override record exists.
4. **Given** a pending submission, **When** an admin rejects it, **Then** live records and prices
   are unchanged.
5. **Given** a user with 20 submissions today, **When** they submit again, **Then** it is refused.
6. **Given** an anonymous visitor, **When** they try to submit, **Then** it is refused.
7. **Given** a user submitting a price of 6.50 or 650.00, **When** they submit, **Then** it is
   refused.
8. **Given** a user submitting a new station, **When** they pick a brand or barangay that does not
   exist, **Then** it is refused.
9. **Given** two users, **When** one reads submissions, **Then** they see only their own, with
   status.

---

### User Story 3 - Record weekly shifts (Priority: P2)

The automated fetcher records a weekly shift per brand and fuel category, with its amount,
effective date and source. Only the trusted server process can record shifts. Out-of-range shifts
are refused and change no price.

**Why this priority**: shifts keep prices current, but prices exist without them.

**Independent Test**: record valid and invalid shifts as the server process and as a regular user,
then check stored shifts and current prices.

**Acceptance Scenarios**:

1. **Given** the server process, **When** it records Petron gasoline +1.20 effective Oct 7 with a
   source URL, fetch time and extractor name, **Then** the shift is stored and applies to every
   Petron gasoline product.
2. **Given** the server process, **When** it records a shift of +120.00, **Then** it is refused
   and no price changes.
3. **Given** the server process, **When** it records a shift without source details, **Then** it
   is refused.
4. **Given** a signed-in user or an admin through the public interface, **When** they try to
   record a shift, **Then** it is refused.
5. **Given** a shift for a brand, category and date that already exists, **When** a second one is
   recorded for the same brand, category and date, **Then** it is refused.

---

### User Story 4 - Moderate accounts and reference data (Priority: P3)

Admins manage brands, fuel categories, fuel products and locations, and ban or unban accounts.
Banned accounts cannot submit. Every admin action is logged.

**Why this priority**: seed data covers launch. Moderation matters once spam appears.

**Independent Test**: as an invented admin and invented users, add reference data, ban a user,
and check the log and the ban effect.

**Acceptance Scenarios**:

1. **Given** an admin, **When** they ban a user, **Then** that user's next submission is refused
   and the ban is logged with admin, time and target.
2. **Given** an admin, **When** they unban the user, **Then** the user can submit again and the
   unban is logged.
3. **Given** a regular user, **When** they try to add a brand, product, category or location, or
   ban someone, **Then** it is refused.
4. **Given** an admin, **When** they approve or reject a submission, **Then** the action is
   logged.
5. **Given** a brand with stations, **When** anyone tries to delete it, **Then** it is refused.

### Edge Cases

- A station product with no approved baseline has no current price and is not shown as 0.
- A shift dated the same day as the anchor baseline or override does not apply to it. Only shifts
  dated after the anchor apply.
- Several shifts on different dates since the anchor all add up.
- When a station product has both baselines and overrides, the anchor is the one with the latest
  observed date, whichever kind it is. On the same date, the override wins.
- A shift dated in the future does not apply until its effective date.
- The 20.00 to 200.00 range applies to stored baselines and overrides. The computed price is not
  range-checked.
- A barangay named "Poblacion" can exist in two cities, but not twice in one city.
- Two stations of one brand in one barangay are told apart by street address. A second station
  with the same brand, barangay and street address is refused.
- Coordinates outside the Philippines are refused. Missing coordinates are allowed.
- Rejected, pending and withdrawn submissions count toward the 20-per-day limit.
- A correction to a record that no longer exists is refused at approval.

## Requirements *(mandatory)*

### Functional Requirements

**Locations and reference data**

- **FR-001**: The system MUST store provinces, cities and barangays, where each barangay belongs
  to one city and each city to one province.
- **FR-002**: Names MUST be unique within their parent: province by name, city by province and
  name, barangay by city and name.
- **FR-003**: The system MUST store brands with unique names, fuel categories (diesel, gasoline,
  kerosene) and fuel products, where each product belongs to one brand and one category and is
  unique by brand and name.
- **FR-004**: Deleting a brand, category, product or location that other records use MUST be
  refused.
- **FR-005**: Seed data MUST load Misamis Oriental, Cagayan de Oro, its 80 barangays and the three
  fuel categories.

**Stations**

- **FR-006**: A station MUST have a name, a brand, a barangay and a street address, and MAY have
  latitude and longitude. City and province come from the barangay and are not stored on the
  station.
- **FR-007**: Stations MUST be unique by brand, barangay and street address.
- **FR-008**: Latitude MUST be between 4 and 22 and longitude between 116 and 127 when present.
- **FR-009**: The system MUST record which fuel products each station sells, and a station may
  sell only products of its own brand.

**Prices**

- **FR-010**: Baselines and overrides MUST each be stored as their own records per station
  product, with the price, the date it was observed and the submitter.
- **FR-011**: Prices MUST be stored as exact decimal amounts with two decimal places and MUST be
  between 20.00 and 200.00 per liter.
- **FR-012**: Shifts MUST be stored per brand, fuel category and effective date, with amount,
  source URL or image reference, fetch time and extractor name, and MUST be unique by brand,
  category and effective date.
- **FR-013**: Shift amounts MUST be between -20.00 and +20.00.
- **FR-014**: The current price of a station product MUST be computed when read, never stored. It
  equals the price of its most recent approved baseline or override (the anchor, override winning
  on the same date) plus the sum of shifts for its brand and category dated after the anchor and
  on or before today.
- **FR-015**: Each current price MUST return the anchor date (reported at), the date of the latest
  applied shift or nothing (shifted at), and whether any shift applied (is estimate).

**Submissions and approval**

- **FR-016**: A signed-in, non-banned user MUST be able to submit a new station, a baseline, an
  override, or a correction to an existing baseline or override. Each submission is stored as
  pending.
- **FR-017**: Pending, rejected and withdrawn submissions MUST NOT change any live record or
  current price.
- **FR-017a**: A user MUST be able to withdraw their own pending submission and MUST NOT be able
  to edit it.
- **FR-017b**: An admin's submission MUST be approved automatically when submitted, is still
  stored and logged as a submission, and does not count toward the daily limit.
- **FR-018**: Admin approval MUST apply a submission: a new station, baseline or override becomes
  a live record, and a correction updates the existing record in place.
- **FR-019**: The data layer MUST refuse a 21st submission by one non-admin account within one
  calendar day (Asia/Manila), counting pending, approved, rejected and withdrawn submissions.
- **FR-020**: Submitted values MUST pass the same range and reference checks as live records
  (FR-007, FR-008, FR-009, FR-011) at submission time.

**Access**

- **FR-021**: Every table MUST deny access by default. Access is granted only by the rules below.
- **FR-022**: Anyone MUST be able to read locations, brands, categories, products, stations,
  station products, shifts and current prices. Public reads MUST NOT return submitter identity.
- **FR-023**: A signed-in user MUST be able to read only their own submissions and their status.
- **FR-024**: Only admins MUST be able to approve or reject submissions, manage reference data,
  ban and unban accounts, and read all submissions.
- **FR-025**: Only the trusted server process MUST be able to record shifts.
- **FR-026**: A banned account MUST NOT be able to submit. Admins set and clear bans.
- **FR-027**: Every admin action (approve, reject, ban, unban, reference data change) MUST be
  logged with the admin, the action, the target record and the time. Only admins can read the
  log.

### Key Entities

- **Province, City, Barangay**: location hierarchy. Barangay belongs to city, city to province.
- **Brand**: an oil company, such as Petron.
- **Fuel category**: diesel, gasoline or kerosene.
- **Fuel product**: a brand's product in a category, such as Petron Xtra 91 (gasoline).
- **Station**: one branch of a brand in a barangay, with street address and optional coordinates.
- **Station product**: a product a station sells.
- **Baseline**: an observed price for a station product, collected once.
- **Override**: an observed price for a station product that differs from the shifted estimate.
  It becomes the new anchor.
- **Shift**: a weekly amount for a brand and category, with its source.
- **Submission**: a pending, approved or rejected change from a user, with submitter and type.
- **Profile**: a user's account data in the app, holding the admin flag and the ban time.
- **Admin log**: one entry per admin action.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For every test case in the acceptance scenarios, the current price matches the
  hand-computed value to the centavo.
- **SC-002**: Every displayed price can be traced to its anchor record and the shifts applied, in
  100% of test cases.
- **SC-003**: 100% of the access rules in FR-021 to FR-027 are covered by an automated test that
  tries the forbidden action and sees it refused.
- **SC-004**: Out-of-range prices, shifts and coordinates are refused in 100% of test cases.
- **SC-005**: The schema and seed data install on an empty database in one step without errors.
- **SC-006**: The platform's security check reports no issues for the data layer.

## Assumptions

- Admin status is held on the profile and set only by an existing admin or the server process.
  The mechanism is decided in the plan.
- The shift fetcher, its sources and the review of failed shifts are a later feature. Failed shift
  review stays an open question in `OPEN-QUESTIONS.md`.
- Screens for viewing, submitting and moderating are later features.
- Only prices per liter are tracked.
- "Today" for the daily limit and dates for shifts use Philippine time (Asia/Manila).
- A shift's effective date is a date, not a time of day. Same-day timing differences between
  brands are ignored.
- Test data uses invented stations, users and prices.
