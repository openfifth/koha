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
import { inject, onUnmounted } from "vue";
import { storeToRefs } from "pinia";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { getVisibleGroups, libraryGroups, currencies } =
            storeToRefs(acquisitionsStore);

        const {
            filterOwnersBasedOnGroup,
            resetOwnersAndVisibleGroups,
            formatLibraryGroupIds,
        } = acquisitionsStore;

        const baseResource = useBaseResource({
            resourceName: "fund_group",
            nameAttr: "name",
            idAttr: "fund_group_id",
            showComponent: "FundGroupShow",
            listComponent: "FundGroupList",
            addComponent: "FundGroupFormAdd",
            editComponent: "FundGroupFormAddEdit",
            apiClient: APIClient.acquisition.fundGroups,
            resourceTableUrl: APIClient.acquisition._baseURL + "fund_groups",
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
                {
                    name: "lib_group_visibility",
                    requiredKey: "id",
                    selectLabel: "title",
                    type: "select",
                    label: $__("Visible to"),
                    options: getVisibleGroups.value,
                    required: true,
                    onSelected: filterOwnersBasedOnGroup,
                    hideIn: [
                        "List",
                        ...(!libraryGroups.value ? ["Form", "Show"] : []),
                    ],
                    showElement: {
                        type: "table",
                        columnData: "lib_group_limits",
                        columns: [
                            { name: $__("ID"), value: "id" },
                            { name: $__("Title"), value: "title" },
                        ],
                        hidden: resource => resource.lib_group_limits.length,
                    },
                    allowMultipleChoices: true,
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

        const onSubmit = (e, fundGroupToSave) => {
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
                const acq_client = APIClient.acquisition;
                acq_client.fundGroups.update(fund_group, fund_group_id).then(
                    success => {
                        baseResource.setMessage($__("Fund group updated"));
                        baseResource.router.push({
                            name: "FundGroupList",
                        });
                    },
                    error => {}
                );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client.fundGroups.create(fund_group).then(
                    success => {
                        baseResource.setMessage($__("Fund group created"));
                        baseResource.router.push({ name: "FundGroupList" });
                    },
                    error => {}
                );
            }
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            if (caller === "form") {
                componentData.resource.value.lib_group_visibility =
                    formatLibraryGroupIds(resource.lib_group_visibility);
            }
        };

        onUnmounted(() => {
            resetOwnersAndVisibleGroups();
        });

        return {
            ...baseResource,
            tableOptions,
            onSubmit,
            afterResourceFetch,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "FundGroupResource",
};
</script>
