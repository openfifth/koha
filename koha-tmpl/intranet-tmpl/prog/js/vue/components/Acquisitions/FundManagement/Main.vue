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
                    <LeftMenu
                        :title="'Acquisitions'"
                        :key="modulesEnabled"
                    ></LeftMenu>
                </div>
            </div>
        </div>
    </div>
    <div class="main container-fluid" v-else>
        <Dialog />
    </div>
</template>

<script>
import LeftMenu from "../../LeftMenu.vue"
import Breadcrumbs from "../../Breadcrumbs.vue"
import Help from "../../Help.vue"
import Dialog from "../../Dialog.vue"
import "vue-select/dist/vue-select.css"
import { inject, onBeforeMount, ref } from "vue"
import { storeToRefs } from "pinia"
import { APIClient } from "../../../fetch/api-client.js"
import { useRoute } from 'vue-router'

export default {
    components: {
        LeftMenu,
        Breadcrumbs,
        Dialog,
        Help,
    },
    setup() {
        const mainStore = inject("mainStore")
        const { loading, loaded, setError } = mainStore

        const acquisitionsStore = inject("acquisitionsStore")
        const {
            filterUsersByPermissions,
            filterLibGroupsByUsersBranchcode,
            convertSettingsToObject,
            setLibraryGroups,
            loadAuthorisedValues
        } = acquisitionsStore
        const {
            user,
            settings,
            libraryGroups,
            permittedUsers,
            modulesEnabled,
            visibleGroups,
            owners,
            currencies,
            authorisedValues
        } = storeToRefs(acquisitionsStore)

        const initialized = ref(false);
        const userPermitted = ref(false);

        const route = useRoute()
        onBeforeMount(() => {
            loading();

            const libraryClient = APIClient.libraries
            libraryClient.libraryGroups.getAll().then(
                libraryGroups => {
                    setLibraryGroups(libraryGroups)
                },
                error => {}
            )

            loadAuthorisedValues(authorisedValues.value, acquisitionsStore).then(() => {
                permittedUsers.value = permitted_patrons
                const { permission } = route.meta.self
                const permissionRequired = permission ? permission : null
                user.value.loggedInUser = logged_in_user
                user.value.loggedInUser.loggedInBranch =
                    logged_in_branch.branchcode
                user.value.userflags = userflags
                currencies.value = currencies
                const { acquisition, superlibrarian } = user.value.userflags
                if (!acquisition && !superlibrarian) {
                    return setError(
                        $__(
                            "You do not have permission to access this module. Please contact your system administrator."
                        ),
                        false
                    )
                }
                owners.value =
                    filterUsersByPermissions(permissionRequired)
                visibleGroups.value = filterLibGroupsByUsersBranchcode()
                settings.value = {
                    modulesEnabled: {
                        value: "funds",
                    },
                }
                userPermitted.value = true
                loaded()
                initialized.value = true
            })
        })

        return {
            setError,
            loading,
            loaded,
            settings,
            user,
            libraryGroups,
            permittedUsers,
            modulesEnabled,
            visibleGroups,
            owners,
            filterUsersByPermissions,
            filterLibGroupsByUsersBranchcode,
            convertSettingsToObject,
            currencies,
            setLibraryGroups,
            initialized,
            userPermitted,
            authorisedValues
        }
    }
}
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
input:not([type="submit"]):not([type="search"]):not([type="button"]):not([type="checkbox"]),
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
