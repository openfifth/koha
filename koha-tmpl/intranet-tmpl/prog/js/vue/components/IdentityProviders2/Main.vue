<template>
    <div>
        <div id="sub-header">
            <Breadcrumbs />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-md-12">
                    <main>
                        <Dialog />
                        <router-view />
                    </main>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { inject, onBeforeMount } from "vue";
import Breadcrumbs from "@koha-vue/components/Breadcrumbs.vue";
import Dialog from "@koha-vue/components/Dialog.vue";
import "vue-select/dist/vue-select.css";

export default {
    setup() {
        const mainStore = inject("mainStore");
        const { loading, loaded } = mainStore;

        onBeforeMount(() => {
            // Placeholder: The actual loading state management might be handled by parent or router
            // Removed setTimeout and initialized ref for synchronous rendering
        });

        return {};
    },
    components: {
        Breadcrumbs,
        Dialog,
    },
};
</script>

<style>
#menu ul ul,
#navmenulist ul ul {
    padding-left: 2em;
    font-size: 100%;
}

form .v-select {
    display: inline-block;
    background-color: white;
    width: 30%;
}

.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not(
        [type="checkbox"]
    ):not([type="radio"]),
textarea {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 30%;
}

#navmenulist ul li a.current.disabled {
    background-color: inherit;
    border-left: 5px solid #e6e6e6;
    color: #000;
}

#navmenulist ul li a.disabled {
    color: #666;
    pointer-events: none;
    font-weight: 700;
}
</style>
