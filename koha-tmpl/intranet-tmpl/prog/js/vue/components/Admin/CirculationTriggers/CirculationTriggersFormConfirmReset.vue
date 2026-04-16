<template>
    <CirculationTriggersForm
        :submitAction="resetCircRules"
        formTitle="Confirm circulation rule set reset"
    >
        <fieldset class="rows">
            <div class="page-section bg-info">
                <p>
                    {{
                        $__(
                            "Resetting this rule set for the chosen context will have an impact on all the contexts that used to fall back on this rule set."
                        )
                    }}
                </p>
                <p>
                    {{
                        $__(
                            "To better understand which contexts will be affected, use 'Display: all applied rules.' on the circulations triggers page."
                        )
                    }}
                </p>
            </div>
            <legend>{{ $__("Trigger context") }}</legend>
            <ol v-if="initialized">
                <li>
                    <p>
                        <strong>{{ $__("Library") }}:</strong>
                    </p>
                    <p id="library_id">
                        {{ handleContext(library_id, libraries, "library_id") }}
                    </p>
                </li>
                <li>
                    <p>
                        <strong>{{ $__("Patron category") }}:</strong>
                    </p>
                    <p id="patron_category_id">
                        {{
                            handleContext(
                                patron_category_id,
                                patronCategories,
                                "patron_category_id"
                            )
                        }}
                    </p>
                </li>
                <li>
                    <p>
                        <strong>{{ $__("Item type") }}:</strong>
                    </p>
                    <p id="item_type_id">
                        {{
                            handleContext(
                                item_type_id,
                                itemTypes,
                                "item_type_id",
                                "description"
                            )
                        }}
                    </p>
                </li>
            </ol>
            <div v-else>
                <p>{{ $__("Loading circulation context...") }}</p>
            </div>
        </fieldset>

        <fieldset class="rows">
            <legend>
                {{ $__("Rules (overrides) which will be deleted") }}
            </legend>
            <table>
                <thead>
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
                </thead>
                <tbody v-if="initialized">
                    <tr>
                        <!-- Delay -->
                        <td>
                            <span
                                v-if="
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_delay`
                                    ]
                                "
                                :class="{
                                    fallback:
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_delay`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_delay`
                                    ].value
                                }}
                            </span>
                        </td>

                        <!--  Notice -->
                        <td>
                            <span
                                v-if="
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_notice`
                                    ]
                                "
                                :class="{
                                    fallback:
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_notice`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleNotice(
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_notice`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- Email -->
                        <td>
                            <span
                                v-if="
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_mtt`
                                    ]?.length
                                "
                                :class="{
                                    fallback:
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_mtt`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleTransport(
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_mtt`
                                        ].value,
                                        "email",
                                        !effectiveRuleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- Print -->
                        <td>
                            <span
                                v-if="
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_mtt`
                                    ]?.length
                                "
                                :class="{
                                    fallback:
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_mtt`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleTransport(
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_mtt`
                                        ].value,
                                        "print",
                                        !effectiveRuleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- SMS -->
                        <td>
                            <span
                                v-if="
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_mtt`
                                    ]?.length
                                "
                                :class="{
                                    fallback:
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_mtt`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleTransport(
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_mtt`
                                        ].value,
                                        !effectiveRuleSet[
                                            `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                        <!-- Restricts Checkouts -->
                        <td>
                            <span
                                v-if="
                                    effectiveRuleSet[
                                        `overdue_${triggerNumber}_restrict`
                                    ]
                                "
                                :class="{
                                    fallback:
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_restrict`
                                        ].isFallback,
                                }"
                            >
                                {{
                                    handleRestrictions(
                                        effectiveRuleSet[
                                            `overdue_${triggerNumber}_restrict`
                                        ].value
                                    )
                                }}
                            </span>
                        </td>
                    </tr>
                </tbody>
                <tbody v-else>
                    <tr>
                        {{
                            $__("Loading circulation rule set...")
                        }}
                    </tr>
                </tbody>
            </table>
        </fieldset>

        <fieldset class="rows" v-if="alertMessage">
            <div class="alert alert-warning">{{ alertMessage }}</div>
        </fieldset>
    </CirculationTriggersForm>
</template>

<script>
import ButtonSubmit from "../../ButtonSubmit.vue";
import CirculationTriggersForm from "./CirculationTriggersForm.vue";
import { inject } from "vue";
import { storeToRefs } from "pinia";

export default {
    setup() {
        const circRulesStore = inject("circRulesStore");
        const {
            handleContext,
            handleNotice,
            handleTransport,
            getSelectedRuleSet,
            formatTriggerSpecificRuleSetForDisplay,
            deleteRuleSet,
            handleRestrictions,
        } = circRulesStore;
        const {
            libraries,
            itemTypes,
            patronCategories,
            lastEditedTriggerNumber,
        } = storeToRefs(circRulesStore);
        return {
            libraries,
            itemTypes,
            patronCategories,
            lastEditedTriggerNumber,
            handleContext,
            handleNotice,
            handleTransport,
            getSelectedRuleSet,
            formatTriggerSpecificRuleSetForDisplay,
            deleteRuleSet,
            handleRestrictions,
        };
    },
    data() {
        return {
            alertMessage: null,
            initialized: false,
            library_id: "*",
            item_type_id: "*",
            patron_category_id: "*",
            triggerNumber: null,
            ruleSet: null,
            currentRuleSet: null,
            fallbackRuleSet: null,
            effectiveRuleSet: null,
        };
    },
    beforeRouteEnter(to, from, next) {
        next(async vm => {
            vm.setContext(to.query);
            vm.currentRuleSet = await vm.getSelectedRuleSet(
                {
                    library_id: vm.library_id,
                    patron_category_id: vm.patron_category_id,
                    item_type_id: vm.item_type_id,
                },
                false
            );
            vm.effectiveRuleSet = vm.formatTriggerSpecificRuleSetForDisplay(
                vm.currentRuleSet.context,
                vm.triggerNumber,
                false
            );
            vm.initialized = true;
        });
    },
    methods: {
        async resetCircRules(e) {
            e.preventDefault();
            try {
                await this.deleteRuleSet(
                    this.currentRuleSet,
                    this.triggerNumber
                );
            } catch (e) {
                this.alertMessage = e;
                // reload the form components that have changed, remain in edit mode
                this.$router.push({
                    path: "/cgi-bin/koha/admin/circulation_triggers/reset",
                    query: {
                        ...this.currentRuleSet.context,
                        triggerNumber: this.triggerNumber,
                    },
                });
                return;
            }
            this.lastEditedTriggerNumber = this.triggerNumber;
            await this.$router.push({
                name: "CirculationTriggersList",
                query: { refresh: Date.now() },
            });
        },
        setContext(query) {
            this.library_id = query.library_id ?? "*";
            this.item_type_id = query.item_type_id ?? "*";
            this.patron_category_id = query.patron_category_id ?? "*";
            this.triggerNumber = parseInt(query.triggerNumber);
        },
    },
    components: { ButtonSubmit, CirculationTriggersForm },
};
</script>

<style scoped>
#circulation-trigger-form-confirm-reset {
    max-height: 90vh;
}

form li {
    display: flex;
    align-items: center;
}

.numeric-input-wrapper {
    position: relative;
    display: inline-block;
    width: 30%;
}

.input-with-clear {
    position: relative;
    display: flex;
    align-items: center;
    width: 100%;
}

.numeric-input {
    padding-right: 40px; /* Adjust to leave space for clear button */
    padding-left: 0.25em;
    padding-top: 2px;
    padding-bottom: 2px;
    width: 100%;
    border-radius: 4px;
    border: 1px solid #ccc;
    font-size: 16px;
    box-sizing: border-box;
    transition: border-color 0.2s ease;
}

.clear-btn {
    position: absolute;
    right: 22px; /* Adjust positioning */
    fill: var(--vs-controls-color);
    background-color: transparent;
    border: 0;
    font-size: 1.2em;
    color: #333;
    cursor: pointer;
    z-index: 2; /* Ensure it is above the input */
}

.button:active:hover,
.clear-btn:active:hover {
    background-color: #d4d4d4;
    border-color: #8c8c8c;
}

/* Chevron buttons container */
.chevron-buttons {
    display: flex;
    flex-direction: column;
    position: absolute;
    right: 0px;
    top: 0;
    bottom: 0;
    width: 16px;
    padding: 0px 5px 0px 2px;
    justify-content: center;
    z-index: 2;
}

/* Chevron button styles */
.increment-btn,
.decrement-btn {
    background-color: transparent;
    border: 0px solid #ccc;
    font-size: 10px;
    padding: 0px;
    cursor: pointer;
    color: rgba(60, 60, 60, 0.5);
    border-radius: 2px;
}

.increment-btn:hover,
.decrement-btn:hover {
    background-color: #ddd;
}

/* Hide the native increment/decrement buttons */
input[type="number"]::-webkit-inner-spin-button,
input[type="number"]::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
}

input[type="number"] {
    -moz-appearance: textfield; /* For Firefox */
}

.numeric-input:focus,
.numeric-input:hover {
    border-color: #007bff; /* Match focus color of v-select */
    outline: none;
}

.dialog.alert
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(
        .bg-success
    ):not(.bg-primary):not(.action),
.dialog.error
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(
        .bg-success
    ):not(.bg-primary):not(.action) {
    margin: 0;
    background-color: rgba(255, 255, 255, 1);
}

.router-link-active {
    margin-left: 10px;
}
.modal-header {
    display: flex;
    justify-content: space-between;
}
</style>
