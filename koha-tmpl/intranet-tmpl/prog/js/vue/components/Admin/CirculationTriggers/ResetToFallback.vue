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
export default {
    props: {
        ruleSetToSubmit: { type: Object, default: null },
        fallbackRuleSet: { type: Object, default: null },
        ruleName: { type: String, required: true },
        setAllowSubmission: { type: Function, required: true },
    },
    computed: {
        isOverridden() {
            return (
                this.ruleSetToSubmit?.[this.ruleName] !== null &&
                this.ruleSetToSubmit?.[this.ruleName] !== undefined &&
                this.fallbackRuleSet?.[this.ruleName] !== null &&
                this.fallbackRuleSet?.[this.ruleName] !== undefined
            );
        },
    },
    methods: {
        resetToFallback() {
            this.ruleSetToSubmit[this.ruleName] = null;
            this.setAllowSubmission();
        },
    },
};
</script>
