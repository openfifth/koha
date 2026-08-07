-- ============================================================================
-- Bug 19814 — Batch Check-in Test Data
-- Idempotent: safe to re-run. All rows are tagged with 'BATCHTEST19814' so a
-- re-run undoes the previous run before rebuilding.
--
-- Run from host:
--   docker exec -i kohadev-db-1 mysql -u root -ppassword koha_kohadev \
--       < /tmp/bug19814_batch_test.sql
--
-- Or paste this whole file into a MySQL session connected to koha_kohadev.
-- ============================================================================

-- --- 0. Config ---------------------------------------------------------------
SET @br   := 'CPL';   -- logged-in branch (change if you prefer)
SET @br2  := 'MPL';   -- "other" branch for transfer scenarios

-- Two non-staff patrons; we don't care which ones
SET @p1 := (SELECT borrowernumber FROM borrowers
             WHERE categorycode NOT IN ('S')
             ORDER BY borrowernumber LIMIT 1);
SET @p2 := (SELECT borrowernumber FROM borrowers
             WHERE categorycode NOT IN ('S') AND borrowernumber <> @p1
             ORDER BY borrowernumber LIMIT 1);

-- --- 1. Undo any state from a previous run ----------------------------------
DELETE FROM issues              WHERE note     = 'BATCHTEST19814';
DELETE FROM old_issues          WHERE note     = 'BATCHTEST19814';
DELETE FROM reserves            WHERE reservenotes = 'BATCHTEST19814';
DELETE FROM old_reserves        WHERE reservenotes = 'BATCHTEST19814';
DELETE FROM recalls             WHERE notes    = 'BATCHTEST19814';
-- Catches both the manually-tagged row from step 5 of the test plan AND any
-- transfer the app itself created for a tagged item during a previous run
-- (those are never tagged with a comment, so a plain comments= match misses
-- them and stale in-transit transfers bleed into the next pass).
DELETE FROM branchtransfers
 WHERE comments = 'BATCHTEST19814'
    OR itemnumber IN ( SELECT itemnumber FROM items WHERE itemnotes_nonpublic = 'BATCHTEST19814' );
DELETE FROM borrower_debarments WHERE comment  = 'BATCHTEST19814';

UPDATE items SET
    itemlost            = 0,  itemlost_on   = NULL,
    withdrawn           = 0,  withdrawn_on  = NULL,
    notforloan          = 0,  damaged       = 0,
    onloan              = NULL,
    itemnotes_nonpublic = NULL,
    homebranch          = @br,
    holdingbranch       = @br
  WHERE itemnotes_nonpublic = 'BATCHTEST19814';

-- --- 2. Claim 9 items and tag them -------------------------------------------
DROP TEMPORARY TABLE IF EXISTS _bt;
CREATE TEMPORARY TABLE _bt (
    n            INT PRIMARY KEY,
    itemnumber   INT,
    barcode      VARCHAR(20),
    biblionumber INT
);
SET @rn := 0;
INSERT INTO _bt (n, itemnumber, barcode, biblionumber)
SELECT @rn := @rn + 1, itemnumber, barcode, biblionumber
  FROM items
 WHERE itemlost = 0 AND withdrawn = 0 AND notforloan = 0
   AND onloan IS NULL
   AND barcode IS NOT NULL AND barcode <> ''
 ORDER BY itemnumber
 LIMIT 9;

UPDATE items i JOIN _bt b USING (itemnumber)
   SET i.itemnotes_nonpublic = 'BATCHTEST19814',
       i.homebranch          = @br,
       i.holdingbranch       = @br;

-- --- 3. Build scenarios ------------------------------------------------------

-- Slot 1: CLEAN checkout (checks in with no messages)
INSERT INTO issues (borrowernumber, itemnumber, branchcode, issuedate, date_due, note)
SELECT @p1, itemnumber, @br, NOW() - INTERVAL 3 DAY, NOW() + INTERVAL 11 DAY, 'BATCHTEST19814'
  FROM _bt WHERE n = 1;

-- Slot 2: OVERDUE checkout
INSERT INTO issues (borrowernumber, itemnumber, branchcode, issuedate, date_due, note)
SELECT @p1, itemnumber, @br, NOW() - INTERVAL 40 DAY, NOW() - INTERVAL 10 DAY, 'BATCHTEST19814'
  FROM _bt WHERE n = 2;

-- Slot 3: HOLD at same branch (ResFound -- captured/left waiting based on
-- HoldsAutoFill/checkbox, never pauses the batch for confirmation)
INSERT INTO issues (borrowernumber, itemnumber, branchcode, issuedate, date_due, note)
SELECT @p1, itemnumber, @br, NOW() - INTERVAL 2 DAY, NOW() + INTERVAL 12 DAY, 'BATCHTEST19814'
  FROM _bt WHERE n = 3;
INSERT INTO reserves
    (borrowernumber, biblionumber, itemnumber, branchcode, reservedate, priority, reservenotes)
SELECT @p2, biblionumber, itemnumber, @br, NOW(), 1, 'BATCHTEST19814'
  FROM _bt WHERE n = 3;

-- Slot 4: HOLD at other branch (ResFound + NeedsTransfer)
INSERT INTO issues (borrowernumber, itemnumber, branchcode, issuedate, date_due, note)
SELECT @p1, itemnumber, @br, NOW() - INTERVAL 2 DAY, NOW() + INTERVAL 12 DAY, 'BATCHTEST19814'
  FROM _bt WHERE n = 4;
INSERT INTO reserves
    (borrowernumber, biblionumber, itemnumber, branchcode, reservedate, priority, reservenotes)
SELECT @p2, biblionumber, itemnumber, @br2, NOW(), 1, 'BATCHTEST19814'
  FROM _bt WHERE n = 4;

-- Slot 5: LOST checkout (WasLost — lost-then-found flow)
UPDATE items SET itemlost = 1, itemlost_on = NOW()
 WHERE itemnumber = (SELECT itemnumber FROM _bt WHERE n = 5);
INSERT INTO issues (borrowernumber, itemnumber, branchcode, issuedate, date_due, note)
SELECT @p1, itemnumber, @br, NOW() - INTERVAL 30 DAY, NOW() - INTERVAL 5 DAY, 'BATCHTEST19814'
  FROM _bt WHERE n = 5;

-- Slot 6: RECALL (RecallFound)
INSERT INTO issues (borrowernumber, itemnumber, branchcode, issuedate, date_due, note)
SELECT @p1, itemnumber, @br, NOW() - INTERVAL 2 DAY, NOW() + INTERVAL 12 DAY, 'BATCHTEST19814'
  FROM _bt WHERE n = 6;
INSERT INTO recalls
    (patron_id, biblio_id, item_id, pickup_library_id, created_date, item_level, notes, status)
SELECT @p2, biblionumber, itemnumber, @br, NOW(), 1, 'BATCHTEST19814', 'requested'
  FROM _bt WHERE n = 6;

-- Slot 7: WITHDRAWN item (not on loan — should be rejected)
UPDATE items SET withdrawn = 1, withdrawn_on = NOW()
 WHERE itemnumber = (SELECT itemnumber FROM _bt WHERE n = 7);

-- Slot 8: Item homed at another branch (NeedsTransfer or Wrongbranch
-- depending on AllowReturnToBranch / HomeOrHoldingBranch prefs)
UPDATE items SET homebranch = @br2
 WHERE itemnumber = (SELECT itemnumber FROM _bt WHERE n = 8);

-- Slot 9: NOT CHECKED OUT (NotIssued) — untouched item, just tagged

-- Mark everything that now has a live issue as "on loan"
UPDATE items SET onloan = DATE(NOW())
  WHERE itemnumber IN (SELECT itemnumber FROM _bt WHERE n IN (1,2,3,4,5,6));

-- --- 4. Report the barcodes + their expected behaviour -----------------------
SELECT
    n AS slot,
    barcode,
    CASE n
      WHEN 1 THEN 'Clean check-in, no messages'
      WHEN 2 THEN 'Clean check-in (overdue; no batch-specific alert)'
      WHEN 3 THEN 'ResFound - hold at this branch (captured only if checkbox/HoldsAutoFill on)'
      WHEN 4 THEN 'ResFound + NeedsTransfer - hold at other branch'
      WHEN 5 THEN 'WasLost - item was lost, now found'
      WHEN 6 THEN 'RecallFound - recall at this branch'
      WHEN 7 THEN 'withdrawn - item is withdrawn'
      WHEN 8 THEN 'NeedsTransfer/Wrongbranch - item homed at MPL'
      WHEN 9 THEN 'NotIssued - item exists but was not checked out'
    END AS expected_flow
  FROM _bt
 ORDER BY n;

-- Bad-barcode scenarios don't need data; paste these alongside real barcodes
-- to exercise the BadBarcode path:
--   FAKE-BATCH-001
--   FAKE-BATCH-002
