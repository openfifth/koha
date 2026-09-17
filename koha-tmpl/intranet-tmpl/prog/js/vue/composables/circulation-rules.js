import { $__ } from "@koha-vue/i18n";
import { isEqual } from "lodash";

// NOTES ON RULE SETS TYPES
// exhaustive:  includes 'pure fallback' rules sets for contexts that no rules match.
//              Format: [{overdue_X_<rule_name>: {value: mixed: isFallback: bool}}]
// effective:   includes sets only for contexts for which one or more rule exists in the db. These sets will include fallbacks.
//              Format: [{overdue_X_<rule_name>: <value>}}
// raw:         includes only the exact sets as they are found in the db
//              Format: [{overdue_X_<rule_name>: <value>}}]

/**
 * The rule names that make up a single overdue trigger.
 *
 * @type {String[]}
 */
export const ruleSuffixes = ["delay", "notice", "mtt", "restrict"];

/**
 * Sort comparator ordering objects by one of their properties.
 *
 * @param {String} property - The property to order by.
 * @return {Function} A comparator suitable for Array.prototype.sort.
 */
export function compareByProperty(property) {
    return (a, b) => a[property].localeCompare(b[property]);
}

/**
 * Determine whether two rule set contexts address the same library, patron
 * category and item type.
 *
 * @param {Object} a - A rule set context.
 * @param {Object} b - A rule set context.
 * @return {Boolean} true if both contexts are identical.
 */
export function isSameContext(a, b) {
    return (
        a.library_id === b.library_id &&
        a.patron_category_id === b.patron_category_id &&
        a.item_type_id === b.item_type_id
    );
}

/**
 * Determine whether a context appears in a list of contexts.
 *
 * @param {Object[]} contextList - The contexts to search.
 * @param {Object} context - The context to look for.
 * @return {Boolean} true if a matching context is present.
 */
export function containsMatchingContext(contextList, context) {
    return contextList.some(candidate => isSameContext(candidate, context));
}

/**
 * Score how specifically a rule set's context matches a reference context.
 * Library matches outweigh patron category matches, which outweigh item type
 * matches. Wildcards score nothing.
 *
 * @param {Object} ruleSetContext - The context of the candidate rule set.
 * @param {Object} referenceContext - The context being resolved for.
 * @return {Number} The specificity score.
 */
export function getSpecificityScore(ruleSetContext, referenceContext) {
    let score = 0;
    if (
        ruleSetContext.library_id !== "*" &&
        ruleSetContext.library_id === referenceContext.library_id
    )
        score += 4;
    if (
        ruleSetContext.patron_category_id !== "*" &&
        ruleSetContext.patron_category_id ===
            referenceContext.patron_category_id
    )
        score += 2;
    if (
        ruleSetContext.item_type_id !== "*" &&
        ruleSetContext.item_type_id === referenceContext.item_type_id
    )
        score += 1;
    return score;
}

/**
 * Determine whether a rule set sets any rule explicitly for a trigger.
 *
 * @param {Object} ruleSet - The rule set to inspect.
 * @param {Number} triggerNumber - The trigger to inspect.
 * @return {Boolean} true if at least one rule is set for the trigger.
 */
export function hasExplicitRulesForTrigger(ruleSet, triggerNumber) {
    return ruleSuffixes.some(
        suffix => ruleSet[`overdue_${triggerNumber}_${suffix}`] != null
    );
}

/**
 * Find the highest trigger number for which a rule set sets any rule
 * explicitly.
 *
 * @param {Object} ruleSet - The rule set to inspect.
 * @return {Number} The highest trigger number, or 0 if none are set.
 */
export function maxExplicitTriggerNumber(ruleSet) {
    const regex = new RegExp(`^overdue_(\\d+)_(${ruleSuffixes.join("|")})$`);
    let max = 0;
    Object.keys(ruleSet).forEach(key => {
        const match = key.match(regex);
        if (match && ruleSet[key] !== null) {
            max = Math.max(max, parseInt(match[1]));
        }
    });
    return max;
}

/**
 * Determine whether a rule set has been changed elsewhere since it was read,
 * by comparing it against the version currently held in the database.
 *
 * @param {?Object} oldRuleSet - The rule set as it was read.
 * @param {Object} newRuleSet - The rule set as it now stands in the database.
 * @param {Number} triggerNumber - The trigger to compare.
 * @return {Boolean} true if the two disagree for the given trigger.
 */
export function hasConflict(oldRuleSet, newRuleSet, triggerNumber) {
    if (!oldRuleSet || !hasExplicitRulesForTrigger(oldRuleSet, triggerNumber)) {
        return false;
    }

    if (!isSameContext(oldRuleSet.context, newRuleSet.context)) {
        return false;
    }

    return ruleSuffixes.some(
        suffix =>
            !isEqual(
                oldRuleSet[`overdue_${triggerNumber}_${suffix}`] ?? null,
                newRuleSet[`overdue_${triggerNumber}_${suffix}`] ?? null
            )
    );
}

/**
 * Determine whether exactly one rule set configures a given trigger.
 *
 * @param {Object[]} ruleSets - The rule sets to count within.
 * @param {Number} triggerNumber - The trigger to count for.
 * @return {Boolean} true if precisely one rule set configures the trigger.
 */
export function isOnlyRuleSetForTrigger(ruleSets, triggerNumber) {
    return (
        ruleSets.filter(ruleSet =>
            hasExplicitRulesForTrigger(ruleSet, triggerNumber)
        ).length === 1
    );
}

/**
 * Determine whether a trigger is the last one configured for a library.
 *
 * @param {Number|String} triggerNumber - The trigger to test.
 * @param {Number} triggerCount - The library's trigger count.
 * @return {Boolean} true if this is the library's last trigger.
 */
export function isLastTrigger(triggerNumber, triggerCount) {
    return parseInt(triggerNumber) === triggerCount;
}

/**
 * Split a stored message transport type into its individual types.
 *
 * @param {?String} rawMtt - The stored value, e.g. "email,sms".
 * @return {String[]|undefined} The individual transport types.
 */
export function formatMttForDisplay(rawMtt) {
    return rawMtt?.split(",");
}

/**
 * Split the message transport types of every trigger of every given rule set,
 * in place.
 *
 * @param {Object[]} ruleSets - The rule sets to convert.
 * @return {void}
 */
export function formatRuleSetMttFields(ruleSets) {
    let triggerNumber = 1;
    for (const ruleSet of ruleSets) {
        while (ruleSet[`overdue_${triggerNumber}_mtt`] !== undefined) {
            if (typeof ruleSet[`overdue_${triggerNumber}_mtt`] === "string") {
                ruleSet[`overdue_${triggerNumber}_mtt`] = formatMttForDisplay(
                    ruleSet[`overdue_${triggerNumber}_mtt`]
                );
            }
            triggerNumber++;
        }
        triggerNumber = 1;
    }
}

/**
 * Find the most specific rule set supplying a value for a single rule, where
 * the context itself does not set it.
 *
 * @param {Object} context - The context being resolved for.
 * @param {Number} triggerNumber - The trigger being resolved.
 * @param {String} suffix - The rule suffix being resolved.
 * @param {Object[]} ruleSets - The rule sets to resolve against.
 * @return {?Object} The winning rule set, or null if none supplies a value.
 */
export function findFallbackRuleSetForField(
    context,
    triggerNumber,
    suffix,
    ruleSets
) {
    const candidates = ruleSets.filter(
        ruleSet =>
            ruleSet[`overdue_${triggerNumber}_${suffix}`] != null &&
            (ruleSet.context.library_id === context.library_id ||
                ruleSet.context.library_id === "*") &&
            (ruleSet.context.patron_category_id ===
                context.patron_category_id ||
                ruleSet.context.patron_category_id === "*") &&
            (ruleSet.context.item_type_id === context.item_type_id ||
                ruleSet.context.item_type_id === "*")
    );
    if (candidates.length === 0) return null;
    return candidates.reduce((best, current) =>
        getSpecificityScore(current.context, context) >
        getSpecificityScore(best.context, context)
            ? current
            : best
    );
}

/**
 * Build the state a rule set would be left in for one trigger, were it
 * resolved against a given set of rule sets. Used to preview the effect of a
 * deletion before it is carried out.
 *
 * @param {Object} dependentRuleSet - The rule set to project.
 * @param {Number} triggerNumber - The trigger to project.
 * @param {Object[]} contextRuleSets - The rule sets to resolve against.
 * @return {Object} The projected rule set, in exhaustive format.
 */
export function buildProjectedRuleSet(
    dependentRuleSet,
    triggerNumber,
    contextRuleSets
) {
    const projectedRuleSet = {
        context: dependentRuleSet.context,
        [`overdue_${triggerNumber}_has_rules`]: {
            value: true,
            isFallback: false,
        },
    };

    ruleSuffixes.forEach(suffix => {
        const field = `overdue_${triggerNumber}_${suffix}`;
        if (dependentRuleSet[field] != null) {
            projectedRuleSet[field] = {
                value: dependentRuleSet[field],
                isFallback: false,
            };
            return;
        }
        const fallback = findFallbackRuleSetForField(
            dependentRuleSet.context,
            triggerNumber,
            suffix,
            contextRuleSets
        );
        projectedRuleSet[field] = {
            value: fallback?.[field] ?? null,
            isFallback: true,
        };
    });

    return projectedRuleSet;
}

/**
 * Determine whether a rule set inherits any of its values for a trigger from
 * one of the contexts being deleted.
 *
 * @param {Object} candidate - The rule set to test.
 * @param {Number} triggerNumber - The trigger being deleted.
 * @param {Object[]} deletedContexts - The contexts being deleted.
 * @param {Object[]} contextRuleSets - The rule sets to resolve against.
 * @return {Boolean} true if the deletion would change the rules that apply.
 */
export function isImpactedByDeletion(
    candidate,
    triggerNumber,
    deletedContexts,
    contextRuleSets
) {
    if (containsMatchingContext(deletedContexts, candidate.context)) {
        return false;
    }
    if (!hasExplicitRulesForTrigger(candidate, triggerNumber)) {
        return false;
    }
    return ruleSuffixes.some(suffix => {
        if (candidate[`overdue_${triggerNumber}_${suffix}`] != null) {
            return false;
        }
        const fallback = findFallbackRuleSetForField(
            candidate.context,
            triggerNumber,
            suffix,
            contextRuleSets
        );
        return (
            fallback &&
            containsMatchingContext(deletedContexts, fallback.context)
        );
    });
}

/**
 * Resolve the value that applies for a single rule in a given context, either
 * because the context sets it explicitly or because it inherits it.
 *
 * @param {Object[]} ruleSets - The rule sets to resolve against.
 * @param {Object} context - The context being resolved for.
 * @param {String} ruleSuffix - The rule suffix being resolved, or "has_rules".
 * @param {Number} triggerNumber - The trigger being resolved.
 * @param {Boolean} [includeFallbacks=true] - Whether to inherit from less
 * specific contexts when the context sets no value of its own.
 * @return {Object|undefined} { value: mixed, isFallback: Boolean }, or
 * undefined where no value is set and fallbacks are excluded.
 */
export function findEffectiveRule(
    ruleSets,
    context,
    ruleSuffix,
    triggerNumber,
    includeFallbacks = true
) {
    if (!ruleSets || !Array.isArray(ruleSets) || ruleSets.length === 0) {
        return { value: null, isFallback: true };
    }
    // Check if the current ruleSet's value for the ruleSuffix is undefined
    const existingRule = ruleSets.find(
        ruleSet =>
            ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !== undefined &&
            ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !== null &&
            ruleSet?.context.library_id === context.library_id &&
            ruleSet?.context.patron_category_id ===
                context.patron_category_id &&
            ruleSet?.context.item_type_id === context.item_type_id
    );

    // if handling 'has_rules', derive from actual rules rather than DB
    if (ruleSuffix === "has_rules") {
        const hasExplicit = ruleSets.some(
            ruleSet =>
                ruleSet?.context.library_id === context.library_id &&
                ruleSet?.context.patron_category_id ===
                    context.patron_category_id &&
                ruleSet?.context.item_type_id === context.item_type_id &&
                hasExplicitRulesForTrigger(ruleSet, triggerNumber)
        );
        return {
            value: hasExplicit ? true : null,
            isFallback: !hasExplicit,
        };
    }

    // If the current ruleSet's value is not null, use it directly
    if (existingRule !== undefined) {
        return {
            value: existingRule[`overdue_${triggerNumber}_${ruleSuffix}`],
            isFallback: !hasExplicitRulesForTrigger(
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
    const relevantRules = ruleSets.filter(
        ruleSet =>
            ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !== undefined &&
            ruleSet[`overdue_${triggerNumber}_${ruleSuffix}`] !== null &&
            (ruleSet.context.library_id === context.library_id ||
                ruleSet.context.library_id === "*") &&
            (ruleSet.context.patron_category_id ===
                context.patron_category_id ||
                ruleSet.context.patron_category_id === "*") &&
            (ruleSet.context.item_type_id === context.item_type_id ||
                ruleSet.context.item_type_id === "*")
    );

    // Sort the ruleSets based on specificity score, descending
    const sortedRules = relevantRules.sort(
        (a, b) =>
            getSpecificityScore(b.context, context) -
            getSpecificityScore(a.context, context)
    );
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
}

/**
 * Build the effective rule set for a single context and trigger.
 *
 * @param {Object[]} ruleSets - The rule sets to resolve against.
 * @param {Object} context - The context to build for.
 * @param {Number} triggerNumber - The trigger to build for.
 * @param {Boolean} [includeFallbacks=true] - Whether to inherit from less
 * specific contexts.
 * @return {Object} The rule set for that trigger, in exhaustive format.
 */
export function formatTriggerSpecificRuleSetForDisplay(
    ruleSets,
    context,
    triggerNumber,
    includeFallbacks = true
) {
    const triggerSpecificRuleSet = {
        context,
    };
    ruleSuffixes.forEach(ruleSuffix => {
        triggerSpecificRuleSet[`overdue_${triggerNumber}_${ruleSuffix}`] =
            findEffectiveRule(
                ruleSets,
                context,
                ruleSuffix,
                triggerNumber,
                includeFallbacks
            );
    });
    triggerSpecificRuleSet[`overdue_${triggerNumber}_has_rules`] =
        findEffectiveRule(
            ruleSets,
            context,
            "has_rules",
            triggerNumber,
            includeFallbacks
        );
    return triggerSpecificRuleSet;
}

/**
 * Build the effective rule set for a single context, one entry per trigger.
 *
 * @param {Object[]} ruleSets - The rule sets to resolve against.
 * @param {Object} context - The context to build for.
 * @param {Number} triggerCount - The number of triggers to build.
 * @return {Object[]} One rule set per trigger, in exhaustive format.
 */
export function setEffectiveTriggerFilteredRuleSet(
    ruleSets,
    context,
    triggerCount
) {
    const effectiveTriggerFilteredRuleSets = [];
    for (let i = 1; i <= triggerCount; i++) {
        const triggerSpecificRuleSet = formatTriggerSpecificRuleSetForDisplay(
            ruleSets,
            context,
            i
        );
        if (!triggerSpecificRuleSet) {
            continue;
        }
        effectiveTriggerFilteredRuleSets.push(triggerSpecificRuleSet);
    }
    return effectiveTriggerFilteredRuleSets;
}

/**
 * Look up the display name of a context's library, patron category or item
 * type.
 *
 * @param {String} value - The id to look up.
 * @param {Object[]} data - The libraries, patron categories or item types.
 * @param {String} type - The name of the id property to match on.
 * @param {String} [displayProperty="name"] - The property to display.
 * @return {String} The display name.
 */
export function handleContext(value, data, type, displayProperty = "name") {
    const item = data.find(item => item[type] === value);
    return item[displayProperty];
}

/**
 * Look up the display name of a notice.
 *
 * @param {String} notice - The letter code.
 * @param {Object[]} letters - The available letters.
 * @return {String} The letter name, or the code where no letter matches.
 */
export function handleNotice(notice, letters) {
    const letter = letters.find(letter => letter.code === notice);
    return letter ? letter.name : notice;
}

/**
 * Render whether a rule restricts the patron.
 *
 * @param {?String} value - The stored value.
 * @return {String|undefined} The translated answer, or undefined where unset.
 */
export function handleRestrictions(value) {
    if (!value) {
        return;
    }
    return value === "1" ? $__("Yes") : $__("No");
}

/**
 * Render whether a rule sends a notice by a given transport type.
 *
 * @param {?String[]} value - The rule's transport types.
 * @param {String} type - The transport type to report on.
 * @return {String} The translated answer, or "" where none are set.
 */
export function handleTransport(value, type) {
    if (!value) {
        return "";
    }
    return value.includes(type) ? $__("Yes") : $__("No");
}

/**
 * Scroll an element into view, waiting for it to be rendered first.
 *
 * @param {String} id - The id of the element to scroll to.
 * @return {Promise<void>}
 */
export async function scrollToElementById(id) {
    let count = 0;
    // ensures that the relevant section is loaded before we attempt to scroll it into view
    while (!document.getElementById(id) && count < 8) {
        await new Promise(resolve => setTimeout(resolve, 250));
        count++;
    }
    const element = document.getElementById(id);
    if (!element) {
        // handle loading the page if the element is not at all present
        return;
    }
    element.scrollIntoView({ behavior: "smooth" });
}
