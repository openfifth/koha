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
import { computed, inject, ref } from "vue";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
        route: Object,
    },
    setup(props) {
        const isSubFund = ref(props.route.query.fund_id ? true : false);

        const patron_to_html = $patron_to_html;

        const acquisitionsStore = inject("acquisitionsStore");
        const { formatValueWithCurrency } = acquisitionsStore;

        const ledgersQuery = ref({});
        const fundsQuery = ref({});
        const fundGroupsQuery = ref({});
        const getLedgersQuery = computed(() => ledgersQuery.value);
        const getFundsQuery = computed(() => fundsQuery.value);
        const getFundGroupsQuery = computed(() => fundGroupsQuery.value);

        const filterLibGroupsAndFundGroupsBySelectedLedger = (
            e,
            options,
            resource
        ) => {
            if (!e && resource.ledger_id) {
                fundGroupsQuery.value = {
                    currency: resource.currency,
                };
                fundsQuery.value = {
                    ledger_id: resource.ledger_id,
                };
                return;
            }
            const selectedLedger = options.find(
                ledger => ledger.ledger_id === e
            );
            if (selectedLedger) {
                fundGroupsQuery.value = {
                    currency: selectedLedger.currency,
                };
                fundsQuery.value = {
                    ledger_id: e,
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
                return;
            }
            ledgersQuery.value = { fiscal_period_id: e };

            if (e !== resource.fiscal_period_id) {
                resource.ledger_id = null;
            }
        };

        const defaultToolbarButtons = (defaultButtons, resource, router) => {
            return {
                list: defaultButtons.list,
                show: !resource.sub_funds?.length
                    ? defaultButtons.show
                    : defaultButtons.show.filter(
                          button => button.action !== "delete"
                      ),
            };
        };

        const additionalToolbarButtons = resource => {
            return {
                show: [
                    ...(!isSubFund.value
                        ? [
                              {
                                  to: {
                                      name: "FundFormAdd",
                                      query: { fund_id: resource.fund_id },
                                  },
                                  icon: "plus",
                                  title: $__("Add sub fund"),
                              },
                          ]
                        : []),
                    {
                        to: {
                            name: "TransferFunds",
                            query: {
                                fund_id: resource.fund_id,
                                ...(isSubFund.value && {
                                    fund_parent_id: resource.fund_parent_id,
                                }),
                            },
                        },
                        icon: "arrow-right-arrow-left",
                        title: $__("Transfer funds"),
                    },
                ],
            };
        };

        const baseResource = useBaseResource({
            resourceName: "fund",
            nameAttr: "name",
            idAttr: "fund_id",
            components: {
                show: "FundShow",
                list: "FundList",
                add: "FundFormAdd",
                edit: "FundFormAddEdit",
            },
            apiClient: APIClient.acquisition.funds,
            table: {
                resourceTableUrl: APIClient.acquisition._baseURL + "funds",
            },
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
            defaultToolbarButtons,
            additionalToolbarButtons,
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
                              query: { "ledgers.ledger_id": { "!=": null } },
                              showElement: {
                                  type: "text",
                                  value: "fiscal_period.code",
                                  link: {
                                      name: "FiscalPeriodShow",
                                      params: {
                                          fiscal_period_id: "fiscal_period_id",
                                      },
                                  },
                              },
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
                              showElement: {
                                  type: "text",
                                  value: "ledger.name",
                                  link: {
                                      name: "LedgerShow",
                                      params: {
                                          ledger_id: "ledger_id",
                                      },
                                  },
                              },
                              hideIn: ["List"],
                          },
                      ]
                    : []),
                ...(!isSubFund.value || props.routeAction === "list"
                    ? [
                          {
                              name: "fund_parent_id",
                              type: "relationshipSelect",
                              label: $__("Parent fund"),
                              relationshipAPIClient:
                                  APIClient.acquisition.funds,
                              relationshipOptionLabelAttr: "name",
                              relationshipRequiredKey: "fund_id",
                              query: getFundsQuery,
                              disabled: resource => !resource.fiscal_period_id,
                              showElement: {
                                  type: "text",
                                  value: "parent_fund.name",
                                  link: {
                                      name: "FundShow",
                                      params: {
                                          fund_id: "fund_parent_id",
                                      },
                                  },
                              },
                              tableColumnDefinition: {
                                  title: $__("Parent fund"),
                                  data: "parent_fund.name",
                                  searchable: true,
                                  orderable: true,
                                  render(data, type, row, meta) {
                                      return row.parent_fund
                                          ? '<a href="/cgi-bin/koha/acquisitions/fund_management/fund' +
                                                row.parent_fund.fund_id +
                                                '" class="show">' +
                                                escape_str(
                                                    row.parent_fund.name
                                                ) +
                                                "</a>"
                                          : "";
                                  },
                              },
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
                              relationshipOptionLabelAttr: "name",
                              relationshipRequiredKey: "fund_group_id",
                              onSelected:
                                  filterLibGroupsAndFundGroupsBySelectedLedger,
                              query: getFundGroupsQuery,
                              disabled: resource => !resource.ledger_id,
                              showElement: {
                                  type: "text",
                                  value: "fund_group.name",
                                  link: {
                                      name: "FundGroupShow",
                                      params: {
                                          fund_group_id: "fund_group_id",
                                      },
                                  },
                              },
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
                {
                    name: "managing_branch",
                    type: "relationshipSelect",
                    label: $__("Managing library"),
                    relationshipAPIClient: APIClient.libraries.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    showElement: {
                        type: "text",
                        value: "managing_library.name",
                        link: {
                            href: "/cgi-bin/koha/admin/branches.pl",
                            params: {
                                op: "view",
                                branchcode: "managing_branch",
                            },
                        },
                    },
                    hideIn: ["List"],
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
        });

        const tableURL = () => {
            if (props.embedded) {
                const id = isSubFund.value
                    ? baseResource.route.params.fund_parent_id
                    : baseResource.route.params.ledger_id;
                const query = {};
                query[
                    "me." + (isSubFund.value ? "fund_parent_id" : "ledger_id")
                ] = id;
                return `/api/v1/acquisitions/funds?q=` + JSON.stringify(query);
            }
            return `/api/v1/acquisitions/funds`;
        };

        const tableOptions = {
            url: tableURL(),
            table_settings: null,
            add_filters: true,
            options: { embed: "sub_funds,fund_allocations,parent_fund" },
            add_filters: true,
            ...(!props.embedded && {
                actions: {
                    0: ["show"],
                    "-1": [
                        ...(baseResource.isUserPermitted("editFund")
                            ? ["edit"]
                            : []),
                        ...(baseResource.isUserPermitted("deleteFund")
                            ? [
                                  {
                                      delete: {
                                          text: $__("Delete"),
                                          icon: "fa fa-trash",
                                          should_display: row =>
                                              row.sub_funds.length == 0,
                                      },
                                  },
                              ]
                            : []),
                    ],
                },
            }),
        };

        const onFormSave = (e, fundToSave) => {
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

            if (!isSubFund.value) {
                delete fund.fund_id;
            } else {
                delete fund.fund_id;
                fund.fund_parent_id =
                    baseResource.route.query.fund_id || fund.fund_id;
            }
            delete fund.last_updated;
            delete fund.owner;
            delete fund.fund_allocations;
            delete fund.ledger;
            delete fund.fund_group;
            delete fund.fiscal_period;
            delete fund.sub_funds;
            delete fund.managing_library;

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

        const appendToShow = componentData => {
            const { resource } = componentData;
            let formatValueWithCurrencyHandler = formatValueWithCurrency;
            return [
                ...(resource.fund_allocations?.length
                    ? [
                          {
                              type: "component",
                              name: $__("Allocations"),
                              hidden: fund => fund.fund_id,
                              componentPath:
                                  "@koha-vue/components/RelationshipTableDisplay.vue",
                              componentProps: {
                                  tableOptions: {
                                      type: "object",
                                      value: {
                                          columns: [
                                              {
                                                  title: __("Date"),
                                                  data: "last_updated",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return row.last_updated.substring(
                                                          0,
                                                          10
                                                      );
                                                  },
                                              },
                                              {
                                                  title: __("Amount"),
                                                  data: "allocation_amount",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      const symbol =
                                                          row.allocation_amount >=
                                                          0
                                                              ? "+"
                                                              : "";
                                                      const colour =
                                                          row.allocation_amount >=
                                                          0
                                                              ? "green"
                                                              : "red";
                                                      return (
                                                          '<span style="color:' +
                                                          colour +
                                                          ';">' +
                                                          symbol +
                                                          row.allocation_amount +
                                                          "</span>"
                                                      );
                                                  },
                                              },
                                              {
                                                  title: __("New fund total"),
                                                  data: "new_fund_value",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return formatValueWithCurrencyHandler(
                                                          row.new_fund_value,
                                                          row.currency
                                                      );
                                                  },
                                              },
                                              {
                                                  title: __("Reference"),
                                                  data: "reference",
                                                  searchable: true,
                                                  orderable: true,
                                              },
                                              {
                                                  title: __("Note"),
                                                  data: "note",
                                                  searchable: true,
                                                  orderable: true,
                                              },
                                          ],
                                          url:
                                              APIClient.acquisition.httpClient
                                                  ._baseURL +
                                              "fund_allocations",
                                          table_settings: null,
                                          add_filters: true,
                                          actions: {
                                              0: ["show"],
                                          },
                                      },
                                  },
                                  apiClient: {
                                      type: "object",
                                      value: APIClient.acquisition
                                          .fundAllocations,
                                  },
                                  filters: {
                                      type: "filter",
                                      keys: {
                                          fund_id: {
                                              property: "fund_id",
                                          },
                                      },
                                  },
                              },
                              resource: {
                                  type: "resource",
                              },
                              resourceName: {
                                  type: "string",
                                  value: "allocation",
                              },
                              resourceNamePlural: {
                                  type: "string",
                                  value: "allocations",
                              },
                          },
                      ]
                    : []),
                ...(resource.sub_funds?.length
                    ? [
                          {
                              type: "component",
                              name: $__("Sub funds"),
                              hidden: fund => fund.fund_id,
                              componentPath:
                                  "@koha-vue/components/RelationshipTableDisplay.vue",
                              componentProps: {
                                  tableOptions: {
                                      type: "object",
                                      value: {
                                          columns: [
                                              {
                                                  title: __("Name"),
                                                  data: "name:fund_id",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return (
                                                          '<a href="/cgi-bin/koha/acquisitions/fund_management/fund/' +
                                                          row.fund_id +
                                                          '" class="showFund">' +
                                                          escape_str(
                                                              `${row.name}`
                                                          ) +
                                                          "</a>"
                                                      );
                                                  },
                                              },
                                              {
                                                  title: __("Code"),
                                                  data: "code",
                                                  searchable: true,
                                                  orderable: true,
                                              },
                                              {
                                                  title: __("Status"),
                                                  data: "status",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return row.status
                                                          ? __("Active")
                                                          : __("Inactive");
                                                  },
                                              },
                                              {
                                                  title: __("Fund value"),
                                                  data: "fund_value",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return formatValueWithCurrency(
                                                          row.fund_value,
                                                          row.currency
                                                      );
                                                  },
                                              },
                                          ],
                                          url:
                                              APIClient.acquisition.httpClient
                                                  ._baseURL + "funds",
                                          table_settings: null,
                                          add_filters: true,
                                          actions: {
                                              0: [
                                                  {
                                                      showFund: {
                                                          callback: (
                                                              fund,
                                                              dt,
                                                              event
                                                          ) => {
                                                              event?.preventDefault();
                                                              baseResource.router.push(
                                                                  {
                                                                      name: "FundShow",
                                                                      params: {
                                                                          fund_id:
                                                                              fund.fund_id,
                                                                      },
                                                                  }
                                                              );
                                                          },
                                                      },
                                                  },
                                              ],
                                          },
                                      },
                                  },
                                  apiClient: {
                                      type: "object",
                                      value: APIClient.acquisition.funds,
                                  },
                                  filters: {
                                      type: "filter",
                                      keys: {
                                          fund_parent_id: {
                                              property: "fund_id",
                                          },
                                      },
                                  },
                                  resource: {
                                      type: "resource",
                                  },
                                  resourceName: {
                                      type: "string",
                                      value: "sub fund",
                                  },
                                  resourceNamePlural: {
                                      type: "string",
                                      value: "sub funds",
                                  },
                              },
                          },
                      ]
                    : []),
            ];
        };

        const afterNewResourceCreate = (resource, componentData) => {
            if (componentData.route.query.fund_id) {
                resource.fund_parent_id = parseInt(
                    componentData.route.query.fund_id
                );
            }
            if (componentData.route.query.ledger_id) {
                resource.ledger_id = parseInt(
                    componentData.route.query.ledger_id
                );
                resource.fiscal_period_id = parseInt(
                    componentData.route.query.fiscal_period_id
                );
            }
            return resource;
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            afterResourceFetch,
            fundGroupsQuery,
            ledgersQuery,
            isSubFund,
            appendToShow,
            afterNewResourceCreate,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "FundResource",
};
</script>
