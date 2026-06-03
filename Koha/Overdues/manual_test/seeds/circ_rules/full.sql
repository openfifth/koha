-- Scenario 6 — full
-- Mirrors: `longoverdue.pl --lost 90=2 --charge 2 --mark-returned`
-- with WhenLostForgiveFine=1
--
-- The "everything LostItem could do" scenario: set itemlost, forgive
-- outstanding fines, charge replacement fee, mark-returned, cancel
-- transfers (transfer cancellation is implicit in the new enact_lost).
--
-- Trigger row: lost=2, charge=1, mark_returned=1, forgive_fine=1.
-- Context: CPL / PT / BK.

-- Cleanup
DELETE FROM borrower_debarments
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers WHERE cardnumber = 'LO_PARITY_FULL_PATRON');
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

INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES
    ('CPL', 'PT', 'BK', 'overdue_1_delay',         '90'),
    ('CPL', 'PT', 'BK', 'overdue_1_lost',          '2'),
    ('CPL', 'PT', 'BK', 'overdue_1_charge',        '1'),
    ('CPL', 'PT', 'BK', 'overdue_1_mark_returned', '1'),
    ('CPL', 'PT', 'BK', 'overdue_1_forgive_fine',  '1');

INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'LO Parity full Title', CURDATE());
SET @biblionumber = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber, 'BK');
SET @biblioitemnumber = LAST_INSERT_ID();

INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber, @biblioitemnumber, 'LO_PARITY_FULL_ITEM', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber = LAST_INSERT_ID();

INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('LO_PARITY_FULL_PATRON', 'Test', 'Full', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber = LAST_INSERT_ID();

INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber, @itemnumber, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 120 DAY),
   DATE_SUB(CURDATE(), INTERVAL 90 DAY));

UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 90 DAY) WHERE itemnumber = @itemnumber;

-- Pre-existing UNRETURNED OVERDUE accountline for forgive_fine
INSERT INTO accountlines
  (borrowernumber, itemnumber, issue_id, date, amount, amountoutstanding,
   debit_type_code, status, interface, branchcode)
VALUES
  (@borrowernumber, @itemnumber,
   (SELECT issue_id FROM issues WHERE itemnumber = @itemnumber),
   DATE_SUB(CURDATE(), INTERVAL 45 DAY),
   12.00, 12.00, 'OVERDUE', 'UNRETURNED', 'cron', 'CPL');
