<template>
    <div style="display: flex; min-width: 30%">
        <InputNumberElement
            id="percentageToggleField"
            v-model="resource[toggleValue]"
            :size="6"
            @update:modelValue="verifyFieldValue()"
        />
        <button
            type="button"
            @click="setToPercentage"
            :style="`background-color: ${toggleValue === percentageField ? '#e2ee79' : '#fff'}`"
        >
            {{ $__("%") }}
        </button>
        <button
            type="button"
            @click="setToAmount"
            :style="`background-color: ${toggleValue === amountField ? '#e2ee79' : '#fff'}`"
        >
            {{ $__("Amount") }}
        </button>
        <span style="margin-left: 5px" class="error" v-if="fieldError">
            {{ fieldError }}
        </span>
    </div>
</template>

<script>
import { ref } from "vue";
import InputNumberElement from "../../Elements/InputNumberElement.vue";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        resource: Object,
        percentageField: String,
        amountField: String,
    },
    inheritAttrs: false,
    setup(props) {
        const toggleValue = ref(props.percentageField);
        const fieldError = ref("");

        const setToPercentage = () => {
            toggleValue.value = percentageField;
            props.resource[props.amountField] = undefined;
        };

        const setToAmount = () => {
            toggleValue.value = props.amountField;
            props.resource[props.percentageField] = undefined;
        };

        const verifyFieldValue = () => {
            if (toggleValue.value === props.percentageField) {
                const result = /^[\-]?\d{0,2}(\.\d{0,3})*$/.test(
                    props.resource[props.percentageField]
                );
                if (!result) {
                    fieldError.value = $__(
                        "Please enter a decimal number in the format: 0.0"
                    );
                }
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
        InputNumberElement,
    },
};
</script>

<style scoped>
input {
    margin-right: 2em;
}
button {
    width: 5em;
    border: 1px solid #ccc;
}
</style>
