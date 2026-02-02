import { defineStore } from "pinia";

export const useShibbolethStore = defineStore("shibboleth", {
    state: () => ({
        config: null,
        mappings: [],
    }),
    actions: {
        setConfig(config) {
            this.config = config;
        },
        setMappings(mappings) {
            this.mappings = mappings;
        },
    },
});
