<template>
    <button
        v-if="isOverridden"
        type="button"
        class="btn btn-link"
        :title="$__('Undo override and reset to fallback')"
        @click="resetToFallback"
    >
        <i class="fa fa-undo"></i>
    </button>
</template>

<script>
import { cloneDeep, isEqual } from "lodash";

export default {
    props: {
        ruleSetToSubmit: { type: Object, default: null },
        fallbackRuleSet: { type: Object, default: null },
        ruleName: { type: String, required: true },
        setAllowSubmission: { type: Function, required: true },
    },
    computed: {
        isOverridden() {
            const value = this.ruleSetToSubmit?.[this.ruleName];
            const fallback = this.fallbackRuleSet?.[this.ruleName]?.value;

            return (
                value !== null &&
                value !== undefined &&
                fallback !== null &&
                fallback !== undefined &&
                !isEqual(value, fallback)
            );
        },
    },
    methods: {
        // Cloned because mtt's fallback is the very array held in the raw rule
        // sets, which the transport select would otherwise edit in place.
        resetToFallback() {
            this.ruleSetToSubmit[this.ruleName] = cloneDeep(
                this.fallbackRuleSet?.[this.ruleName]?.value
            );
            this.setAllowSubmission();
        },
    },
};
</script>
