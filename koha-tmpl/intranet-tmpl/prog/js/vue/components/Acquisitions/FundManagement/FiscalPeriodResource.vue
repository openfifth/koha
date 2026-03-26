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

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const patron_to_html = $patron_to_html;

        const acquisitionsStore = inject("acquisitionsStore");
        const { formatValueWithCurrency } = acquisitionsStore;

        const additionalToolbarButtons = (resource, componentData) => {
            const { instancedResource } = componentData;
            return {
                show: [
                    {
                        to: {
                            name: "LedgerFormAdd",
                            query: {
                                fiscal_period_id: resource.fiscal_period_id,
                            },
                        },
                        title: $__("Add ledger"),
                        icon: "plus",
                        index: -1,
                    },
                ],
            };
        };

        const baseResource = useBaseResource({
            resourceName: "fiscal_period",
            nameAttr: "name",
            idAttr: "fiscal_period_id",
            components: {
                show: "FiscalPeriodShow",
                list: "FiscalPeriodList",
                add: "FiscalPeriodFormAdd",
                edit: "FiscalPeriodFormAddEdit",
            },
            apiClient: APIClient.acquisition.fiscalPeriods,
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
            table: {
                resourceTableUrl:
                    APIClient.acquisition._baseURL + "fiscal_periods",
            },
            moduleStore: "acquisitionsStore",
            props,
            additionalToolbarButtons,
            resourceAttrs: [
                {
                    name: "fiscal_period_id",
                    label: $__("ID"),
                    group: $__("Information and status"),
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
                    name: "description",
                    type: "textarea",
                    label: $__("Description"),
                    group: $__("Information and status"),
                },
                {
                    name: "start_date",
                    type: "date",
                    label: $__("Start date"),
                    group: $__("Information and status"),
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
                    group: $__("Information and status"),
                    required: true,
                },
                {
                    name: "status",
                    type: "select",
                    label: $__("Status"),
                    group: $__("Information and status"),
                    defaultValue: true,
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        { description: $__("Active"), value: true },
                        { description: $__("Inactive"), value: false },
                    ],
                    format: (val, resource, attr) =>
                        attr.options.find(op => op.value === val).description,
                    required: true,
                },
                {
                    name: "managing_branch",
                    label: $__("Managing library"),
                    group: $__("Management and restrictions"),
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
                    name: "owner_id",
                    type: "patronSearch",
                    label: $__("Owner"),
                    group: $__("Management and restrictions"),
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
                                permission: "acquisition.period_manage",
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

        const onFormSave = (e, fiscalPeriodToSave) => {
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
            delete fiscal_period.patron;
            delete fiscal_period.patron_str;
            delete fiscal_period.owner;
            delete fiscal_period.managing_library;
            delete fiscal_period.ledgers;

            if (fiscal_period_id) {
                return baseResource.apiClient
                    .update(fiscal_period, fiscal_period_id)
                    .then(
                        fiscalPeriod => {
                            baseResource.setMessage(
                                $__("Fiscal period updated")
                            );
                            return fiscalPeriod;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(fiscal_period).then(
                    fiscalPeriod => {
                        baseResource.setMessage($__("Fiscal period created"));
                        return fiscalPeriod;
                    },
                    error => {}
                );
            }
        };

        const appendToShow = componentData => {
            const { resource } = componentData;
            return [
                ...(resource.ledgers?.length
                    ? [
                          {
                              type: "component",
                              name: $__("Ledgers"),
                              componentPath:
                                  "@koha-vue/components/RelationshipTableDisplay.vue",
                              componentProps: {
                                  tableOptions: {
                                      type: "object",
                                      value: {
                                          columns: [
                                              {
                                                  title: __("Name"),
                                                  data: "name:ledger_id",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return (
                                                          '<a href="/cgi-bin/koha/acquisitions/fund_management/ledger/' +
                                                          row.ledger_id +
                                                          '" class="showLedger">' +
                                                          escape_str(
                                                              `${row.name}`
                                                          ) +
                                                          "</a>"
                                                      );
                                                  },
                                              },
                                              {
                                                  title: __("Description"),
                                                  data: "description",
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
                                          ],
                                          url:
                                              APIClient.acquisition.httpClient
                                                  ._baseURL + "ledgers",
                                          table_settings: null,
                                          add_filters: true,
                                          actions: {
                                              0: [
                                                  {
                                                      showLedger: {
                                                          callback: (
                                                              ledger,
                                                              dt,
                                                              event
                                                          ) => {
                                                              event?.preventDefault();
                                                              baseResource.router.push(
                                                                  {
                                                                      name: "LedgerShow",
                                                                      params: {
                                                                          ledger_id:
                                                                              ledger.ledger_id,
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
                                      value: APIClient.acquisition.ledgers,
                                  },
                                  filters: {
                                      type: "filter",
                                      keys: {
                                          fiscal_period_id: {
                                              property: "fiscal_period_id",
                                          },
                                      },
                                  },
                                  resource: {
                                      type: "resource",
                                  },
                                  resourceName: {
                                      type: "string",
                                      value: "ledger",
                                  },
                                  resourceNamePlural: {
                                      type: "string",
                                      value: "ledgers",
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
            appendToShow,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "FiscalPeriodResource",
};
</script>
