<template>
    <h1 id="acq2_homepage">{{ $__("Homepage") }}</h1>
</template>

<script>
import { inject, onBeforeMount } from "vue";
import { storeToRefs } from "pinia";
import { setWarning } from "../../../messages";
import { $__ } from "@koha-vue/i18n";

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
};
</script>

<style></style>
