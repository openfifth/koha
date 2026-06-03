-- One overdue_1 trigger: delay=5, restrict=1.
-- Context: CPL / PT / BK (kohadevbox sample data).
--
-- Clears prior rows for this exact context+rule_name set so the seed is
-- idempotent across reruns.

DELETE FROM circulation_rules
WHERE branchcode = 'CPL' AND categorycode = 'PT' AND itemtype = 'BK'
  AND rule_name IN ('overdue_1_delay', 'overdue_1_restrict');

INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES
    ('CPL', 'PT', 'BK', 'overdue_1_delay',    '5'),
    ('CPL', 'PT', 'BK', 'overdue_1_restrict', '1');
