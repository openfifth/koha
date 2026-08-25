import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";

export const useHoldsStore = defineStore("holds", () => {
    const store = reactive({
        authorisedValues: {
            av_hold_cancellation_reasons: "HOLD_CANCELLATION",
        },
    });

    const sharedActions = withAuthorisedValueActions(store);

    return {
        ...toRefs(store),
        ...sharedActions,
    };
});
