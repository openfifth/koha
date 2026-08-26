<template>
    <div class="holdability-shield">
        <!-- Skeleton: shown until the one holdability call resolves for the
             first time (or immediately, if nothing is cached yet). -->
        <div v-if="!initialized" class="placeholder-glow">
            <p class="placeholder col-9"></p>
            <span class="placeholder col-3"></span>
            <span class="placeholder col-3"></span>
        </div>

        <template v-else>
            <p v-if="holdability.items" class="text-muted">
                {{
                    $__("%s item(s), %s holdable · Queue position: #%s").format(
                        holdability.items.total,
                        holdability.items.holdable,
                        holdability.prospective_priority
                    )
                }}
            </p>

            <div v-if="holdability.hold_fee" class="alert alert-info py-2">
                {{
                    $__("A fee of %s applies to this hold.").format(
                        holdability.hold_fee
                    )
                }}
            </div>

            <!-- Rendered inline rather than through the global Dialog: a list
                 of reasons doesn't fit the single message string
                 Dialog.setError()/setWarning() expects. -->
            <div v-if="!holdability.available" class="alert alert-danger">
                <p class="mb-1">
                    {{ $__("This hold cannot be placed:") }}
                </p>
                <ul class="mb-2">
                    <li v-for="b in holdability.blockers" :key="b.code">
                        {{ blockerLabel(b.code) }}
                    </li>
                </ul>
                <button
                    v-if="canOverride"
                    type="button"
                    class="btn btn-warning btn-sm"
                    @click="requestOverride"
                >
                    {{ $__("Override") }}
                </button>
            </div>
        </template>
    </div>
</template>

<script>
import { computed, onMounted, ref, watch } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import { useMainStore } from "../../../stores/main.js";
import { useHoldsStore } from "../../../stores/holds.js";
import { $__ } from "@koha-vue/i18n";

// Human-readable text for every code Koha::*::Availability::Hold can
// produce (api/v1/swagger/definitions/availability_reason.yaml). Kept as a
// label lookup only - which codes are override-able comes from the API's
// own `overridable` flag on each reason, not from anything here.
const BLOCKER_LABELS = {
    age_restricted: $__("This item is age restricted"),
    already_possession: $__("The patron already has this item checked out"),
    bad_address: $__("The patron has an incomplete address"),
    branch_not_in_hold_group: $__(
        "The pickup library is not in the record's hold group"
    ),
    cannot_be_transferred: $__(
        "This item cannot be transferred to the pickup library"
    ),
    cannot_reserve_from_other_branches: $__(
        "This library only allows holds on its own items"
    ),
    card_lost: $__("The patron's card has been reported lost"),
    damaged: $__("This item is damaged"),
    debt_limit: $__("The patron has too much debt to place a hold"),
    expired: $__("The patron's card has expired"),
    hold_limit: $__("The patron has reached their hold limit"),
    item_already_on_hold: $__("The patron already has a hold on this item"),
    library_not_pickup_location: $__(
        "This library is not a valid pickup location"
    ),
    no_item_available: $__("No item on this record can fill a hold"),
    no_items: $__("This record has no items"),
    no_reserves_allowed: $__("Holds are not allowed on this item"),
    not_reservable: $__("This item cannot be held"),
    pickup_not_in_hold_group: $__(
        "The pickup library is not in this item's hold group"
    ),
    recall: $__("This item has an active recall"),
    restricted: $__("The patron's account is restricted"),
    too_many_holds_for_this_record: $__(
        "The patron already has the maximum holds on this record"
    ),
    too_many_reserves: $__("The patron has reached their total hold limit"),
    too_many_reserves_today: $__("The patron has reached today's hold limit"),
};

export default {
    name: "HoldabilityShield",
    props: {
        // What to check. How to check it (the fetch, the cache, the
        // override syspref) is this component's own concern - it reads its
        // stores directly (useMainStore/useHoldsStore, called - not
        // inject()ed) rather than have all of that threaded down as props.
        // That does mean this component depends on stores/holds.js existing
        // wherever it's used - a real, visible coupling, accepted for now
        // since there's no second consumer yet to design a generic
        // interface against, and mainStore already works this way in every
        // module.
        biblioId: { type: [String, Number], required: true },
        patronId: { type: [String, Number], required: true },
        pickupLibraryId: { type: [String, Number], required: true },
    },
    emits: [
        // The full holdability result, whenever a check (fresh or
        // background-refreshed) resolves available - the parent needs this
        // to decide whether to show its own form.
        "eligibility",
        // Array<{ code, label, overridable }>, whenever a check resolves
        // unavailable - lets a caller react (e.g. hide its own form) without
        // duplicating the label lookup this component already owns.
        "blocked",
        // Array<{ code, label, overridable }>, fired when the user clicks
        // this component's own Override button - *before* any confirmation.
        // This component only knows what was blocked, not what confirming
        // or retrying means in every context, so both the modal and the
        // retry stay the caller's job.
        "override-requested",
    ],
    setup(props, { emit }) {
        const mainStore = useMainStore();
        const holdsStore = useHoldsStore();
        const { loading, loaded } = mainStore;

        const initialized = ref(false);
        const holdability = ref(null);

        const canOverride = computed(() => {
            if (!holdability.value || holdability.value.available) return false;
            return (
                holdsStore.sysprefs.AllowHoldPolicyOverride &&
                holdability.value.blockers.every(b => b.overridable)
            );
        });

        const blockerLabel = code => BLOCKER_LABELS[code] || code;

        // Single source of truth for turning a raw blocker into what
        // callers need to render a message - keeps BLOCKER_LABELS from
        // needing a second copy anywhere else.
        const enrichBlockers = blockers =>
            blockers.map(b => ({
                code: b.code,
                label: blockerLabel(b.code),
                overridable: b.overridable,
            }));

        const emitResult = result => {
            if (result.available) {
                emit("eligibility", result);
            } else {
                emit("blocked", enrichBlockers(result.blockers));
            }
        };

        const fetchHoldability = background => {
            if (!background) loading();

            return APIClient.circulation.holdability
                .biblio(props.biblioId, {
                    patron_id: props.patronId,
                    pickup_library_id: props.pickupLibraryId,
                })
                .then(
                    result => {
                        holdsStore.setExpressCache(
                            props.biblioId,
                            props.patronId,
                            props.pickupLibraryId,
                            result
                        );
                        holdability.value = result;
                        initialized.value = true;
                        emitResult(result);
                        if (!background) loaded();
                    },
                    () => {
                        if (!background) loaded();
                    }
                );
        };

        const check = () => {
            const cached = holdsStore.getExpressCache(
                props.biblioId,
                props.patronId,
                props.pickupLibraryId
            );
            if (cached) {
                holdability.value = cached.holdability;
                initialized.value = true;
                emitResult(cached.holdability);
                fetchHoldability(true); // refresh in the background
            } else {
                initialized.value = false;
                fetchHoldability(false);
            }
        };

        const requestOverride = () => {
            emit(
                "override-requested",
                enrichBlockers(holdability.value.blockers)
            );
        };

        onMounted(check);
        // Any of the three re-checks - not just a patron change, as before
        // this component owned the fetch. A different pickup library can
        // genuinely change the verdict (cannot_be_transferred,
        // library_not_pickup_location), so it has to re-check too now that
        // this is a self-contained check rather than a one-shot render.
        watch(
            () => [props.biblioId, props.patronId, props.pickupLibraryId],
            check
        );

        return {
            initialized,
            holdability,
            canOverride,
            blockerLabel,
            requestOverride,
        };
    },
};
</script>

<style></style>
