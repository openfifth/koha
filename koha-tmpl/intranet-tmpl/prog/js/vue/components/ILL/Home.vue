<template>
    <ModuleDashboard name="ILL" :availableWidgets="availableWidgets" />
</template>

<script>
import ModuleDashboard from "../ModuleDashboard/ModuleDashboard.vue";
import ILLRequests from "../ModuleDashboard/Widgets/ILLRequests.vue";
import { markRaw } from "vue";

export default {
    components: { ModuleDashboard },
    setup() {
        const availableWidgets = [markRaw(ILLRequests)];
        return {
            availableWidgets,
        };
    },
};
</script>
