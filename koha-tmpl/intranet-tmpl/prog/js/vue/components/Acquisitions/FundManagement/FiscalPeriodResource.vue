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
        const patron_to_html = $patron_to_html;

        const acquisitionsStore = inject("acquisitionsStore");
        const { getVisibleGroups, getOwners, libraryGroups } =
            storeToRefs(acquisitionsStore);

        const {
            filterGroupsBasedOnOwner,
            filterOwnersBasedOnGroup,
            resetOwnersAndVisibleGroups,
            formatLibraryGroupIds,
        } = acquisitionsStore;

        const baseResource = useBaseResource({
            resourceName: "fiscal_period",
            nameAttr: "code",
            idAttr: "fiscal_period_id",
            showComponent: "FiscalPeriodShow",
            listComponent: "FiscalPeriodList",
            addComponent: "FiscalPeriodFormAdd",
            editComponent: "FiscalPeriodFormAddEdit",
            apiClient: APIClient.acquisition.fiscalPeriods,
            resourceTableUrl: APIClient.acquisition._baseURL + "fiscal_periods",
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this fiscal period?"
                ),
                deleteSuccessMessage: $__("Fiscal period %s deleted"),
                displayName: $__("Fiscal period"),
                editLabel: $__("Edit fiscal period #%s"),
                emptyListMessage: $__("There are no fiscal periods defined"),
                newLabel: $__("New fiscal period"),
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "fiscal_period_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "code",
                    required: true,
                    type: "text",
                    label: $__("Code"),
                },
                {
                    name: "description",
                    type: "textarea",
                    label: $__("Description"),
                    required: true,
                },
                {
                    name: "status",
                    type: "boolean",
                    label: $__("Active"),
                    defaultValue: true,
                },
                {
                    name: "start_date",
                    type: "date",
                    label: $__("Start date"),
                    required: true,
                    componentProps: {
                        required: {
                            type: "boolean",
                            value: true,
                        },
                        date_to: {
                            type: "string",
                            value: "end_date",
                        },
                    },
                },
                {
                    name: "end_date",
                    type: "date",
                    label: $__("End date"),
                    required: false,
                },
                {
                    name: "spend_limit",
                    type: "number",
                    label: $__("Spend limit"),
                    defaultValue: null,
                    size: 6,
                    hideIn: ["List"],
                },
                {
                    name: "owner_id",
                    selectLabel: "displayName",
                    type: "select",
                    requiredKey: "borrowernumber",
                    label: $__("Owner"),
                    options: getOwners.value,
                    required: true,
                    onSelected: filterGroupsBasedOnOwner,
                    showElement: {
                        name: "owner",
                        type: "select",
                        format: patron_to_html,
                    },
                    hideIn: ["List"],
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
            url: "/api/v1/acquisitions/fiscal_periods",
            table_settings: null,
            add_filters: true,
            actions: {
                0: ["show"],
                "-1": [
                    ...(baseResource.isUserPermitted("editFiscalPeriod")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("deleteFiscalPeriod")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const onSubmit = (e, fiscalPeriodToSave) => {
            e.preventDefault();

            if (!baseResource.isUserPermitted("createFiscalPeriods")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create fiscal periods."
                    )
                );
                return;
            }

            const fiscal_period = JSON.parse(
                JSON.stringify(fiscalPeriodToSave)
            );
            const fiscal_period_id = fiscal_period.fiscal_period_id;

            delete fiscal_period.fiscal_period_id;
            delete fiscal_period.last_updated;

            if (fiscal_period_id) {
                const acq_client = APIClient.acquisition;
                acq_client.fiscalPeriods
                    .update(fiscal_period, fiscal_period_id)
                    .then(
                        success => {
                            baseResource.setMessage(
                                $__("Fiscal period updated")
                            );
                            baseResource.router.push({
                                name: "FiscalPeriodList",
                            });
                        },
                        error => {}
                    );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client.fiscalPeriods.create(fiscal_period).then(
                    success => {
                        baseResource.setMessage($__("Fiscal period created"));
                        baseResource.router.push({ name: "FiscalPeriodList" });
                    },
                    error => {}
                );
            }
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            if (caller === "form") {
                componentData.resource.lib_group_visibility =
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
    name: "FiscalPeriodResource",
};
</script>
