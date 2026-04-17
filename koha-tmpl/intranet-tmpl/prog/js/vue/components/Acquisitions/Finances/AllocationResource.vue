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
import { ref, inject } from "vue";

export default {
    props: {
        routeAction: String,
        route: Object,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const {
            params: { entity, entity_id },
            query: { action },
        } = props.route;
        const isFund = ref(entity === "fund" ? true : false);
        const isValueIncrease = ref(action === "increase");
        const isValueDecrease = ref(action === "decrease");
        const isTransfer = ref(action === "transfer");

        const acquisitionsStore = inject("acquisitionsStore");
        const { formatValueWithCurrency } = acquisitionsStore;

        const remainingAmountLabel = () => {
            if (isValueIncrease.value) {
                return isFund.value
                    ? $__("Increased fund amount")
                    : $__("Increased ledger amount");
            }
            if (isValueDecrease.value) {
                return isFund.value
                    ? $__("Decreased fund amount")
                    : $__("Decreased ledger amount");
            }
            if (isTransfer.value) {
                return isFund.value
                    ? $__("Remaining fund amount")
                    : $__("Remaining ledger amount");
            }
        };

        const baseResource = useBaseResource({
            resourceName: "allocation",
            nameAttr: "name",
            idAttr: "allocation_id",
            components: {
                add: "AllocationFormAdd",
            },
            apiClient: APIClient.acquisition.allocations,
            table: {
                resourceTableUrl:
                    APIClient.acquisition._baseURL + "allocations",
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this allocation?"
                ),
                deleteSuccessMessage: $__("Allocation %s deleted"),
                displayName: $__("Allocation"),
                editLabel: $__("Edit allocation #%s"),
                emptyListMessage: $__("There are no allocations defined"),
                newLabel: $__("New allocation"),
                breachAmountMessage: $__(
                    "The parent amount will be breached by %s. Please reduce the amount for this allocation."
                ),
            },
            moduleStore: "acquisitionsStore",
            props,
            navigationOnFormSave: isFund.value ? "FundList" : "LedgerList",
            resourceAttrs: [
                {
                    name: "allocation_id",
                    type: "text",
                    hideIn: ["Form"],
                },
                {
                    name: "fiscal_period_name",
                    type: "display",
                    label: $__("Fiscal period"),
                },
                {
                    name: "ledger_name",
                    type: "display",
                    label: $__("Ledger"),
                },
                ...(isFund.value
                    ? [
                          {
                              name: "fund_name",
                              type: "display",
                              label: $__("Fund"),
                          },
                      ]
                    : []),
                {
                    name: `${entity}_amount`,
                    type: "display",
                    label: $__("Current amount"),
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                },
                {
                    name: "allocation_amount",
                    type: "number",
                    label: isValueIncrease.value
                        ? $__("Increase amount by")
                        : isValueDecrease.value
                          ? $__("Decrease amount by")
                          : $__("Amount being transferred"),
                    defaultValue: 0,
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                },
                ...(isTransfer.value
                    ? [
                          {
                              name: "is_transferred_to",
                              type: "relationshipSelect",
                              label: isFund.value
                                  ? $__("Destination fund")
                                  : $__("Destination ledger"),
                              relationshipAPIClient:
                                  APIClient.acquisition[
                                      isFund.value ? "funds" : "ledgers"
                                  ],
                              relationshipOptionLabelAttr: "name",
                              relationshipRequiredKey: isFund.value
                                  ? "fund_id"
                                  : "ledger_id",
                              query: {
                                  [isFund.value ? "fund_id" : "ledger_id"]: {
                                      "!=": entity_id,
                                  },
                              },
                              required: true,
                          },
                      ]
                    : []),
                {
                    name: "reference",
                    type: "text",
                    label: $__("Reference"),
                },
                {
                    name: "note",
                    type: "text",
                    label: $__("Note"),
                },
                {
                    name: "remaining_amount",
                    type: "display",
                    label: remainingAmountLabel(),
                    format: (value, resource) => {
                        const allocatedAmount =
                            parseInt(resource.allocation_amount) || 0;
                        const remainder = isValueIncrease.value
                            ? resource[`${entity}_amount`] + allocatedAmount
                            : resource[`${entity}_amount`] - allocatedAmount;
                        resource.remaining_amount = remainder;
                        return formatValueWithCurrency(
                            remainder,
                            resource.currency
                        );
                    },
                },
            ],
        });

        const afterNewResourceCreate = (
            resource,
            componentData,
            initialized
        ) => {
            APIClient.acquisition[`${entity}s`].get(entity_id).then(result => {
                resource.fiscal_period_name = result.fiscal_period.name;
                const ledger = isFund.value ? result.ledger : result;
                resource.ledger_name = ledger.name;
                resource.currency = ledger.currency;
                if (isFund.value) resource.fund_name = result.name;
                resource[`${entity}_amount`] = result[`${entity}_amount`];
                resource[`${entity}_id`] = entity_id;
                resource.type = action;
                initialized.value = true;
            });
            return resource;
        };

        const onFormSave = (e, allocationToSave) => {
            e.preventDefault();

            const allocation = JSON.parse(JSON.stringify(allocationToSave));

            if (allocation.remaining_amount < 0) {
                baseResource.setWarning(
                    $__(
                        "Insufficient funds to process this transaction, please adjust the allocation amount"
                    )
                );
                return;
            }

            [
                "currency",
                "fiscal_period_name",
                "ledger_name",
                "fund_name",
                "ledger_amount",
                "fund_amount",
                "remaining_amount",
                "allocation_id",
            ].forEach(key => {
                delete allocation[key];
            });

            return baseResource.apiClient.create(allocation).then(
                allocation => {
                    baseResource.setMessage($__("Allocation created"));
                    return allocation;
                },
                error => {
                    baseResource.setWarning(
                        baseResource.i18n.breachAmountMessage.format(
                            formatValueWithCurrency(error.result.breach_amount)
                        )
                    );
                }
            );
        };

        return {
            ...baseResource,
            onFormSave,
            afterNewResourceCreate,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "AllocationResource",
};
</script>
