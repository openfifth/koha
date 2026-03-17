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
        const { authorisedValues } = storeToRefs(overduesStore);
        const { loadAuthorisedValues } = overduesStore;

        onBeforeMount(() => {
            loading();
            let needsAuthorisedValues = false;
            authorisedValues.value = patronAttrs.reduce((acc, pa) => {
                if (pa.authorised_value_category) {
                    needsAuthorisedValues = true;
                    acc[pa.code] = pa.authorised_value_category;
                }
                return acc;
            }, {});
            if (needsAuthorisedValues) {
                loadAuthorisedValues(
                    authorisedValues.value,
                    overduesStore
                ).then(() => {
                    loaded();
                    initialized.value = true;
                });
            }
        });
        return {
            patronAttrs,
            initialized,
        };
    },
};
</script>

<style></style>
