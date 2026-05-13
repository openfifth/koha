<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },

    setup(props) {
        const baseResource = useBaseResource({
            resourceName: "edi_ean_account",
            nameAttr: "ean",
            idAttr: "edi_ean_account_id",
            components: {
                show: "EdiEanAccountShow",
                list: "EdiEanAccountList",
                add: "EdiEanAccountFormAdd",
                edit: "EdiEanAccountFormAddEdit",
            },
            apiClient: APIClient.acquisition.ediEanAccounts,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this library EAN account?"
                ),
                deleteSuccessMessage: $__("Library EAN account %s deleted"),
                displayName: $__("Library EAN account"),
                editLabel: $__("Edit library EAN account %s"),
                emptyListMessage: $__(
                    "There are no library EAN accounts defined"
                ),
                newLabel: $__("New library EAN account"),
            },
            table: {
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL +
                    "edi_ean_accounts",
                add_filters: false,
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "branchcode",
                    label: $__("Library"),
                    type: "relationshipSelect",
                    relationshipAPIClient: APIClient.libraries.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    showElement: {
                        type: "text",
                        value: "library.name",
                        link: {
                            href: "/cgi-bin/koha/admin/branches.pl",
                            params: {
                                op: "view",
                                branchcode: "branchcode",
                            },
                        },
                    },
                },
                {
                    name: "description",
                    label: $__("Description"),
                    type: "text",
                },
                {
                    name: "ean",
                    label: $__("EAN"),
                    type: "text",
                },
                {
                    name: "id_code_qualifier",
                    label: $__("Qualifier"),
                    type: "select",
                    selectLabel: "description",
                    requiredKey: "code",
                    options: [
                        {
                            code: "14",
                            description: $__("EAN International (14)"),
                        },
                        {
                            code: "31B",
                            description: $__("US SAN Agency (31B)"),
                        },
                        {
                            code: "91",
                            description: $__("Assigned by supplier (91)"),
                        },
                        {
                            code: "92",
                            description: $__("Assigned by buyer (92)"),
                        },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(opt => opt.code === val);
                        return opt ? opt.description : val;
                    },
                },
            ],
        });

        const tableOptions = {
            options: {
                embed: "library",
            },
            url: baseResource.getResourceTableUrl(),
            table_settings: null,
            add_filters: false,
            actions: {
                "-1": [
                    ...(baseResource.isUserPermitted("edi_manage")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("edi_manage")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const onFormSave = (e, accountToSave) => {
            e.preventDefault();

            const account = JSON.parse(JSON.stringify(accountToSave));
            const edi_ean_account_id = account.edi_ean_account_id;

            delete account.edi_ean_account_id;
            delete account.library;

            if (edi_ean_account_id) {
                return baseResource.apiClient
                    .update(account, edi_ean_account_id)
                    .then(
                        ean => {
                            baseResource.setMessage(
                                $__("Library EAN account updated")
                            );
                            return ean;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(account).then(
                    ean => {
                        baseResource.setMessage(
                            $__("Library EAN account created")
                        );
                        return ean;
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

    emits: ["select-resource"],
    name: "EdiEanAccountResource",
    components: {
        BaseResource,
    },
};
</script>
