-- Scenario 7 — graduated
-- Mirrors: `longoverdue.pl --lost 30=1 --lost 60=2 --charge 2`
-- (two ranges; the second range adds a charge)
--
-- New pipeline: two trigger rule sets on the same (branch, category,
-- itemtype) context, fired at different delays.
--   trigger 1: delay=30, lost=1
--   trigger 2: delay=60, lost=2, charge=1
-- Seed two checkouts (one at each delay) so each rule fires.
--
-- Note: legacy longoverdue.pl uses --skip-lost-value to avoid
-- re-processing items already at the target lost value across runs.
-- The new pipeline does not yet implement equivalent eligibility
-- gating — that's an eligibility pre-filter concern, not a circ rule.
-- Context: CPL / PT / BK.

-- Cleanup
DELETE FROM borrower_debarments
  WHERE borrowernumber IN (SELECT borrowernumber FROM borrowers
    WHERE cardnumber IN ('LO_PARITY_GRADUATED_PATRON_1', 'LO_PARITY_GRADUATED_PATRON_2'));
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

INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES
    -- trigger 1: at day 30, set itemlost = 1
    ('CPL', 'PT', 'BK', 'overdue_1_delay',  '30'),
    ('CPL', 'PT', 'BK', 'overdue_1_lost',   '1'),
    -- trigger 2: at day 60, set itemlost = 2 and charge the replacement fee
    ('CPL', 'PT', 'BK', 'overdue_2_delay',  '60'),
    ('CPL', 'PT', 'BK', 'overdue_2_lost',   '2'),
    ('CPL', 'PT', 'BK', 'overdue_2_charge', '1');

-- ============================================================
-- Checkout 1: 30 days overdue — fires trigger 1
-- ============================================================
INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'LO Parity graduated Title 1', CURDATE());
SET @biblionumber_1 = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber_1, 'BK');
SET @biblioitemnumber_1 = LAST_INSERT_ID();

INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber_1, @biblioitemnumber_1, 'LO_PARITY_GRADUATED_ITEM_1', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber_1 = LAST_INSERT_ID();

INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('LO_PARITY_GRADUATED_PATRON_1', 'Test', 'Graduated1', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber_1 = LAST_INSERT_ID();

INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber_1, @itemnumber_1, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 60 DAY),
   DATE_SUB(CURDATE(), INTERVAL 30 DAY));

UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE itemnumber = @itemnumber_1;

-- ============================================================
-- Checkout 2: 60 days overdue — fires trigger 2
-- ============================================================
INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'LO Parity graduated Title 2', CURDATE());
SET @biblionumber_2 = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber_2, 'BK');
SET @biblioitemnumber_2 = LAST_INSERT_ID();

INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber_2, @biblioitemnumber_2, 'LO_PARITY_GRADUATED_ITEM_2', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber_2 = LAST_INSERT_ID();

INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('LO_PARITY_GRADUATED_PATRON_2', 'Test', 'Graduated2', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber_2 = LAST_INSERT_ID();

INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber_2, @itemnumber_2, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 90 DAY),
   DATE_SUB(CURDATE(), INTERVAL 60 DAY));

UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 60 DAY) WHERE itemnumber = @itemnumber_2;
