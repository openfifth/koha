-- Scenario 1 — lost_only
-- Mirrors: `longoverdue.pl --lost 30=1`
-- (no --charge, no --mark-returned, WhenLostChargeReplacementFee=0,
-- MarkLostItemsAsReturned does not match 'cronjob', WhenLostForgiveFine=0)
--
-- Trigger row: lost=1 only.
-- Context: CPL / PT / BK (kohadevbox sample data).
--
-- Self-contained: drops prior scenario rows, inserts circ rule, biblio,
-- biblioitem, item, patron, and issue (30 days overdue).

-- Cleanup (in dependency order)
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

-- Circulation rule: trigger 1 fires at day 30, sets itemlost = 1
INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES
    ('CPL', 'PT', 'BK', 'overdue_1_delay', '30'),
    ('CPL', 'PT', 'BK', 'overdue_1_lost',  '1');

-- Biblio + biblioitems
INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'LO Parity lost_only Title', CURDATE());
SET @biblionumber = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber, 'BK');
SET @biblioitemnumber = LAST_INSERT_ID();

-- Item: homebranch + holdingbranch CPL, itype BK, replacementprice set
INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber, @biblioitemnumber, 'LO_PARITY_LOST_ONLY_ITEM', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber = LAST_INSERT_ID();

-- Patron: PT category, CPL home branch
INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('LO_PARITY_LOST_ONLY_PATRON', 'Test', 'LostOnly', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber = LAST_INSERT_ID();

-- Issue: date_due = today - 30 days  =>  days_overdue = 30  =>  matches overdue_1_delay
INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber, @itemnumber, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 60 DAY),
   DATE_SUB(CURDATE(), INTERVAL 30 DAY));

UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE itemnumber = @itemnumber;
