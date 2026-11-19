<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
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
            resourceName: "iso18626_supplying_agency",
            nameAttr: "name",
            idAttr: "iso18626_supplying_agency_id",
            components: {
                show: "SupplyingAgenciesShow",
                list: "SupplyingAgenciesList",
                add: "SupplyingAgenciesFormAdd",
                edit: "SupplyingAgenciesFormAddEdit",
            },
            apiClient: APIClient.ill.supplying_agencies,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this supplying agency?"
                ),
                deleteSuccessMessage: $__("Supplying agency %s deleted"),
                displayName: $__("Supplying agency"),
                editLabel: $__("Edit supplying agency #%s"),
                emptyListMessage: $__(
                    "There are no supplying agencies defined"
                ),
                newLabel: $__("New supplying agency"),
            },
            table: {
                resourceTableUrl:
                    APIClient.ill.httpClient._baseURL +
                    "iso18626_supplying_agencies",
            },
            groupLabels: {
                details: $__("Details"),
                iso18626_authentication: $__("ISO18626 authentication"),
            },
            resourceAttrs: [
                {
                    name: "iso18626_supplying_agency_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form"],
                    group: "details",
                },
                {
                    name: "name",
                    label: $__("Name"),
                    required: true,
                    type: "text",
                    group: "details",
                },
                {
                    name: "type",
                    label: $__("Agency ID type"),
                    required: true,
                    type: "select",
                    options: [
                        {
                            value: "DNUCNI",
                            description: $__("DNUCNI"),
                        },
                        {
                            value: "ICOLC",
                            description: $__("ICOLC"),
                        },
                        {
                            value: "ISIL",
                            description: $__("ISIL"),
                        },
                    ],
                    requiredKey: "value",
                    selectLabel: "description",
                    group: "details",
                },
                {
                    name: "agency_id",
                    label: $__("Agency ID"),
                    required: true,
                    type: "text",
                    group: "details",
                },
                {
                    name: "account_id",
                    label: $__("Account ID"),
                    required: true,
                    type: "text",
                    group: "iso18626_authentication",
                },
                {
                    name: "securityCode",
                    label: $__("Security code"),
                    required: true,
                    type: "text",
                    hideIn: ["List"],
                    group: "iso18626_authentication",
                },
                {
                    name: "endpoint",
                    label: $__("Endpoint"),
                    placeholder:
                        "https://supplier.example/api/v1/public/ill/iso18626",
                    required: true,
                    type: "text",
                    hideIn: ["List"],
                    group: "details",
                },
            ],
            moduleStore: "ILLStore",
            props: props,
        });

        const tableOptions = {
            url: () => tableUrl(),
            actions: {
                0: ["show"],
                1: ["show"],
                "-1": ["edit", "delete"],
            },
        };

        const onFormSave = (e, supplyingAgencyToSave) => {
            e.preventDefault();

            let iso18626_supplying_agency = JSON.parse(
                JSON.stringify(supplyingAgencyToSave)
            ); // copy
            let iso18626_supplying_agency_id =
                iso18626_supplying_agency.iso18626_supplying_agency_id;

            delete iso18626_supplying_agency.iso18626_supplying_agency_id;

            if (iso18626_supplying_agency_id) {
                return baseResource.apiClient
                    .update(
                        iso18626_supplying_agency,
                        iso18626_supplying_agency_id
                    )
                    .then(
                        supplying_agency => {
                            baseResource.setMessage(
                                $__("Supplying agency updated")
                            );
                            return supplying_agency;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient
                    .create(iso18626_supplying_agency)
                    .then(
                        supplying_agency => {
                            baseResource.setMessage(
                                $__("Supplying agency created")
                            );
                            return supplying_agency;
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
    name: "SupplyingAgencyResource",
    components: {
        BaseResource,
    },
};
</script>
