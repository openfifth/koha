# Spec drift and core regressions

## Purpose

The initial spec was a draft of intent, not a settled design, and parts of it have since
been overtaken — by upstream changes, by documented Koha behaviour that contradicts its
premises, and by constraints that only surfaced during implementation. Where that
happened, the implementation departed from it on the author's own judgement.

This document exists to put those judgement calls where they can be examined rather than
inferred from the diff. The **Warranted** column is the author's self-assessment and is
recorded to be challenged, not to close the question; the **Regression** column is held to
a stricter standard, citing the specific core or legacy behaviour each row departs from so
the claim can be checked directly. Rows marked *undecided* or *unconfirmed* are open
questions, not positions.

Reviewers are invited to disagree with any verdict here. A row whose reasoning does not
survive review is more useful than one that was never written down.

## Scope

Comparison of `Koha/Overdues/spec.md` (initial draft) against the implementation as of
2026-09-24, branch `bug_39756_rewrite`.

The pipeline replaces two cron scripts, and both are treated as legacy baselines:

- `misc/cronjobs/overdue_notices.pl` at `6ff80241588^` (before Bug 10190 reworked it),
  cited as `notices:<line>` — notice selection and sending.
- `misc/cronjobs/longoverdue.pl` at current `main`, cited as `longoverdue:<line>` — lost
  marking, replacement charging, mark-returned.

`Koha/Overdues/trigger_enactment_spec.md` is a later working document that already maps
much of `longoverdue.pl`; rows below cite it where a decision is recorded there.

"Regression" means behaviour present in core or in a legacy script that the implementation
does not reproduce. Its verdicts are:

- **Yes** — stands, with no recorded intent to address it. Includes regressions accepted
  deliberately, annotated as such.
- **Fix planned** — identified and recorded, not yet implemented. Every instance cites
  where the intent is written down.
- **—** — none.

"Warranted" judges the drift alone, not the regression. `n/a` means the row records a gap
rather than a divergence.

Ordered by **resolution impact** — how much of the system changes as a result of
addressing the row: for rows already resolved, the magnitude of the change made; for rows
still open, the magnitude of the change a fix would require. This is not a severity
ordering. Row 16 is a one-line fix with real behavioural consequences and sits low;
rows 1-2 are already resolved and sit high because the resolutions restructured the
system.

| # | Area | Spec | Implementation | Drift | Warranted | Regression vs core / legacy |
|---|------|------|----------------|-------|-----------|------------------------------|
| 1 | Closed-days path algorithm | Two required paths (spec.md:53-57). Path 2 (spec.md:109-116): fetch **all** overdues with no days calculation → compute `days_overdue` per item via calendar → cache one calendar per library → filter to known delays in application | Two paths retained (TriggerProcessor.pm:83-85). `_process_calendar_adjusted` (:145-191) inverts Path 2: one calendar per branch → `days_backward` per delay to produce target **dates** (:164-174) → fetch only checkouts matching those `(branch, date)` pairs (:176-184) → shared dispatch | Filtering moved from application to SQL; per-item calendar arithmetic eliminated. Only the calendar-caching step (spec step 3) survives intact | **Yes.** Spec Path 2 loads every overdue row and computes per item — the opposite of the spec's own performance brief. Date-first filtering is the only form that scales | — |
| 2 | Delay translation | Not specified | `%effective_delay_by_raw_delay` — identity in the simple path (TriggerProcessor.pm:112-117), raw open-day delay → effective calendar-day delay in the calendar path (:169-171); consumed by `set_effective_overdue_rule_sets` | Unspecified layer. It is what lets both paths share `_dispatch_overdues`, since rule sets are keyed by calendar-day delay while rules are configured in open days | **Yes.** Required by row 1's inversion — computing dates up front means the rule cache must be keyed by the resulting calendar delay | — (if the translation is wrong, every calendar-path trigger fires on the wrong day) |
| 3 | Trigger model: exact day vs range | "Actions trigger **only** on the exact day when `days_overdue == trigger_delay`" (spec.md:9-10), with "configurable trigger date parameter" and "support backdated runs for failure recovery" (spec.md:11-12) | Exact-day matching implemented. **No trigger-date option** — `GetOptions` accepts only `dry-run`, `verbose`, `debug` (process_circulation_triggers.pl:82-86); both paths anchor on `dt_from_string` (TriggerProcessor.pm:159, 218) | Exact-day model per spec, but the recovery mechanism the spec paired it with was not built | **No.** The exact-day model is only safe *because* of the backdate flag. Without it a skipped cron run silently drops that day's triggers with no way to replay | **Yes.** `longoverdue:479-489` sweeps a range (`startrange`..`endrange`, default `maxdays` 366), so a missed run self-heals on the next. The new model has no equivalent. Not recorded anywhere — spec_notes.md:142 carries only the spec's "validate trigger date parameter" bullet, not a plan to add the flag |
| 4 | Rule-context branch | Rules keyed by "library" (spec.md:15) | `resolve_rule_context_branchcode` per `CircControl` + `HomeOrHoldingBranch` (TriggerProcessor.pm:248-255, Repository.pm:77-86) | Spec's "library" is undefined among four candidate branches; implementation mirrors `_GetCircControlBranch` | **Yes.** Spec underdetermined; core alignment is the only defensible reading | — (governs which rule set is looked up for every item on both paths) |
| 5 | Legacy syspref migration | Not specified | Six `DefaultLongOverdue*` prefs unreferenced anywhere in `Koha/Overdues/`; their function is replaced by circulation-rule contexts | Category/branch/itemtype scoping moves from CLI flags and sysprefs (`longoverdue:59-78`, `:328-341`) to rule contexts. Mapping recorded at trigger_enactment_spec.md:36-41 | **Yes, incomplete.** Rule contexts are the right home. The opt-in migration helper proposed at trigger_enactment_spec.md:8 is not built, so libraries with bespoke values have no path off the old script | **Fix planned** — trigger_enactment_spec.md:8 proposes an opt-in `translate_longoverdue_to_triggers.pl` helper or staff-UI import. Until then `DefaultLongOverdueLostValue`, `DefaultLongOverdueDays`, `DefaultLongOverdueChargeValue`, `DefaultLongOverduePatronCategories` and `DefaultLongOverdueSkipPatronCategories` cease to have any effect |
| 6 | Simple-path query shape | `DATEDIFF(?, DATE(date_due))` with `HAVING days_overdue IN (...)` (spec.md:98, 105) | Per-delay date-range `OR` clauses, no `DATEDIFF`, no `HAVING` (Repository.pm:52-57, 231-252) | Equivalent selection, index-usable; spec's `HAVING` on a computed column would force a full scan | **Yes.** Spec's form defeats the spec's own performance goal | — |
| 7 | Notice send path | Not specified | `GetPreparedLetter` + `Koha::Notice::Message->new->store` (ActionExecutor.pm:413-446) | — | **No.** Bypasses the addressing the legacy path set | **Fix planned** — trigger_enactment_spec.md:157-165 records that `notices:1047-1051` passed `to_address`, `from_address` and `reply_address` to `EnqueueLetter`, and names the remedy: switch to `C4::Letters::EnqueueLetter` or populate the fields directly. Rows 8 and 18-20 land in the same rework |
| 8 | Transport degradation | Not specified | Absent | — | **No.** Behaviour lost, not replaced | **Fix planned** — trigger_enactment_spec.md:167-178 documents the rules: `email` with no address → `print`, `sms` with no `smsalertnumber` → `print`, and template fallback to the configured mtt |
| 9 | Digest grouping key | `"borrowernumber\|notice_code\|delay"`, flat string (spec.md:131, 196) | 4-level nested hash `{borrowernumber}{notice_code}{mtt}{delay}` (ActionExecutor.pm:489) | `mtt` dimension added, string key replaced by nesting | **Yes.** One notice per transport requires `mtt` in the key | — (reshaped the whole notice queue and every consumer of it) |
| 10 | Notice/mtt emptiness asymmetry | Not specified | Uniform treatment for all actions (RuleResolver.pm:150-163) | `notice => ''` (deliberate suppression) and `mtt => ''` (unset) require opposite handling; neither the spec nor the code distinguishes them | n/a — unaddressed in both | — (resolving means per-action emptiness semantics in `_find_effective_rule_value`, changing resolution for all six action types) |
| 11 | Empty rule value | "Return first **non-empty** ruleset found" (spec.md:124) | Walk halts on `defined` (RuleResolver.pm:155-157) | `mtt => ''` is a persisted empty row, defined, so the walk stops at the exact context | **No.** Spec was correct; `defined` was the wrong predicate | **Fix planned** — semantics settled 2026-09-24: for `mtt`, `''`/NULL/undef are all "unset" and continue the walk; `notice => ''` remains a deliberate suppression that halts it. Regression is vs legacy only (`notices:747-751` re-queried the default branch `unless @message_transport_types`); `Koha::CirculationRules` returns the most specific row whatever its value. Follows from row 10 |
| 12 | Already-handled items | Not specified in spec.md; trigger_enactment_spec.md:41 states the new script "will identify and ignore 'already handled items'", and :285 leaves placement open | No guard. `enact_lost` sets `itemlost` unconditionally (ActionExecutor.pm:527-535); no lost-status exclusion in either fetch path | The promised replacement for `DefaultLongOverdueSkipLostStatuses` was not built | **No.** Exact-day triggering limits but does not remove re-application — a backdated or repeated run re-marks and re-charges | **Fix planned** — trigger_enactment_spec.md:41 commits to it; :285 flags placement (pre-filter vs action layer) as open. Replaces `longoverdue:362` (`AND itemlost NOT IN (...)`), `:371` (`AND itemlost <> ?`) and `--skip-lost-value`. See also row 3 |
| 13 | Calendar path scaling | Not specified | `CALENDAR_PAIRS_INLINE_LIMIT => 150`; above it, one query per branch via `_ChainedResultset` (TriggerProcessor.pm:33, 179-184, 196-210) | Threshold and fallback are implementation decisions with no spec basis | **Yes, threshold arbitrary.** A fallback is needed; `150` has no stated derivation | — |
| 14 | Batch by `days_overdue` | "Group items by days_overdue for batch processing" (spec.md:85, 154) | Single pass, no grouping; rules resolved from a cache keyed by context+delay (TriggerProcessor.pm:225-285) | Grouping is redundant once the effective set is precomputed. Marked "NOT QUITE DOING" in spec.md:154 | **Yes, unconfirmed.** Sound reasoning, but spec.md:154 flags that intent was never clarified | — (reopening it would reintroduce a grouping pass over every dispatched item) |
| 15 | Item structure | 10 fields (spec.md:164-178) | 14 fields (TriggerProcessor.pm:231-246) | `notice_preferences` dropped; `issue_id`, `itemlost`, `itemhomebranch`, `itemholdingbranch`, `patronhomebranch` added. `replacementfee` addition already annotated at spec.md:176 | **Yes.** Dropped field is dead per row 25; additions avoid per-item refetches across every enactor | — |
| 16 | Rule fallback hierarchy | 4 contexts (spec.md:16-20, 122-124):<br>1. `B,C,I`<br>2. `B,C,*`<br>3. `B,*,*`<br>4. `*,*,*` | 7 contexts (RuleResolver.pm:174-182):<br>1. `B,C,I`<br>2. `B,C,*`<br>3. `B,*,I`<br>4. `B,*,*`<br>5. `*,C,*`<br>6. `*,*,I`<br>7. `*,*,*` | Implementation adds `B,*,I`, `*,C,*`, `*,*,I`; spec had no itemtype-only tiers | **Yes, incomplete.** Spec's 4 tiers do not model core; added tiers are required, but it stops one short | **Yes.** Core enumerates 8 via `order_by => { -desc => [branchcode, categorycode, itemtype] }` (CirculationRules.pm:320-336). `*,C,I` is absent, so a category+itemtype rule set never fires. Identified 2026-09-24; no decision taken. One inserted line — see [Fallback chain](#fallback-chain) |
| 17 | Default replacement cost | Not specified | `enact_charge` returns early when `replacementfee` is 0 or unset (ActionExecutor.pm:591-594), and always passes `replacement_price` explicitly (:625) | `useDefaultReplacementCost` is never reached — `add_lost_replacement_fee` only consults it when no explicit price is given | **No.** An item with `replacementprice = 0` and an itemtype `defaultreplacecost` is now silently not charged | **Fix planned** — spec_notes.md:25 records the itemtype `defaultreplacecost` fallback as in-scope behaviour. Replaces `longoverdue:542` → `LostItem` → `chargelostitem`, which honoured `useDefaultReplacementCost` |
| 18 | One print per patron | Not specified | Absent | — | **No.** Behaviour lost, not replaced | **Fix planned** — trigger_enactment_spec.md:180 calls for a print-once-per-patron guard so a multi-MTT trigger does not enqueue duplicate print rows. Replaces `$print_sent` (`notices:865`). One guard in the bucket loop |
| 19 | Print notice truncation | Not specified | Absent | — | **No.** Behaviour lost, not replaced | **Fix planned** — trigger_enactment_spec.md:61 and :188 both carry `PrintNoticesMaxLines`. Replaces the splice at `notices:802`. One splice before enqueue |
| 20 | `itiva` transport | Not specified | Absent | — | **No.** Behaviour lost, not replaced | **Fix planned** — trigger_enactment_spec.md:179 records `mtt eq 'itiva'` → skip. Currently treated as a sendable mtt. One skip condition |
| 21 | `checkin_library` on cron returns | Not specified | Not passed; `mark_returned` sets NULL (ActionExecutor.pm:644-663, Checkout.pm) | — | **Undecided.** Sanctioned by the `mark_returned` interface; the asymmetry with the desk path needs a call | **Fix planned** — recorded in `project_bug39756_mark_returned_gaps` 2026-09-24, pending a decision rather than a patch. `C4::Circulation::MarkIssueReturned` falls back to `$issue->branchcode` when there is no userenv; the cron path records nothing. One parameter |
| 22 | Write-safety default | dry-run listed as a flag (spec.md:63-66) | Acts by default; `--dry-run` previews (process_circulation_triggers.pl:78-86) | Default inverted relative to the script being replaced | **Undecided.** Consistent with `overdue_notices.pl`, inconsistent with `longoverdue.pl`. The new script does both jobs, so one of the two conventions had to give | **Yes.** `longoverdue:523` gates every write behind `--confirm`; the script is inert by default. A mistimed cron entry now charges and marks lost rather than doing nothing. Not recorded anywhere |
| 23 | Lost/charge/return coupling | Not specified | `lost`, `charge`, `forgive_fine`, `mark_returned` are independent rule actions (ActionExecutor.pm:509-663) | Legacy coupled them: `--charge` names *which* lost value also charges, and `--mark-returned` only took effect on the charging branch | **Yes.** Resolves the long-standing defect flagged at `longoverdue:474` — "FIXME - The item is only marked returned if you supply --charge" | — (strictly an improvement; recorded so the behaviour change is not mistaken for a regression) |
| 24 | `MarkLostItemsAsReturned` | Not specified | Not consulted; mark-returned is a rule action | Pref-driven behaviour replaced by explicit configuration | **Yes.** The pref selects behaviour by call site (`longoverdue:542` passes `'cronjob'` into `LostItem`); rule actions express the same intent per context | **Yes — accepted.** Deprecation decided at trigger_enactment_spec.md:280 (`→ trigger row mark_returned: bool. Syspref deprecated`), mapping at :34. Scoped: the pref still governs the desk and API paths; only the cron path stops consulting it. Libraries relying on its `cronjob` token must re-express it as a rule |
| 25 | Patron digest preferences | "Patrons can opt for digest per notice type" (spec.md:24); `notice_preferences` in row and SQL (spec.md:99, 175) | No `wants_digest` read anywhere in `Koha/Overdues/`; query attributes are `prefetch`/`order_by` only (Repository.pm:254-258) | Spec premise wrong, annotated in place at spec.md:29-34. Overdue digests are unconditional, library-controlled | **Yes.** Spec premise contradicted by documented Koha behaviour | — (resolved by not building it; no code to change) |
| 26 | Calendar class | "Use existing `Koha::Calendar`" (spec.md:153, 212) | `Koha::Library::Calendar` (TriggerProcessor.pm:165) | Upstream moved the tree (Bug 42310); spec name is stale | **Yes.** Forced by upstream; no choice available | — |
| 27 | Closed-days syspref | `IgnoreClosedDaysInOverdueCalculation` (spec.md:223) | `OverdueTriggersCalendar` (TriggerProcessor.pm:83) | Renamed; old pref dropped | **Yes.** Deliberate rename on this branch; spec predates it | — |
| 28 | Script flags | dry-run, verbose, debug (spec.md:63-66) | All three present (process_circulation_triggers.pl:82-86) | `--debug` additionally self-suppresses off a TTY (:93-95), unspecified | **Yes.** Bounds cron mail volume without skipping the run | — (see row 3 for the flag that is missing) |
| 29 | Dry-run UI | "likely out of scope" (spec.md:68-76) | Not implemented | Correctly not implemented | n/a — no drift | — |

## Fallback chain

Row 16 in full. Core order is `Koha::CirculationRules::get_effective_rule`
(CirculationRules.pm:320-336), which resolves by SQL: each context column matched as
`[ $value, undef ]`, ordered `-desc` on `branchcode, categorycode, itemtype`, `rows => 1`.
In MariaDB, `DESC` sorts non-NULL before NULL, so the ordering enumerates all eight
context tiers in precedence order.

| Core | RuleResolver | Context | Source |
|------|--------------|---------|--------|
| 1 | 1 | `B , C , I` | RuleResolver.pm:175 — `# exact match` |
| 2 | 2 | `B , C , *` | RuleResolver.pm:176 — `# library + category` |
| 3 | 3 | `B , * , I` | RuleResolver.pm:177 — `# library + itemtype` |
| 4 | 4 | `B , * , *` | RuleResolver.pm:178 — `# library only` |
| 5 | — | `* , C , I` | **absent** |
| 6 | 5 | `* , C , *` | RuleResolver.pm:179 — `# category only` |
| 7 | 6 | `* , * , I` | RuleResolver.pm:180 — `# itemtype only` |
| 8 | 7 | `* , * , *` | RuleResolver.pm:181 — `# default` |

Tiers 1-4 are identical. RuleResolver 5-7 are core 6-8 in the same relative order, so the
only difference is the missing tier. Inserting `* , C , I` after RuleResolver.pm:178
makes the chain match core exactly.

The `# category only` comment at :179 is accurate as written, but reads as if it were the
whole category-scoped branch — the category-plus-itemtype tier it would otherwise sit
above was never written.
