import { defineStore } from "pinia";
import { reactive, toRefs } from "vue";
import { permissionsActions } from "../composables/permissions";

export const usePluginStoreStore = defineStore("plugin-store", () => {
    const store = reactive({
        installedPlugins: [],
        userPermissions: null,
    });

    const sharedActions = {
        ...permissionsActions(store),
    };

    return {
        ...toRefs(store),
        ...sharedActions,
    };
});
