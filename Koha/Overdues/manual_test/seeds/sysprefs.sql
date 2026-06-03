-- Reset relevant sysprefs to documented Koha defaults.
-- Scope: only those sysprefs that affect circulation_triggers.pl behaviour.
-- Idempotent: UPDATE-only, assumes sysprefs already exist in `systempreferences`.

-- Branchcode resolution for rule-set lookup
UPDATE systempreferences SET value = 'ItemHomeLibrary' WHERE variable = 'CircControl';
UPDATE systempreferences SET value = 'homebranch'      WHERE variable = 'HomeOrHoldingBranch';

-- Branchcode resolution for LOST fee context (used by Koha::Checkout::branch_for_fee_context)
UPDATE systempreferences SET value = 'ItemHomeLibrary' WHERE variable = 'LostChargesControl';

-- Replacement cost handling
UPDATE systempreferences SET value = '0' WHERE variable = 'useDefaultReplacementCost';

-- Calendar handling
UPDATE systempreferences SET value = '0' WHERE variable = 'IgnoreClosedDaysInOverdueCalculation';

-- Audit
UPDATE systempreferences SET value = '1' WHERE variable = 'FinesLog';

-- Restriction removal on return (relevant for enact_mark_returned -> MarkIssueReturned)
UPDATE systempreferences SET value = 'no' WHERE variable = 'AutoRemoveOverduesRestrictions';
