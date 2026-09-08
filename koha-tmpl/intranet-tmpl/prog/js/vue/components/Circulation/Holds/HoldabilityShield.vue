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
                        Number(holdability.hold_fee).format_price()
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
            </div>
        </template>
    </div>
</template>

<script>
import { computed, onMounted, ref, watch } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import { useMainStore } from "../../../stores/main.js";
import { useHoldsStore } from "../../../stores/holds.js";
import { blockerLabel } from "../../../composables/hold-blocker-labels.js";

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
        // { blockers: Array<{ code, label, overridable }>, overridable },
        // whenever a check resolves unavailable - lets a caller react (e.g.
        // hide its own form) without duplicating the label lookup this
        // component already owns. `overridable` is the same "every blocker
        // is overridable and the syspref allows it" check this component
        // already needs for its own purposes - included here rather than
        // left for the caller to re-derive, since this is a pure reporter
        // now and has no button of its own to gate with it any more.
        "blocked",
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
                emit("blocked", {
                    blockers: enrichBlockers(result.blockers),
                    overridable: canOverride.value,
                });
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
            blockerLabel,
        };
    },
};
</script>

<style></style>
