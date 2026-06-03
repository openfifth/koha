-- Scenario 3 — lost_charge_returned
-- Mirrors: `longoverdue.pl --lost 90=2 --charge 2 --mark-returned`
-- (WhenLostForgiveFine=0)
--
-- Trigger row: lost=2, charge=1, mark_returned=1.
-- Context: CPL / PT / BK.

-- Cleanup
DELETE FROM borrower_debarments
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_LOST_CHARGE_RET_PATRON');
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

INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES
    ('CPL', 'PT', 'BK', 'overdue_1_delay',         '90'),
    ('CPL', 'PT', 'BK', 'overdue_1_lost',          '2'),
    ('CPL', 'PT', 'BK', 'overdue_1_charge',        '1'),
    ('CPL', 'PT', 'BK', 'overdue_1_mark_returned', '1');

INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'LO Parity lost_charge_returned Title', CURDATE());
SET @biblionumber = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber, 'BK');
SET @biblioitemnumber = LAST_INSERT_ID();

INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber, @biblioitemnumber, 'LO_PARITY_LOST_CHARGE_RET_ITEM', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber = LAST_INSERT_ID();

INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('LO_PARITY_LOST_CHARGE_RET_PATRON', 'Test', 'LostChargeRet', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber = LAST_INSERT_ID();

-- Issue: date_due = today - 90 days  =>  days_overdue = 90
INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber, @itemnumber, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 120 DAY),
   DATE_SUB(CURDATE(), INTERVAL 90 DAY));

UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 90 DAY) WHERE itemnumber = @itemnumber;
