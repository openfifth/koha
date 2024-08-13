<template>
    <slot></slot>
    <table>
        <thead>
            <th v-if="!modal" class="trigger_context">
                {{ $__("Library") }}
            </th>
            <th v-if="!modal" class="trigger_context">
                {{ $__("Patron category") }}
            </th>
            <th v-if="!modal" class="trigger_context border_right">
                {{ $__("Item type") }}
            </th>
            <th v-if="modal">
                {{ $__("Trigger") }}
            </th>
            <th>
                {{ $__("Delay") }}
            </th>
            <th>
                {{ $__("Notice") }}
            </th>
            <th>
                {{ $__("Email") }}
            </th>
            <th>
                {{ $__("Print") }}
            </th>
            <th>
                {{ $__("SMS") }}
            </th>
            <th>
                {{ $__("Restricts checkouts") }}
            </th>
            <th v-if="actions">
                {{ $__("Actions") }}
            </th>
        </thead>
        <tbody>
            <template
                v-for="(ruleSet, i) in ruleSets"
                :key="'ruleSet' + i"
                :class="{
                    selected_rule_set:
                        modal && i + 1 === parseInt(activeTriggerBeingEdited),
                }"
            >
                <tr
                    v-if="
                        ruleSet[
                            `overdue_${modal ? i + 1 : triggerNumber}_has_rules`
                        ]
                    "
                >
                    <td v-if="!modal" class="trigger_context">
                        {{
                            handleContext(
                                ruleSet.context.library_id,
                                libraries,
                                "library_id"
                            )
                        }}
                    </td>
                    <td v-if="!modal" class="trigger_context">
                        {{
                            handleContext(
                                ruleSet.context.patron_category_id,
                                patronCategories,
                                "patron_category_id"
                            )
                        }}
                    </td>
                    <td v-if="!modal" class="trigger_context border_right">
                        {{
                            handleContext(
                                ruleSet.context.item_type_id,
                                itemTypes,
                                "item_type_id",
                                "description"
                            )
                        }}
                    </td>
                    <td v-if="modal">
                        {{ i + 1 }}
                    </td>
                    <!-- Delay -->
                    <td>
                        <span
                            :class="{
                                fallback:
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_delay`
                                    ].isFallback,
                            }"
                        >
                            {{
                                ruleSet[
                                    `overdue_${modal ? i + 1 : triggerNumber}_delay`
                                ].value
                            }}
                        </span>
                    </td>
                    <!--  Notice -->
                    <td>
                        <span
                            :class="{
                                fallback:
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                    ].isFallback,
                            }"
                        >
                            {{
                                handleNotice(
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                    ].value
                                )
                            }}
                        </span>
                    </td>
                    <!-- Email -->
                    <td>
                        <span
                            :class="{
                                fallback:
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ].isFallback,
                            }"
                        >
                            {{
                                handleTransport(
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ].value,
                                    "email",
                                    !ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                    ].value
                                )
                            }}
                        </span>
                    </td>
                    <!-- Print -->
                    <td>
                        <span
                            :class="{
                                fallback:
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ].isFallback,
                            }"
                        >
                            {{
                                handleTransport(
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ].value,
                                    "print",
                                    !ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                    ].value
                                )
                            }}
                        </span>
                    </td>
                    <!-- SMS -->
                    <td>
                        <span
                            :class="{
                                fallback:
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ].isFallback,
                            }"
                        >
                            {{
                                handleTransport(
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ].value,
                                    "sms",
                                    !ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                    ].value
                                )
                            }}
                        </span>
                    </td>
                    <!-- Restricts Checkouts -->
                    <td>
                        <span
                            :class="{
                                fallback:
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_restrict`
                                    ].isFallback,
                            }"
                        >
                            {{
                                handleRestrictions(
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_restrict`
                                    ].value
                                )
                            }}
                        </span>
                    </td>
                    <td class="actions" v-if="actions">
                        <router-link
                            :to="{
                                name: 'CirculationTriggersFormEdit',
                                query: {
                                    library_id: ruleSet.context.library_id,
                                    item_type_id: ruleSet.context.item_type_id,
                                    patron_category_id:
                                        ruleSet.context.patron_category_id,
                                    triggerNumber: modal
                                        ? i + 1
                                        : triggerNumber,
                                },
                            }"
                            class="btn btn-default btn-xs"
                            ><i class="fa-solid fa-pencil"></i>
                            {{ $__("Edit") }}</router-link
                        >
                        <router-link
                            v-if="
                                ruleSet[
                                    `overdue_${modal ? i + 1 : triggerNumber}_has_rules`
                                ].value &&
                                !isOnlyRuleSetForTrigger(triggerNumber)
                            "
                            :to="{
                                name: 'CirculationTriggersFormConfirmReset',
                                query: {
                                    library_id: ruleSet.context.library_id,
                                    item_type_id: ruleSet.context.item_type_id,
                                    patron_category_id:
                                        ruleSet.context.patron_category_id,
                                    triggerNumber: triggerNumber,
                                },
                            }"
                            class="btn btn-default btn-xs"
                            ><i class="fa-solid fa-eraser"></i>
                            {{ $__("Reset") }}</router-link
                        >
                    </td>
                </tr>
            </template>
            <tr v-if="modal">
                <td colspan="7"></td>
                <td class="actions">
                    <router-link
                        :to="{
                            name: 'CirculationTriggersFormAdd',
                            query: {
                                library_id:
                                    activeRuleSetBeingEdited.context.library_id,
                                item_type_id:
                                    activeRuleSetBeingEdited.context
                                        .item_type_id,
                                patron_category_id:
                                    activeRuleSetBeingEdited.context
                                        .patron_category_id,
                                triggerNumber:
                                    triggerCounts[
                                        activeRuleSetBeingEdited.context
                                            .library_id
                                    ] + 1,
                            },
                        }"
                        class="btn btn-default btn-xs"
                        ><i class="fa-solid fa-pencil"></i>
                        {{ $__("Add") }}</router-link
                    >
                </td>
            </tr>
        </tbody>
    </table>
</template>

<script>
import { inject } from "vue";
import { storeToRefs } from "pinia";

export default {
    props: [
        "triggerNumber",
        "modal",
        "actions",
        "ruleSetBeingEdited",
        "triggerBeingEdited",
        "ruleSets",
    ],
    computed: {
        activeRuleSetBeingEdited() {
            return this.modal ? this.ruleSetBeingEdited : null;
        },
        activeTriggerBeingEdited() {
            return this.modal ? this.triggerBeingEdited : null;
        },
    },
    setup() {
        const circRulesStore = inject("circRulesStore");
        const { triggerCounts, patronCategories, itemTypes, libraries } =
            storeToRefs(circRulesStore);
        const {
            handleContext,
            handleNotice,
            handleTransport,
            isOnlyRuleSetForTrigger,
            handleRestrictions,
        } = circRulesStore;

        return {
            handleContext,
            handleNotice,
            handleTransport,
            triggerCounts,
            patronCategories,
            itemTypes,
            libraries,
            isOnlyRuleSetForTrigger,
            handleRestrictions,
        };
    },
};
</script>

<style scoped>
.selected_rule_set > td {
    background-color: yellow !important;
}

.fallback {
    font-style: italic;
    font-weight: bold;
}

.actions a {
    margin-right: 5px;
}

td.trigger_context {
    color: black;
}

th.trigger_context {
    color: blue;
}

.border_right {
    border-right: solid 4px black;
}
</style>
