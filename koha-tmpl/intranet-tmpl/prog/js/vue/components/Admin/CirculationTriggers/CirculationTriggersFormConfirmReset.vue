<template>
    <CirculationTriggersForm
        :submitAction="resetCircRules"
        formTitle="Confirm circulation rule set reset"
        buttonText="Confirm reset"
    >
        <TriggersTable
            v-if="initialized"
            :ruleSets="[effectiveRuleSet]"
            :triggerNumber="triggerNumber"
            :modal="false"
            :displayActions="false"
            :enableActions="false"
            :title="$__('Rule set selected for reset')"
        />

        <fieldset class="rows" v-if="alertMessage">
            <div class="alert alert-warning">{{ alertMessage }}</div>
        </fieldset>
        <fieldset
            v-if="initialized && dependentRuleSets.length > 0"
            class="rows"
        >
            <div class="page-section bg-warning overflow-hidden">
                <TriggersTable
                    :ruleSets="projectedDependentEffectiveRuleSets"
                    :triggerNumber="triggerNumber"
                    :modal="false"
                    :displayActions="false"
                    :enableActions="false"
                    :title="
                        $__('Affected rule sets preview: state after reset')
                    "
                />
            </div>
        </fieldset>
    </CirculationTriggersForm>
</template>

<script>
import ButtonSubmit from "../../ButtonSubmit.vue";
import CirculationTriggersForm from "./CirculationTriggersForm.vue";
import TriggersTable from "./TriggersTable.vue";
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
            computeDeletionImpact,
            setAllFormattedRuleSets,
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
            computeDeletionImpact,
            setAllFormattedRuleSets,
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
            dependentRuleSets: [],
            projectedDependentEffectiveRuleSets: [],
        };
    },
    beforeRouteEnter(to, from, next) {
        next(async vm => {
            vm.setContext(to.query);
            await vm.loadModalData();
        });
    },
    methods: {
        async loadModalData() {
            await this.setAllFormattedRuleSets();

            this.currentRuleSet = await this.getSelectedRuleSet(
                {
                    library_id: this.library_id,
                    patron_category_id: this.patron_category_id,
                    item_type_id: this.item_type_id,
                },
                false
            );
            this.effectiveRuleSet = this.formatTriggerSpecificRuleSetForDisplay(
                this.currentRuleSet.context,
                this.triggerNumber
            );

            const { dependentRuleSets, projectedDependentEffectiveRuleSets } =
                await this.computeDeletionImpact(
                    [this.currentRuleSet],
                    this.triggerNumber
                );
            this.dependentRuleSets = dependentRuleSets;
            this.projectedDependentEffectiveRuleSets =
                projectedDependentEffectiveRuleSets;

            if (this.dependentRuleSets.length > 0) {
                this.alertMessage = this.$__(
                    "Some sets inherit one or more fields from this rule set. After the reset, those fields will fall through to a less specific rule set or be left empty. See the preview below."
                );
            }

            this.initialized = true;
        },
        async resetCircRules(e) {
            e.preventDefault();
            try {
                await this.deleteRuleSet(
                    this.currentRuleSet,
                    this.triggerNumber
                );
            } catch (e) {
                this.alertMessage = e;
                await this.loadModalData();
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
    components: { ButtonSubmit, CirculationTriggersForm, TriggersTable },
};
</script>

<style scoped>
#circulation-trigger-form-confirm-reset {
    max-height: 90vh;
}

form ol li {
    display: flex;
    align-items: center;
}

.page-section ul li {
    float: none;
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
