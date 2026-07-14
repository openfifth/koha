<template>
    <div v-if="initialized">
        <div id="checkin-app">
            <h1>{{ $__("Check in") }}</h1>
            <p>{{ $__("Checkin Vue app loaded successfully.") }}</p>
            <pre>{{ JSON.stringify(policy, null, 2) }}</pre>
        </div>
    </div>
    <div v-else>
        <p>{{ $__("Loading...") }}</p>
    </div>
</template>

<script>
import { inject, onBeforeMount, reactive, ref } from "vue";
import { $__ } from "@koha-vue/i18n";

export default {
    setup() {
        const mainStore = inject("mainStore");
        const { loading, loaded } = mainStore;

        const initialized = ref(false);
        const policy = reactive(window.__MODULE_POLICY__ || {});

        onBeforeMount(() => {
            loading();
            // Policy is hydrated from the template, no fetch needed
            loaded();
            initialized.value = true;
        });

        return {
            initialized,
            policy,
            $__,
        };
    },
};
</script>
