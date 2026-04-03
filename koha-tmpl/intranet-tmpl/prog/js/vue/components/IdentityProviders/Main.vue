<template>
    <div v-if="initialized">
        <Teleport to="#vue-breadcrumbs-container">
            <Breadcrumbs />
        </Teleport>
        <Dialog />
        <router-view />
    </div>
</template>

<script>
import { inject, onBeforeMount, ref } from "vue";
import Breadcrumbs from "../Breadcrumbs.vue";
import Dialog from "../Dialog.vue";
import "vue-select/dist/vue-select.css";

export default {
    setup() {
        const mainStore = inject("mainStore");
        const { loading, loaded } = mainStore;

        const initialized = ref(false);

        onBeforeMount(() => {
            loading();
            setTimeout(() => {
                loaded();
                initialized.value = true;
            }, 0);
        });

        return { initialized };
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
