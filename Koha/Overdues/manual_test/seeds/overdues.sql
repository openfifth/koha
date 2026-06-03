-- One overdue checkout: 5 days past due, matching circulation_rules seed.
-- Context: CPL homebranch, PT category, BK itemtype.
--
-- Idempotent: clears prior test patron/item/biblio/issue before inserting.
-- Uses identifiers OVERDUE_TEST_PATRON / OVERDUE_TEST_ITEM /
-- 'Overdue Trigger Test Title' so verification queries and teardown can
-- locate the rows without relying on auto-increment ids.

-- Cleanup (in dependency order)
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

-- Biblio + biblioitems
INSERT INTO biblio (frameworkcode, author, title, datecreated)
VALUES ('', 'Manual Test', 'Overdue Trigger Test Title', CURDATE());
SET @biblionumber = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, itemtype)
VALUES (@biblionumber, 'BK');
SET @biblioitemnumber = LAST_INSERT_ID();

-- Item: homebranch + holdingbranch CPL, itype BK
INSERT INTO items
  (biblionumber, biblioitemnumber, barcode, dateaccessioned, homebranch, holdingbranch, itype, replacementprice)
VALUES
  (@biblionumber, @biblioitemnumber, 'OVERDUE_TEST_ITEM', CURDATE(), 'CPL', 'CPL', 'BK', 10.00);
SET @itemnumber = LAST_INSERT_ID();

-- Patron: PT category, CPL home branch
INSERT INTO borrowers
  (cardnumber, surname, firstname, categorycode, branchcode, dateofbirth, dateenrolled, dateexpiry, privacy)
VALUES
  ('OVERDUE_TEST_PATRON', 'Test', 'Overdue', 'PT', 'CPL',
   '1980-01-01', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 YEAR), 1);
SET @borrowernumber = LAST_INSERT_ID();

-- Issue: date_due = today - 5 days  => days_overdue = 5  => matches overdue_1_delay
INSERT INTO issues
  (borrowernumber, itemnumber, branchcode, issuedate, date_due)
VALUES
  (@borrowernumber, @itemnumber, 'CPL',
   DATE_SUB(CURDATE(), INTERVAL 15 DAY),
   DATE_SUB(CURDATE(), INTERVAL 5 DAY));

-- Reflect onloan on the item so the picture is consistent
UPDATE items SET onloan = DATE_SUB(CURDATE(), INTERVAL 5 DAY) WHERE itemnumber = @itemnumber;
