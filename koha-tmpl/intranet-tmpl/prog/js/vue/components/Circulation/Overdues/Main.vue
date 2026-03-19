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
                    <OverdueFilters :patronAttrs="patronAttrs" />
                </div>
            </div>
        </div>
    </div>
    <div class="main container-fluid" v-else>
        <Dialog />
    </div>
</template>

<script>
import Breadcrumbs from "../../Breadcrumbs.vue";
import Help from "../../Help.vue";
import Dialog from "../../Dialog.vue";
import LeftMenu from "../../LeftMenu.vue";
import OverdueFilters from "./OverdueFilters.vue";
import "vue-select/dist/vue-select.css";
import { inject, onBeforeMount, ref } from "vue";
import { storeToRefs } from "pinia";
import { APIClient } from "../../../fetch/api-client.js";

export default {
    components: {
        Breadcrumbs,
        Dialog,
        Help,
        LeftMenu,
        OverdueFilters,
    },
    setup(props) {
        const initialized = ref(false);

        const mainStore = inject("mainStore");
        const { loading, loaded } = mainStore;

        const overduesStore = inject("overduesStore");
        const { authorisedValues, settings, itemTypes } =
            storeToRefs(overduesStore);
        const { loadAuthorisedValues } = overduesStore;

        const fetchConfig = () => {
            const client = APIClient.circulation;
            client.config.get().then(result => {
                settings.value = result.settings;
                const itypesClient = APIClient.item;
                itypesClient.item_types.getAll().then(itypes => {
                    itemTypes.value = itypes;
                    loaded();
                    initialized.value = true;
                });
            });
        };

        onBeforeMount(() => {
            loading();
            const attributeAVs = patronAttrs.reduce((acc, pa) => {
                if (pa.authorised_value_category) {
                    acc[pa.code] = pa.authorised_value_category;
                }
                return acc;
            }, {});
            authorisedValues.value = {
                ...authorisedValues.value,
                ...attributeAVs,
            };
            loadAuthorisedValues(authorisedValues.value, overduesStore).then(
                () => {
                    fetchConfig();
                }
            );
        });
        return {
            patronAttrs,
            initialized,
        };
    },
};
</script>

<style></style>
