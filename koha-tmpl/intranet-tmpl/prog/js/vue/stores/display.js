import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";
import { permissionsActions } from "../composables/permissions";

export const useDisplayStore = defineStore("display", () => {
    const store = reactive({
        config: {
            settings: {
                enabled: 0,
            },
        },
        authorisedValues: {
            av_loc: "LOC",
            av_ccode: "CCODE",
            av_display_return_over: "DISPLAY_RETURN_OVER",
        },
        userPermissions: null,
    });

    const sharedActions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
    };

    return {
        ...toRefs(store),
        ...sharedActions,
    };
});
