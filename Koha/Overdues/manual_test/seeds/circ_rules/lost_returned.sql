-- Scenario 4 — lost_returned
-- Mirrors: `longoverdue.pl --lost 30=1 --mark-returned` (no --charge)
-- (WhenLostChargeReplacementFee=0, WhenLostForgiveFine=0)
--
-- Legacy path: itemlost set directly, then MarkIssueReturned called
-- directly (no LostItem, so no _FixOverduesOnReturn, no transfer
-- cancellation). New pipeline: each action fires independently.
--
-- Trigger row: lost=1, mark_returned=1.
-- Context: CPL / PT / BK.

-- Cleanup
DELETE FROM borrower_debarments
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_RET_PATRON');
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

INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES
    ('CPL', 'PT', 'BK', 'overdue_1_delay',         '30'),
    ('CPL', 'PT', 'BK', 'overdue_1_lost',          '1'),
    ('CPL', 'PT', 'BK', 'overdue_1_mark_returned', '1');

INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'LO Parity lost_returned Title', CURDATE());
SET @biblionumber = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber, 'BK');
SET @biblioitemnumber = LAST_INSERT_ID();

INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber, @biblioitemnumber, 'LO_PARITY_LOST_RET_ITEM', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber = LAST_INSERT_ID();

INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('LO_PARITY_LOST_RET_PATRON', 'Test', 'LostRet', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber = LAST_INSERT_ID();

INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber, @itemnumber, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 60 DAY),
   DATE_SUB(CURDATE(), INTERVAL 30 DAY));

UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE itemnumber = @itemnumber;

-- Seed an UNRETURNED OVERDUE accountline so the test can verify that
-- without forgive_fine on the row, the fine stays UNRETURNED (parity
-- with longoverdue.pl's non-charging mark-returned branch, which does
-- NOT call _FixOverduesOnReturn).
INSERT INTO accountlines
  (borrowernumber, itemnumber, issue_id, date, amount, amountoutstanding,
   debit_type_code, status, interface, branchcode)
VALUES
  (@borrowernumber, @itemnumber,
   (SELECT issue_id FROM issues WHERE itemnumber = @itemnumber),
   DATE_SUB(CURDATE(), INTERVAL 15 DAY),
   5.00, 5.00, 'OVERDUE', 'UNRETURNED', 'cron', 'CPL');
