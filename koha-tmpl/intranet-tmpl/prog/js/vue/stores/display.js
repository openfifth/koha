import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";

export const useDisplayStore = defineStore("display", () => {
    const store = reactive({
        displayReturnOverMapping: [],
        config: {
            settings: {
                enabled: 0,
            },
        },
        authorisedValues: {
            av_loc: "LOC",
            av_ccode: "CCODE",
        },
    });

    const sharedActions = {
        ...withAuthorisedValueActions(store),
    };

    return {
        ...toRefs(store),
        ...sharedActions,
    };
});
