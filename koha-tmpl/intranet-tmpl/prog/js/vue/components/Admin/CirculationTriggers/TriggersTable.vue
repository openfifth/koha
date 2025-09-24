<template>
    <fieldset
        class="rows"
        :id="modal ? 'trigger-table-form' : 'trigger-table-main'"
    >
        <legend>
            {{ title ?? $__("Existing overdues triggers for this context") }}
        </legend>
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
                <th>
                    {{ $__("Set Lost Value") }}
                </th>
                <th>
                    {{ $__("Charge Replacement Cost") }}
                </th>
                <th>
                    {{ $__("Mark as returned") }}
                </th>
                <th>
                    {{ $__("Forgive overdue fine") }}
                </th>
                <th v-if="displayActions">
                    {{ $__("Actions") }}
                </th>
            </thead>
            <tbody>
                <template v-for="(ruleSet, i) in ruleSets" :key="'ruleSet' + i">
                    <tr
                        v-if="
                            ruleSet[
                                `overdue_${modal ? i + 1 : triggerNumber}_has_rules`
                            ]
                        "
                        :class="{
                            selected_rule_set:
                                modal &&
                                i + 1 === parseInt(activeTriggerBeingEdited),
                        }"
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
                                        "email"
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
                                        "print"
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
                                        "sms"
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
                        <!-- Set Lost Value -->
                        <td>
                            <span
                                :class="{
                                    fallback:
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_lost`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleLost(
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_lost`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- Charge Replacement Cost -->
                        <td>
                            <span
                                :class="{
                                    fallback:
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_charge`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleRestrictions(
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_charge`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- Mark Returned -->
                        <td>
                            <span
                                :class="{
                                    fallback:
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_mark_returned`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleRestrictions(
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_mark_returned`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- Forgive Fine -->
                        <td>
                            <span
                                :class="{
                                    fallback:
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_forgive_fine`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleRestrictions(
                                        ruleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_forgive_fine`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <td class="actions" v-if="displayActions">
                            <button
                                type="button"
                                class="btn btn-default btn-xs"
                                :disabled="!enableActions"
                                @click="
                                    $router.push({
                                        name: 'CirculationTriggersFormEdit',
                                        query: {
                                            library_id:
                                                ruleSet.context.library_id,
                                            item_type_id:
                                                ruleSet.context.item_type_id,
                                            patron_category_id:
                                                ruleSet.context
                                                    .patron_category_id,
                                            triggerNumber: modal
                                                ? i + 1
                                                : triggerNumber,
                                        },
                                    })
                                "
                            >
                                <i class="fa-solid fa-pencil"></i>
                                {{ $__("Edit") }}
                            </button>
                            <button
                                v-if="
                                    ruleSet[
                                        `overdue_${modal ? i + 1 : triggerNumber}_has_rules`
                                    ].value &&
                                    !isOnlyRuleSetForTrigger(triggerNumber)
                                "
                                type="button"
                                class="btn btn-default btn-xs"
                                :disabled="!enableActions"
                                @click="
                                    $router.push({
                                        name: 'CirculationTriggersFormConfirmReset',
                                        query: {
                                            library_id:
                                                ruleSet.context.library_id,
                                            item_type_id:
                                                ruleSet.context.item_type_id,
                                            patron_category_id:
                                                ruleSet.context
                                                    .patron_category_id,
                                            triggerNumber: triggerNumber,
                                        },
                                    })
                                "
                            >
                                <i class="fa-solid fa-eraser"></i>
                                {{ $__("Reset") }}
                            </button>
                        </td>
                    </tr>
                </template>
                <tr v-if="modal">
                    <td colspan="11"></td>
                    <td class="actions" v-if="displayActions">
                        <button
                            type="button"
                            class="btn btn-default btn-xs"
                            :disabled="!enableActions"
                            @click="
                                $router.push({
                                    name: 'CirculationTriggersFormAdd',
                                    query: {
                                        library_id:
                                            activeRuleSetBeingEdited.context
                                                .library_id,
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
                                })
                            "
                        >
                            <i class="fa-solid fa-pencil"></i>
                            {{ $__("Add") }}
                        </button>
                    </td>
                </tr>
            </tbody>
        </table>
    </fieldset>
</template>

<script>
import { inject } from "vue";
import { storeToRefs } from "pinia";

export default {
    props: [
        "triggerNumber",
        "modal",
        "displayActions",
        "enableActions",
        "ruleSetBeingEdited",
        "triggerBeingEdited",
        "ruleSets",
        "title",
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
            handleLost,
            isOnlyRuleSetForTrigger,
            handleRestrictions,
        } = circRulesStore;

        return {
            handleContext,
            handleNotice,
            handleTransport,
            handleLost,
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

.actions button {
    margin-right: 5px;
}

.actions button[disabled] {
    opacity: 0.65;
    cursor: not-allowed;
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

table.centered {
    margin: auto;
    width: fit-content;
}
</style>
