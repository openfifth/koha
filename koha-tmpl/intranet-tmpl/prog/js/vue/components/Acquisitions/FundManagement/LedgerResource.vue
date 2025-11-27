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
        const patron_to_html = $patron_to_html;

        const acquisitionsStore = inject("acquisitionsStore");
        const { currencies } = storeToRefs(acquisitionsStore);

        const { formatValueWithCurrency } = acquisitionsStore;

        const additionalToolbarButtons = (resource, componentData) => {
            const { instancedResource } = componentData;
            return {
                show: [
                    {
                        to: {
                            name: "FundFormAdd",
                            query: {
                                ledger_id: resource.ledger_id,
                                fiscal_period_id: resource.fiscal_period_id,
                            },
                        },
                        title: $__("Add fund"),
                        icon: "plus",
                        index: -1,
                    },
                ],
            };
        };

        const baseResource = useBaseResource({
            resourceName: "ledger",
            nameAttr: "name",
            idAttr: "ledger_id",
            components: {
                show: "LedgerShow",
                list: "LedgerList",
                add: "LedgerFormAdd",
                edit: "LedgerFormAddEdit",
            },
            apiClient: APIClient.acquisition.ledgers,
            table: {
                resourceTableUrl: APIClient.acquisition._baseURL + "ledgers",
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this ledger?"
                ),
                deleteSuccessMessage: $__("Ledger %s deleted"),
                displayName: $__("Ledger"),
                editLabel: $__("Edit ledger #%s"),
                emptyListMessage: $__("There are no ledgers defined"),
                newLabel: $__("New ledger"),
            },
            moduleStore: "acquisitionsStore",
            props,
            additionalToolbarButtons,
            resourceAttrs: [
                {
                    name: "ledger_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "name",
                    required: true,
                    type: "text",
                    label: $__("Name"),
                    group: $__("Information and status"),
                },
                {
                    name: "code",
                    required: true,
                    type: "text",
                    label: $__("Code"),
                    group: $__("Information and status"),
                },
                {
                    name: "description",
                    type: "textarea",
                    label: $__("Description"),
                    group: $__("Information and status"),
                    required: true,
                },
                {
                    name: "fiscal_period_id",
                    type: "relationshipSelect",
                    label: $__("Fiscal period"),
                    group: $__("Information and status"),
                    relationshipAPIClient: APIClient.acquisition.fiscalPeriods,
                    relationshipOptionLabelAttr: "code",
                    relationshipRequiredKey: "fiscal_period_id",
                    disabled: true,
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
                {
                    name: "status",
                    type: "boolean",
                    label: $__("Active"),
                    group: $__("Information and status"),
                    defaultValue: true,
                },
                {
                    name: "external_id",
                    type: "text",
                    label: $__("External ID"),
                    group: $__("Information and status"),
                    hideIn: ["List"],
                },
                {
                    name: "currency",
                    type: "select",
                    label: $__("Currency"),
                    group: $__("Financial controlling"),
                    selectLabel: "currency",
                    requiredKey: "currency",
                    options: currencies.value,
                    defaultValue: null,
                    required: true,
                    hideIn: ["List"],
                },
                {
                    name: "spend_limit",
                    type: "number",
                    label: $__("Spend limit"),
                    group: $__("Financial controlling"),
                    defaultValue: 0,
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    hideIn: ["List"],
                },
                {
                    name: "owner_id",
                    type: "component",
                    label: $__("Owner"),
                    group: $__("Management in library"),
                    componentPath: "@koha-vue/components/PatronSearch.vue",
                    required: true,
                    componentProps: {
                        name: {
                            type: "string",
                            value: "owner_id",
                        },
                        required: {
                            type: "boolean",
                            value: true,
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        label: {
                            type: "string",
                            value: $__("Owner"),
                        },
                        additionalFilters: {
                            type: "object",
                            value: {
                                permission: "acquisition.budget_manage",
                            },
                        },
                        fieldName: {
                            type: "string",
                            value: "owner",
                        },
                        filteredUrl: {
                            type: "string",
                            value: "/api/v1/acquisitions/fund_management/users",
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "owner",
                        format: patron_to_html,
                    },
                    hideIn: ["List"],
                },
                {
                    name: "managing_branch",
                    label: $__("Managing library"),
                    group: $__("Management in library"),
                    type: "component",
                    componentPath: "@koha-vue/components/ManagingLibrary.vue",
                    componentProps: {
                        relationshipAPIClient: {
                            type: "object",
                            value: APIClient.libraries.libraries,
                        },
                        relationshipOptionLabelAttr: {
                            type: "string",
                            value: "name",
                        },
                        relationshipRequiredKey: {
                            type: "string",
                            value: "library_id",
                        },
                        name: {
                            type: "string",
                            value: "managing_branch",
                        },
                        resource: {
                            type: "resource",
                        },
                        routeAction: {
                            type: "string",
                            value: props.routeAction,
                        },
                        linkData: {
                            type: "object",
                            value: {
                                href: "/cgi-bin/koha/admin/branches.pl",
                                params: {
                                    op: "view",
                                    branchcode: "managing_branch",
                                },
                            },
                        },
                    },
                    hideIn: ["List"],
                },
                {
                    name: "over_spend_allowed",
                    type: "boolean",
                    label: $__("Overspend allowed"),
                    group: $__("Financial controlling"),
                    hideIn: ["List"],
                },
                {
                    name: "oe_warning_percent",
                    type: "number",
                    label: $__("Overencumbrance warning percentage"),
                    group: $__("Financial controlling"),
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
                    group: $__("Financial controlling"),
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
                    label: $__("Overspend warning amount"),
                    group: $__("Financial controlling"),
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
                    group: $__("Financial controlling"),
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
                const id = baseResource.route.params.fiscal_period_id;
                const query = {
                    "me.fiscal_period_id": id,
                };
                return (
                    "/api/v1/acquisitions/ledgers?q=" + JSON.stringify(query)
                );
            }
            return "/api/v1/acquisitions/ledgers";
        };

        const tableOptions = {
            url: tableURL(),
            table_settings: null,
            add_filters: true,
            options: { embed: "funds" },
            add_filters: true,
            ...(!props.embedded && {
                actions: {
                    0: ["show"],
                    "-1": [
                        ...(baseResource.isUserPermitted("editLedger")
                            ? ["edit"]
                            : []),
                        ...(baseResource.isUserPermitted("deleteLedger")
                            ? ["delete"]
                            : []),
                    ],
                },
            }),
        };

        const onFormSave = (e, ledgerToSave) => {
            e.preventDefault();

            if (!baseResource.isUserPermitted("createLedger")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create ledgers."
                    )
                );
                return;
            }

            const ledger = JSON.parse(JSON.stringify(ledgerToSave));
            const ledger_id = ledger.ledger_id;

            const oe_warning_percent = ledger.oe_warning_percent;
            ledger.oe_warning_percent = oe_warning_percent / 100;

            delete ledger.ledger_id;
            delete ledger.last_updated;
            delete ledger.patron;
            delete ledger.patron_str;
            delete ledger.owner;
            delete ledger.fiscal_period;
            delete ledger.managing_library;

            if (ledger_id) {
                const acq_client = APIClient.acquisition;
                acq_client.ledgers.update(ledger, ledger_id).then(
                    success => {
                        baseResource.setMessage($__("Ledger updated"));
                        baseResource.router.push({ name: "LedgerList" });
                    },
                    error => {}
                );
            } else {
                const acq_client = APIClient.acquisition;
                acq_client.ledgers.create(ledger).then(
                    success => {
                        baseResource.setMessage($__("Ledger created"));
                        baseResource.router.push({ name: "LedgerList" });
                    },
                    error => {}
                );
            }
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            componentData.resource.value.oe_warning_percent =
                resource.oe_warning_percent * 100;
        };

        const afterNewResourceCreate = (resource, componentData) => {
            if (componentData.route.query.fiscal_period_id) {
                resource.fiscal_period_id = parseInt(
                    componentData.route.query.fiscal_period_id
                );
            }
            return resource;
        };

        const appendToShow = componentData => {
            const { resource } = componentData;
            return [
                ...(resource.funds?.length
                    ? [
                          {
                              type: "component",
                              name: $__("Funds"),
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
                                          ledger_id: { property: "ledger_id" },
                                      },
                                  },
                                  resource: {
                                      type: "resource",
                                  },
                                  resourceName: {
                                      type: "string",
                                      value: "fund",
                                  },
                                  resourceNamePlural: {
                                      type: "string",
                                      value: "funds",
                                  },
                              },
                          },
                      ]
                    : []),
            ];
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            afterResourceFetch,
            afterNewResourceCreate,
            appendToShow,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "LedgerResource",
};
</script>
