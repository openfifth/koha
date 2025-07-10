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
        route: Object,
    },
    setup(props) {
        const isSubFund = ref(
            props.route.path.includes("sub_fund") ? true : false
        );

        const patron_to_html = $patron_to_html;

        const acquisitionsStore = inject("acquisitionsStore");
        const { getVisibleGroups, libraryGroups, visibleGroups } =
            storeToRefs(acquisitionsStore);

        const {
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
            if (!e && resource.ledger_id) {
                fundGroupsQuery.value = {
                    currency: resource.currency,
                    lib_group_visibility: resource.lib_group_visibility,
                };
                const applicableGroups = formatLibraryGroupIds(
                    resource.ledger.lib_group_visibility
                );
                visibleGroups.value = applicableGroups;
                resetOwnersAndVisibleGroups(applicableGroups);
                return;
            }
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
            if (!e && resource.fiscal_period_id) {
                ledgersQuery.value = {
                    fiscal_period_id: resource.fiscal_period_id,
                };
                return;
            }
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

        const additionalToolbarButtons = resource => {
            return {
                ...(isSubFund.value && {
                    show: [
                        {
                            to: { name: "SubFundFormAdd" },
                            icon: "plus",
                            title: $__("Add sub fund"),
                        },
                    ],
                }),
            };
        };

        const baseResource = useBaseResource({
            resourceName: isSubFund.value ? "sub_fund" : "fund",
            nameAttr: "name",
            idAttr: isSubFund.value ? "sub_fund_id" : "fund_id",
            showComponent: isSubFund.value ? "SubFundShow" : "FundShow",
            listComponent: "FundList",
            addComponent: isSubFund.value ? "SubFundFormAdd" : "FundFormAdd",
            editComponent: isSubFund.value
                ? "SubFundFormAddEdit"
                : "FundFormAddEdit",
            apiClient: isSubFund.value
                ? APIClient.acquisition.subFunds
                : APIClient.acquisition.funds,
            resourceTableUrl:
                APIClient.acquisition._baseURL + isSubFund.value
                    ? "sub_funds"
                    : "funds",
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this fund?"
                ),
                deleteSuccessMessage: $__("Fund %s deleted"),
                displayName: $__("Fund"),
                editLabel: $__("Edit fund #%s"),
                emptyListMessage: $__("There are no funds defined"),
                newLabel: isSubFund.value
                    ? $__("New sub fund")
                    : $__("New fund"),
            },
            moduleStore: "acquisitionsStore",
            props,
            additionalToolbarButtons,
            resourceAttrs: [
                ...(isSubFund.value
                    ? [
                          {
                              name: "sub_fund_id",
                              label: $__("ID"),
                              type: "text",
                              hideIn: ["Form", "Show"],
                          },
                      ]
                    : [
                          {
                              name: "fund_id",
                              label: $__("ID"),
                              type: "text",
                              hideIn: ["Form", "Show"],
                          },
                      ]),
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
                ...(!isSubFund.value
                    ? [
                          {
                              name: "fiscal_period_id",
                              required: true,
                              type: "relationshipSelect",
                              label: $__("Fiscal period"),
                              relationshipAPIClient:
                                  APIClient.acquisition.fiscalPeriods,
                              relationshipOptionLabelAttr: "code",
                              relationshipRequiredKey: "fiscal_period_id",
                              onSelected: filterLedgersBySelectedFiscalPeriod,
                              hideIn: ["List"],
                          },
                      ]
                    : []),
                ...(!isSubFund.value
                    ? [
                          {
                              name: "ledger_id",
                              required: true,
                              type: "relationshipSelect",
                              label: $__("Ledger"),
                              relationshipAPIClient:
                                  APIClient.acquisition.ledgers,
                              relationshipOptionLabelAttr: "name",
                              relationshipRequiredKey: "ledger_id",
                              onSelected:
                                  filterLibGroupsAndFundGroupsBySelectedLedger,
                              query: getLedgersQuery,
                              disabled: resource => !resource.fiscal_period_id,
                              hideIn: ["List"],
                          },
                      ]
                    : []),
                ...(!isSubFund.value
                    ? [
                          {
                              name: "fund_group_id",
                              type: "relationshipSelect",
                              label: $__("Fund group"),
                              relationshipAPIClient:
                                  APIClient.acquisition.fundGroups,
                              relationshipOptionLabelAttr: "title",
                              relationshipRequiredKey: "fund_group_id",
                              onSelected:
                                  filterLibGroupsAndFundGroupsBySelectedLedger,
                              query: getFundGroupsQuery,
                              disabled: resource => !resource.ledger_id,
                              hideIn: ["List"],
                          },
                      ]
                    : []),
                {
                    name: "owner_id",
                    label: $__("Owner"),
                    showElement: {
                        name: "owner",
                        type: "select",
                        format: patron_to_html,
                    },
                    hideIn: ["List", "Form"],
                },
                ...(isSubFund.value
                    ? []
                    : [
                          {
                              name: "fund_type",
                              type: "select",
                              label: $__("Fund type"),
                              avCat: "av_fund_type",
                              fallbackType: "text",
                          },
                      ]),
                {
                    name: "currency",
                    type: "select",
                    label: $__("Currency"),
                    hideIn: ["List", "Form"],
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
                const id = isSubFund.value
                    ? baseResource.route.params.fund_id
                    : baseResource.route.params.ledger_id;
                const query = {};
                query["me." + (isSubFund.value ? "fund_id" : "ledger_id")] = id;
                return (
                    `/api/v1/acquisitions/${isSubFund.value ? "sub_funds" : "funds"}?q=` +
                    JSON.stringify(query)
                );
            }
            return `/api/v1/acquisitions/${isSubFund.value ? "sub_funds" : "funds"}`;
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
            const fund_id = isSubFund.value ? fund.sub_fund_id : fund.fund_id;

            const oe_warning_percent = fund.oe_warning_percent;
            fund.oe_warning_percent = oe_warning_percent / 100;

            if (!isSubFund.value) {
                delete fund.fund_id;
            } else {
                delete fund.sub_fund_id;
                fund.fund_id = baseResource.route.params.fund_id;
            }
            delete fund.last_updated;

            if (fund_id) {
                const acq_client = APIClient.acquisition;
                acq_client[isSubFund.value ? "subFunds" : "funds"]
                    .update(fund, fund_id)
                    .then(
                        success => {
                            baseResource.setMessage($__("Fund updated"));
                            baseResource.router.push({ name: "FundList" });
                        },
                        error => {}
                    );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client[isSubFund.value ? "subFunds" : "funds"]
                    .create(fund)
                    .then(
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
                filterLedgersBySelectedFiscalPeriod(
                    null,
                    null,
                    componentData.resource.value
                );
                filterLibGroupsAndFundGroupsBySelectedLedger(
                    null,
                    null,
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
            isSubFund,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "FundResource",
};
</script>
