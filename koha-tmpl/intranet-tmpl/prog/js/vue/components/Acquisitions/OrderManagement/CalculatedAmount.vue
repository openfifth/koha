<template>
    <h3 v-if="currency === 'original'">
        {{ $__("Remaining amount in original currency to be distributed") }}:
        {{ remainingAmount.amount }} ({{ remainingAmount.percentage }}%)
    </h3>
    <template v-if="currency !== 'original'">
        <h5>
            {{
                $__("Calculated item amount in %s (tax incl./excl.)").format(
                    calculatedItemAmounts.currency
                )
            }}:
            {{ calculatedItemAmounts.itemPrice }}
        </h5>
        <h5>
            {{ $__("Total cost (tax included)") }}:
            {{ calculatedItemAmounts.totalTaxIncluded }}
        </h5>
        <h5>
            {{ $__("Total cost (tax excluded)") }}:
            {{ calculatedItemAmounts.totalTaxExcluded }}
        </h5>
        <h5>
            {{ $__("Calculated total amount") }}:
            {{ calculatedItemAmounts.totalAmount }}
        </h5>
    </template>
</template>

<script>
import { computed, inject } from "vue";

export default {
    inheritAttrs: false,
    props: {
        resource: Object,
        currency: {
            type: String,
            default: "",
        },
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { formatValueWithCurrency, getActiveCurrency } =
            acquisitionsStore;

        const remainingAmount = computed(() => {
            const calculatedAmount = props.resource.calculated_amount_oc
                ? props.resource.calculated_amount_oc
                : 0;
            const remainderToDistribute =
                calculatedAmount - props.resource.totalDistributedAmount;
            props.resource.remainderToDistribute = remainderToDistribute;
            const result = {
                amount: formatValueWithCurrency(
                    remainderToDistribute || 0,
                    props.resource.vendor_price_currency
                ),
                percentage: remainderToDistribute
                    ? (remainderToDistribute / calculatedAmount) * 100
                    : 0,
            };
            return result;
        });

        const calculatedItemAmounts = computed(() => {
            const orderline = props.resource;
            const itemPrice =
                (orderline.calculated_amount_oc *
                    orderline.distribution_exchange_rate) /
                orderline.quantity_ordered;
            const selectedCurrency =
                orderline.fund_distributions[0]?.currency ||
                getActiveCurrency.currency;
            const isTaxIncluded = orderline.vendor?.list_includes_gst;
            const taxRate = orderline.vendor?.tax_rate || 0;
            const taxIncludedPrice = isTaxIncluded
                ? itemPrice
                : itemPrice * (1 + taxRate);
            const taxExcludedPrice = isTaxIncluded
                ? itemPrice - itemPrice * taxRate
                : itemPrice;
            const totalTaxIncluded =
                taxIncludedPrice * orderline.quantity_ordered;
            const totalTaxExcluded =
                taxExcludedPrice * orderline.quantity_ordered;
            const totalAmount = isTaxIncluded
                ? totalTaxIncluded
                : totalTaxExcluded;

            const itemPricePoints = {
                totalTaxIncluded: formatValueWithCurrency(
                    totalTaxIncluded,
                    selectedCurrency
                ),
                totalTaxExcluded: formatValueWithCurrency(
                    totalTaxExcluded,
                    selectedCurrency
                ),
                totalAmount: formatValueWithCurrency(
                    totalAmount,
                    selectedCurrency
                ),
                itemPrice: formatValueWithCurrency(itemPrice, selectedCurrency),
                currency: selectedCurrency,
            };
            props.resource.replacement_price = itemPrice;
            return itemPricePoints;
        });
        return {
            remainingAmount,
            calculatedItemAmounts,
        };
    },
};
</script>

<style></style>
