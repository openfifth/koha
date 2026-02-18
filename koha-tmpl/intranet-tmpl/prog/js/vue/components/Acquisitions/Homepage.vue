<template>
    <Toolbar>
        <ToolbarButton
            to="cgi-bin/koha/acquisition/vendors/add"
            icon="plus"
            :title="$__('New vendor')"
            callback="redirect"
        />
        <ToolbarButton
            icon="plus"
            :title="$__('New order line')"
            :onClick="() => setCustomModal('addorderline')"
        />
        <ToolbarButton
            icon="plus"
            :title="$__('Orderline search')"
            to="cgi-bin/koha/acquisitions/order_management/orderlines/search"
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

        const mainStore = inject("mainStore");
        const { setCustomModal } = mainStore;

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
            setCustomModal,
        };
    },
    components: {
        Toolbar,
        ToolbarButton,
    },
};
</script>

<style></style>
