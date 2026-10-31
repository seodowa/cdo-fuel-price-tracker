# Lessons

Proposed lessons from closed features. Each entry: date, feature, what happened, rule to keep.

## 2026-10-31, 001-database-schema

- L1. What happened: the `current_price` view first bounded only shifts by Manila today, so a
  future-dated price report could become the anchor (fixed in commit 166fa48).
  Rule: when a derived value filters one input by "on or before today", apply the same date bound
  to every input it combines.
- L2. What happened: `private.is_admin()` first checked only `is_admin`, so a banned admin kept
  admin rights (fixed in commit e3d9c75).
  Rule: a privilege check must also test every flag that revokes the privilege.
- L3. What happened: the admin write policies were merged into `for all` policies (e1abb74) and
  restored to per-command policies three minutes later (9dd8055).
  Rule: write RLS policies per command. A `for all` policy also adds a select policy that overlaps
  the public read policy, which the performance advisor flags as `multiple_permissive_policies`.
- L4. What happened: Build removed the `auth.uid()` default from `submission.submitted_by` and added
  `price_report_submitted_by_idx`, but `data-model.md` still showed the old design until Close.
  Rule: a Build task that changes a column, index or policy updates `data-model.md` in the same
  commit.
