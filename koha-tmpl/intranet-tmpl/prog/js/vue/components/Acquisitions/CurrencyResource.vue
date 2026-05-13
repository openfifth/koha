<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>

<script>
import BaseResource from "../BaseResource.vue";
import { APIClient } from "../../fetch/api-client.js";
import { useBaseResource } from "../../composables/base-resource";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const baseResource = useBaseResource({
            resourceName: "currency",
            nameAttr: "currency",
            idAttr: "currency",
            components: {
                show: "CurrencyShow",
                list: "CurrencyList",
                add: "CurrencyFormAdd",
                edit: "CurrencyFormAddEdit",
            },
            apiClient: APIClient.acquisition.currencies,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this currency?"
                ),
                deleteSuccessMessage: $__("Currency %s deleted"),
                displayName: $__("Currency"),
                editLabel: $__("Edit currency %s"),
                emptyListMessage: $__("There are no currencies defined"),
                newLabel: $__("New currency"),
            },
            table: {
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL + "currencies",
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "currency",
                    type: "text",
                    label: $__("Currency code"),
                },
                {
                    name: "symbol",
                    type: "text",
                    label: $__("Symbol"),
                },
                {
                    name: "isocode",
                    type: "text",
                    label: $__("ISO code"),
                },
                {
                    name: "rate",
                    type: "text",
                    label: $__("Rate"),
                },
                {
                    name: "active",
                    type: "checkbox",
                    label: $__("Active"),
                },
                {
                    name: "p_cs_precedes",
                    type: "checkbox",
                    label: $__("Currency symbol precedes value"),
                    hideIn: ["List"],
                },
                {
                    name: "p_sep_by_space",
                    type: "checkbox",
                    label: $__("Space between symbol and value"),
                    hideIn: ["List"],
                },
            ],
        });

        const tableOptions = {
            table_settings: null,
            add_filters: false,
            actions: {
                0: ["show"],
                "-1": [
                    ...(baseResource.isUserPermitted("managePurchaseOrders")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("managePurchaseOrders")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const onFormSave = (e, currencyToSave) => {
            e.preventDefault();

            const currency = JSON.parse(JSON.stringify(currencyToSave));
            const currency_id = currency.currency;

            delete currency.timestamp;

            if (currency_id && baseResource.routeAction !== "add") {
                delete currency.currency;
                return baseResource.apiClient
                    .update(currency, currency_id)
                    .then(
                        updatedCurrency => {
                            baseResource.setMessage($__("Currency updated"));
                            return updatedCurrency;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(currency).then(
                    newCurrency => {
                        baseResource.setMessage($__("Currency created"));
                        return newCurrency;
                    },
                    error => {}
                );
            }
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "CurrencyResource",
};
</script>
