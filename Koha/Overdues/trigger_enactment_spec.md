# Trigger Enactment Specification

Companion to `spec.md`. Where `spec.md` covers timing, rule resolution, queueing, and digest grouping but leaves the action vocabulary open, this document pins down the semantics of the actions a trigger can enact — starting from what the existing cron scripts currently do.


## Questions

**Should we?** — provide a run-once helper CLI (e.g. `misc/cronjobs/translate_longoverdue_to_triggers.pl`), or staff UI button "Import legacy longoverdue settings", that reads the six `DefaultLongOverdue*` sysprefs and generates the equivalent trigger rows for the librarian to review before committing. Opt-in: nothing happens unless explicitly run. Avoids the auto-migration contention (libraries that didn't have automated actions don't get them) while giving librarians with bespoke values a non-clunky path off the old script. Cf. the "make it easy for administrators to retain existing behaviours" line in §Intended behaviour.

## Intended behaviour - actions enactement

Insofar as we have chosen to allow use of the circulation_triggers staff UI to set charge, lost, and mark returned, the scripts must implement the behaviours defined by administrators.

However, we should also make it easy for administrator to retain existing behaviours should they wish to. This may simply call for documentation that explains how the new UI may be used to recreate the behaviour from the old scripts.

Crucially, we must understand which sys prefs to account for, and exactly when within the process to account for them. This includes whether they are default to the circ rules, alternate to the circ rules, or to be considered in conjunction with them.

### Relevant System Preferences

Possibly relevant
- item-level_itypes — chooses item-level vs biblio-level itemtype; affects rule-context resolution when matching itemtype on a
trigger row.

#### Replaced with new overdue_X_[action] circulation rules / their context

~~Treat them as fallbacks for now, with circulation rules as the override, with the intent to later deprecate them.~~

The script deliberately pre-filters overdues to which a circulation rule set will apply (performance concerns), and only process those.
-> We cannot reliably honour system preferences as defaults without losing the performance improvement.
-> These sys prefs are deprecated. 

- WhenLostChargeReplacementFee                  -> whether for a context where one or more rule sets declare 'lost', the same or a later sets 'charge' to true.
                                                -> indirectly would be a fallback - deprecated
- MarkLostItemsAsReturned                       -> whether for a context where one or more rule sets declare 'lost', the same or a later sets 'mark_returned' to true.
                                                -> indirectly would be a fallback - deprecated
- DefaultLongOverdueLostValue                   -> CLI flag fallback - deprecated
- DefaultLongOverdueDays                        -> CLI flag fallback - deprecated   
- DefaultLongOverdueChargeValue                 -> CLI flag fallback - deprecated       
- DefaultLongOverduePatronCategories            -> CLI flag fallback - deprecated               
- DefaultLongOverdueSkipPatronCategories        -> CLI flag fallback - deprecated                   
- DefaultLongOverdueSkipLostStatuses            -> dropped - the new script will identify and ignore 'already handled items'

#### Unaccounted for
- WhenLostForgiveFine                           -> the forgive fine action triggered via the use of LostItem by longoverdue.pl is unaccounted for.
                                                -> The solution here is simple: add: 'forgive_fine' (bool) -> overdue_X_forgive_fine
                                                -> indirectly would be a fallback - deprecated
                                                -> Atom: `Koha::Account->forgive_debit($debit_line, { interface, user_id?, library_id? })` — creates a FORGIVEN credit equal to `amountoutstanding` and applies it. Called from `ActionExecutor::enact_forgive_fine`.

~~### New~~
- ~~IgnoreClosedDaysInOverdueCalculation~~

#### Updated
- Rename `OverdueNoticeCalendar` syspref to `OverdueTriggersCalendar

#### Kept as sys prefs and must be accounted for at runtime
- CircControl — PatronLibrary | PickupLibrary | ItemHomeLibrary. Determines which branch the rule-set lookup is keyed on (patron home / userenv (or item-side fallback in cron) / item-side per HomeOrHoldingBranch). Mirrors smart-rules.tt's informative blurb.
- HomeOrHoldingBranch — homebranch | holdingbranch. Used (a) for rule-set lookup when CircControl = ItemHomeLibrary (or PickupLibrary falling through in cron) and (b) when LostChargesControl = ItemHomeLibrary.
- LostChargesControl — PatronLibrary | PickupLibrary | ItemHomeLibrary.
- OverdueNoticeFrom
- OverdueNoticeCalendar
- PrintNoticesMaxLines
- EmailOverduesNoEmail
- AddressForFailedOverdueNotices

#### Adjacent — shape what happens after a trigger fires, not the trigger itself - do not impact the script
- BlockReturnOfLostItems (checkin-time)
- ClaimReturnedLostValue (claims-returned workflow)
- AutoRemoveOverduesRestrictions (restriction removal on return)
- CumulativeRestrictionPeriods / SuspensionsCalendar (debarment shape)

## Current behaviour in legacy cron scripts

### `misc/cronjobs/longoverdue.pl`

Operates on three axes — lost value, charge, mark-returned — driven by CLI flags (with system-preference fallbacks):

- **Lost value** (`--lost N=LV`, repeatable, or `DefaultLongOverdueLostValue` / `DefaultLongOverdueDays`): for each item whose days-overdue falls in the range, sets `items.itemlost = LV` directly (`Koha::Items->find(...)->itemlost($lostvalue)->store`).
- **Charge** (`--charge LV`, string, or `DefaultLongOverdueChargeValue`): not a boolean — names *which* of the `--lost` mappings should also charge the replacement cost. When the current range's lost value equals `$charge`, calls `LostItem($itemnumber, 'cronjob', $mark_returned, { library_id => $rule_branch })`, which is what actually levies the fee. If omitted, the lost value is set but no charge is created.
- **Mark-returned** (`--mark-returned`, boolean, or `MarkLostItemsAsReturned` syspref): if charging, passed through to `LostItem` as the `mark_returned` argument. If not charging but the flag is set, calls `MarkIssueReturned($borrowernumber, $itemnumber, undef, $patron->privacy)` directly. So mark-returned can fire with or without a charge, but only the charged branch routes through `LostItem`.

Note the coupling at `longoverdue.pl:528-551`: charge and mark-returned are entangled via `LostItem`'s signature; there is no path that charges without offering mark-returned, and the FIXME at line 479 already flags this as a design wart.

#### What `LostItem` actually does (`C4/Circulation.pm:4517`)

Signature: `LostItem( $itemnumber, $mark_lost_from, $force_mark_returned, $params )`.

1. **Decides whether to mark-returned.** If `$force_mark_returned` is truthy → yes. Otherwise → regex-match `$mark_lost_from` against the `MarkLostItemsAsReturned` syspref (a comma-separated context list). So the caller can force the behaviour or fall back to syspref policy.
2. **Loads issue + item + biblio** for the itemnumber (single join).
3. **If the item is currently checked out** (there's an `issues` row):
   - Runs `_FixOverduesOnReturn`, which forgives/keeps overdue fines per `WhenLostForgiveFine`.
   - **Conditionally charges the replacement fee**: gated by the `WhenLostChargeReplacementFee` syspref. When on, calls `C4::Accounts::chargelostitem` with the item's `replacementprice` (default 0), a title/barcode/callnumber description, and the fee-rule branch resolved via `Koha::Checkout->branch_for_fee_context(fee_type => 'LOST', ...)`. Interface label is `'cron'` if `$mark_lost_from eq 'cronjob'`, else the current `C4::Context->interface`.
   - **If mark-returned was decided yes**, calls `MarkIssueReturned( $borrowernumber, $itemnumber, undef, $patron->privacy, $params )`.
4. **Always cancels outstanding transfers** for the item (`reason => 'ItemLost', force => 1`), whether or not there was a borrower.

Things worth flagging for the trigger redesign:

- `LostItem` does **not** set `items.itemlost` itself — that's the caller's responsibility (longoverdue.pl sets it on line 529 before calling `LostItem`).
- The charge step is gated by a *syspref*, not by the caller's intent. So "call `LostItem`" is really "consider charging per syspref, and definitely do the side effects (overdue fix, optional mark-returned, transfer cancellation)." A trigger-row `charge: true` would need to either bypass `WhenLostChargeReplacementFee` or be documented as subordinate to it.
- `$force_mark_returned` is a one-way override (force-on); there is no "force off" — if syspref says mark-returned and the caller passes false/undef, the syspref wins. Trigger rows would presumably need both directions to be explicit.
- The transfer-cancellation side effect is implicit and unconditional. A trigger model that lets actions toggle independently still inherits this whenever the lost-value/charge path runs through `LostItem`.

### `misc/cronjobs/overdue_notices.pl`

Notice-only. Does not touch charge, lost value, or mark-returned at all. Explicitly *excludes* lost items from its working set via `items.itemlost = 0` at `overdue_notices.pl:591`. Its sole enactment is generating/queueing overdue notices (digest or individual) per the patron's messaging preferences.

## Intended behaviour - notices enactement

Key difficulty: 

there are system-level differences in notices handling, eg "overdue notice digests are controlled by library, not patron", yet there is no
way to tell an overdue notice from a non-overdue notice as these are not categorised. And while default notices exist, libraries may create
as many different notices as they would like, and use each for whichever purpose.

### Questions

### About digests

From https://koha-community.org/manual/latest/en/html/opac.html#your-messaging-label: 
`EnhancedMessagingPreferences` and `EnhancedMessagingPreferencesOPAC` control whether patrons may choose whether to receive digests or not.
Overdue notices are controlled by the library and only the library.

(Currently available: 'Advance notice', 'Item checkout', 'Hold filled', 'Item due', 'Item check-in')

Digests are out of scope for 39756, as we do not need to handle patrons potentially requesting them.
Giving administrators the ability to request to have digest sent out through this new system can and should be a follow-up bug.

### Parity gaps to close against `overdue_notices.pl`

Items the legacy notice path covers that `Koha::Overdues::ActionExecutor::process_notice_queue` currently does not. Listed roughly in order of likely site impact.

#### Letter prep payload (`GetPreparedLetter` parameters)

Legacy goes through `C4::Overdues::parse_overdues_letter` (`C4/Overdues.pm:817-868`). The new path calls `C4::Letters::GetPreparedLetter` directly with a thinner payload. To keep existing site templates rendering correctly:

- `repeat.item.items` must be the **full item hashref** (e.g. `$item->unblessed`), not the bare itemnumber. Templates routinely reference `[% item.items.barcode %]`, `[% item.items.title %]`, `[% item.items.itemcallnumber %]`, etc. The legacy code also stamps `$item->{fine}` onto each row via `GetFine` + `currency_format`.
- `repeat.item.issues` should be the **itemnumber** (legacy uses itemnumber here, not issue_id — see `C4/Overdues.pm:850`).
- `loops => { overdues => [ itemnumber, ... ] }` must be passed for templates that iterate `[% FOREACH o IN overdues %]`.
- `substitute` must include at least `bib => $library->branchname` and `'items.content' => $titles` (pre-rendered title list via `C4::Letters::get_item_content`, see `overdue_notices.pl:923-927`) alongside `count`.

Retain all the above.
~~Upgrade notice template in place? (update loops etc).~~
~~Flag to administrator, interrupt, await new templates?~~

#### Enqueue addressing

Legacy passes `to_address`, `from_address`, and `reply_address` explicitly to `EnqueueLetter` (`overdue_notices.pl:1047-1051`):

- `from_address` ← `$library->from_email_address` (with `AddressForFailedOverdueNotices` fallback when `patron_homelibrary` is set, see `:872-878`)
- `to_address`   ← `$patron->notice_email_address` (or the union of `@emails_to_use` when `--email` is passed)
- `reply_address` ← `$library->inbound_email_address`

`Koha::Notice::Message` - try that first

`Koha::Notice::Message->new->store` is lower-level than `EnqueueLetter`; either switch to `C4::Letters::EnqueueLetter` or populate these fields directly so message_queue rows carry the right per-branch envelope.

#### MTT degradation rules

Process notice in a reverse transport type order
Send all prints
Send all sms
If email fails
Check if print exist 
If not, send print


- `mtt eq 'email'` with no email → downgrade to `print` (`overdue_notices.pl:898-903`).
- `mtt eq 'sms'` with no `smsalertnumber` → downgrade to `print` (same block).
- `mtt eq 'itiva'` → skip (`overdue_notices.pl:896`).
- Print-once-per-patron guard so a multi-MTT trigger does not enqueue duplicate print rows (`$print_sent` at `:893, :1040, :1056`).

#### Template existence pre-check

Legacy calls `Koha::Notice::Templates->find_effective_template` *before* rendering (`overdue_notices.pl:936-944`). The new path relies on `GetPreparedLetter` returning undef. Functionally equivalent, but worth confirming the warn message is informative enough for operators triaging missing templates.

Implement `Koha::Notice::Templates->find_effective_template`.

#### `PrintNoticesMaxLines` truncation

If print fallback lands, splice items past the limit and append the "List too long for form…" footer (`overdue_notices.pl:929-932, :975-978`).

Handle that.

#### Unreplaced-placeholder diagnostic

Legacy scans rendered content for unmatched `<…>` terms and warns under `--verbose` (`overdue_notices.pl:980-986`). Optional, but cheap to port and useful during template debugging.

port that bit across
                my @misses = grep { /./ } map { /^([^>]*)[>]+/; ( $1 || '' ); } split /\</,
                    $letter->{'content'};
                if (@misses) {
                    $verbose
                        and warn "The following terms were not matched and replaced: \n\t" . join "\n\t",
                        @misses;
                }

#### Out of scope by design (not gaps — record so reviewers do not re-raise)

- `--nomail` / `--csv` / `--html` / `--text` output modes (legacy `:988-1013, :842-854`). The new pipeline always enqueues.
- `patron_homelibrary` branch filter at notice-prep time. Item-set narrowing now lives upstream in `Koha::Overdues::Repository`.
- `--list-all`, `--itemscontent`, `--max`, `--frombranch`, per-borrower email override flags. Operator UX of the legacy script does not carry over.
- Digests (already covered under [About digests](#about-digests) — follow-up bug).

## Implication for the trigger system

In the trigger model, each row already pins (library, itemtype, category, delay) and the lost value (if any) is just a column on the row. The disambiguating role of `--charge` disappears, so the per-trigger action set collapses to a small, mostly-boolean shape:

- `lost_value` — nullable string (AV code, or null = leave unchanged)
- `charge` — bool
- `mark_returned` — bool
- `restrict` — bool
- `notice` — nullable string (letter code, or null = no notice)

`charge` and `mark_returned` should be independently settable per trigger; the legacy entanglement via `LostItem`'s signature should not be carried forward into the new model.

## Deprecation target — `LostItem`

`C4::Circulation::LostItem` is in scope for deprecation. The replacement should be OOP/SRP-clean: atomic domain methods, with policy lifted out of the model and into either the trigger executor or a thin application service.

### Irreducible behaviours (what we cannot lose)

Drawn from `LostItem` + its current caller in `longoverdue.pl:529-551`:

1. Set `items.itemlost = <lost_value>` (the actual state mutation).
2. Resolve overdue fines on the lost transition (`_FixOverduesOnReturn` with `WhenLostForgiveFine`).
3. Charge the replacement fee (`C4::Accounts::chargelostitem`).
4. Mark the checkout returned (`MarkIssueReturned`).
5. Cancel outstanding item transfers (`reason => 'ItemLost'`).
6. Resolve the fee-context branch — which rule set's LOST fee applies (`Koha::Checkout->branch_for_fee_context`).
7. Audit interface labelling on accountlines (`'cron'` vs UI).

### Proposed homes

- **`Koha::Item`**
  - `mark_lost($lost_value)` — sets `itemlost`, cancels outstanding transfers (covers 1 + 5). Atomic state mutation, no knowledge of patrons, fees, or checkouts.
- **`Koha::Checkout`**
  - `mark_returned(...)` — already exists (covers 4).
  - `resolve_overdue_fines_on_lost(...)` — extracts the lost-transition slice of `_FixOverduesOnReturn` from `C4::Circulation` (covers 2).
  - `branch_for_fee_context(...)` — already exists (covers 6).
- **`Koha::Account`** (the per-patron account API)
  - `add_lost_replacement_fee({ item, issue, library_id, interface })` — pure charge function. No syspref check; caller passes the resolved branch and interface label (covers 3 + 7).
  - `forgive_debit($debit_line, { interface, user_id?, library_id? })` — creates a FORGIVEN credit equal to the debit's `amountoutstanding` and applies it. Service-level orchestration (creates + applies a credit), placed alongside `add_credit` / `pay`. Caller decides which debit lines qualify and supplies context.

### Orchestration question

Where does the sequence (item state → fines → charge → mark-returned → transfers) live?

- **(a)** Domain method `Koha::Item->mark_lost_with_workflow({...})` that bundles. DRY, but pulls policy back into the model and couples `Item` to `Checkout`/`Account`.
- **(b)** Application service. The trigger executor (`Koha::Overdues::ActionExecutor`) orchestrates from a trigger row. A parallel `Koha::LostItem::Workflow` thin wrapper exists for non-trigger callers (staff UI manually marking lost, batch tools). SRP-clean but two callers means drift risk unless they share one execution function over a common action-shape struct.

The current draft of `ActionExecutor` leans (b)-shaped — orchestration in the executor with per-action `enact_*` methods — but that is a sketch, not a ratified choice. Read as a signal of where the author was heading rather than a commitment.

### Signal from the current draft modules

`Koha::Overdues::ActionExecutor`, `Koha::Overdues::RuleResolver`, and `Koha::Overdues::TriggerProcessor` exist as early drafts. They are useful as signals about how the author was thinking, but should not be treated as a contract. Worth pulling out for spec discussion:

- **Executor shape (draft)** — `ActionExecutor` separates a notice queue (keyed `borrowernumber|notice_code|mtt|delay`) from a flat `action_batch_queue`, with `enact_*` methods per action type. Matches the (b) orchestration sketch above.
- **Action vocabulary (draft)** — `RuleResolver.pm:36` hardcodes `( 'notice', 'charge', 'lost', 'restrict', 'mark_returned', 'forgive_fine' )`. Matches the per-trigger action shape in §"Implication for the trigger system" (plus `forgive_fine`, added to preserve `WhenLostForgiveFine` semantics).
- **Atom coverage (draft)** — `enact_lost` sets `itemlost`; `enact_charge` calls `chargelostitem`; `enact_mark_returned` calls `MarkIssueReturned`; `enact_restrict` adds a debarment; `enact_forgive_fine` calls `Koha::Account->forgive_debit` over the patron's UNRETURNED OVERDUE accountlines for the item. Several behaviours from the irreducible list (`_FixOverduesOnReturn`, transfer cancellation, `branch_for_fee_context`, interface labelling, `$patron->privacy` on mark-returned) are not yet attempted — open whether each lands in a domain method (per "Proposed homes") or stays inside the executor's atoms.
- **Lost-as-prerequisite (draft policy)** — `ActionExecutor.pm:226-232` makes `lost` a precondition for `charge` and `mark_returned` within a single trigger row: if `lost` isn't present, the other two are skipped. Comment justifies it as preserving long-standing Koha behaviour. Needs a spec call: is this the policy we want, or should each action fire independently per its own flag?
- **Action iteration order (draft)** — `ActionExecutor.pm:90` and `:222-241` iterate `restrict, lost, charge, mark_returned`. Encodes an implicit sequencing decision; should be made explicit in the spec.
- **Empty value = absent (draft)** — `ActionExecutor.pm:95` treats empty-string `value` as "action not configured." Worth surfacing in the spec so the staff UI mirrors it.
- **Resolver fallback hierarchy diverges from `spec.md`** — `RuleResolver.pm:165-173` defines 7 fallback levels (incl. library+itemtype, category alone, itemtype alone) whereas `spec.md` §2 lists only 4. Either the spec gets updated or the resolver gets trimmed — flagging here so it doesn't get locked in by accident. (Probably belongs in `spec.md` rather than this doc.)

### Sysprefs — demoted vs retained

Demoted from global policy to per-trigger column (decision moves into the row):

- `WhenLostChargeReplacementFee` → trigger row `charge: bool`. Syspref deprecated.
- `MarkLostItemsAsReturned` → trigger row `mark_returned: bool`. Syspref deprecated.
- `WhenLostForgiveFine` → trigger row `forgive_fine: bool`. Syspref deprecated.

All three are no longer consulted at runtime — the pre-filter only fetches checkouts whose delay matches a configured rule, so a syspref-as-default cannot be honoured without losing the perf improvement (see spec.md).

Open question — `DefaultLongOverdueSkipLostStatuses`: this is about *eligibility* (which items get processed), not enactment. Probably stays in the trigger query/pre-filter, not in the action layer.

### Open questions before locking the design

1. Orchestration: confirm (b) — application service over a common action-shape struct — or push for (a).
2. Is the staff-UI "manually mark item lost" path in scope for this redesign, or are we deprecating only the cron entry point in the first pass?
3. Transfer cancellation: currently unconditional in `LostItem`. Keep as an implicit consequence of `Koha::Item->mark_lost`, or make it a separately toggleable trigger action?
4. Lost-as-prerequisite (`ActionExecutor.pm:226-232` draft): keep the coupling — `charge` and `mark_returned` skip unless `lost` is present on the same row — or let each action fire independently per its own flag?
5. Action iteration order on a single row (`restrict, lost, charge, mark_returned` in the draft): ratify or change.
