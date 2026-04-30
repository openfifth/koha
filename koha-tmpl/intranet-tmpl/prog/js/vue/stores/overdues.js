import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";

export const useOverduesStore = defineStore("overdues", () => {
    const store = reactive({
        authorisedValues: {
            location: "LOC",
        },
        settings: {},
        itemTypes: [],
        patronAttrs: [],
    });
    const sharedActions = withAuthorisedValueActions(store);

    return {
        ...toRefs(store),
        ...sharedActions,
    };
});
