import { defineStore } from "pinia";
import { permissionsMatrix } from "../data/permissionsMatrix";
import { reactive } from "vue";
import { toRefs } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";
import { permissionsActions } from "../composables/permissions";
import { libraryGroupsActions } from "../composables/libraryGroups";

export const useAcquisitionsStore = defineStore("acquisitions", () => {
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
            acquire_fund_types: "ACQUIRE_FUND_TYPE",
        },
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
            this.permittedUsers.forEach(user => {
                user.displayName = user.firstname + " " + user.surname;
                if (returnAll) {
                    filteredUsers.push(user);
                } else {
                    const userPermitted = this.isUserPermitted(
                        operation,
                        user.permissions
                    );
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
        isUserPermitted(operation, flags) {
            const userflags = flags ? flags : this.user.userflags;
            if (!operation) return true;
            if (this.permissionsMatrix[operation].length === 0) return true;

            const { acquisition, parameters, superlibrarian } = userflags;
            if (operation === "manageSettings") {
                let checkResult = false;
                if (
                    superlibrarian ||
                    parameters === 1 ||
                    parameters.manage_sysprefs
                ) {
                    checkResult = true;
                } else {
                    checkResult = false;
                }
                return checkResult;
            }

            if (acquisition === 1 || superlibrarian) {
                return true;
            } else {
                const checks = this.permissionsMatrix[operation].map(
                    permission => {
                        if (acquisition[permission]) {
                            return true;
                        } else {
                            return false;
                        }
                    }
                );
                const failedChecks = checks.filter(check => !check).length;
                return failedChecks > 0 ? false : true;
            }
        },
        filterGroupsBasedOnOwner(e, data, groups) {
            const libGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
            const permittedUsers = this.filterUsersByPermissions(
                this.currentPermission
            );
            if (!e) {
                this.visibleGroups = libGroups;
                this.owners = permittedUsers;
                data.lib_group_visibility = null;
            } else {
                const { branchcode } = permittedUsers.find(
                    user => user.borrowernumber === e
                );
                this.visibleGroups = this.filterLibGroupsByUsersBranchcode(
                    branchcode,
                    groups
                );
            }
        },
        filterOwnersBasedOnGroup(e, data, groups) {
            const libGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
            const permittedUsers = this.filterUsersByPermissions(
                this.currentPermission
            );
            if (!e.length) {
                this.visibleGroups = libGroups;
                this.owners = permittedUsers;
                data.owner_id = null;
            } else {
                const filteredGroups = libGroups.filter(group =>
                    e.includes(group.id)
                );
                const branchcodes =
                    this._findBranchCodesInGroup(filteredGroups);
                this.owners = this.filterUsersByPermissions(
                    this.currentPermission,
                    branchcodes
                );
            }
        },
        setOwnersBasedOnPermission(permission) {
            if (this.permittedUsers) {
                this.owners = this.filterUsersByPermissions(permission);
            }
        },
        resetOwnersAndVisibleGroups(groups) {
            this.owners = this.filterUsersByPermissions(this.currentPermission);
            this.visibleGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
        },
        getSetting(input) {
            if (typeof input === "string") {
                return this.settings[input];
            } else {
                return input.map(setting => {
                    return this.settings[setting];
                });
            }
        },
        convertSettingsToObject(settings) {
            const settingsObject = {};
            settings.forEach(setting => {
                settingsObject[setting.variable] = setting;
            });
            return settingsObject;
        },
        formatValueWithCurrency(currency, value) {
            const { symbol } = this.currencies.find(
                curr => curr.currency === currency
            );
            if (!value) {
                return `${symbol}0`;
            }
            if (value < 0) {
                return `-${symbol}${-value}`;
            }
            return `${symbol}${value}`;
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
                : this.filterLibGroupsByUsersBranchcode();
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
