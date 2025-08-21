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

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
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
