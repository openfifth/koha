import { defineStore } from "pinia";
import { reactive, toRefs, computed } from "vue";
import { withAuthorisedValueActions } from "../composables/authorisedValues";
import { permissionsActions } from "../composables/permissions";

export const useVendorStore = defineStore("vendors", () => {
    const store = reactive({
        vendors: [],
        currencies: [],
        gstValues: [],
        libraryGroups: null,
        visibleGroups: null,
        user: {
            loggedInUser: null,
            userflags: null,
        },
        config: {
            settings: {
                edifact: false,
                marcOrderAutomation: false,
            },
        },
        authorisedValues: {
            av_vendor_types: "VENDOR_TYPE",
            av_vendor_interface_types: "VENDOR_INTERFACE_TYPE",
            av_vendor_payment_methods: "VENDOR_PAYMENT_METHOD",
            av_lang: "LANG",
        },
        userPermissions: null,
    });
    const actions = {
        ...withAuthorisedValueActions(store),
        ...permissionsActions(store),
        determineBranch(code) {
            if (code) {
                return code;
            }
            const {
                loggedInUser: { loggedInBranch, branchcode },
            } = store.user;
            return loggedInBranch ? loggedInBranch : branchcode;
        },
        _matchSubGroups(group, filteredGroups, branch, groupsToCheck) {
            let matched = false;
            if (group.libraries.find(lib => lib.branchcode === branch)) {
                if (
                    groupsToCheck &&
                    groupsToCheck.length &&
                    groupsToCheck.includes(group.id)
                ) {
                    filteredGroups[group.id] = group;
                    matched = true;
                }
                if (!groupsToCheck || groupsToCheck.length === 0) {
                    filteredGroups[group.id] = group;
                    matched = true;
                }
            }
            if (group.subGroups && group.subGroups.length) {
                group.subGroups.forEach(grp => {
                    const result = this._matchSubGroups(
                        grp,
                        filteredGroups,
                        branch,
                        groupsToCheck
                    );
                    matched = matched ? matched : result;
                });
            }
            return matched;
        },
        filterLibGroupsByUsersBranchcode(branchcode, groupsToCheck) {
            const branch = this.determineBranch(branchcode);
            const filteredGroups = {};
            if (!store.libraryGroups) {
                return [];
            }
            store.libraryGroups.forEach(group => {
                const matched = this._matchSubGroups(
                    group,
                    filteredGroups,
                    branch,
                    groupsToCheck
                );
                // If a sub group has been matched but the parent level group did not, then we should add the parent level group as well
                // This happens when a parent group doesn't have any branchcodes assigned to it, only sub groups
                if (
                    matched &&
                    !Object.keys(filteredGroups).find(id => id === group.id)
                ) {
                    filteredGroups[group.id] = group;
                }
            });
            return Object.keys(filteredGroups)
                .map(key => {
                    return filteredGroups[key];
                })
                .sort((a, b) => a.id - b.id);
        },
        formatLibraryGroupIds(ids) {
            if (!ids) {
                return [];
            }
            const groups = ids.includes("|") ? ids.split("|") : [ids];
            const groupIds = groups.map(group => {
                return parseInt(group);
            });
            return groupIds;
        },
        setLibraryGroups(groups) {
            if (!groups?.length) {
                return;
            }
            const topLevelGroups = groups.filter(
                group => !group.parent_id && group.ft_acquisitions
            );
            if (!topLevelGroups?.length) {
                return;
            }
            store.libraryGroups = topLevelGroups.map(group => {
                return this._mapLibraryGroup(group, groups);
            });
        },
        _mapLibraryGroup(group, groups) {
            const groupInfo = {
                id: group.id,
                title: group.title,
                libraries: [],
                subGroups: [],
            };
            const libsOrSubGroups = groups.filter(
                grp => grp.parent_id == group.id
            );
            libsOrSubGroups.forEach(libOrSubGroup => {
                if (libOrSubGroup.branchcode) {
                    groupInfo.libraries.push(libOrSubGroup);
                } else {
                    const subGroupInfo = this._mapLibraryGroup(
                        libOrSubGroup,
                        groups,
                        true
                    );
                    groupInfo.subGroups.push(subGroupInfo);
                }
            });
            groupInfo.subGroups.forEach(subGroup => {
                subGroup.libraries.forEach(lib => {
                    if (
                        !groupInfo.libraries.find(
                            g => g.branchcode === lib.branchcode
                        )
                    ) {
                        groupInfo.libraries.push(lib);
                    }
                });
            });
            return groupInfo;
        },
    };
    const getters = {
        getVisibleGroups: computed(() => {
            return store.visibleGroups?.length
                ? store.visibleGroups
                : actions.filterLibGroupsByUsersBranchcode();
        }),
    };

    return {
        ...toRefs(store),
        ...actions,
        ...getters,
    };
});
