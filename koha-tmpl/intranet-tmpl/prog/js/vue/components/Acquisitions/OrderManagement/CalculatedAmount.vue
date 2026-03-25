<template>
    <h3>
        {{ $__("Remaining amount in original currency to be distributed") }}:
        {{ remainingAmount }}
    </h3>
</template>

<script>
import { computed, inject, ref, watch } from "vue";
export default {
    props: {
        resource: Object,
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { formatValueWithCurrency } = acquisitionsStore;

        const remainingAmount = computed(() => {
            const calculatedAmount = props.resource.calculated_amount_oc
                ? props.resource.calculated_amount_oc
                : 0;
            const remainderToDistribute =
                calculatedAmount - props.resource.totalDistributedAmount;
            props.resource.remainderToDistribute = remainderToDistribute;
            return formatValueWithCurrency(
                remainderToDistribute || 0,
                props.resource.vendor_price_currency
            );
        });

        return {
            remainingAmount,
        };
    },
};
</script>

<style></style>
