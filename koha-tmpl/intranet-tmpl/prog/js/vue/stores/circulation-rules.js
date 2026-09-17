import { defineStore } from "pinia";
import { $__ } from "../i18n";
import { APIClient } from "../fetch/api-client.js";
import { permissionsActions } from "../composables/permissions";
import { reactive, toRefs, computed } from "vue";
import { cloneDeep } from "lodash";
import {
    ruleSuffixes,
    buildProjectedRuleSet,
    compareByProperty,
    containsMatchingContext,
    findEffectiveRule,
    formatMttForDisplay,
    formatRuleSetMttFields,
    hasConflict,
    hasExplicitRulesForTrigger,
    isImpactedByDeletion,
    maxExplicitTriggerNumber,
} from "../composables/circulation-rules";

export const useCircRulesStore = defineStore("circRules", () => {
    const store = reactive({
        // context
        currentLibraryId: "*",
        currentPatronCategoryId: null,
        currentItemTypeId: null,
        triggerCounts: { "*": 0 },
        lastEditedTriggerNumber: null,
        metaInitialized: false,
        // references
        itemTypes: [],
        libraries: [],
        patronCategories: [],
        userPermissions: null,
        user_library_id: null,
        letters: [],
        transportTypes: [
            { code: "email", name: $__("Email") },
            { code: "sms", name: $__("SMS") },
            { code: "print", name: $__("Print") },
        ],
        // rule sets
        allDefaultLibraryRawRuleSets: [], // source of truth for default library
        allCurrentLibraryRawRuleSets: [], // source of truth for current library
        allLibrariesRawRuleSets: [], // all rule sets across all libraries; loaded lazily on confirm screens for library=* rule sets. Only loaded if necessary (eg. 'Delete' modal access on default library triggers).
        allEffectiveRuleSets: [], // main data set for display explicitly set rules for current library
        allExhaustiveEffectiveRuleSets: [], // main data set for display all applied rules for current library
        currentAndDefaultRawRuleSets: [], // data set to identify effective rules from (combines allDefaultLibraryRawRuleSets and allCurrentLibraryRawRuleSets)
        librariesWithRules: [],
        storeInitialized: false,
    });

    const canManageAnyLibrary = computed(
        () =>
            !store.userPermissions ||
            !!store.userPermissions
                .CAN_user_parameters_manage_circ_rules_from_any_libraries
    );

    // Exposed as a computed rather than an action to prevent `$id` warnings
    // when called from a Vue component during render.
    const getLibrariesBlockingTriggerDeletion = computed(
        () => triggerNumber => {
            const hasRuleAboveCurrentTriggerNumber = ruleSet => {
                return Object.keys(ruleSet).some(ruleName => {
                    const match = ruleName.match(/^overdue_(\d+)_/);
                    if (!match) {
                        return false;
                    }
                    return (
                        ruleSet[ruleName] != null &&
                        parseInt(match[1]) > triggerNumber
                    );
                });
            };

            const blocking = new Set();
            for (const ruleSet of store.allLibrariesRawRuleSets) {
                const library_id = ruleSet.context?.library_id;
                if (!library_id || library_id === "*") {
                    continue;
                }
                if (blocking.has(library_id)) {
                    continue;
                }
                if (hasRuleAboveCurrentTriggerNumber(ruleSet)) {
                    blocking.add(library_id);
                }
            }
            return [...blocking];
        }
    );

    const actions = {
        // controllers
        async init(defaultLibraryId = "*", userLibraryId = null) {
            store.user_library_id = userLibraryId;
            await this.loadUserPermissions();
            await this.getItemTypes();
            await this.getLibraries();
            await this.getPatronCategories();
            // If user can only manage their own library, override the default view
            if (!canManageAnyLibrary.value && store.user_library_id) {
                this.currentLibraryId = store.user_library_id;
            } else {
                this.currentLibraryId = defaultLibraryId;
            }
            this.metaInitialized = true;
        },
        async loadUserPermissions() {
            if (this.userPermissions !== null) {
                return;
            }
            await this.getConfigurationOptions();
        },
        // services
        setAllExhaustiveEffectiveRuleSets() {
            // clear array
            this.allExhaustiveEffectiveRuleSets = [];
            // generate complete rule set list
            this.patronCategories.forEach(category => {
                this.itemTypes.forEach(itemType => {
                    const effectiveRuleSet = {
                        context: {
                            library_id: this.currentLibraryId,
                            patron_category_id: category.patron_category_id,
                            item_type_id: itemType.item_type_id,
                        },
                    };
                    for (
                        let i = 1;
                        i <= this.triggerCounts[this.currentLibraryId];
                        i++
                    ) {
                        ruleSuffixes.forEach(ruleSuffix => {
                            effectiveRuleSet[`overdue_${i}_${ruleSuffix}`] =
                                findEffectiveRule(
                                    this.currentAndDefaultRawRuleSets,
                                    effectiveRuleSet.context,
                                    ruleSuffix,
                                    i
                                );
                        });
                        effectiveRuleSet[`overdue_${i}_has_rules`] =
                            findEffectiveRule(
                                this.currentAndDefaultRawRuleSets,
                                effectiveRuleSet.context,
                                "has_rules",
                                i
                            );
                    }
                    this.allExhaustiveEffectiveRuleSets.push(effectiveRuleSet);
                });
            });
        },
        setAllEffectiveRuleSets() {
            // clear array
            this.allEffectiveRuleSets = [];
            // generate complete rule set list
            this.allCurrentLibraryRawRuleSets.forEach(ruleSet => {
                const effectiveRuleSet = {
                    context: { ...ruleSet.context },
                };
                for (
                    let i = 1;
                    i <= this.triggerCounts[this.currentLibraryId];
                    i++
                ) {
                    if (!hasExplicitRulesForTrigger(ruleSet, i)) {
                        continue;
                    }
                    ruleSuffixes.forEach(ruleSuffix => {
                        effectiveRuleSet[`overdue_${i}_${ruleSuffix}`] =
                            findEffectiveRule(
                                this.currentAndDefaultRawRuleSets,
                                ruleSet.context,
                                ruleSuffix,
                                i
                            );
                    });
                    effectiveRuleSet[`overdue_${i}_has_rules`] =
                        findEffectiveRule(
                            this.currentAndDefaultRawRuleSets,
                            ruleSet.context,
                            "has_rules",
                            i
                        );
                }
                this.allEffectiveRuleSets.push(effectiveRuleSet);
            });
        },
        updateTriggerCount() {
            // Library-specific triggerCounts can fall into the following use cases:
            // - No rule sets specific to them exist. Therefore, their triggerCount is the same as default's.
            // - Rule sets exists that override default triggers. Therefore, their triggerCount is the same as default's.
            // - Rule sets exists for triggers for which there is no default.
            //     => such triggers are follow up addition to the existing default sequence.
            //     => the triggerCount for this library will be higher than default's, and equal to the highest trigger number for this library that has any explicit rules.

            // Set the triggerCount for the default library rule set
            if (this.currentLibraryId === "*") {
                this.triggerCounts["*"] =
                    this.allDefaultLibraryRawRuleSets.reduce(
                        (max, ruleSet) =>
                            Math.max(max, maxExplicitTriggerNumber(ruleSet)),
                        0
                    );
                return;
            }

            // Set a library-specific trigger count: no rule set exists -> simply use the default trigger count
            if (this.allCurrentLibraryRawRuleSets.length === 0) {
                this.triggerCounts[this.currentLibraryId] =
                    this.triggerCounts["*"];
                return;
            }

            // Set a library-specific trigger count: at least one rule set exists -> start from the first trigger for which there is no default rule set
            let i = this.triggerCounts["*"] + 1;
            while (
                this.allCurrentLibraryRawRuleSets.some(ruleSet =>
                    hasExplicitRulesForTrigger(ruleSet, i)
                )
            ) {
                i++;
            }
            this.triggerCounts[this.currentLibraryId] = i - 1;
        },
        async setAllRawRuleSets() {
            await this.getCurrentAndDefaultRawRuleSets();

            this.currentAndDefaultRawRuleSets = [
                ...this.allCurrentLibraryRawRuleSets,
                ...this.allDefaultLibraryRawRuleSets,
            ];
        },
        async setAllFormattedRuleSets() {
            await this.setAllRawRuleSets();
            formatRuleSetMttFields(this.allDefaultLibraryRawRuleSets);
            if (this.currentLibraryId !== "*") {
                formatRuleSetMttFields(this.allCurrentLibraryRawRuleSets);
            }
        },
        async getSelectedRuleSet(context, effective = true) {
            const rawSelectedRuleSet = await this.getRawSelectedRuleSet(
                context,
                effective
            );
            if (!rawSelectedRuleSet) {
                return;
            }

            let formattedSelectedRuleSet = cloneDeep(rawSelectedRuleSet);
            let i = 1;
            while (i <= this.triggerCounts[this.currentLibraryId]) {
                if (rawSelectedRuleSet[`overdue_${i}_mtt`]) {
                    formattedSelectedRuleSet[`overdue_${i}_mtt`] =
                        formatMttForDisplay(
                            rawSelectedRuleSet[`overdue_${i}_mtt`]
                        );
                }
                i++;
            }
            return formattedSelectedRuleSet;
        },
        // For a set of rule sets being deleted for a given trigger, return the
        // rule sets that depend on any of them (deduplicated, excluding the
        // ones being deleted themselves) and a projection of their state after
        // the deletion has happened. Reset and bulk-delete modals both consume
        // this — reset passes [currentRuleSet], delete passes the full set.
        async computeDeletionImpact(deletedRuleSets, triggerNumber) {
            let searchRuleSets, contextRuleSets;
            if (this.currentLibraryId === "*") {
                await this.loadAllLibrariesRuleSets();
                searchRuleSets = this.allLibrariesRawRuleSets;
                contextRuleSets = this.allLibrariesRawRuleSets;
            } else {
                searchRuleSets = this.allCurrentLibraryRawRuleSets;
                contextRuleSets = this.currentAndDefaultRawRuleSets;
            }

            const deletedContexts = deletedRuleSets.map(
                ruleSet => ruleSet.context
            );

            const projectedRemainingRawRuleSets = contextRuleSets.filter(
                ruleSet =>
                    !containsMatchingContext(deletedContexts, ruleSet.context)
            );

            const dependentRuleSets = searchRuleSets.filter(candidate =>
                isImpactedByDeletion(
                    candidate,
                    triggerNumber,
                    deletedContexts,
                    contextRuleSets
                )
            );

            const projectedDependentEffectiveRuleSets = dependentRuleSets.map(
                dependentRuleSet =>
                    buildProjectedRuleSet(
                        dependentRuleSet,
                        triggerNumber,
                        projectedRemainingRawRuleSets
                    )
            );

            return {
                dependentRuleSets,
                projectedDependentEffectiveRuleSets,
            };
        },
        // repositories
        async deleteRuleSet(ruleSet, triggerNumber) {
            if (!hasExplicitRulesForTrigger(ruleSet, triggerNumber)) {
                return;
            }

            const ruleSetInDb = await this.getSelectedRuleSet(
                ruleSet.context,
                false
            );

            if (hasConflict(ruleSet, ruleSetInDb, triggerNumber)) {
                throw "The rule set for the selected trigger context could not be reset as it was updated elsewhere. Please see the updated trigger above.";
            }

            const rulesForDeletion = { context: ruleSet.context };
            ruleSuffixes.forEach(suffix => {
                rulesForDeletion[`overdue_${triggerNumber}_${suffix}`] = null;
            });
            await this.updateCircRuleSets(rulesForDeletion, triggerNumber);
        },
        async getLibrariesWithRules() {
            const allRules = await this.fetchRawRuleSets();
            const libraryIds = new Set(
                allRules
                    .map(r => r.context?.library_id)
                    .filter(id => id && id !== "*")
            );
            this.librariesWithRules = this.libraries.filter(
                lib => lib.library_id !== "*" && libraryIds.has(lib.library_id)
            );
        },
        async loadAllLibrariesRuleSets() {
            this.allLibrariesRawRuleSets = await this.fetchRawRuleSets();
            formatRuleSetMttFields(this.allLibrariesRawRuleSets);
        },
        async getCurrentAndDefaultRawRuleSets() {
            this.allDefaultLibraryRawRuleSets = await this.fetchRawRuleSets({
                library_id: "*",
            });
            if (this.currentLibraryId === "*") {
                this.allCurrentLibraryRawRuleSets =
                    this.allDefaultLibraryRawRuleSets;
                return;
            }
            this.allCurrentLibraryRawRuleSets = await this.fetchRawRuleSets({
                library_id: this.currentLibraryId,
            });
        },
        async fetchRawRuleSets(params = {}) {
            return APIClient.circRule.circ_rules.getAll(
                {},
                { effective: false, ...params }
            );
        },
        async getConfigurationOptions() {
            const client = APIClient.circRule;
            const { permissions } = await client.config.getAll();
            this.userPermissions = permissions;
        },
        async getItemTypes() {
            const client = APIClient.item;
            let itemTypes = await client.item_types.getAll();
            itemTypes.sort(compareByProperty("description"));
            itemTypes.unshift({
                item_type_id: "*",
                description: $__("Default rule for all item types"),
            });
            this.itemTypes = itemTypes;
        },
        async getLibraries() {
            const client = APIClient.library;
            let libraries = [];
            libraries = await client.libraries.getAll();
            libraries.sort(compareByProperty("name"));
            libraries.unshift({
                library_id: "*",
                name: $__("Default rule for all libraries"),
            });
            this.libraries = libraries;
        },
        async getPatronCategories() {
            const client = APIClient.patron;
            let patronCategories = await client.categories.getAll();
            patronCategories.sort(compareByProperty("name"));
            patronCategories.unshift({
                patron_category_id: "*",
                name: $__("Default rule for all categories"),
            });
            this.patronCategories = patronCategories;
        },
        async getRawSelectedRuleSet(context, effective = false) {
            if (context.library_id === null) {
                context.library_id = "*";
            }
            const result = await this.fetchRawRuleSets({
                library_id: context.library_id,
                patron_category_id: context.patron_category_id,
                item_type_id: context.item_type_id,
                effective,
            });
            return result[0] ?? null;
        },
        async updateCircRuleSets(existingRuleSet, triggerNumber) {
            const circRuleSet = { context: existingRuleSet.context };
            circRuleSet[`overdue_${triggerNumber}_delay`] =
                existingRuleSet[`overdue_${triggerNumber}_delay`];
            circRuleSet[`overdue_${triggerNumber}_notice`] =
                existingRuleSet[`overdue_${triggerNumber}_notice`];
            circRuleSet[`overdue_${triggerNumber}_restrict`] =
                existingRuleSet[`overdue_${triggerNumber}_restrict`];
            circRuleSet[`overdue_${triggerNumber}_mtt`] =
                existingRuleSet[`overdue_${triggerNumber}_mtt`];
            const client = APIClient.circRule;
            await client.circ_rules.update(circRuleSet);
        },
        ...permissionsActions(store),
    };

    return {
        ...toRefs(store),
        ...actions,
        canManageAnyLibrary,
        getLibrariesBlockingTriggerDeletion,
    };
});
