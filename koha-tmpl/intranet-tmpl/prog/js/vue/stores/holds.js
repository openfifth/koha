import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";

export const useHoldsStore = defineStore("holds", () => {
    const store = reactive({
        authorisedValues: {
            av_hold_cancellation_reasons: "HOLD_CANCELLATION",
        },
        sysprefs: {
            AllowHoldPolicyOverride: 0,
        },
        // Keyed by `${biblio_id}:${patron_id}:${pickup_library_id}` - the
        // result can genuinely differ per pickup library (cannot_be_transferred,
        // library_not_pickup_location), so that has to be part of the key once
        // HoldabilityShield re-checks on a pickup library change, not just a
        // biblio/patron change. Lets HoldabilityShield render instantly from
        // the last response for a combination already seen, while a fresh
        // call still runs in the background and replaces the entry
        // (stale-while-revalidate, not a permanent cache).
        expressCache: {},
    });

    const sharedActions = withAuthorisedValueActions(store);

    const actions = {
        getExpressCache(biblio_id, patron_id, pickup_library_id) {
            return this.expressCache[
                `${biblio_id}:${patron_id}:${pickup_library_id}`
            ];
        },
        setExpressCache(biblio_id, patron_id, pickup_library_id, holdability) {
            this.expressCache[
                `${biblio_id}:${patron_id}:${pickup_library_id}`
            ] = {
                holdability,
                fetched_at: Date.now(),
            };
        },
    };

    return {
        ...toRefs(store),
        ...sharedActions,
        ...actions,
    };
});
