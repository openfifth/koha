<template>
    <Toolbar>
        <ToolbarButton
            to="cgi-bin/koha/acquisition/vendors/add"
            icon="plus"
            :title="$__('New vendor')"
            callback="redirect"
        />
        <ToolbarButton
            to="cgi-bin/koha/acquisition/vendors/add"
            icon="plus"
            :title="$__('New order line')"
            callback="redirect"
        />
    </Toolbar>
    <h1>{{ $__("Homepage") }}</h1>
    <h3>Vendor search here</h3>
    <h3>Widget dashboard here</h3>
</template>

<script>
import { inject, onBeforeMount } from "vue";
import { storeToRefs } from "pinia";
import { setWarning } from "../../messages";
import { $__ } from "@koha-vue/i18n";
import Toolbar from "../Toolbar.vue";
import ToolbarButton from "../ToolbarButton.vue";

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore");
        const { navigationBlocked } = storeToRefs(acquisitionsStore);

        onBeforeMount(() => {
            if (navigationBlocked.value) {
                setWarning(
                    $__(
                        "You did not have the required permissions to access that page. Please contact your system administrator."
                    )
                );
                navigationBlocked.value = false;
            }
        });

        return {
            navigationBlocked,
        };
    },
    components: {
        Toolbar,
        ToolbarButton,
    },
};
</script>

<style></style>
