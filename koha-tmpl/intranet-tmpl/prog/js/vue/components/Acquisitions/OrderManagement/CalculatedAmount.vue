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
import { computed, inject, watch } from "vue";
import BigNumber from "bignumber.js";

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
            const calculatedAmount = new BigNumber(
                props.resource.calculated_amount_oc || 0
            );
            const remainderToDistribute = calculatedAmount.minus(
                props.resource.totalDistributedAmount || 0
            );
            return {
                remainder: remainderToDistribute.toNumber(),
                amount: formatValueWithCurrency(
                    remainderToDistribute.toNumber(),
                    props.resource.vendor_price_currency
                ),
                percentage: remainderToDistribute.isZero()
                    ? 0
                    : remainderToDistribute
                          .div(calculatedAmount)
                          .times(100)
                          .decimalPlaces(2, BigNumber.ROUND_HALF_UP)
                          .toNumber(),
            };
        });

        const calculatedItemAmounts = computed(() => {
            const orderline = props.resource;
            const itemPrice = new BigNumber(orderline.calculated_amount_oc || 0)
                .times(orderline.distribution_exchange_rate || 1)
                .div(orderline.quantity_ordered || 1);
            const selectedCurrency = Array.isArray(orderline.fund_distributions)
                ? orderline.fund_distributions[0]?.currency
                : getActiveCurrency.currency;
            const isTaxIncluded = orderline.vendor?.list_includes_gst;
            const taxRate = new BigNumber(orderline.vendor?.tax_rate || 0);
            const taxIncludedPrice = isTaxIncluded
                ? itemPrice
                : itemPrice.times(new BigNumber(1).plus(taxRate));
            const taxExcludedPrice = isTaxIncluded
                ? itemPrice.div(new BigNumber(1).plus(taxRate))
                : itemPrice;
            const qty = new BigNumber(orderline.quantity_ordered || 0);
            const totalTaxIncluded = taxIncludedPrice.times(qty);
            const totalTaxExcluded = taxExcludedPrice.times(qty);
            const totalAmount = isTaxIncluded
                ? totalTaxIncluded
                : totalTaxExcluded;

            const itemPricePoints = {
                replacementItemPrice: itemPrice.isZero()
                    ? null
                    : itemPrice.toNumber(),
                totalTaxIncluded: formatValueWithCurrency(
                    totalTaxIncluded.toNumber(),
                    selectedCurrency
                ),
                totalTaxExcluded: formatValueWithCurrency(
                    totalTaxExcluded.toNumber(),
                    selectedCurrency
                ),
                totalAmount: formatValueWithCurrency(
                    totalAmount.toNumber(),
                    selectedCurrency
                ),
                itemPrice: formatValueWithCurrency(
                    itemPrice.toNumber(),
                    selectedCurrency
                ),
                currency: selectedCurrency,
            };
            return itemPricePoints;
        });
        watch(
            remainingAmount,
            val => {
                props.resource.remainderToDistribute = val.remainder;
            },
            { immediate: true }
        );

        watch(
            calculatedItemAmounts,
            val => {
                props.resource.replacement_price = val.replacementItemPrice;
            },
            { immediate: true }
        );

        return {
            remainingAmount,
            calculatedItemAmounts,
        };
    },
};
</script>

<style></style>
