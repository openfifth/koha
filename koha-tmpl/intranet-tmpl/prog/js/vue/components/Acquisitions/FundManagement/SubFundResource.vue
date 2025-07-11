<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>

<script>
import BaseResource from "../../BaseResource.vue";
import { APIClient } from "../../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";
import { useBaseResource } from "../../../composables/base-resource";
import { computed, inject, onUnmounted, ref } from "vue";
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
        const { getVisibleGroups, libraryGroups, visibleGroups } =
            storeToRefs(acquisitionsStore);

        const {
            resetOwnersAndVisibleGroups,
            formatLibraryGroupIds,
            formatValueWithCurrency,
        } = acquisitionsStore;

        const baseResource = useBaseResource({
            resourceName: "sub_fund",
            nameAttr: "name",
            idAttr: "sub_fund_id",
            showComponent: "SubFundShow",
            listComponent: "SubFundList",
            addComponent: "SubFundFormAdd",
            editComponent: "SubFundFormAddEdit",
            apiClient: APIClient.acquisition.subFunds,
            resourceTableUrl: APIClient.acquisition._baseURL + "sub_funds",
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this sub fund?"
                ),
                deleteSuccessMessage: $__("Sub fund %s deleted"),
                displayName: $__("Sub fund"),
                editLabel: $__("Edit sub fund #%s"),
                emptyListMessage: $__("There are no sub funds defined"),
                newLabel: $__("New sub fund"),
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "sub_fund_id",
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
                    name: "description",
                    type: "textarea",
                    label: $__("Description"),
                    required: true,
                },
                {
                    name: "code",
                    required: true,
                    type: "text",
                    label: $__("Code"),
                },
                {
                    name: "fund_type",
                    type: "select",
                    label: $__("Fund type"),
                    avCat: "av_fund_type",
                    fallbackType: "text",
                },
                {
                    name: "status",
                    type: "boolean",
                    label: $__("Active"),
                    defaultValue: true,
                },
                {
                    name: "external_id",
                    type: "text",
                    label: $__("External ID"),
                    hideIn: ["List"],
                },
                {
                    name: "spend_limit",
                    type: "number",
                    label: $__("Spend limit"),
                    defaultValue: 0,
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    hideIn: ["List"],
                },
                {
                    name: "lib_group_visibility",
                    selectLabel: "title",
                    type: "select",
                    label: $__("Visible to"),
                    options: getVisibleGroups.value,
                    required: true,
                    hideIn: [
                        "List",
                        ...(!libraryGroups.value ? ["Form", "Show"] : []),
                    ],
                    allowMultipleChoices: true,
                },
                {
                    name: "over_spend_allowed",
                    type: "boolean",
                    label: $__("Overspend allowed"),
                    hideIn: ["List"],
                },
                {
                    name: "oe_warning_percent",
                    type: "number",
                    label: $__("Overencumbrance warning percentage"),
                    placeholder: $__(
                        "The percentage at which a warning is triggered"
                    ),
                    size: 6,
                    format: v => v + "%",
                    hideIn: ["List"],
                },
                {
                    name: "oe_limit_amount",
                    type: "number",
                    label: $__("Overencumbrance limit amount"),
                    placeholder: $__(
                        "The amount at which a block is triggered"
                    ),
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    hideIn: ["List"],
                },
                {
                    name: "os_warning_sum",
                    type: "number",
                    label: $__("Overspend warning sum"),
                    placeholder: $__(
                        "The amount at which a warning is triggered"
                    ),
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    hideIn: ["List"],
                },
                {
                    name: "os_limit_sum",
                    type: "number",
                    label: $__("Overspend limit sum"),
                    placeholder: $__(
                        "The amount at which a block is triggered"
                    ),
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    hideIn: ["List"],
                },
            ],
            libraryGroups: libraryGroups.value,
        });

        const tableURL = () => {
            if (props.embedded) {
                const id = baseResource.route.params.fund_id;
                const query = {
                    "me.fund_id": id,
                };
                return (
                    "/api/v1/acquisitions/sub_funds?q=" + JSON.stringify(query)
                );
            }
            return "/api/v1/acquisitions/sub_funds";
        };

        const tableOptions = {
            url: tableURL(),
            table_settings: null,
            add_filters: true,
            options: { embed: "fund_allocations" },
            add_filters: true,
            ...(!props.embedded && {
                actions: {
                    0: ["show"],
                    "-1": [
                        ...(baseResource.isUserPermitted("editSubFund")
                            ? ["edit"]
                            : []),
                        ...(baseResource.isUserPermitted("deleteSubFund")
                            ? ["delete"]
                            : []),
                    ],
                },
            }),
        };

        const onSubmit = (e, subFundToSave) => {
            e.preventDefault();

            if (!baseResource.isUserPermitted("createSubFund")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create sub funds."
                    )
                );
                return;
            }

            const sub_fund = JSON.parse(JSON.stringify(subFundToSave));
            const sub_fund_id = sub_fund.sub_fund_id;

            const oe_warning_percent = sub_fund.oe_warning_percent;
            sub_fund.oe_warning_percent = oe_warning_percent / 100;

            delete sub_fund.sub_fund_id;
            delete sub_fund.last_updated;

            if (sub_fund_id) {
                const acq_client = APIClient.acquisition;
                acq_client.subFunds.update(sub_fund, sub_fund_id).then(
                    success => {
                        baseResource.setMessage($__("Sub fund updated"));
                        baseResource.router.push({ name: "FundList" });
                    },
                    error => {}
                );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client.subFunds.create(sub_fund).then(
                    success => {
                        baseResource.setMessage($__("Sub fund created"));
                        baseResource.router.push({ name: "FundList" });
                    },
                    error => {}
                );
            }
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            componentData.resource.value.oe_warning_percent =
                resource.oe_warning_percent * 100;
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
            fundGroupsQuery,
            ledgersQuery,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "SubFundResource",
};
</script>
