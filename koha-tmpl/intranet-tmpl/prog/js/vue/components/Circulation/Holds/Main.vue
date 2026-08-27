<template>
    <div v-if="initialized">
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
                    <!-- <LeftMenu :title="$__('Holds')"></LeftMenu> -->
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
import Breadcrumbs from "../../Breadcrumbs.vue";
import Help from "../../Help.vue";
import LeftMenu from "../../LeftMenu.vue";
import Dialog from "../../Dialog.vue";
import "vue-select/dist/vue-select.css";
import { storeToRefs } from "pinia";
import { APIClient } from "../../../fetch/api-client.js";

export default {
    setup() {
        const holdsStore = inject("holdsStore");
        const { authorisedValues, sysprefs } = storeToRefs(holdsStore);
        const { loadAuthorisedValues } = holdsStore;

        const mainStore = inject("mainStore");
        const { loading, loaded, setError } = mainStore;

        const initialized = ref(false);

        onBeforeMount(() => {
            loading();

            const fetchSysprefs = APIClient.sysprefs.sysprefs
                .get("AllowHoldPolicyOverride")
                .then(result => {
                    sysprefs.value.AllowHoldPolicyOverride = result.value;
                });

            Promise.all([
                loadAuthorisedValues(authorisedValues.value, holdsStore),
                fetchSysprefs,
            ]).then(() => {
                loaded();
                initialized.value = true;
            });
        });

        return {
            holdsStore,
            authorisedValues,
            sysprefs,
            setError,
            loading,
            loaded,
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

<style></style>
