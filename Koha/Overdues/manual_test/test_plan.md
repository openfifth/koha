# Overdue Triggers — Base Scenario Test Plan

Manual end-to-end exercise of `misc/cronjobs/process_circulation_triggers.pl` against
default sysprefs.

## Scope

Single scenario: **one overdue checkout, 5 days past due, triggers `restrict`.**

Verifies the full pipeline:

1. `Repository::GetOverdueSummariesForKnownTriggerDelays` fetches the checkout
2. `RuleResolver` resolves the effective rule set keyed `branch|category|itemtype|delay`
3. `ActionExecutor::route_item_actions_to_queue` enqueues the action via the
   CircControl + HomeOrHoldingBranch branchcode resolution
4. `ActionExecutor::process_action_queue` dispatches to `enact_restrict`
5. A debarment row appears in `borrower_debarments`

Other actions (notice, lost, charge, mark_returned, forgive_fine) are out of
scope for the base scenario — `restrict` is chosen because it has no fee /
library_id resolution, no Item/Patron object hydration, and no stubbed
notice-side dependencies.

## Assumptions

- Dev env is **koha-testing-docker** (or anything carrying the standard
  sample library `CPL`, patron category `PT`, itemtype `BK`). Adjust the
  seeds if your env uses different codes.
- DB is reachable from the script (`koha-mysql kohadev` or `mysql` inside
  `ktd --shell`).
- No other in-flight overdue test data — the seeds are idempotent and clear
  prior runs by the same identifiers, but won't touch anything else.

## Setup

Run inside `ktd --shell` (or any env with `koha-mysql` configured):

```sh
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/sysprefs.sql
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/circ_rules.sql
koha-mysql kohadev < Koha/Overdues/manual_test/seeds/overdues.sql
```

Order matters only insofar as the rule-set lookup needs both the circ rule
and the overdue row present at script-run time.

## Execute

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

Expected: no warnings, no errors. Output may include the `Data::Dumper` debug
print of the actions hash from `route_item_actions_to_queue` (left in place
during dev).

## Verify

### 1. Debarment added

```sql
SELECT borrower_debarment_id, type, comment, created FROM borrower_debarments WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'OVERDUE_TEST_PATRON')   AND type = 'OVERDUES';
```

Expected: exactly 1 row, `comment` starting with `OVERDUES_PROCESS `.

### 2. No other side effects

The base rule has only `restrict` set. Confirm nothing else fired:

```sql
-- Item still on loan, not lost
SELECT itemlost, onloan FROM items WHERE barcode = 'OVERDUE_TEST_ITEM';
-- Expected: itemlost = 0, onloan IS NOT NULL

-- Issue still in issues table (not marked returned)
SELECT issue_id, date_due FROM issues
WHERE itemnumber = (SELECT itemnumber FROM items WHERE barcode = 'OVERDUE_TEST_ITEM');
-- Expected: 1 row

-- No new accountlines for this patron
SELECT accountlines_id, debit_type_code, credit_type_code, amount
FROM accountlines
WHERE borrowernumber = (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'OVERDUE_TEST_PATRON');
-- Expected: no rows (or only pre-existing rows unrelated to this run)
```

### 3. Re-run safety

Run the script a second time without re-seeding:

```sh
perl misc/cronjobs/process_circulation_triggers.pl
```

Then re-check query 1 — `AddUniqueDebarment` is idempotent, so still 1 row
(comment may have been refreshed).

## Teardown

Wipes the seed data only:

```sql
DELETE FROM borrower_debarments
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'OVERDUE_TEST_PATRON');
DELETE FROM accountlines
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'OVERDUE_TEST_PATRON');
DELETE FROM issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'OVERDUE_TEST_ITEM');
DELETE FROM old_issues
  WHERE itemnumber IN (SELECT itemnumber FROM items WHERE barcode = 'OVERDUE_TEST_ITEM');
DELETE FROM items WHERE barcode = 'OVERDUE_TEST_ITEM';
DELETE FROM biblio WHERE title = 'Overdue Trigger Test Title';
DELETE FROM borrowers WHERE cardnumber = 'OVERDUE_TEST_PATRON';
DELETE FROM circulation_rules
  WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
    AND rule_name IN ('overdue_1_delay', 'overdue_1_restrict');
```

Sysprefs are left alone — they're real config, not test data.
