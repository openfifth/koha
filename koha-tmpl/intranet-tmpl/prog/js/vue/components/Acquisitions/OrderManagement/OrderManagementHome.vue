<template>
    <Toolbar>
        <ToolbarLink
            :to="{ name: 'OrderlineFormAdd' }"
            icon="plus"
            :title="$__('Add orderline')"
            v-if="isUserPermitted('manageOrderlines')"
        />
    </Toolbar>
</template>

<script>
import { inject } from "vue";
import Toolbar from "../../Toolbar.vue";
import ToolbarLink from "../../ToolbarLink.vue";

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore");
        const { isUserPermitted } = acquisitionsStore;

        return {
            isUserPermitted,
        };
    },
    components: {
        Toolbar,
        ToolbarLink,
    },
};
</script>

<style></style>
