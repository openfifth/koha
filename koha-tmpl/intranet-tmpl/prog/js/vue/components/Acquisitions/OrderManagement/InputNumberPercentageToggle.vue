<template>
    <div style="display: flex; min-width: 30%">
        <InputNumber
            id="percentageToggleField"
            v-model="resource[toggleValue]"
            :size="6"
            @update:modelValue="verifyFieldValue()"
            :formatInputValue="formatInputValue"
            :max="toggleValue == percentageField ? 100 : null"
            :min="toggleValue == percentageField ? 0 : null"
            :step="0.01"
            :resource="resource"
        />
        <div class="btn-group" role="group">
            <button
                type="button"
                class="btn btn-outline-secondary"
                :class="{ active: toggleValue === percentageField }"
                @click="setToPercentage"
            >
                {{ $__("%") }}
            </button>
            <button
                type="button"
                class="btn btn-outline-secondary"
                :class="{ active: toggleValue === amountField }"
                @click="setToAmount"
            >
                {{ $__("Amount") }}
            </button>
        </div>
        <span style="margin-left: 5px" class="error" v-if="fieldError">
            {{ fieldError }}
        </span>
    </div>
</template>

<script>
import { ref } from "vue";
import InputNumber from "../../Elements/InputNumber.vue";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        resource: Object,
        percentageField: String,
        amountField: String,
        onChange: Function,
        formatInputValue: Function,
    },
    inheritAttrs: false,
    setup(props, { emit }) {
        const toggleValue = ref(props.percentageField);
        const fieldError = ref("");

        const setToPercentage = () => {
            toggleValue.value = props.percentageField;
            props.resource[props.amountField] = undefined;
            props.resource[props.percentageField] = undefined;
            emit("toggleChanged", props.resource, toggleValue.value);
        };

        const setToAmount = () => {
            toggleValue.value = props.amountField;
            props.resource[props.percentageField] = undefined;
            props.resource[props.amountField] = undefined;
            emit("toggleChanged", props.resource, toggleValue.value);
        };

        const verifyFieldValue = () => {
            if (toggleValue.value === props.percentageField) {
                const result = /^[\-]?\d{0,3}(\.\d{0,3})*$/.test(
                    props.resource[props.percentageField]
                );
                if (!result) {
                    fieldError.value = $__(
                        "Please enter a decimal number in the format: 0.0"
                    );
                } else {
                    fieldError.value = "";
                }
            }
            if (!fieldError.value && props.onChange) {
                props.onChange(props.resource, toggleValue.value);
            }
            return true;
        };
        return {
            toggleValue,
            setToAmount,
            setToPercentage,
            verifyFieldValue,
            fieldError,
        };
    },
    components: {
        InputNumber,
    },
    emits: ["toggleChanged"],
};
</script>

<style scoped>
input {
    margin-right: 2em;
}
</style>
