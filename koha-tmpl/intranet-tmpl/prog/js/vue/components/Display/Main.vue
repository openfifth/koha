<template>
    <div v-if="initialized && config.settings.enabled == 1">
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-md-10 order-md-2 order-sm-1">
                    <main>
                        <Dialog />
                        <router-view />
                    </main>
                </div>

                <div class="col-md-2 order-sm-2 order-md-1">
                    <LeftMenu :title="$__('Displays')"></LeftMenu>
                </div>
            </div>
        </div>
    </div>
    <div class="main container-fluid" v-else>
        <Dialog />
    </div>
</template>

<script>
import { inject, onBeforeMount, ref } from "vue";
import Breadcrumbs from "../Breadcrumbs.vue";
import Help from "../Help.vue";
import LeftMenu from "../LeftMenu.vue";
import Dialog from "../Dialog.vue";
import { APIClient } from "../../fetch/api-client.js";
import "vue-select/dist/vue-select.css";
import { storeToRefs } from "pinia";
import { $__ } from "@koha-vue/i18n";

export default {
    setup() {
        const mainStore = inject("mainStore");

        const { loading, loaded, setError } = mainStore;

        const displayStore = inject("displayStore");

        const { config, authorisedValues, userPermissions } =
            storeToRefs(displayStore);
        const { loadAuthorisedValues } = displayStore;

        const initialized = ref(false);

        onBeforeMount(() => {
            loading();

            const client = APIClient.display;
            client.config.get().then(result => {
                userPermissions.value = result.settings.permissions;
                config.value.settings.enabled = result.settings.enabled;
                if (config.value.settings.enabled != 1) {
                    loaded();
                    return setError(
                        $__(
                            'The displays module is disabled, turn on <a href="/cgi-bin/koha/admin/preferences.pl?tab=&op=search&searchfield=UseDisplayModule">UseDisplayModule</a> to use it'
                        ),
                        false
                    );
                }

                loadAuthorisedValues(authorisedValues.value, displayStore).then(
                    () => {
                        loaded();
                        initialized.value = true;
                    }
                );
            });
        });

        return {
            loading,
            loaded,
            authorisedValues,
            config,
            setError,
            userPermissions,
            displayStore,
            initialized,
        };
    },
    components: {
        Breadcrumbs,
        Dialog,
        Help,
        LeftMenu,
    },
};
</script>

<style>
form .v-select {
    display: inline-block;
    background-color: white;
    width: 30%;
}
</style>
