import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";

export const useILLStore = defineStore("ill", () => {
    const store = reactive({
        config: {
            settings: {
                ILLModule: 1,
                ILLPartnerCode: "IL",
            },
        },
    });

    return {
        ...toRefs(store),
    };
});
