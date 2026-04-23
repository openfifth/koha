<template>
    <h3 v-if="currency === 'original'">
        {{ $__("Remaining amount in original currency to be distributed") }}:
        {{ remainingAmount.amount }} ({{
            !remainingAmount ? 0 : remainingAmount.percentage
        }}%)
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
            props.resource.remainderToDistribute =
                remainderToDistribute.toNumber();
            const result = {
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
            return result;
        });

        const calculatedItemAmounts = computed(() => {
            const orderline = props.resource;
            const itemPrice = new BigNumber(orderline.calculated_amount_oc || 0)
                .times(orderline.distribution_exchange_rate || 0)
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
            props.resource.replacement_price = itemPrice.isZero()
                ? null
                : itemPrice.toNumber();
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
