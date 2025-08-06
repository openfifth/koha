import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";

export const useILLStore = defineStore("ill", () => {
    const store = reactive({
        config: {
            settings: {
                ILLModule: true,
            },
        },
    });

    return {
        ...toRefs(store),
    };
});
