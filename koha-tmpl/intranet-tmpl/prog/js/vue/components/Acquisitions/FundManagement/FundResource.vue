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
import { $__ } from "../../../i18n";
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
        const {
            getVisibleGroups,
            getOwners,
            libraryGroups,
            visibleGroups,
            currencies,
        } = storeToRefs(acquisitionsStore);

        const {
            filterGroupsBasedOnOwner,
            filterOwnersBasedOnGroup,
            resetOwnersAndVisibleGroups,
            formatLibraryGroupIds,
            formatValueWithCurrency,
        } = acquisitionsStore;

        const ledgersQuery = ref({});
        const fundGroupsQuery = ref({});
        const getLedgersQuery = computed(() => ledgersQuery.value);
        const getFundGroupsQuery = computed(() => fundGroupsQuery.value);

        const filterLibGroupsAndFundGroupsBySelectedLedger = (
            e,
            options,
            resource
        ) => {
            const selectedLedger = options.find(
                ledger => ledger.ledger_id === e
            );
            if (selectedLedger) {
                const applicableGroups = formatLibraryGroupIds(
                    selectedLedger.lib_group_visibility
                );
                visibleGroups.value = applicableGroups;
                resetOwnersAndVisibleGroups(applicableGroups);

                fundGroupsQuery.value = {
                    currency: selectedLedger.currency,
                    lib_group_visibility: applicableGroups,
                };
            }
        };

        const filterLedgersBySelectedFiscalPeriod = (e, options, resource) => {
            if (!e) {
                ledgersQuery.value = {};
                resource.ledger_id = null;
                resource.lib_group_visibility = [];
                return;
            }

            const chosenFP = options.find(fp => fp.fiscal_period_id === e);

            const { ledgers } = chosenFP;
            if (!ledgers || ledgers.length === 0) {
                setWarning(
                    $__(
                        "There are no ledgers attached to this fiscal period. Please create one or select a different fiscal period."
                    )
                );
                resource.fiscal_period_id = null;
                return;
            }
            ledgersQuery.value = { fiscal_period_id: e };

            if (e !== resource.fiscal_period_id) {
                resource.ledger_id = null;
                resource.lib_group_visibility = [];
            }
        };

        const baseResource = useBaseResource({
            resourceName: "fund",
            nameAttr: "name",
            idAttr: "fund_id",
            showComponent: "FundShow",
            listComponent: "FundList",
            addComponent: "FundFormAdd",
            editComponent: "FundFormAddEdit",
            apiClient: APIClient.acquisition.funds,
            resourceTableUrl: APIClient.acquisition._baseURL + "funds",
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this fund?"
                ),
                deleteSuccessMessage: $__("Fund %s deleted"),
                displayName: $__("Fund"),
                editLabel: $__("Edit fund #%s"),
                emptyListMessage: $__("There are no funds defined"),
                newLabel: $__("New fund"),
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "fund_id",
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
                    name: "fiscal_period_id",
                    required: true,
                    type: "relationshipSelect",
                    label: $__("Fiscal period"),
                    relationshipAPIClient: APIClient.acquisition.fiscalPeriods,
                    relationshipOptionLabelAttr: "code",
                    relationshipRequiredKey: "fiscal_period_id",
                    onSelected: filterLedgersBySelectedFiscalPeriod,
                    hideIn: ["List"],
                },
                {
                    name: "ledger_id",
                    required: true,
                    type: "relationshipSelect",
                    label: $__("Ledger"),
                    relationshipAPIClient: APIClient.acquisition.ledgers,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "ledger_id",
                    onSelected: filterLibGroupsAndFundGroupsBySelectedLedger,
                    query: getLedgersQuery,
                    disabled: resource => !resource.fiscal_period_id,
                    hideIn: ["List"],
                },
                {
                    name: "fund_group_id",
                    type: "relationshipSelect",
                    label: $__("Fund group"),
                    relationshipAPIClient: APIClient.acquisition.fundGroups,
                    relationshipOptionLabelAttr: "title",
                    relationshipRequiredKey: "fund_group_id",
                    onSelected: filterLibGroupsAndFundGroupsBySelectedLedger,
                    query: getFundGroupsQuery,
                    disabled: resource => !resource.ledger_id,
                    hideIn: ["List"],
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
                const id = baseResource.route.params.ledger_id;
                const query = {
                    "me.ledger_id": id,
                };
                return "/api/v1/acquisitions/funds?q=" + JSON.stringify(query);
            }
            return "/api/v1/acquisitions/funds";
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
                        ...(baseResource.isUserPermitted("editFund")
                            ? ["edit"]
                            : []),
                        ...(baseResource.isUserPermitted("deleteFund")
                            ? ["delete"]
                            : []),
                    ],
                },
            }),
        };

        const onSubmit = (e, fundToSave) => {
            e.preventDefault();

            if (!baseResource.isUserPermitted("createFund")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create funds."
                    )
                );
                return;
            }

            const fund = JSON.parse(JSON.stringify(fundToSave));
            const fund_id = fund.fund_id;

            const oe_warning_percent = fund.oe_warning_percent;
            fund.oe_warning_percent = oe_warning_percent / 100;

            delete fund.fund_id;
            delete fund.last_updated;

            if (fund_id) {
                const acq_client = APIClient.acquisition;
                acq_client.funds.update(fund, fund_id).then(
                    success => {
                        baseResource.setMessage($__("Fund updated"));
                        baseResource.router.push({ name: "FundList" });
                    },
                    error => {}
                );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client.funds.create(fund).then(
                    success => {
                        baseResource.setMessage($__("Fund created"));
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
                filterGroupsBySelectedFiscalPeriod(
                    resource.fiscal_period_id,
                    componentData.instancedResource.libraryGroups,
                    componentData.resource.value
                );
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
    name: "FiscalPeriodResource",
};
</script>
