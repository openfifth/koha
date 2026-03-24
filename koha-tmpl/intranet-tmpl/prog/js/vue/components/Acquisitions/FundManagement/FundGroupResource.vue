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

        const baseResource = useBaseResource({
            resourceName: "fund_group",
            nameAttr: "name",
            idAttr: "fund_group_id",
            components: {
                show: "FundGroupShow",
                list: "FundGroupList",
                add: "FundGroupFormAdd",
                edit: "FundGroupFormAddEdit",
            },
            apiClient: APIClient.acquisition.fundGroups,
            table: {
                resourceTableUrl:
                    APIClient.acquisition._baseURL + "fund_groups",
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this fund group?"
                ),
                deleteSuccessMessage: $__("Fund group %s deleted"),
                displayName: $__("Fund group"),
                editLabel: $__("Edit fund group #%s"),
                emptyListMessage: $__("There are no fund groups defined"),
                newLabel: $__("New fund group"),
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "fund_group_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "name",
                    required: true,
                    type: "text",
                    label: $__("Name"),
                },
                {
                    name: "currency",
                    type: "select",
                    label: $__("Currency"),
                    selectLabel: "currency",
                    requiredKey: "currency",
                    options: currencies.value,
                    defaultValue: null,
                    required: true,
                },
            ],
        });

        const tableOptions = {
            url: "/api/v1/acquisitions/fund_groups",
            table_settings: null,
            add_filters: true,
            actions: {
                0: ["show"],
                "-1": [
                    ...(baseResource.isUserPermitted("editFundGroup")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("deleteFundGroup")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const onFormSave = (e, fundGroupToSave) => {
            e.preventDefault();

            if (!baseResource.isUserPermitted("createFundGroups")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create fund groups."
                    )
                );
                return;
            }

            const fund_group = JSON.parse(JSON.stringify(fundGroupToSave));
            const fund_group_id = fund_group.fund_group_id;

            delete fund_group.fund_group_id;
            delete fund_group.last_updated;

            if (fund_group_id) {
                return baseResource.apiClient
                    .update(fund_group, fund_group_id)
                    .then(
                        fund_group => {
                            baseResource.setMessage($__("Fund group updated"));
                            return fund_group;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(fund_group).then(
                    fund_group => {
                        baseResource.setMessage($__("Fund group created"));
                        return fund_group;
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
    name: "FundGroupResource",
};
</script>
