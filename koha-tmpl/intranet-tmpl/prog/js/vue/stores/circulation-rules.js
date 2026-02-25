import { defineStore } from "pinia";
import { $__ } from "../i18n";
import { APIClient } from "../fetch/api-client.js";
import { isEqual } from "lodash";
import { permissionsActions } from "../composables/permissions";
import { reactive, toRefs } from "vue";

// NOTES ON RULE SETS TYPES
// exhaustive:  includes 'pure fallback' rules sets for contexts that no rules match.
//              Format: [{overdue_X_<rule_name>: {value: mixed: isFallback: bool}}]
// effective:   includes sets only for contexts for which one or more rule exists in the db. These sets will include fallbacks.
//              Format: [{overdue_X_<rule_name>: <value>}}
// raw:         includes only the exact sets as they are found in the db
//              Format: [{overdue_X_<rule_name>: <value>}}]

export const useCircRulesStore = defineStore("circRules", () => {
    const store = reactive({
        // context
        currentLibraryId: "*",
        currentPatronCategoryId: null,
        currentItemTypeId: null,
        triggerCounts: { "*": 0 },
        // references
        itemTypes: [],
        libraries: [],
        patronCategories: [],
        userPermissions: null,
        letters: [],
        ruleSuffixes: ["delay", "notice", "mtt", "restrict", "has_rules"],
        transportTypes: [
            { code: "email", name: "Email" },
            { code: "sms", name: "SMS" },
            { code: "print", name: "Print" },
        ],
        // rule sets
        allDefaultLibraryRawRuleSets: [], // source of truth for default library
        allCurrentLibraryRawRuleSets: [], // source of truth for current library
        allEffectiveRuleSets: [], // main data set for display explicitly set rules for current library
        allExhaustiveEffectiveRuleSets: [], // main data set for display all applied rules for current library
        currentAndDefaultRawRuleSets: [], // data set to identify effective rules from (combines allDefaultLibraryRawRuleSets and allCurrentLibraryRawRuleSets)
        librariesWithRules: [],
        storeInitialized: false,
    });

    const actions = {
        // controllers
        async init() {
            await this.getItemTypes();
            await this.getLibraries();
            await this.getPatronCategories();
        },
        async loadUserPermissions() {
            if (this.userPermissions !== null) {
                return;
            }
            await this.getConfigurationOptions();
        },
        // utilities
        formatTriggerSpecificRuleSetForDisplay(
            context,
            triggerNumber,
            includeFallbacks = true
        ) {
            const triggerSpecificRuleSet = {
                context,
            };
            this.ruleSuffixes.forEach(ruleSuffix => {
                triggerSpecificRuleSet[
                    `overdue_${triggerNumber}_${ruleSuffix}`
                ] = this.findEffectiveRule(
                    context,
                    ruleSuffix,
                    triggerNumber,
                    includeFallbacks
                );
            });
            triggerSpecificRuleSet.context = context;
            return triggerSpecificRuleSet;
        },
        handleContext(value, data, type, displayProperty = "name") {
            const item = data.find(item => item[type] === value);
            return item[displayProperty];
        },
        handleNotice(notice) {
            const letter = this.letters.find(letter => letter.code === notice);
            return letter ? letter.name : notice;
        },
        handleRestrictions(value) {
            if (!value) {
                return;
            }
            return value === "1" ? $__("Yes") : $__("No");
        },
        handleTransport(value, type, noLetter) {
            if (!value || noLetter) {
                return "";
            }
            return value.includes(type) ? $__("Yes") : $__("No");
        },
        hasExplicitRulesForTrigger(ruleSet, triggerNumber) {
            return ["delay", "notice", "mtt", "restrict"].some(
                suffix => ruleSet[`overdue_${triggerNumber}_${suffix}`] != null
            );
        },
        hasConflict(oldRuleSet, newRuleSet, triggerNumber) {
            if (
                !oldRuleSet ||
                !this.hasExplicitRulesForTrigger(oldRuleSet, triggerNumber)
            ) {
                return false;
            }
            return (
                oldRuleSet.context.library_id !==
                    newRuleSet.context.library_id ||
                oldRuleSet.context.item_type_id !==
                    newRuleSet.context.item_type_id ||
                oldRuleSet.context.patron_category_id !==
                    newRuleSet.context.patron_category_id ||
                oldRuleSet[`overdue_${triggerNumber}_delay`] !==
                    newRuleSet[`overdue_${triggerNumber}_delay`] ||
                oldRuleSet[`overdue_${triggerNumber}_notice`] !==
                    newRuleSet[`overdue_${triggerNumber}_notice`] ||
                oldRuleSet[`overdue_${triggerNumber}_restrict`] !==
                    newRuleSet[`overdue_${triggerNumber}_restrict`] ||
                !isEqual(
                    oldRuleSet[`overdue_${triggerNumber}_mtt`],
                    newRuleSet[`overdue_${triggerNumber}_mtt`]
                )
            );
        },
        isOnlyRuleSetForTrigger(triggerNumber) {
            return (
                this.allCurrentLibraryRawRuleSets.filter(ruleSet =>
                    this.hasExplicitRulesForTrigger(ruleSet, triggerNumber)
                ).length === 1
            );
        },
        isLastTrigger(triggerNumber) {
            return (
                parseInt(triggerNumber) ===
                this.triggerCounts[this.currentLibraryId]
            );
        },
        // services
        findEffectiveRule(
            context,
            ruleSuffix,
            triggerNumber,
            includeFallbacks = true
        ) {
            if (
                !this.currentAndDefaultRawRuleSets ||
                !Array.isArray(this.currentAndDefaultRawRuleSets) ||
                this.currentAndDefaultRawRuleSets.length === 0
            ) {
                return { value: null, isFallback: true };
            }
            // Check if the current ruleSet's value for the ruleSuffix is undefined
            const existingRule = this.currentAndDefaultRawRuleSets.find(
                ruleSet =>
                    ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !==
                        undefined &&
                    ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !==
                        null &&
                    ruleSet?.context.library_id === context.library_id &&
                    ruleSet?.context.patron_category_id ===
                        context.patron_category_id &&
                    ruleSet?.context.item_type_id === context.item_type_id
            );

            // if handling 'has_rules', derive from actual rules rather than DB
            if (ruleSuffix === "has_rules") {
                const hasExplicit = this.currentAndDefaultRawRuleSets.some(
                    ruleSet =>
                        ruleSet?.context.library_id === context.library_id &&
                        ruleSet?.context.patron_category_id ===
                            context.patron_category_id &&
                        ruleSet?.context.item_type_id ===
                            context.item_type_id &&
                        this.hasExplicitRulesForTrigger(ruleSet, triggerNumber)
                );
                return {
                    value: hasExplicit ? true : null,
                    isFallback: !hasExplicit,
                };
            }

            // If the current ruleSet's value is not null, use it directly
            if (existingRule !== undefined) {
                return {
                    value: existingRule[
                        `overdue_${triggerNumber}_${ruleSuffix}`
                    ],
                    isFallback: !this.hasExplicitRulesForTrigger(
                        existingRule,
                        triggerNumber
                    ),
                };
            }

            // If set to return a raw set, return
            if (!includeFallbacks) {
                return;
            }

            // Filter ruleSets to only those with non-null values for the specified ruleSuffix
            // and that are no excluded from the selected context
            const relevantRules = this.currentAndDefaultRawRuleSets.filter(
                ruleSet =>
                    ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !==
                        undefined &&
                    ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !==
                        null &&
                    (ruleSet.context.library_id === context.library_id ||
                        ruleSet.context.library_id === "*") &&
                    (ruleSet.context.patron_category_id ===
                        context.patron_category_id ||
                        ruleSet.context.patron_category_id === "*") &&
                    (ruleSet.context.item_type_id === context.item_type_id ||
                        ruleSet.context.item_type_id === "*")
            );

            // Function to calculate specificity score
            const getSpecificityScore = ruleSetContext => {
                let score = 0;
                if (
                    ruleSetContext.library_id !== "*" &&
                    ruleSetContext.library_id === context.library_id
                )
                    score += 4;
                if (
                    ruleSetContext.patron_category_id !== "*" &&
                    ruleSetContext.patron_category_id ===
                        context.patron_category_id
                )
                    score += 2;
                if (
                    ruleSetContext.item_type_id !== "*" &&
                    ruleSetContext.item_type_id === context.item_type_id
                )
                    score += 1;
                return score;
            };

            // Sort the ruleSets based on specificity score, descending
            const sortedRules = relevantRules.sort((a, b) => {
                return (
                    getSpecificityScore(b.context) -
                    getSpecificityScore(a.context)
                );
            });
            // If no ruleSet found, return null
            if (sortedRules.length === 0) {
                return { value: null, isFallback: true };
            }
            // Get the value from the most specific ruleSet
            const bestRule = sortedRules[0];
            return {
                value: bestRule[`overdue_${triggerNumber}_${ruleSuffix}`],
                isFallback: true,
            };
        },
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
                        this.ruleSuffixes.forEach(ruleSuffix => {
                            effectiveRuleSet[`overdue_${i}_${ruleSuffix}`] =
                                this.findEffectiveRule(
                                    effectiveRuleSet.context,
                                    ruleSuffix,
                                    i
                                );
                        });
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
                    if (!this.hasExplicitRulesForTrigger(ruleSet, i)) {
                        continue;
                    }
                    this.ruleSuffixes.forEach(ruleSuffix => {
                        effectiveRuleSet[`overdue_${i}_${ruleSuffix}`] =
                            this.findEffectiveRule(
                                ruleSet.context,
                                ruleSuffix,
                                i
                            );
                    });
                }
                this.allEffectiveRuleSets.push(effectiveRuleSet);
            });
        },
        setEffectiveTriggerFilteredRuleSet(context) {
            const effectiveTriggerFilteredRuleSets = [];
            for (
                let i = 1;
                i <= this.triggerCounts[this.currentLibraryId];
                i++
            ) {
                const triggerSpecificRuleSet =
                    this.formatTriggerSpecificRuleSetForDisplay(context, i);
                if (!triggerSpecificRuleSet) {
                    continue;
                }
                effectiveTriggerFilteredRuleSets.push(triggerSpecificRuleSet);
            }
            return effectiveTriggerFilteredRuleSets;
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
                const triggerNumRegex =
                    /^overdue_(\d+)_(delay|notice|mtt|restrict)$/;
                const triggerNums = new Set();
                this.allDefaultLibraryRawRuleSets.forEach(ruleSet => {
                    Object.keys(ruleSet).forEach(key => {
                        const match = key.match(triggerNumRegex);
                        if (match && ruleSet[key] !== null) {
                            triggerNums.add(parseInt(match[1]));
                        }
                    });
                });
                this.triggerCounts["*"] =
                    triggerNums.size > 0 ? Math.max(...triggerNums) : 0;
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
                    this.hasExplicitRulesForTrigger(ruleSet, i)
                )
            ) {
                i++;
            }
            this.triggerCounts[this.currentLibraryId] = i - 1;
        },
        async setAllRawRuleSets() {
            const client = APIClient.circRule;
            await this.getAllRawRuleSets();

            this.currentAndDefaultRawRuleSets = [
                ...this.allCurrentLibraryRawRuleSets,
                ...this.allDefaultLibraryRawRuleSets,
            ];
        },
        // repositories
        async deleteRuleSet(ruleSet, triggerNumber) {
            const ruleSetInDb = await this.getSelectedRuleSet(ruleSet.context);

            if (this.hasConflict(ruleSet, ruleSetInDb, triggerNumber)) {
                throw "The rule set for the selected trigger context could not be reset as it was updated elsewhere. Please see the updated trigger above.";
            }

            const rulesForDeletion = { context: ruleSet.context };

            if (ruleSet[`overdue_${triggerNumber}_delay`] !== null) {
                rulesForDeletion[`overdue_${triggerNumber}_delay`] = null;
            }
            if (ruleSet[`overdue_${triggerNumber}_notice`] !== null) {
                rulesForDeletion[`overdue_${triggerNumber}_notice`] = null;
            }
            if (ruleSet[`overdue_${triggerNumber}_restrict`] !== null) {
                rulesForDeletion[`overdue_${triggerNumber}_restrict`] = null;
            }
            if (ruleSet[`overdue_${triggerNumber}_mtt`] !== null) {
                rulesForDeletion[`overdue_${triggerNumber}_mtt`] = null;
            }
            this.updateCircRuleSets(rulesForDeletion, triggerNumber);
        },
        async getLibrariesWithRules() {
            const client = APIClient.circRule;
            const allRules = await client.circ_rules.getAll(
                {},
                { effective: false }
            );
            const libraryIds = new Set(
                allRules
                    .map(r => r.context?.library_id)
                    .filter(id => id && id !== "*")
            );
            this.librariesWithRules = this.libraries.filter(
                lib => lib.library_id !== "*" && libraryIds.has(lib.library_id)
            );
        },
        async getAllRawRuleSets() {
            const client = APIClient.circRule;
            this.allDefaultLibraryRawRuleSets = await client.circ_rules.getAll(
                {},
                { library_id: "*", effective: false }
            );
            if (this.currentLibraryId === "*") {
                this.allCurrentLibraryRawRuleSets =
                    this.allDefaultLibraryRawRuleSets;
                return;
            }

            this.allCurrentLibraryRawRuleSets = await client.circ_rules.getAll(
                {},
                { library_id: this.currentLibraryId, effective: false }
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

            libraries.unshift({
                library_id: "*",
                name: $__("Default rule for all libraries"),
            });
            this.libraries = libraries;
        },
        async getPatronCategories() {
            const client = APIClient.patron;
            let patronCategories = await client.categories.getAll();

            patronCategories.unshift({
                patron_category_id: "*",
                name: $__("Default rule for all categories"),
            });
            this.patronCategories = patronCategories;
        },
        async getSelectedRuleSet(context, effective = false) {
            if (context.library_id === null) {
                context.library_id = "*";
            }
            const client = APIClient.circRule;
            const result = await client.circ_rules.getAll(
                {},
                {
                    library_id: context.library_id,
                    patron_category_id: context.patron_category_id,
                    item_type_id: context.item_type_id,
                    effective,
                }
            );
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
    };
});
