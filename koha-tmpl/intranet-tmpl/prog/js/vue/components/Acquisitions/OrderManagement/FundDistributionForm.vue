<template>
    <ol>
        <li v-for="(attr, index) in distributionFields" v-bind:key="index">
            <FormElement
                :resource="resource"
                :attr="attr"
                :index="index"
                :options="fundOptions"
            />
        </li>
    </ol>
</template>

<script>
import { computed, inject, ref, watch } from "vue";
import { $__ } from "@koha-vue/i18n";
import FormElement from "../../FormElement.vue";
import { storeToRefs } from "pinia";

export default {
    components: { FormElement },
    props: {
        index: Number,
        resource: Object,
        options: Array,
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { gstValues } = storeToRefs(acquisitionsStore);
        const {
            getCurrencyConversionRate,
            formatValueWithCurrency,
            getActiveCurrency,
            formatFloatingPoint,
            differentCurrenciesInLedgers,
        } = acquisitionsStore;

        const fundDistributions = inject("resourceRelationships");
        const orderline = inject("resource");
        // Set the tax rate if a vendor has already been selected
        if (orderline.vendor) {
            props.resource.tax_rate = orderline.vendor.tax_rate;
        }
        // Set the exchange rate if one has been set for the orderline
        if (orderline.distribution_exchange_rate) {
            props.resource.exchange_rate = orderline.distribution_exchange_rate;
        }
        // Set the currency for the final distribution for display in the UI
        if (orderline.vendor_price_currency) {
            props.resource.currency = orderline.vendor_price_currency;
        }

        const calculateDistributedAmount = (
            distribution,
            orderLine = orderline
        ) => {
            const taxIncluded = orderLine.vendor?.list_includes_gst;
            distribution.taxIncluded = taxIncluded;
            const totalAmount = orderLine.calculated_amount_oc;

            // If the distribution is a percentage, caluculate the value based on that percentage and set the distributed_amount_oc
            if (distribution.percentage) {
                distribution.distributed_amount_oc =
                    totalAmount * (distribution.percentage / 100);
            }

            // Calculate the currency conversion if required (exchange rate will be 1.00 if the currencies match)
            const fxConvertedDistribution =
                distribution.distributed_amount_oc * distribution.exchange_rate;
            // Calculate whether to add the tax value based on listincgst
            const withTaxAdded = taxIncluded
                ? fxConvertedDistribution
                : fxConvertedDistribution * (1 + distribution.tax_rate);

            // Work out tax value
            distribution.tax_value = taxIncluded
                ? fxConvertedDistribution * distribution.tax_rate
                : withTaxAdded - fxConvertedDistribution;
            // Set the distributed amounts
            distribution.distributed_amount_tax_included = taxIncluded
                ? fxConvertedDistribution
                : withTaxAdded;
            distribution.distributed_amount_tax_excluded = taxIncluded
                ? fxConvertedDistribution - distribution.tax_value
                : fxConvertedDistribution;
            distribution.distributed_amount = fxConvertedDistribution;
        };
        // Assign this method to the distribution to use outside this component where required
        props.resource.calculateDistributedAmount =
            calculateDistributedAmount.bind(null, props.resource, orderline);
        // Calculate the initial distributed amount based on a default of 100% being allocated to the first fund selected
        if (props.index === 0) {
            props.resource.percentage = 100;
            calculateDistributedAmount(props.resource);
        } else {
            const remainderToDistribute =
                orderline.calculated_amount_oc -
                orderline.totalDistributedAmount;
            const remainderPercentage =
                (remainderToDistribute / orderline.calculated_amount_oc) * 100;
            props.resource.percentage = remainderPercentage;
        }

        watch(
            () => orderline.calculated_amount_oc,
            () => {
                calculateDistributedAmount(props.resource);
            }
        );

        const filterFundsBasedOnPreviousSelections = () => {
            if (fundDistributions.length > 1) {
                const selectedFundIds = fundDistributions.map(fd => fd.fund_id);
                let firstSelection;
                selectedFundIds.forEach(fundId => {
                    if (!fundId) return;
                    const fund = props.options.find(
                        fund => fund.fund_id == fundId
                    );
                    if (!firstSelection) firstSelection = fund;
                });
                if (!firstSelection) {
                    return props.options;
                } else {
                    const fundsNotYetSelected = props.options.filter(
                        fund =>
                            !fundDistributions.some(
                                fd => fd.fund_id == fund.fund_id
                            )
                    );
                    const currentlySelectedFundForThisResource =
                        props.options.find(
                            fund =>
                                fund.fund_id ==
                                fundDistributions[props.index].fund_id
                        );
                    if (currentlySelectedFundForThisResource)
                        fundsNotYetSelected.push(
                            currentlySelectedFundForThisResource
                        );
                    return differentCurrenciesInLedgers
                        ? fundsNotYetSelected.filter(
                              fund => fund.currency == firstSelection.currency
                          )
                        : fundsNotYetSelected;
                }
            } else {
                return props.options;
            }
        };

        const fundList = ref(filterFundsBasedOnPreviousSelections());
        const fundOptions = computed(() => fundList.value);

        const distributedAmount = ref(0);
        const calculatedTotalDistributedAmount = fundDistributions => {
            return fundDistributions.reduce((acc, fd) => {
                return acc + parseFloat(fd.distributed_amount_oc || 0);
            }, 0);
        };

        watch(fundDistributions, () => {
            fundList.value = filterFundsBasedOnPreviousSelections();
            orderline.totalDistributedAmount =
                calculatedTotalDistributedAmount(fundDistributions);
            if (
                fundDistributions[props.index]?.fund_id !==
                props.resource.fund_id
            ) {
                Object.keys(fundDistributions[props.index]).forEach(key => {
                    props.resource[key] = fundDistributions[props.index][key];
                });
            }
        });

        const distributionFields = ref([
            {
                name: "fund_id",
                type: "select",
                label: $__("Fund"),
                requiredKey: "fund_id",
                selectLabel: "name",
                onSelected: (e, options, resource) => {
                    const fund = props.options.find(
                        option => option.fund_id === e
                    );
                    props.resource.fund = fund;
                    const { vendor_price_currency } = orderline;
                    orderline.distribution_exchange_rate =
                        getCurrencyConversionRate(
                            vendor_price_currency,
                            fund?.currency
                        );
                    fundDistributions.forEach(fd => {
                        fd.currency = differentCurrenciesInLedgers
                            ? fund?.currency || vendor_price_currency
                            : getActiveCurrency.currency;
                        fd.exchange_rate = orderline.distribution_exchange_rate;
                        calculateDistributedAmount(fd);
                    });
                },
                indexRequired: true,
            },
            {
                name: "distribution",
                label: $__("Distribution"),
                type: "component",
                componentPath:
                    "@koha-vue/components/Acquisitions/OrderManagement/InputNumberPercentageToggle.vue",
                componentProps: {
                    resource: {
                        type: "resource",
                        value: null,
                    },
                    percentageField: {
                        type: "string",
                        value: "percentage",
                    },
                    amountField: {
                        type: "string",
                        value: "distributed_amount_oc",
                    },
                    onChange: {
                        type: "function",
                        value: (resource, toggleValue) => {
                            if (
                                toggleValue === "percentage" &&
                                !resource.percentage
                            ) {
                                resource.distributed_amount_oc = 0;
                            }
                            calculateDistributedAmount(resource);
                        },
                    },
                    formatInputValue: {
                        type: "function",
                        value: (value, resource) => {
                            const isPercentage = resource.percentage;
                            if (isPercentage) {
                                return `${formatFloatingPoint(value)}%`;
                            }
                            const currency =
                                resource.currency || getActiveCurrency.currency;
                            return formatValueWithCurrency(value, currency);
                        },
                    },
                },
                events: [
                    {
                        name: "toggleChanged",
                        callback: (resource, toggleValue) => {
                            resource.distributed_amount = 0;
                        },
                    },
                ],
            },
            {
                name: "tax_rate",
                type: "select",
                label: $__("Tax rate"),
                options: gstValues.value,
                selectLabel: "label",
                requiredKey: "value",
                onSelected: (e, options, resource) => {
                    calculateDistributedAmount(resource);
                },
                hideIn: ["List"],
            },
            {
                name: "distributed_amount",
                label: $__("Calculated amount"),
                type: "display",
                disabled: true,
                size: 6,
                format: (attr, resource) => {
                    const distributionValue = resource.taxIncluded
                        ? resource.distributed_amount_tax_included
                        : resource.distributed_amount_tax_excluded;
                    return formatValueWithCurrency(
                        distributionValue,
                        resource.currency
                    );
                },
                hideIn: ["List"],
            },
        ]);

        return {
            distributionFields,
            distributedAmount,
            fundOptions,
        };
    },
};
</script>

<style scoped>
/* :deep(form .v-select) {
    display: inline-block;
    background-color: white;
    width: 60%;
}

:deep(.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not(
        [type="checkbox"]
    ):not([type="radio"]),
textarea) {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 60%;
} */
</style>
