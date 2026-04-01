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
        const format_date = $date;

        const acquisitionsStore = inject("acquisitionsStore");
        const { currencies, user } = storeToRefs(acquisitionsStore);

        const { formatValueWithCurrency, getBranchnamesFromGroups } =
            acquisitionsStore;

        const additionalToolbarButtons = (resource, componentData) => {
            const handleAllocationButtons = () => {
                return [
                    {
                        title: $__("Increase ledger amount"),
                        action: "increase",
                        icon: "plus",
                    },
                    {
                        title: $__("Decrease ledger amount"),
                        action: "decrease",
                        icon: "minus",
                    },
                    {
                        title: $__("Transfer ledger amount"),
                        action: "transfer",
                        icon: "arrow-right-arrow-left",
                    },
                ].map(({ title, action, icon }) => {
                    return {
                        to: {
                            name: "AllocationFormAdd",
                            params: {
                                entity: "ledger",
                                entity_id: resource.ledger_id,
                            },
                            query: {
                                action,
                            },
                        },
                        title,
                        icon,
                    };
                });
            };
            return {
                show: [
                    ...(!resource.locked
                        ? [
                              {
                                  to: {
                                      name: "FundFormAdd",
                                      query: {
                                          ledger_id: resource.ledger_id,
                                          fiscal_period_id:
                                              resource.fiscal_period_id,
                                      },
                                  },
                                  title: $__("Add fund"),
                                  icon: "plus",
                                  index: -1,
                              },
                          ]
                        : []),
                    ...handleAllocationButtons(),
                ],
            };
        };

        const defaultToolbarButtons = (defaultButtons, resource) => {
            return {
                list: [],
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
            defaultToolbarButtons,
            resourceAttrs: [
                {
                    name: "ledger_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "fiscal_period_name",
                    type: "display",
                    label: $__("Fiscal period"),
                    group: $__("Information and status"),
                    showElement: {
                        type: "text",
                        value: "fiscal_period.name",
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
                    name: "external_id",
                    type: "text",
                    label: $__("External ID"),
                    group: $__("Information and status"),
                    hideIn: ["List"],
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
                    name: "locked",
                    type: "boolean",
                    label: $__("Ledger locked?"),
                    group: $__("Information and status"),
                    defaultValue: false,
                    tooltip: $__(
                        "Please note: if you lock the ledger it will not be possible to add new funds"
                    ),
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
                    disabled: ledger => !!ledger.ledger_id,
                    hideIn: ["List"],
                },
                {
                    name: "ledger_amount",
                    type: "number",
                    label: $__("Ledger amount"),
                    group: $__("Financial controlling"),
                    defaultValue: 0,
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    formatInputValue: (value, resource) => {
                        return formatValueWithCurrency(
                            value,
                            resource.currency
                        );
                    },
                    toolTip: $__(
                        "Please note: you can change this amount after creating the ledger record"
                    ),
                    hideIn: ["List"],
                },
                {
                    name: "owner_id",
                    type: "patronSearch",
                    label: $__("Owner"),
                    group: $__("Management in library"),
                    componentProps: {
                        name: {
                            type: "string",
                            value: "owner_id",
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
                        required: {
                            type: "boolean",
                            value: true,
                        },
                    },
                    required: true,
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
                    name: "oe_warning_amount",
                    type: "number",
                    label: $__("Overencumbrance warning amount"),
                    group: $__("Financial controlling"),
                    placeholder: $__(
                        "The amount at which a warning is triggered"
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
            if (!ledgerToSave.fiscal_period_id) {
                setWarning($__("You have not selected a fiscal period."));
                return;
            }

            const ledger = JSON.parse(JSON.stringify(ledgerToSave));
            const ledger_id = ledger.ledger_id;

            const oe_warning_percent = ledger.oe_warning_percent;
            ledger.oe_warning_percent = oe_warning_percent / 100;

            delete ledger.ledger_id;
            delete ledger.patron;
            delete ledger.patron_str;
            delete ledger.owner;
            delete ledger.fiscal_period;
            delete ledger.fiscal_period_name;
            delete ledger.managing_library;
            delete ledger.modified_date;
            delete ledger.created_date;
            delete ledger.funds;
            delete ledger.child_object_managing_branches;
            delete ledger.allocations;

            if (ledger_id) {
                return baseResource.apiClient.update(ledger, ledger_id).then(
                    ledger => {
                        baseResource.setMessage($__("Ledger updated"));
                        return ledger;
                    },
                    error => {}
                );
            } else {
                return baseResource.apiClient.create(ledger).then(
                    ledger => {
                        baseResource.setMessage($__("Ledger created"));
                        return ledger;
                    },
                    error => {}
                );
            }
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            componentData.resource.value.oe_warning_percent =
                resource.oe_warning_percent * 100;
            componentData.resource.value.fiscal_period_name =
                resource.fiscal_period.name;
            const { branchNames, groupNames } = getBranchnamesFromGroups(
                resource.fiscal_period.managing_library
                    ?.acquisitions_library_groups
            );
            const childManagingBranches = resource
                .child_object_managing_branches.length
                ? resource.child_object_managing_branches.reduce(
                      (acc, comb) => {
                          if (
                              !acc.includes(comb.branchcode) &&
                              branchNames.includes(comb.branchname)
                          ) {
                              acc.push(comb.branchcode);
                          }
                          return acc;
                      },
                      [resource.managing_branch]
                  )
                : branchNames;
            baseResource.setMessage(
                $__("Access restriction for group(s) %s").format(
                    groupNames.join(", ")
                )
            );
            const branchAttr = baseResource.resourceAttrs.find(
                ra => ra.name === "managing_branch"
            );
            branchAttr.componentProps.query = {
                type: "object",
                value: {
                    [resource.child_object_managing_branches
                        ? "branchcode"
                        : "branchname"]: { "-in": childManagingBranches },
                },
            };
        };

        const afterNewResourceCreate = (
            resource,
            componentData,
            initialized
        ) => {
            if (componentData.route.query.fiscal_period_id) {
                resource.fiscal_period_id = parseInt(
                    componentData.route.query.fiscal_period_id
                );
                APIClient.acquisition.fiscalPeriods
                    .get(resource.fiscal_period_id)
                    .then(fiscalPeriod => {
                        resource.fiscal_period_name = fiscalPeriod.name;
                        if (
                            fiscalPeriod.managing_library
                                ?.acquisitions_library_groups.length
                        ) {
                            const { branchNames, groupNames } =
                                getBranchnamesFromGroups(
                                    fiscalPeriod.managing_library
                                        ?.acquisitions_library_groups
                                );
                            baseResource.setMessage(
                                $__(
                                    "Access restriction for group(s) %s"
                                ).format(groupNames.join(", "))
                            );

                            resource.managing_branch =
                                user.value.loggedInUser.loggedInBranch;
                            const branchAttr = componentData.resourceAttrs.find(
                                ra => ra.name === "managing_branch"
                            );
                            branchAttr.componentProps.query = {
                                type: "object",
                                value: { branchname: { "-in": branchNames } },
                            };

                            initialized.value = true;
                        } else {
                            initialized.value = true;
                        }
                    });
            } else {
                initialized.value = true;
            }
            return resource;
        };

        const appendToShow = componentData => {
            const { resource } = componentData;
            return [
                ...(resource.allocations?.length
                    ? [
                          {
                              type: "component",
                              name: $__("Allocations"),
                              componentPath:
                                  "@koha-vue/components/RelationshipTableDisplay.vue",
                              componentProps: {
                                  tableOptions: {
                                      type: "object",
                                      value: {
                                          columns: [
                                              {
                                                  title: __("Timestamp"),
                                                  data: "created_date",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return format_date(
                                                          row.created_date,
                                                          { withtime: true }
                                                      );
                                                  },
                                              },
                                              {
                                                  title: __("Type"),
                                                  data: "type",
                                                  searchable: true,
                                                  orderable: true,
                                                  render: function (
                                                      data,
                                                      type,
                                                      row,
                                                      meta
                                                  ) {
                                                      return (
                                                          String(row.type)
                                                              .charAt(0)
                                                              .toUpperCase() +
                                                          String(
                                                              row.type
                                                          ).slice(1)
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
                                                      const isIncrease =
                                                          row.type ===
                                                              "increase" ||
                                                          (row.type ===
                                                              "transfer" &&
                                                              row.is_transferred_from);
                                                      const symbol = isIncrease
                                                          ? "+"
                                                          : "-";
                                                      const colour = isIncrease
                                                          ? "green"
                                                          : "red";
                                                      return (
                                                          '<span style="color:' +
                                                          colour +
                                                          ';">' +
                                                          symbol +
                                                          formatValueWithCurrency(
                                                              row.allocation_amount
                                                          ) +
                                                          "</span>"
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
                                                  ._baseURL + "allocations",
                                          table_settings: null,
                                          add_filters: true,
                                          actions: {
                                              0: ["show"],
                                          },
                                      },
                                  },
                                  apiClient: {
                                      type: "object",
                                      value: APIClient.acquisition.allocations,
                                  },
                                  filters: {
                                      type: "filter",
                                      keys: {
                                          ledger_id: {
                                              property: "ledger_id",
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
