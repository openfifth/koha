<template>
    <div v-if="initialized && userPermitted">
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-md-10 order-md-2 order-sm-1">
                    <main>
                        <Dialog />
                        <router-view :key="$route.name" />
                    </main>
                </div>

                <div class="col-md-2 order-sm-2 order-md-1">
                    <LeftMenu :title="'Acquisitions'"></LeftMenu>
                </div>
            </div>
        </div>
    </div>
    <div class="main container-fluid" v-else>
        <Dialog />
    </div>
</template>

<script>
import LeftMenu from "../LeftMenu.vue";
import Breadcrumbs from "../Breadcrumbs.vue";
import Help from "../Help.vue";
import Dialog from "../Dialog.vue";
import "vue-select/dist/vue-select.css";
import { inject, onBeforeMount, ref } from "vue";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { useRoute } from "vue-router";

export default {
    components: {
        LeftMenu,
        Breadcrumbs,
        Dialog,
        Help,
    },
    setup() {
        const mainStore = inject("mainStore");
        const { loading, loaded, setError } = mainStore;

        const acquisitionsStore = inject("acquisitionsStore");
        const { loadAuthorisedValues } = acquisitionsStore;
        const {
            user,
            settings,
            permittedUsers,
            modulesEnabled,
            currencies,
            gstValues,
            sysprefs,
            authorisedValues,
            userPermissions,
        } = storeToRefs(acquisitionsStore);

        const initialized = ref(false);
        const userPermitted = ref(false);

        const route = useRoute();
        onBeforeMount(() => {
            loading();

            loadAuthorisedValues(
                authorisedValues.value,
                acquisitionsStore
            ).then(() => {
                const client = APIClient.acquisition;
                client.config.get("fund_management").then(result => {
                    userPermissions.value = result.permissions;
                    permittedUsers.value = permitted_patrons;
                    const { permission } = route.meta.self;
                    const permissionRequired = permission ? permission : null;
                    user.value.loggedInUser = logged_in_user;
                    user.value.loggedInUser.loggedInBranch =
                        logged_in_branch.branchcode;
                    user.value.userflags = userflags;
                    currencies.value = currencyList;
                    sysprefs.value = result.sysprefs;
                    gstValues.value = result.gst_values.map(gv => {
                        return {
                            label: `${Number(gv.option * 100).format_price()}%`,
                            value: gv.option,
                        };
                    });
                    const { acquisition, superlibrarian } =
                        user.value.userflags;
                    if (!acquisition && !superlibrarian) {
                        return setError(
                            $__(
                                "You do not have permission to access this module. Please contact your system administrator."
                            ),
                            false
                        );
                    }
                    userPermitted.value = true;
                    loaded();
                    initialized.value = true;
                });
            });
        });

        return {
            setError,
            loading,
            loaded,
            settings,
            user,
            permittedUsers,
            modulesEnabled,
            currencies,
            initialized,
            userPermitted,
            authorisedValues,
        };
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
.flatpickr-input {
    width: 30%;
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
