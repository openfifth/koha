import { defineStore } from "pinia";
import { permissionsMatrix } from "../data/permissionsMatrix";
import { reactive, computed, toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";
import { permissionsActions } from "../composables/permissions";
import { libraryGroupsActions } from "../composables/libraryGroups";

export const useAcquisitionsStore = defineStore("acquisitionsStore", () => {
    const store = reactive({
        user: {
            loggedInUser: null,
            userflags: null,
        },
        libraryGroups: null,
        settings: null,
        permittedUsers: null,
        visibleGroups: null,
        owners: null,
        navigationBlocked: false,
        currentPermission: null,
        moduleList: {
            funds: { name: "Funds and ledgers", code: "funds" },
        },
        permissionsMatrix: permissionsMatrix,
        currencies: [],
        authorisedValues: {
            av_fund_type: "FUND_TYPE",
        },
        userPermissions: null,
    });
    const actions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
        ...libraryGroupsActions(store),
        _findBranchCodesInGroup(groups) {
            const codes = [];
            groups.forEach(group => {
                group.libraries.forEach(lib => {
                    if (!codes.find(code => code === lib.branchcode)) {
                        codes.push(lib.branchcode);
                    }
                });
            });
            return codes;
        },
        filterUsersByPermissions(
            operation,
            branchcodes = null,
            returnAll = false
        ) {
            const filteredUsers = [];
            store.permittedUsers.forEach(user => {
                user.displayName = user.firstname + " " + user.surname;
                if (returnAll) {
                    filteredUsers.push(user);
                } else {
                    const userPermitted = permissionsActions(
                        store
                    ).isUserPermitted(operation, user.permissions);
                    if (userPermitted) {
                        filteredUsers.push(user);
                    }
                }
            });
            if (branchcodes) {
                return filteredUsers.filter(user =>
                    branchcodes.includes(user.branchcode)
                );
            } else {
                return filteredUsers;
            }
        },
        // isUserPermitted(operation, flags) {
        //     const userflags = flags ? flags : this.user.userflags;
        //     if (!operation) return true;
        //     if (this.permissionsMatrix[operation].length === 0) return true;

        //     const { acquisition, parameters, superlibrarian } = userflags;
        //     if (operation === "manageSettings") {
        //         let checkResult = false;
        //         if (
        //             superlibrarian ||
        //             parameters === 1 ||
        //             parameters.manage_sysprefs
        //         ) {
        //             checkResult = true;
        //         } else {
        //             checkResult = false;
        //         }
        //         return checkResult;
        //     }

        //     if (acquisition === 1 || superlibrarian) {
        //         return true;
        //     } else {
        //         const checks = this.permissionsMatrix[operation].map(
        //             permission => {
        //                 if (acquisition[permission]) {
        //                     return true;
        //                 } else {
        //                     return false;
        //                 }
        //             }
        //         );
        //         const failedChecks = checks.filter(check => !check).length;
        //         return failedChecks > 0 ? false : true;
        //     }
        // },
        filterGroupsBasedOnOwner(e, data) {
            const libGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                store.visibleGroups
            );
            const permittedUsers = this.filterUsersByPermissions(
                store.currentPermission
            );
            if (!e) {
                store.visibleGroups = libGroups;
                store.owners = permittedUsers;
                data.lib_group_visibility = null;
            } else {
                const { branchcode } = permittedUsers.find(
                    user => user.borrowernumber === e.borrowernumber
                );
                store.visibleGroups = this.filterLibGroupsByUsersBranchcode(
                    branchcode,
                    store.visibleGroups
                );
            }
        },
        filterOwnersBasedOnGroup(e, data) {
            const libGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                store.visibleGroups
            );
            const permittedUsers = this.filterUsersByPermissions(
                store.currentPermission
            );
            if (!e.length) {
                store.visibleGroups = libGroups;
                store.owners = permittedUsers;
                data.owner_id = null;
            } else {
                const filteredGroups = libGroups.filter(group =>
                    e.includes(group.id)
                );
                const branchcodes =
                    this._findBranchCodesInGroup(filteredGroups);
                store.owners = this.filterUsersByPermissions(
                    store.currentPermission,
                    branchcodes
                );
            }
        },
        setOwnersBasedOnPermission(permission) {
            if (store.permittedUsers) {
                store.owners = this.filterUsersByPermissions(permission);
            }
        },
        resetOwnersAndVisibleGroups(groups) {
            store.owners = this.filterUsersByPermissions(
                store.currentPermission
            );
            store.visibleGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
        },
        formatValueWithCurrency(value, currency) {
            const { symbol } = store.currencies.find(
                curr => curr.currency === currency
            );
            if (!value) {
                return `${symbol}0`;
            }
            const formattedPrice = value.format_price();
            if (!formattedPrice) {
                return `${symbol}0`;
            }
            if (formattedPrice < 0) {
                return `-${symbol}${-formattedPrice}`;
            }
            return `${symbol}${formattedPrice}`;
        },
    };
    const getters = {
        modulesEnabled: computed(() => {
            const modulesEnabled = store.settings.modulesEnabled;
            return modulesEnabled.value ? modulesEnabled.value : "";
        }),
        getVisibleGroups: computed(() => {
            return store.visibleGroups?.length
                ? store.visibleGroups
                : actions.filterLibGroupsByUsersBranchcode();
        }),
        getOwners: computed(() => {
            return store.owners;
        }),
    };

    return {
        ...toRefs(store),
        ...actions,
        ...getters,
    };
});
