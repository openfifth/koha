# TEMPORARY FILE - for ease of access during dev

## DECISIONS
### Forgive fine atom — home
- Service-level orchestration (creates a FORGIVEN credit via `add_credit`, then applies it to the debit) lives on `Koha::Account` as `forgive_debit($debit_line, { interface, user_id?, library_id? })`, alongside `add_credit` / `pay` / `add_lost_replacement_fee`. Caller (`ActionExecutor::enact_forgive_fine`) builds the account once and iterates over the patron's UNRETURNED OVERDUE accountlines.

### Branchcode for rule-set lookup in `route_item_actions_to_queue`
- Must honor both `CircControl` and `HomeOrHoldingBranch` (mirrors the informative blurb in smart-rules.tt).
- Resolution (cron context, no userenv):
  - `CircControl = PatronLibrary` → patron's home branch
  - `CircControl = ItemHomeLibrary` (default) → item homebranch or holdingbranch per `HomeOrHoldingBranch`
  - `CircControl = PickupLibrary` → falls through to the ItemHomeLibrary case (matches `_GetCircControlBranch`)
- The issue's `branchcode` (frozen at checkout via `_GetCircControlBranch`) is NOT used directly for rule resolution.
- Required keys on `$overdue_item` (carried by `TriggerProcessor`, sourced from `Repository`):
  - `itemhomebranch` (item.homebranch)
  - `itemholdingbranch` (item.holdingbranch)
  - `patronhomebranch` (patron.branchcode)
- Extracted to `ActionExecutor::_resolve_rule_context_branchcode` with a POD TODO pointing at `Koha::CirculationRules` as the eventual home (taking scalars rather than objects so batch callers don't load Item + Patron per row). DRY against `C4::Circulation::_GetCircControlBranch` (private + EXPORT_OK-flagged-as-wrong) is the later refactor.

### Fee-context branch for `enact_charge` — separate concern from rule resolution
- LOST fees go through `Koha::Checkout::branch_for_fee_context(fee_type => 'LOST', ...)`, which uses `LostChargesControl` (not `CircControl`) + `HomeOrHoldingBranch`.
- `LostChargesControl` does NOT influence the rule lookup that decides "should we charge?" — that's already settled by the trigger row via `_resolve_rule_context_branchcode` (CircControl-driven).
- `LostChargesControl` only governs the `library_id` stamped on the resulting LOST debit line, which in turn drives two downstream lookups inside `Koha::Account::add_lost_replacement_fee`:
  - the `lost_item_processing_fee` circ rule
  - the itemtype `defaultreplacecost` fallback (when `replacement_price` is undef and `useDefaultReplacementCost` is on)
- So the two branchcodes used in the executor are separate concerns: `_resolve_rule_context_branchcode` for "which trigger fires", `branch_for_fee_context` for "where the resulting LOST debit is stamped".

### `enact_forgive_fine` — accountline scoping and log policy
- Search filter scopes to the active checkout via `issue_id` (NOT done by legacy `_FixOverduesOnReturn`, which omits `issue_id` and uses `->next` to pick one arbitrarily — latent bug avoided).
- Log policy: track `$forgiven_count` inside the loop and gate the `FinesLog` line on it, NOT on the resultset being non-empty. Reason: `forgive_debit` returns `undef` when `amountoutstanding == 0`, so a matching row may still result in no forgiveness — the log should reflect actual work done, with the count appended for visibility.

### Intentional divergence from `_FixOverduesOnReturn`
The new `enact_forgive_fine` deliberately does NOT replicate several `_FixOverduesOnReturn` behaviours — each is moved or deferred:
- No zero-amount accountline cleanup (`amount == 0 && payments == 0` → delete) → deferred to `Koha::Item::mark_lost`.
- No accountline `status` flip (`UNRETURNED → RETURNED`/`LOST`) → deferred to `Koha::Item::mark_lost`.
- No `txn_do` wrapper.
- No `$exemptfine` gate — gated up in `process_action_queue` by the trigger row's `forgive_fine` rule value. `WhenLostForgiveFine` is deprecated and not consulted (see spec.md).
- Logging via `Koha::Logger->info` instead of `C4::Log::logaction("FINES", "MODIFY", ...)`. Caveat: legacy writes to `action_logs` table (surfaces in staff UI audit trail); we don't. If FinesLog is meant to be a librarian-visible audit, `Koha::Logger` may not be the right channel — flag for later.

### Cron userenv requirement on `process_circulation_triggers.pl`
- `MarkIssueReturned` (C4/Circulation.pm:2888) reads `C4::Context->userenv->{branch}` unconditionally to set `issues.checkin_library`. Without an installed userenv, that dereferences undef and dies.
- The convention is `use Koha::Script -cron;` at the top of the cron script — its import-time hook calls `set_userenv(undef, undef, undef, 'CRON', 'CRON', undef×5)` and `interface('cron')`, installing a placeholder hashref so `userenv->{branch}` returns undef cleanly (and `checkin_library` is stored as NULL).
- All legacy cronjobs (longoverdue.pl, fines.pl, overdue_notices.pl) declare it. Added to `misc/cronjobs/process_circulation_triggers.pl` between `use warnings;` and the Koha imports, matching their placement.

### `notice_queue` shape — nested hashrefs over stringified compound keys
- The spec's `"borrowernumber|notice_code|mtt|delay" => [@entries]` shape carried over by analogy from the rule cache (`"library|category|itemtype" => $rules`) without the structural pressure that justifies it there. The rule cache's string keys earn their keep via `_get_fallback_contexts`, which generates seven `*`-wildcard candidate keys per resolution and probes each as a direct hash lookup — string-key with sigils is the cleanest shape for that walk. The notice queue has no fallback hierarchy, no wildcards, no priority walking — just a flat collection of buckets.
- Going with `$self->{notice_queue}{$borrowernumber}{$notice_code}{$mtt}{$delay} = [@entries]`:
    - Drops `_parse_notice_key` and `_build_notice_key` (format-knowledge helpers that only exist because we serialised).
    - Reduces `_corresponding_print_key` to a direct sub-hash access — no swap-and-rebuild.
    - Reduces `_notice_keys_for_mtt` to direct nested iteration (no `grep` + `split`).
    - Removes the (low-risk but non-zero) concern that a `|` in a `notice_code` breaks the key parser.
    - Mirrors legacy `overdue_notices.pl`'s `$borrower_overdues->{triggers}->{$i}->{$notice}->{$mtt}` shape — readers can map between the two without translation overhead.
- **Scope: notice queue only.** Rule resolver caches (`raw_overdue_rule_sets`, `effective_overdue_rule_sets`) stay string-keyed — wildcard fallback iteration in `_get_fallback_contexts` genuinely needs that shape.
- Concrete callsite list (for the refactor): `add_to_notice_queue`, `route_item_actions_to_queue`, `process_notice_queue`, `_corresponding_print_key`, `_notice_keys_for_mtt`, plus tests that poke `$executor->{notice_queue}->{'42|OD1|email|7'}` directly.

### `mtt` is a structural level in the notice queue
- Spec proposed `"borrowernumber|notice_code|delay"`, omitting `mtt`. Grouping multiple MTTs under one bucket can't be reconciled at send time — different transports need different rendering and produce different `message_queue` rows. `mtt` is its own level.
- In the nested shape: `$self->{notice_queue}{$borrowernumber}{$notice_code}{$mtt}{$delay}`. A rule with `mtt = "email,print"` fans out into two distinct buckets (one per MTT), driven by the multi-MTT fan-out in `route_item_actions_to_queue` and the per-MTT processing passes in `process_notice_queue`.

### Cross-notice_code aggregation — not combined
- Scenario: patron has a book and a CD both 5 days overdue; general rule for library + patron category says notice `OD1`, CD-specific rule says `ITEM_DUE_REMINDER`. Result: two separate sends, one per notice_code, one MTT row per send.
- Matches legacy `overdue_notices.pl`: it never combines across notice_codes — bucket key is `(trigger, notice_code, mtt)`, `parse_overdues_letter` is called once per bucket.
- Combining across notice_codes ("daily summary across all notices") would be a feature beyond legacy parity. Out of scope.

## QUESTIONS
### general
- JUST TO CONFIRM:do we only take the date into account when applying triggers, and completely disregard times?
    - alternatively, do we interprete this as 'if date_due is 2025-10-10 14:00:00', then only enact if the script runs after 14:00:00.
### Path 1: Simple Calculation (No Closed Days)
- is it alright for the grouping of notices to depend on Koha::Checkouts::GetOverduesSummaries() fetching grouping overdues by borrowers as it fetches them? Should there be some form of failsafe in place? 
### Closed Days Calculation
- ALTERNATIVE PROPOSAL: what if we work backwards instead?
    - pre-calculate target due dates by counting backwards from today for each known delay value, excluding closed days from the count.
    - use the same logic as for the simple calculation, having updated the know delay values accordingly.
    If this work, I think we'd get dryer code and better performance. It almost feels too simple an answer - is it?
### caching
- JUST TO CONFIRM: the intent is NOT to use my $memory_cache = Koha::Cache::Memory::Lite (we're just working with caching on object instances) correct?
### Koha::Overdues::TriggerProcessor
- QUESTION: provided the standard and digest queues both get processed completely separately:
    - do we need to process the standard (action) queue first?
    - do we need to process the digest (notice) queue first?
    - would we want to process both in parallel? - run separate scripts maybe, or however this might be possible? <em>genuinely does not know if that would work/ or how, but wondering</em>
### Koha::Overdues::RuleResolver
JUST TO CONFIRM: Does the following sound right?
- Getting potentially relevant overdue rules only
    - went with filtering down to context we know are relevant only
    - also only fetching overdue_ rules, not all circulation_rules row
- Resolving them (as "actions per delay for contexts"), and caching that.
- Treating this like an intermediary caching layer
    - store an array of potentially relevant rule sets
    - includes a method that effective resolves rule sets - that is, ties a rule set to an item batch being processed
- I might not have completely understood the resolved rules sets structure. That, or I have spotted an issue with it.
    - if the key is  library|category|itemtype
    - and if the value is 
    ```
         {
             delay => int,           # Days overdue to trigger
             actions => [            # Array of actions
                 {
                     type => string,        # 'notice', 'restrict', etc.
                     notice_code => string, # For notice actions
                     # ... other action parameters
                 }
             ]
         }
    ```
    We are failing to handle triggers - that is, the fact that for one context (library|category|itemtype), we will have sets of rules per trigger number -> different delays
    - Could we instead EITHER do
        -  key is  library|category|itemtype
        -  value is an object
        -  key is  delay
        -  value is unchanged

    - ALTERNATIVE PROPOSAL (what I've gone with) :
    ```
        library|category|itemtype|delay => {
             actions => [            # Array of actions
                 {
                     type => string,        # 'notice', 'restrict', etc.
                     notice_code => string, # For notice actions
                     # ... other action parameters
                 }
             ]
         }
    ```
    - OR
    ```
         {
             delay => int,           # Days overdue to trigger
             actions => [            # Array of actions
                 {
                     type => string,        # 'notice', 'restrict', etc.
                     notice_code => string, # For notice actions
                     # ... other action parameters
                 }
             ]
         }
    ```
    Would this make sense?
### Error handling
QUESTIONS:
- Validate trigger date parameter
    - is that delay? Trigger nnumber?
- Handle missing rule configurations gracefully
- Log processing statistics and errors
    - which statistics?
        - items
            - processed?
            - skipped (for good reason)
            - 'missed' => error occured
            - actions
                - executed?
                - 'missed' => error occured
        - notices sent?
        - for both the above -> per context?
    - where do we log to? (this very much is just me not knowing)
- Fail gracefully if calendar data unavailable
    - Do we need a clear message to admin users (full permissions) to indicate this occured (probably goes back to me not knowing where we're logging to)