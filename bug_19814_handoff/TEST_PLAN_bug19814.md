# Bug 19814 — Librarian-facing batch check-in test plan

This walkthrough drives the batch check-in feature using the seeded
data from `bug19814_batch_test.sql`. It describes **exactly what the
librarian should see** for each barcode so deviations are easy to
spot.

The 9 seeded items are picked dynamically from your DB, so barcodes
vary. Use the table printed at the end of the SQL run to map the
barcodes in your paste list to the slot numbers used below.

**This version supersedes an earlier draft that assumed holds pause
the batch for confirmation, like the single-item check-in popup does.
They don't** — see section 2. Everything below reflects behaviour
confirmed against a running instance, not the original design intent.

---

## 0. Seed the data

```sh
docker exec -i kohadev-db-1 mysql -u root -ppassword koha_kohadev \
  < bug19814_batch_test.sql
```

Expected at the end of the run: a 9-row table listing each barcode
and its `expected_flow`. Keep this open; you will reference it for
every step. The script is idempotent — safe to re-run before each
section below, including cleaning up any leftover transfers a
previous pass created.

Logged-in branch should be **CPL** (matches the SQL's `@br`).

---

## 1. System preferences to check first

Set and remember the starting values; you will flip some of these in
later steps.

| Pref | Start at |
|---|---|
| `HoldsAutoFill` | Off |
| `AutomaticItemReturn` | Off |
| `BatchCheckinDefaults` | (leave default) |
| `BlockReturnOfLostItems` | Off |
| `BlockReturnOfWithdrawnItems` | Off |
| `CircConfirmItemParts` | Off |
| `UseRecalls` | **On** — required for scenario 6 (recall) to produce any alert at all |
| `finesMode` | `production` — only needed if you want to exercise the "Exempt fines" checkbox in section 4; the checkbox is hidden entirely otherwise |

Scenario 6 also needs a `recalls_allowed` circulation rule with a
non-zero value — this is checked separately from `UseRecalls` by core
Koha (`Koha::Item->can_be_waiting_recall`), and a default KTD install
has none. If Administration ▸ Circulation and fines rules shows none
for your itemtype/branch/category combination, add a global one:

```sql
INSERT INTO circulation_rules (branchcode, categorycode, itemtype, rule_name, rule_value)
VALUES (NULL, NULL, NULL, 'recalls_allowed', '10')
ON DUPLICATE KEY UPDATE rule_value='10';
```

Then go to **Circulation ▸ Check in** and tick **Batch mode**. Leave
"Automatically capture holds" and "Automatically create transfers"
checkboxes **unchecked** for the first pass.

---

## 2. First batch — exercise every scenario

Paste your list into the batch textarea:

```
3999900000001
3999900000002
3999900000018
3999900000021
3999900000019
3999900000017
3999900000020
39999000000238
39999000000252
FAKE-BATCH-001
FAKE-BATCH-002
```

Submit. **No confirmation modal appears in this pass.** The modal
only pauses the batch for item-parts (`CircConfirmItemParts` +
`items.materials` set) or bundle items — never for holds, regardless
of any syspref or checkbox. None of the base seed data triggers
either of those, so the whole batch completes in one request. (You'll
deliberately trigger the pause in section 4.)

### Final results table

You should see a **Batch return results** table with one row per
barcode. For each row:

| Slot (from SQL output) | Expected status / alert(s) |
|---|---|
| 1 — Clean check-in | Returned. No alert. |
| 2 — Overdue check-in | Returned. No alert (the overdue banner is single-item UI only). |
| 3 — ResFound same branch | Returned. `alert-warning` "Hold found" only. With the checkbox and `HoldsAutoFill` both off, the hold is **not** captured — it's left for the holds queue. |
| 4 — ResFound + NeedsTransfer | Returned. `alert-warning` "Hold found" only, same reason — no transfer is created yet. You'll see that appear in section 3. |
| 5 — WasLost | Returned. `alert-info` "Item was lost, now found". If a lost-item fee was generated, also "Lost item fee refunded to the borrowing patron's account." |
| 6 — RecallFound | Returned. `alert-warning` "Recall found" **only if** `UseRecalls=On` and the `recalls_allowed` rule from section 1 are both in place. Without either, this row shows no alert at all — that's core Koha recall logic, unchanged by this branch, not a regression. |
| 7 — withdrawn | Not checked out. "Item is withdrawn" + "Item was not checked out". |
| 8 — Item homed at MPL | Not checked out (never issued in seed data). "Item needs transfer" + "Item was not checked out" (or "This item cannot be returned to this branch" if `AllowReturnToBranch` blocks it). |
| 9 — NotIssued | Not checked out. "Item was not checked out" only. |
| FAKE-BATCH-001 | Invalid barcode. "Bad barcode". |
| FAKE-BATCH-002 | Invalid barcode. "Bad barcode". |

If a row shows **"Received code X from AddReturn. Contact support."**
that means a new message key is not yet handled in
`checkin-messages.inc` — flag it in review.

### Post-run DB sanity (optional, run once)

```sql
-- Slot 3/4 holds are still waiting -- NOT captured, checkbox and sysprefs are off
SELECT reserve_id, found FROM reserves WHERE reservenotes='BATCHTEST19814';
-- Slot 6 recall is still 'requested' -- checkin never changes recall status by itself
SELECT recall_id, status FROM recalls WHERE notes='BATCHTEST19814';
-- Slots 1,2,3,4,5,6 are no longer on loan
SELECT itemnumber, onloan FROM items WHERE itemnotes_nonpublic='BATCHTEST19814';
```

---

## 3. Re-seed and test syspref enforcement

Re-run the SQL (it cleans up its own state, including any transfers
created by the previous pass) and repeat the batch.

### 3a. HoldsAutoFill on, "Automatically capture holds" unchecked

* Set `HoldsAutoFill = Allow` (on).
* Reload the check-in page and re-enable batch mode — you should now
  see **"Automatically capture holds" checked and greyed out
  (disabled)**: the server enforces the pref regardless of what the
  checkbox says.
* Submit the same 9 barcodes.

**Expected:** slot 3 and slot 4 both show "Hold found", and this time
the hold **is** captured — `reserves.found` is `W` for slot 3, `T`
for slot 4. Slot 4 additionally shows **"Item transferred to Midway
to fill hold"**, with a **Print transfer slip** button in the new
Actions column.

If the checkbox isn't forced checked+disabled, or the holds are still
uncaptured in the DB, the server-side coercion for `HoldsAutoFill` is
broken.

### 3b. AutomaticItemReturn on, "Automatically create transfers" unchecked

* Set `AutomaticItemReturn = Do` (on).
* "Automatically create transfers" should now show checked+disabled
  too.
* Submit the batch again.

**Expected:** slot 8 (item homed at MPL) shows "Item transferred to
MPL" with its own Print transfer slip button, and a row exists in
`branchtransfers` — even though the checkbox was never ticked.

---

## 4. Confirm modal and batch state preservation

The modal is scoped to item-parts / bundle confirmation only (see
section 2), so this section deliberately sets that up rather than
relying on a hold.

Re-seed, then:

1. Set `CircConfirmItemParts = On`.
2. Flag slot 9's item (the barcode your seed run printed for slot 9)
   with a `materials` value, or nothing will pause:
   ```sql
   UPDATE items SET materials = 'CD included' WHERE barcode = '<slot 9 barcode>';
   ```
3. Book drop mode and a manual return-date override are **mutually
   exclusive in this UI** — ticking Book drop mode disables the date
   field. Pick one:
   * tick **Book drop mode**, or
   * leave it unchecked, click the calendar toggle next to "Specify
     return date", and enter a backdated date/time (e.g. yesterday
     14:00).
4. If you also want to exercise **Exempt fines**, set `finesMode =
   production` first (see section 1) — the checkbox doesn't render at
   all otherwise.
5. Submit the same 9 barcodes.
6. The modal pauses on slot 9 (the item-parts item you just flagged),
   not slot 3 — holds never pause the batch. Click **"Confirm all
   parts present"**.
7. When the drain completes, verify:
   * The **"Checked-in items" table below the results still lists
     all 6 real checkouts from before the pause** (slots 1, 2, 3, 4,
     5, 6). If it's empty or missing entirely, the confirm-modal round
     trip lost that history.
   * The actual return time landed in `old_issues.returndate` for
     those items, matching your backdate/dropbox choice — **not** the
     "Due date" column in the Checked-in items table, which is the
     item's original loan due date and is unaffected by backdating:
     ```sql
     SELECT itemnumber, returndate FROM old_issues WHERE note='BATCHTEST19814';
     ```
   * No new overdue fine was created for the overdue slot 2.

If any of the toggles got lost mid-batch, the hidden-input
preservation is broken.

---

## 5. WrongTransfer repair

1. Re-seed (this also clears out any transfer rows a previous
   section left behind).
2. Manually insert a transfer for slot 4's item from CPL → a third
   branch (e.g. FFL), not MPL:
   ```sql
   INSERT INTO branchtransfers (itemnumber, frombranch, tobranch, datesent, reason, comments)
   SELECT itemnumber, 'CPL', 'FFL', NOW(), 'Manual', 'BATCHTEST19814'
     FROM items WHERE itemnotes_nonpublic='BATCHTEST19814'
     ORDER BY itemnumber LIMIT 1 OFFSET 3;
   ```
3. Submit the batch. Slot 4 row should show "This item is still on
   transfer to FFL".
4. Check the DB: the original CPL→FFL row should now have
   `datecancelled` set and `cancellation_reason = 'WrongTransfer'`,
   and a *new* CPL→FFL row should exist (same destination/reason as
   the original — the repair only corrects `frombranch` to the
   item's actual current branch, it doesn't reroute the item).
   Separately, because slot 4 also has a hold waiting at MPL, expect
   a **third**, unrelated row: CPL→MPL with `reason = 'Reserve'`,
   created by the normal hold-capture flow, not by the WrongTransfer
   repair.

---

## 6. Per-item error resilience

An earlier draft of this plan suggested deleting a `biblio` row while
an `issue` still referenced it through `items`, to force a per-item
exception mid-batch. **That doesn't work** — Koha's foreign key
constraints block the delete outright (it errors with no side
effects), so there's no safe way to reproduce that exact corruption
against a real instance.

The practical version of this test is already covered by section 2:
`FAKE-BATCH-001`/`FAKE-BATCH-002` exercise the "item not found" error
path through the same per-item `eval` wrapper, and everything else in
the batch — both before and after them in the list — completes
normally. That's good evidence one bad item doesn't abort the rest.

If you want higher confidence than that, it's a code-review check
rather than something to click through live: confirm
`process_batch_checkin_item()` is called inside an `eval` in both the
initial batch loop and the post-confirm drain loop in
`circ/returns.pl`, and that a thrown exception there is logged and
converted into an `error` status row rather than propagating and
aborting the request.

---

## 7. Accessibility / presentation spot-check

While the modal is open:

* Tab order cycles only within the modal.
* Focus returns to the Check-in textarea after you close it.
* Escape key does **not** close the modal (intentional — prevents
  accidental dismiss).
* `btn-default` buttons throughout this page (e.g. "Cancel batch",
  "Skip this item") are intentional — it's a Koha-specific class
  defined in `staff-global.scss` via a `button-variant()` mixin, used
  throughout this exact template. It is **not** a leftover Bootstrap 4
  class and doesn't need "fixing."
* The "More settings" toggle on the check-in page shows/hides via
  `d-none` (inspect the DOM — no inline `style="display:none"`).

---

## 8. If something looks off

| Symptom | Likely cause |
|---|---|
| Modal opens for slot 3 or 4 (a hold) | Shouldn't happen — holds never pause the batch, only item-parts/bundle confirmation does. If it does, something regressed. |
| Modal never opens for slot 9 in section 4 | `CircConfirmItemParts` is off, or slot 9's item doesn't have a `materials` value set. |
| Modal opens but drain loses later items | Batch state JSON round-trip failing — check the error log for "Failed to decode batch state JSON". |
| "Checked-in items" table disappears after confirming | Regression in the `checkin_counter`/`checkin_barcode_N` hidden fields on the batch confirm modal's form. |
| Exempt-fine / dropbox forgotten after modal | Hidden inputs for `batch_state_*` missing from the modal form. |
| "Received code X from AddReturn" alert | New message key needs a handler in `checkin-messages.inc`. |
| Slot 8 says "Wrongbranch" but you expected "NeedsTransfer" | `AllowReturnToBranch` is blocking it — adjust the pref. |
| Fake barcodes don't show "Bad barcode" | Error handling in `process_batch_checkin_item` regressed. |
| Slot 6 shows no "Recall found" alert | `UseRecalls` is off, or no `recalls_allowed` circulation rule exists — see section 1. |
| Hold captured (section 3a) but no transfer message/button for slot 4 | Check `confirm_hold()`'s caller in `process_batch_checkin_item` — it should set a `HoldTransfer` message and `transfer_reserve_id` when the pickup branch differs from the checkin branch. |

---

## 9. Regression sanity (after manual pass)

Inside KTD:

```
prove t/db_dependent/Circulation/Returns.t
prove t/00-testcritic.t t/00-valid-xml.t
```

There is deliberately no Cypress coverage for this feature — the
check-in page is expected to be rewritten in Vue in the near future,
so a Cypress suite against the current Template Toolkit markup would
be short-lived. Rely on this manual walkthrough plus the Perl-side
checks above.
