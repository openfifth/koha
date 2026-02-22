import { defineStore } from "pinia";

export const useIdentityProvidersStore = defineStore("identity_providers", {
    state: () => ({
        current_provider: null,
    }),
    actions: {
        setCurrentProvider(provider) {
            this.current_provider = provider;
        },
        clearCurrentProvider() {
            this.current_provider = null;
        },
    },
});
