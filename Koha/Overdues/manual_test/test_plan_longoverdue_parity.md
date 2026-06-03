# Overdue Triggers — longoverdue.pl Parity Test Plan

Manual exercises of `misc/cronjobs/process_circulation_triggers.pl` covering the
distinct enactment variants that `misc/cronjobs/longoverdue.pl` could
produce via its CLI flags and the related sysprefs
(`WhenLostChargeReplacementFee`, `MarkLostItemsAsReturned`,
`WhenLostForgiveFine`).

## Scope

Seven scenarios, each one self-contained:

| # | Scenario              | longoverdue equivalent                                              |
|---|-----------------------|---------------------------------------------------------------------|
| 1 | lost_only             | `--lost 30=1`                                                       |
| 2 | lost_charge           | `--lost 60=2 --charge 2`                                            |
| 3 | lost_charge_returned  | `--lost 90=2 --charge 2 --mark-returned`                            |
| 4 | lost_returned         | `--lost 30=1 --mark-returned` (no charge)                           |
| 5 | lost_charge_forgive   | `--lost 60=2 --charge 2`, `WhenLostForgiveFine=1`                   |
| 6 | full                  | `--lost 90=2 --charge 2 --mark-returned`, `WhenLostForgiveFine=1`   |
| 7 | graduated             | `--lost 30=1 --lost 60=2 --charge 2` (two ranges, two checkouts)    |

The mapping is intentionally **row-explicit**: every flag the legacy
script would have set via CLI or syspref fallback is set on the trigger
row, so the scenarios don't rely on syspref state beyond the defaults
in `sysprefs.sql`.

Out of scope: notice-side actions (deferred), scoping axes
(`--category`/`--library`/`--itemtype`), `--skip-lost-value` eligibility
pre-filter, run-to-run progression of a single item through multiple
delay ranges (a runtime concern handled across separate cron firings).

## Assumptions

- Dev env is **koha-testing-docker** (or anything carrying the standard
  sample library `CPL`, patron category `PT`, itemtype `BK`).
- DB is reachable from the script (`koha-mysql kohadev` or `mysql`
  inside `ktd --shell`).
- The base `circ_rules.sql` smoke-test seed is **not** loaded
  simultaneously — its identifiers (`OVERDUE_TEST_*`) are different but
  its rule rows on (CPL,PT,BK) would compose with these. Run scenarios
  in isolation.

## Shared setup (once)

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/sysprefs.sql
```

This pins `CircControl`, `HomeOrHoldingBranch`, `LostChargesControl`
and friends to documented defaults. The per-trigger row settings drive
behaviour from there. `WhenLostChargeReplacementFee`,
`MarkLostItemsAsReturned`, and `WhenLostForgiveFine` are deprecated and
not consulted by the new script (see spec.md), so the table column 3
references are historical-parity context only.

---

## Scenario 1 — `lost_only`

### Goal

Mirror `longoverdue.pl --lost 30=1`. Single trigger row sets
`itemlost = 1` at 30 days overdue.

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/lost_only.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- itemlost set to 1
SELECT itemlost FROM items WHERE barcode = 'LO_PARITY_LOST_ONLY_ITEM';
-- Expected: 1

-- Issue still open (no mark_returned on this row)
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_ONLY_ITEM');
-- Expected: 1 row

-- No charge accountline created
SELECT debit_type_code, amount, interface FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_ONLY_PATRON');
-- Expected: no rows

-- No debarment
SELECT borrower_debarment_id FROM borrower_debarments
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_ONLY_PATRON');
-- Expected: no rows
```

### Behavioural delta vs longoverdue.pl

Legacy set `itemlost` directly without calling `LostItem`, so outstanding
transfers on the item were left in place. The new `enact_lost` calls
`Koha::Item->mark_lost`, which cancels outstanding transfers as a
side effect. If the item has no outstanding transfers (the default
seed state), the two behaviours are observationally identical.

### Re-run safety

Run the script a second time without re-seeding. `itemlost` stays at
`1`; `enact_lost` is idempotent on already-lost items.

### Teardown

```sql
DELETE FROM borrower_debarments
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_ONLY_PATRON');
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_ONLY_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_ONLY_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_ONLY_ITEM');
DELETE FROM items WHERE barcode = 'LO_PARITY_LOST_ONLY_ITEM';
DELETE FROM biblio WHERE title = 'LO Parity lost_only Title';
DELETE FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_ONLY_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost');
```

---

## Scenario 2 — `lost_charge`

### Goal

Mirror `longoverdue.pl --lost 60=2 --charge 2`. Trigger row: `lost=2`,
`charge=1`. Replacement fee posted; issue stays open (no mark_returned).

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/lost_charge.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- itemlost set to 2
SELECT itemlost FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_ITEM';
-- Expected: 2

-- Issue still open
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_ITEM');
-- Expected: 1 row

-- LOST replacement-fee accountline at item.replacementprice (10.00),
-- interface 'cron', library_id resolved via branch_for_fee_context
-- (LostChargesControl=ItemHomeLibrary + homebranch  =>  CPL)
SELECT debit_type_code, amount, amountoutstanding, interface, branchcode
  FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_PATRON');
-- Expected: 1 row — debit_type_code='LOST', amount=10.00,
--           amountoutstanding=10.00, interface='cron', branchcode='CPL'
```

### Re-run safety

Re-run the script. `add_lost_replacement_fee` may post a second LOST
accountline — the new pipeline does not currently deduplicate. **Note
this**; it's a behaviour to revisit when wiring eligibility pre-filter.

### Teardown

```sql
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_ITEM');
DELETE FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_ITEM';
DELETE FROM biblio WHERE title = 'LO Parity lost_charge Title';
DELETE FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost', 'overdue_1_charge');
```

---

## Scenario 3 — `lost_charge_returned`

### Goal

Mirror `longoverdue.pl --lost 90=2 --charge 2 --mark-returned`. Trigger
row: `lost=2, charge=1, mark_returned=1`. Issue archived to
`old_issues`, fee posted, item flagged lost.

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/lost_charge_returned.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- itemlost set to 2
SELECT itemlost, onloan FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_RET_ITEM';
-- Expected: itemlost=2, onloan IS NULL (MarkIssueReturned clears it)

-- Issue removed; row archived to old_issues
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_RET_ITEM');
-- Expected: no rows

SELECT issue_id, returndate FROM old_issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_RET_ITEM');
-- Expected: 1 row, returndate set

-- LOST accountline (re-keyed to old_issue_id by MarkIssueReturned)
SELECT debit_type_code, amount, interface, issue_id, old_issue_id
  FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_RET_PATRON');
-- Expected: 1 row, debit_type_code='LOST', amount=10.00, interface='cron',
--           old_issue_id populated (issue_id may be NULL after archival)
```

### Re-run safety

Re-run: issue is already archived, so no second mark_returned. The
charge enactor may still attempt to find/post — currently, the new
`enact_charge` will try to look up the issue and fail-soft if not
found. Verify either (a) no new LOST accountline, or (b) one new
accountline with `issue_id` NULL.

### Teardown

```sql
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_RET_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_RET_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_RET_ITEM');
DELETE FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_RET_ITEM';
DELETE FROM biblio WHERE title = 'LO Parity lost_charge_returned Title';
DELETE FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_RET_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost', 'overdue_1_charge', 'overdue_1_mark_returned');
```

---

## Scenario 4 — `lost_returned`

### Goal

Mirror `longoverdue.pl --lost 30=1 --mark-returned` with no charge.
Trigger row: `lost=1, mark_returned=1`. The seed also includes a
pre-existing UNRETURNED OVERDUE accountline — without `forgive_fine` on
the row, that line stays UNRETURNED (parity with the legacy
non-charging mark-returned branch, which doesn't run
`_FixOverduesOnReturn`).

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/lost_returned.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- itemlost set to 1
SELECT itemlost, onloan FROM items WHERE barcode = 'LO_PARITY_LOST_RET_ITEM';
-- Expected: itemlost=1, onloan IS NULL

-- Issue archived
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_RET_ITEM');
-- Expected: no rows
SELECT issue_id, returndate FROM old_issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_RET_ITEM');
-- Expected: 1 row

-- Pre-seeded OVERDUE fine: still UNRETURNED, still 5.00 outstanding,
-- no FORGIVEN credit applied. (No new LOST charge — row has no charge=1)
SELECT debit_type_code, credit_type_code, amount, amountoutstanding, status
  FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_RET_PATRON');
-- Expected: 1 row — debit_type_code='OVERDUE', amount=5.00,
--           amountoutstanding=5.00, status='UNRETURNED'
```

### Behavioural note

`MarkIssueReturned` may convert the OVERDUE accountline's status from
UNRETURNED to RETURNED depending on
`AutoRemoveOverduesRestrictions`/related sysprefs. Confirm against the
documented defaults in `sysprefs.sql`. If RETURNED appears, that's the
mark-returned step doing its job, not forgive_fine.

### Re-run safety

Issue already archived; idempotent.

### Teardown

```sql
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_RET_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_RET_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_RET_ITEM');
DELETE FROM items WHERE barcode = 'LO_PARITY_LOST_RET_ITEM';
DELETE FROM biblio WHERE title = 'LO Parity lost_returned Title';
DELETE FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_RET_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost', 'overdue_1_mark_returned');
```

---

## Scenario 5 — `lost_charge_forgive`

### Goal

Mirror `longoverdue.pl --lost 60=2 --charge 2` with
`WhenLostForgiveFine=1`. Trigger row: `lost=2, charge=1,
forgive_fine=1`. Pre-seeded UNRETURNED OVERDUE (8.00) should be
forgiven; new LOST charge (10.00) posted.

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/lost_charge_forgive.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- itemlost set to 2; issue still open (no mark_returned)
SELECT itemlost FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_FORGIVE_ITEM';
-- Expected: 2

SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_FORGIVE_ITEM');
-- Expected: 1 row

-- Accountlines: original OVERDUE (forgiven), new FORGIVEN credit, new LOST debit
SELECT debit_type_code, credit_type_code, amount, amountoutstanding, status, interface
  FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_FORGIVE_PATRON')
  ORDER BY accountlines_id;
-- Expected: 3 rows —
--   1) OVERDUE debit, amount=8.00, amountoutstanding=0.00 (forgiven)
--   2) FORGIVEN credit, amount=-8.00 (or amount=8.00 stored as credit), amountoutstanding=0.00
--   3) LOST debit, amount=10.00, amountoutstanding=10.00, interface='cron'
```

### Re-run safety

Forgive runs over UNRETURNED OVERDUE matches; on re-run the original
fine is already forgiven (amountoutstanding=0). `forgive_debit` returns
the original credit (no second credit). The LOST charge may
double-post — same caveat as scenario 2.

### Teardown

```sql
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_FORGIVE_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_FORGIVE_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_FORGIVE_ITEM');
DELETE FROM items WHERE barcode = 'LO_PARITY_LOST_CHARGE_FORGIVE_ITEM';
DELETE FROM biblio WHERE title = 'LO Parity lost_charge_forgive Title';
DELETE FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_FORGIVE_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost', 'overdue_1_charge', 'overdue_1_forgive_fine');
```

---

## Scenario 6 — `full`

### Goal

Mirror `longoverdue.pl --lost 90=2 --charge 2 --mark-returned` with
`WhenLostForgiveFine=1`. Everything fires: lost, charge, mark_returned,
forgive_fine.

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/full.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- itemlost set; onloan cleared by MarkIssueReturned
SELECT itemlost, onloan FROM items WHERE barcode = 'LO_PARITY_FULL_ITEM';
-- Expected: itemlost=2, onloan IS NULL

-- Issue archived
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_FULL_ITEM');
-- Expected: no rows
SELECT issue_id, returndate FROM old_issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_FULL_ITEM');
-- Expected: 1 row

-- Accountlines: OVERDUE forgiven (12.00 -> 0.00 outstanding), FORGIVEN
-- credit, new LOST debit (10.00)
SELECT debit_type_code, credit_type_code, amount, amountoutstanding, status, interface
  FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_FULL_PATRON')
  ORDER BY accountlines_id;
-- Expected: 3 rows as in scenario 5, with LOST replacing OVERDUE as the
-- single outstanding balance, plus an old_issue_id linkage on the LOST
-- row.
```

### Re-run safety

Same caveats as scenario 5 — forgive idempotent, LOST charge may
double-post if re-run.

### Teardown

```sql
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_FULL_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_FULL_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_FULL_ITEM');
DELETE FROM items WHERE barcode = 'LO_PARITY_FULL_ITEM';
DELETE FROM biblio WHERE title = 'LO Parity full Title';
DELETE FROM borrowers WHERE cardnumber = 'LO_PARITY_FULL_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost', 'overdue_1_charge',
                      'overdue_1_mark_returned', 'overdue_1_forgive_fine');
```

---

## Scenario 7 — `graduated`

### Goal

Mirror `longoverdue.pl --lost 30=1 --lost 60=2 --charge 2`. Two trigger
rule sets on the same context, two checkouts at distinct delays. The
day-30 checkout should fire trigger 1 (itemlost=1 only); the day-60
checkout should fire trigger 2 (itemlost=2 + charge).

### Setup

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules/graduated.sql
```

### Run

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

### Verify

```sql
-- Checkout 1 (day 30): itemlost=1, issue still open, no accountlines
SELECT itemlost FROM items WHERE barcode = 'LO_PARITY_GRADUATED_ITEM_1';
-- Expected: 1
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_GRADUATED_ITEM_1');
-- Expected: 1 row
SELECT accountlines_id FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_GRADUATED_PATRON_1');
-- Expected: no rows

-- Checkout 2 (day 60): itemlost=2, issue still open, LOST 10.00 accountline
SELECT itemlost FROM items WHERE barcode = 'LO_PARITY_GRADUATED_ITEM_2';
-- Expected: 2
SELECT issue_id FROM issues
  WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'LO_PARITY_GRADUATED_ITEM_2');
-- Expected: 1 row
SELECT debit_type_code, amount, interface FROM accountlines
  WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_GRADUATED_PATRON_2');
-- Expected: 1 row — debit_type_code='LOST', amount=10.00, interface='cron'
```

### Behavioural note

Legacy `longoverdue.pl` iterates ranges in descending delay order and
uses `--skip-lost-value` to avoid re-processing items already at the
target lost value. The new pipeline does not yet implement equivalent
eligibility gating; each `(branch,category,itemtype,delay)` rule set
fires on every matching overdue checkout, every run. Single-item
progression from delay 30 → 60 across separate cron firings is an
eligibility-pre-filter concern, out of scope here.

### Re-run safety

Same caveat as scenario 2 — re-running posts duplicate LOST
accountlines for the day-60 item.

### Teardown

```sql
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers
    WHERE cardnumber IN ('LO_PARITY_GRADUATED_PATRON_1', 'LO_PARITY_GRADUATED_PATRON_2'));
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items
    WHERE barcode IN ('LO_PARITY_GRADUATED_ITEM_1', 'LO_PARITY_GRADUATED_ITEM_2'));
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items
    WHERE barcode IN ('LO_PARITY_GRADUATED_ITEM_1', 'LO_PARITY_GRADUATED_ITEM_2'));
DELETE FROM items WHERE barcode IN ('LO_PARITY_GRADUATED_ITEM_1', 'LO_PARITY_GRADUATED_ITEM_2');
DELETE FROM biblio WHERE title IN ('LO Parity graduated Title 1', 'LO Parity graduated Title 2');
DELETE FROM borrowers WHERE cardnumber IN ('LO_PARITY_GRADUATED_PATRON_1', 'LO_PARITY_GRADUATED_PATRON_2');
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_lost',
                      'overdue_2_delay', 'overdue_2_lost', 'overdue_2_charge');
```
