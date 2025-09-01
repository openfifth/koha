<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>

<script>
import BaseResource from "../../BaseResource.vue";
import { APIClient } from "../../../fetch/api-client.js";
import { useBaseResource } from "../../../composables/base-resource";
import { $__ } from "@koha-vue/i18n";
import { inject } from "vue";
import { storeToRefs } from "pinia";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { currencies } = storeToRefs(acquisitionsStore);
        const { getCurrencyConversionRate, getActiveCurrency } =
            acquisitionsStore;

        const baseResource = useBaseResource({
            resourceName: "orderline",
            nameAttr: "orderline_id",
            idAttr: "orderline_id",
            showComponent: "OrderlineShow",
            listComponent: "OrderlineList",
            addComponent: "OrderlineFormAdd",
            editComponent: "OrderlineFormAddEdit",
            apiClient: APIClient.acquisition.orderlines,
            resourceTableUrl: APIClient.acquisition._baseURL + "orderlines",
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this orderline?"
                ),
                deleteSuccessMessage: $__("Orderline %s deleted"),
                displayName: $__("Orderline"),
                editLabel: $__("Edit orderline #%s"),
                emptyListMessage: $__("There are no orderlines defined"),
                newLabel: $__("New orderline"),
            },
            props,
            moduleStore: "acquisitionsStore",
            resourceAttrs: [
                //TODO: orderline templates
                {
                    name: "is_continuous",
                    group: $__("Order type"),
                    type: "checkbox",
                    label: $__("Continuous"),
                    value: false,
                    hint: $__(
                        "Use continuous if you will receive multiple invoices, e.g. for serial subscriptions. If you use the option 'continuous' the option to create items when ordering is disabled. Items can be created on receiving or later in the catalog (without link to the order line)"
                    ),
                    hideIn: ["List"],
                },
                {
                    name: "renewal_required",
                    group: $__("Order type"),
                    type: "checkbox",
                    label: $__("Renewal required"),
                    value: false,
                    disabled: resource => !resource.is_continuous,
                    hideIn: ["List"],
                },
                {
                    name: "review_interval",
                    group: $__("Order type"),
                    type: "number",
                    label: $__("Review interval"),
                    placeholder: $__("Review interval (days)"),
                    value: null,
                    disabled: resource => !resource.is_continuous,
                    hideIn: ["List"],
                },
                {
                    name: "planned_cancellation_date",
                    type: "date",
                    group: $__("Order type"),
                    label: $__("Planned cancellation"),
                    componentProps: {
                        disabled: {
                            resourceProperty: "is_continuous",
                            qualifier: "!",
                        },
                    },
                    value: "",
                },
                //TODO: Catalog details
                {
                    name: "patrons_to_notify",
                    group: $__("Patrons to notify"),
                    type: "component",
                    label: $__("Notify on receiving"),
                    componentPath: "./PatronSearch.vue",
                    componentProps: {
                        name: {
                            type: "string",
                            value: "patrons_to_notify",
                        },
                        required: {
                            type: "boolean",
                            value: false,
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        fieldName: {
                            type: "string",
                            value: "patrons_to_notify",
                        },
                        modalType: {
                            type: "string",
                            value: "add",
                        },
                    },
                    // showElement: {
                    //     type: "text",
                    //     value: "owner",
                    //     format: patron_to_html,
                    // },
                    hideIn: ["List"],
                },
                {
                    name: "managing_branch",
                    group: $__("Library management"),
                    type: "relationshipSelect",
                    label: $__("Managing library"),
                    relationshipAPIClient: APIClient.libraries.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    hideIn: ["List"],
                },
                {
                    name: "managed_by",
                    group: $__("Library management"),
                    type: "component",
                    label: $__("Managed by"),
                    componentPath: "./PatronSearch.vue",
                    componentProps: {
                        name: {
                            type: "string",
                            value: "managed_by",
                        },
                        required: {
                            type: "boolean",
                            value: false,
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        fieldName: {
                            type: "string",
                            value: "managed_by",
                        },
                        modalType: {
                            type: "string",
                            value: "add",
                        },
                    },
                    // showElement: {
                    //     type: "text",
                    //     value: "owner",
                    //     format: patron_to_html,
                    // },
                    hideIn: ["List"],
                },
                {
                    name: "vendor_id",
                    group: $__("Vendor selection"),
                    type: "relationshipSelect",
                    label: $__("Vendor"),
                    relationshipAPIClient: APIClient.acquisition.vendors,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "id",
                    hint: $__(
                        "If you leave the vendor empty the orderline can only be saved as a draft"
                    ),
                    onSelected: (e, options, resource) => {
                        const vendor = options.find(option => option.id === e);
                        // resource.tax_rate = vendor.tax_rate;
                        resource.vendor = vendor;
                        resource.fund_distributions.forEach(fd => {
                            fd.tax_rate = vendor.tax_rate;
                        });
                    },
                    hideIn: ["List"],
                },
                {
                    name: "quantity_ordered",
                    group: $__("Accounting details"),
                    type: "number",
                    label: $__("Quantity"),
                    defaultValue: null,
                    size: 6,
                    hideIn: ["List"],
                },
                {
                    name: "vendor_price",
                    group: $__("Accounting details"),
                    type: "number",
                    required: true,
                    label: $__("Price"),
                    defaultValue: null,
                    size: 6,
                    hideIn: ["List"],
                },
                {
                    name: "vendor_price_currency",
                    group: $__("Accounting details"),
                    type: "select",
                    selectLabel: "currency",
                    requiredKey: "currency",
                    label: $__("Currency"),
                    options: currencies.value,
                    onSelected: (e, options, resource) => {
                        if (resource.fund_distributions.length) {
                            resource.fund_distributions.forEach(fd => {
                                const fxRate = getCurrencyConversionRate(
                                    e,
                                    fd.fund?.currency
                                );
                                resource.distribution_exchange_rate = fxRate;
                                fd.exchange_rate = fxRate;
                            });
                        } else {
                            resource.distribution_exchange_rate =
                                getCurrencyConversionRate(e, null);
                        }
                    },
                    defaultValue: null,
                },
                {
                    name: "uncertain_price",
                    group: $__("Accounting details"),
                    type: "checkbox",
                    label: $__("Uncertain price"),
                    value: false,
                    hideIn: ["List"],
                },
                {
                    name: "discount",
                    group: $__("Accounting details"),
                    type: "component",
                    label: $__("Discount"),
                    componentPath:
                        "./Acquisitions/OrderManagement/InputNumberPercentageToggle.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        percentageField: {
                            type: "string",
                            value: "discount_percentage",
                        },
                        amountField: {
                            type: "string",
                            value: "discount_amount_oc",
                        },
                    },
                    hideIn: ["List"],
                },
                // {
                //     name: "replacement_price",
                //     group: $__("Accounting details"),
                //     type: "number",
                //     label: $__("Replacement cost"),
                //     defaultValue: null,
                //     size: 6,
                //     hideIn: ["List"],
                // },
                // {
                //     name: "tax_rate",
                //     group: $__("Accounting details"),
                //     type: "select",
                //     label: $__("Tax rate"),
                //     options: gstValues.value,
                //     defaultValue: null,
                //     selectLabel: "label",
                //     requiredKey: "value",
                //     hideIn: ["List"],
                // },
                {
                    name: "price_summary",
                    group: $__("Accounting details"),
                    type: "component",
                    componentPath:
                        "./Acquisitions/OrderManagement/PriceSummary.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                    },
                    hideIn: ["List"],
                },
                {
                    name: "calculated_amount_oc",
                    type: "component",
                    group: $__("Fund / fund distributions"),
                    componentPath:
                        "./Acquisitions/OrderManagement/CalculatedAmount.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        currency: {
                            type: "string",
                            value: "original",
                        },
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "fund_distributions",
                    type: "relationshipWidget",
                    group: $__("Fund / fund distributions"),
                    apiClient: APIClient.acquisition.funds,
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "fund_distributions",
                        },
                        relationshipStrings: {
                            nameLowerCase: $__("fund distribution"),
                            namePlural: $__("fund distributions"),
                            nameUpperCase: $__("Fund distribution"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                orderline_id: null,
                                fund_id: null,
                                percentage: null,
                                distributed_amount_oc: null,
                                exchange_rate: null,
                                distributed_amount: null,
                                tax_rate: null,
                                tax_value: null,
                                distibuted_amount_tax_excluded: null,
                                distibuted_amount_tax_included: null,
                            },
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        fetchOptions: {
                            type: "boolean",
                            value: true,
                        },
                        disabled: {
                            type: "function",
                            value: resource => {
                                // if(!resource.fund_distributions?.length) return false
                                if (
                                    resource.fund_distributions?.length &&
                                    (!resource.fund_distributions[0].fund_id ||
                                        resource.totalDistributedAmount ===
                                            resource.calculated_amount_oc)
                                )
                                    return true;
                                return false;
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            type: "component",
                            componentPath:
                                "./Acquisitions/OrderManagement/FundDistributionForm.vue",
                            indexRequired: true,
                            componentProps: {
                                resource: {
                                    type: "resource",
                                    value: null,
                                },
                                options: {
                                    type: "parentProp",
                                    value: null,
                                },
                            },
                            hideIn: ["List", "Show"],
                        },
                    ],
                    hideIn: ["List"],
                },
                {
                    name: "distribution_exchange_rate",
                    group: $__("Fund / fund distributions"),
                    label: $__("Exchange rate"),
                    type: "number",
                    defaultValue: 1.0,
                    size: 6,
                    hint: resource => {
                        return `(${resource.vendor_price_currency || getActiveCurrency.currency} to ${resource?.fund_distributions?.[0]?.fund?.currency || getActiveCurrency.currency})`;
                    },
                    onChange: resource => {
                        resource.fund_distributions.forEach(fd => {
                            fd.exchange_rate =
                                resource.distribution_exchange_rate;
                            fd.calculateDistributedAmount(fd);
                        });
                    },
                    hideIn: ["List"],
                },
                {
                    name: "replacement_price",
                    group: $__("Fund / fund distributions"),
                    label: $__("Item replacement cost"),
                    type: "number",
                    defaultValue: 1.0,
                    size: 6,
                    hideIn: ["List"],
                },
                {
                    name: "calculated_item_costs",
                    type: "component",
                    group: $__("Fund / fund distributions"),
                    componentPath:
                        "./Acquisitions/OrderManagement/CalculatedAmount.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                    },
                    hideIn: ["List", "Show"],
                },
            ],
        });

        const tableURL = () => {
            return "";
        };

        const tableOptions = {
            url: tableURL(),
            table_settings: null,
            add_filters: true,
            add_filters: true,
            actions: {
                0: ["show"],
                "-1": [
                    ...(baseResource.isUserPermitted("editOrderline")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("deleteOrderline")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const onSubmit = (e, orderlineToSave) => {
            e.preventDefault();
            // TODOs:
            // Need to check all costs distributed (resource.remainderToDistribute)
            // Various new prperties added to support reactivity through different components, delete here to avoid API spec conflict
        };

        return {
            ...baseResource,
            tableOptions,
            onSubmit,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "OrderlineResource",
};
</script>
