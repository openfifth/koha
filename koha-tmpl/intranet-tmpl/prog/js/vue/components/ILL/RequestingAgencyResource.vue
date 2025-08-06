<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { inject } from "vue";
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
    },

    setup(props) {
        const baseResource = useBaseResource({
            resourceName: "iso18626_requesting_agency",
            nameAttr: "name",
            idAttr: "iso18626_requesting_agency_id",
            components: {
                show: "RequestingAgenciesShow",
                list: "RequestingAgenciesList",
                add: "RequestingAgenciesFormAdd",
                edit: "RequestingAgenciesFormAddEdit",
            },
            apiClient: APIClient.ill.requesting_agencies,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this requesting agency?"
                ),
                deleteSuccessMessage: $__("Requesting agency %s deleted"),
                displayName: $__("Requesting agency"),
                editLabel: $__("Edit requesting agency #%s"),
                emptyListMessage: $__(
                    "There are no requesting agencies defined"
                ),
                newLabel: $__("New requesting agency"),
            },
            table: {
                resourceTableUrl:
                    APIClient.ill.httpClient._baseURL +
                    "iso18626_requesting_agencies",
            },
            resourceAttrs: [
                {
                    name: "iso18626_requesting_agency_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form"],
                },
                {
                    name: "name",
                    label: $__("Name"),
                    required: true,
                    type: "text",
                },
                {
                    name: "type",
                    label: $__("Type"),
                    required: true,
                    type: "select",
                    options: [
                        {
                            value: "DNUCNI",
                            description: __("DNUCNI"),
                        },
                        {
                            value: "ICOLC",
                            description: __("ICOLC"),
                        },
                        {
                            value: "ISIL",
                            description: __("ISIL"),
                        },
                    ],
                    requiredKey: "value",
                    selectLabel: "description",
                },
                {
                    name: "account_id",
                    label: $__("Account ID"),
                    required: true,
                    type: "text",
                },
                {
                    name: "securityCode",
                    label: $__("Security Code"),
                    required: true,
                    type: "text",
                    hideIn: ["List"],
                },
                {
                    name: "callback_endpoint",
                    label: $__("Callback endpoint"),
                    type: "text",
                    hideIn: ["List"],
                },
            ],
            moduleStore: "ILLStore",
            props: props,
        });

        const tableOptions = {
            url: () => tableUrl(),
            //table_settings: supplying_ill_table_settings, #FIXME: This causes error from datatables.js -> out of this scope
            // table_settings: {
            //     columns: [
            //         {
            //             columnname: "iso18626_request_id",
            //             cannot_be_modified: 0,
            //             is_hidden: 0,
            //             cannot_be_toggled: 0,
            //         },
            //         {
            //             columnname: "supplyingAgencyId",
            //             is_hidden: 0,
            //             cannot_be_modified: 0,
            //             cannot_be_toggled: 0,
            //         },
            //         {
            //             is_hidden: 0,
            //             cannot_be_toggled: 0,
            //             cannot_be_modified: 0,
            //             columnname: "requestingAgencyId",
            //         },
            //         {
            //             is_hidden: 0,
            //             cannot_be_toggled: 0,
            //             cannot_be_modified: 0,
            //             columnname: "status",
            //         },
            //         {
            //             is_hidden: 0,
            //             cannot_be_modified: 0,
            //             cannot_be_toggled: 0,
            //             columnname: "timestamp",
            //         },
            //         {
            //             is_hidden: 0,
            //             cannot_be_toggled: 0,
            //             cannot_be_modified: 0,
            //             columnname: "requestingAgencyRequestId",
            //         },
            //     ],
            //     default_display_length: null,
            //     table: "iso18626_requests",
            //     module: "ill",
            //     default_save_state: 1,
            //     page: "ill",
            //     default_sort_order: null,
            //     default_save_state_search: 0,
            // },
            actions: {
                0: ["show"],
                1: ["show"],
                "-1": ["edit", "delete"],
            },
        };

        const onFormSave = (e, requestingAgencyToSave) => {
            e.preventDefault();

            let iso18626_requesting_agency = JSON.parse(
                JSON.stringify(requestingAgencyToSave)
            ); // copy
            let iso18626_requesting_agency_id =
                iso18626_requesting_agency.iso18626_requesting_agency_id;

            delete iso18626_requesting_agency.iso18626_requesting_agency_id;

            if (iso18626_requesting_agency_id) {
                baseResource.apiClient
                    .update(
                        iso18626_requesting_agency,
                        iso18626_requesting_agency_id
                    )
                    .then(
                        success => {
                            baseResource.setMessage(
                                $__("Requesting agency updated")
                            );
                            baseResource.router.push({
                                name: "RequestingAgenciesList",
                            });
                        },
                        error => {}
                    );
            } else {
                baseResource.apiClient.create(iso18626_requesting_agency).then(
                    success => {
                        baseResource.setMessage(
                            $__("Requesting agency created")
                        );
                        baseResource.router.push({
                            name: "RequestingAgenciesList",
                        });
                    },
                    error => {}
                );
            }
        };
        const tableUrl = filters => {
            return baseResource.getResourceTableUrl();
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            tableUrl,
        };
    },
    emits: ["select-resource"],
    name: "RequestingAgencyResource",
    components: {
        BaseResource,
    },
};
</script>
