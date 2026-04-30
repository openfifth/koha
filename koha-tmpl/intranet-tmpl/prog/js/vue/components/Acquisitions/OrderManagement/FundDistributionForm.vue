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
import BigNumber from "bignumber.js";
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
            differentCurrenciesInLedgers,
            buildFundTreeOptions,
        } = acquisitionsStore;

        const fundDistributions = inject("resourceRelationships");
        const orderline = inject("resource");
        // Set the tax rate if a vendor has already been selected
        if (orderline.vendor) {
            props.resource.tax_rate = orderline.vendor.tax_rate || 0;
        }
        // Set the exchange rate if one has been set for the orderline
        if (orderline.distribution_exchange_rate) {
            props.resource.exchange_rate = orderline.distribution_exchange_rate || 1;
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
                distribution.distributed_amount_oc = new BigNumber(
                    totalAmount || 0
                )
                    .times(distribution.percentage)
                    .div(100)
                    .toNumber();
            }

            // Calculate the currency conversion if required (exchange rate will be 1.00 if the currencies match)
            const fxConverted = new BigNumber(
                distribution.distributed_amount_oc || 0
            ).times(distribution.exchange_rate || 0);

            if (taxIncluded) {
                // Price includes tax: back-calculate the excluded amount by dividing out the tax rate
                const taxExcluded = fxConverted.div(
                    new BigNumber(1).plus(distribution.tax_rate || 0)
                );
                distribution.distributed_amount_tax_included =
                    fxConverted.toNumber();
                distribution.distributed_amount_tax_excluded =
                    taxExcluded.toNumber();
                distribution.tax_value = fxConverted
                    .minus(taxExcluded)
                    .toNumber();
            } else {
                // Price excludes tax: add tax on top
                const taxIncludedAmount = fxConverted.times(
                    new BigNumber(1).plus(distribution.tax_rate || 0)
                );
                distribution.distributed_amount_tax_excluded =
                    fxConverted.toNumber();
                distribution.distributed_amount_tax_included =
                    taxIncludedAmount.toNumber();
                distribution.tax_value = taxIncludedAmount
                    .minus(fxConverted)
                    .toNumber();
            }
            distribution.distributed_amount = fxConverted.toNumber();
        };
        // Assign this method to the distribution to use outside this component where required
        props.resource.calculateDistributedAmount =
            calculateDistributedAmount.bind(null, props.resource, orderline);
        // Calculate the initial distributed amount based on a default of 100% being allocated to the first fund selected
        if (props.index === 0) {
            props.resource.percentage = 100;
            calculateDistributedAmount(props.resource);
        } else {
            const calculatedAmount = new BigNumber(
                orderline.calculated_amount_oc || 0
            );
            const remainderToDistribute = calculatedAmount.minus(
                orderline.totalDistributedAmount || 0
            );
            props.resource.percentage = calculatedAmount.isZero()
                ? 0
                : remainderToDistribute
                      .div(calculatedAmount)
                      .times(100)
                      .toNumber();
        }

        watch(
            () => orderline.calculated_amount_oc,
            () => {
                calculateDistributedAmount(props.resource);
            }
        );

        const filterFundsBasedOnPreviousSelections = () => {
            const activeFunds = props.options.filter(fund => fund.status);
            if (fundDistributions.length > 1) {
                const selectedFundIds = fundDistributions.map(fd => fd.fund_id);
                let firstSelection;
                selectedFundIds.forEach(fundId => {
                    if (!fundId) return;
                    const fund = activeFunds.find(
                        fund => fund.fund_id == fundId
                    );
                    if (!firstSelection) firstSelection = fund;
                });
                if (!firstSelection) {
                    return activeFunds;
                } else {
                    const fundsNotYetSelected = activeFunds.filter(
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
                return activeFunds;
            }
        };

        const fundList = ref(filterFundsBasedOnPreviousSelections());
        const fundOptions = computed(() => fundList.value);

        const distributedAmount = ref(0);
        const calculatedTotalDistributedAmount = fundDistributions => {
            return fundDistributions
                .reduce(
                    (acc, fd) =>
                        acc.plus(new BigNumber(fd.distributed_amount_oc || 0)),
                    new BigNumber(0)
                )
                .toNumber();
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
                treeSelect: true,
                treeSelectOptionsHandler: buildFundTreeOptions,
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
                        fd.exchange_rate = orderline.distribution_exchange_rate || 1;
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
                    idString: {
                        type: "string",
                        value: "distributed_amount",
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
