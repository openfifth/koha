import { ref } from "vue";
import { APIClient } from "../fetch/api-client.js";
import { useHoldOverrideConfirmation } from "./hold-override-confirmation.js";

// Shared "place directly, or open the override confirmation first" sequence
// used by every hold form (Express, and the Item Group/Item panels of the
// granular hold screen) - what varies between callers is only the body sent
// to POST /holds (biblio_id vs item_group_id vs item_id), not the submit
// flow itself. HoldabilityShield only ever reports what's blocked; this is
// where a caller decides what to do about it.
export const useHoldSubmission = () => {
    const { requestHoldOverride } = useHoldOverrideConfirmation();

    const placing = ref(false);
    const holdPlaced = ref(false);
    const errorMessage = ref(null);

    // body: the POST /holds payload (patron_id, pickup_library_id, plus
    // whichever of biblio_id/item_group_id/item_id the caller is placing a
    // hold against). Returns the same promise placeHold's caller would get
    // from APIClient.circulation.holds.create, so callers can still chain
    // their own success handling (e.g. a toast) after it resolves.
    const placeHold = (body, overrides = []) => {
        placing.value = true;
        errorMessage.value = null;
        holdPlaced.value = true; // optimistic: lock the form immediately

        return APIClient.circulation.holds.create(body, overrides).then(
            hold => {
                placing.value = false;
                return hold;
            },
            error => {
                // Roll back the optimistic lock - nothing was placed.
                placing.value = false;
                holdPlaced.value = false;
                errorMessage.value = error.message || error;
                throw error;
            }
        );
    };

    // The single entry point for a form's "Place hold" button: place the
    // hold directly when it's already available, otherwise - if there's an
    // overridable block - show the override confirmation first and only
    // place the hold if the user accepts it.
    const submit = (available, overridable, blockedReasons, body) => {
        if (available) {
            return placeHold(body);
        } else if (overridable) {
            return requestHoldOverride(blockedReasons).then(codes => {
                if (codes) return placeHold(body, codes);
            });
        }
    };

    return { placing, holdPlaced, errorMessage, submit, placeHold };
};
