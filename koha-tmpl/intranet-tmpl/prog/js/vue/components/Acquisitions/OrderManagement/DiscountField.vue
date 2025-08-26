<template>
    <div style="display: flex; min-width: 30%">
        <InputNumberElement
            id="discountField"
            v-model="resource[`discount_${toggleValue}`]"
            :size="6"
            @update:modelValue="verifyDiscountValue()"
        />
        <button
            type="button"
            @click="setToPercentage"
            :style="`background-color: ${toggleValue === 'percentage' ? '#e2ee79' : '#fff'}`"
        >
            {{ $__("%") }}
        </button>
        <button
            type="button"
            @click="setToAmount"
            :style="`background-color: ${toggleValue === 'amount_oc' ? '#e2ee79' : '#fff'}`"
        >
            {{ $__("Amount") }}
        </button>
        <span style="margin-left: 5px" class="error" v-if="discountError">
            {{ discountError }}
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
    },
    inheritAttrs: false,
    setup(props) {
        const toggleValue = ref("percentage");
        const discountError = ref("");

        const setToPercentage = () => {
            toggleValue.value = "percentage";
            props.resource.discount_amount_oc = undefined;
        };

        const setToAmount = () => {
            toggleValue.value = "amount_oc";
            props.resource.discount_percentage = undefined;
        };

        const verifyDiscountValue = () => {
            if (toggleValue.value === "percentage") {
                const result = /^[\-]?\d{0,2}(\.\d{0,3})*$/.test(
                    props.resource[`discount_${toggleValue.value}`]
                );
                if (!result) {
                    discountError.value = $__(
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
            verifyDiscountValue,
            discountError,
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
