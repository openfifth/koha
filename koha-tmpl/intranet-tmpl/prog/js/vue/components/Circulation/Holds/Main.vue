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
                    <LeftMenu :title="$__('Holds')"></LeftMenu>
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

export default {
    setup() {
        const holdsStore = inject("holdsStore");
        const { authorisedValues } = storeToRefs(holdsStore);
        const { loadAuthorisedValues } = holdsStore;

        const mainStore = inject("mainStore");
        const { loading, loaded, setError } = mainStore;

        const initialized = ref(false);

        onBeforeMount(() => {
            loading();

            loadAuthorisedValues(authorisedValues.value, holdsStore).then(
                () => {
                    loaded();
                    initialized.value = true;
                }
            );
        });

        return {
            holdsStore,
            authorisedValues,
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
