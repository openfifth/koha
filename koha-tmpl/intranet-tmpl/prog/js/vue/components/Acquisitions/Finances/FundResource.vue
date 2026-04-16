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
import { storeToRefs } from "pinia";

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
        const format_date = $date;

        const acquisitionsStore = inject("acquisitionsStore");
        const { user, authorisedValues } = storeToRefs(acquisitionsStore);
        const { formatValueWithCurrency, getBranchnamesFromGroups } =
            acquisitionsStore;

        const defaultToolbarButtons = (defaultButtons, resource, router) => {
            return {
                list: [],
                show: defaultButtons.show.filter(button => {
                    if (button.action === "delete" && resource.sub_funds?.length)
                        return false;
                    if (button.action === "edit" && resource.ledger_locked)
                        return false;
                    return true;
                }),
            };
        };

        const additionalToolbarButtons = resource => {
            const handleAllocationButtons = () => {
                return [
                    {
                        title: $__("Increase fund amount"),
                        action: "increase",
                        icon: "plus",
                    },
                    {
                        title: $__("Decrease fund amount"),
                        action: "decrease",
                        icon: "minus",
                    },
                    {
                        title: $__("Transfer fund amount"),
                        action: "transfer",
                        icon: "arrow-right-arrow-left",
                    },
                ].map(({ title, action, icon }) => {
                    return {
                        to: {
                            name: "AllocationFormAdd",
                            params: {
                                entity: "fund",
                                entity_id: resource.fund_id,
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
                    ...(!isSubFund.value && !resource.ledger_locked
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
                    ...handleAllocationButtons(),
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
                breachAmountMessage: isSubFund.value
                    ? $__(
                          "The parent fund amount will be breached by %s. Please reduce the amount for this sub fund."
                      )
                    : $__(
                          "The parent ledger amount will be breached by %s. Please reduce the amount for this fund."
                      ),
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
                    name: "ledger_name",
                    type: "display",
                    label: $__("Ledger"),
                    group: $__("Information and status"),
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
                {
                    name: "fund_parent_name",
                    type: "display",
                    label: $__("Parent fund"),
                    group: $__("Information and status"),
                    showElement: {
                        type: "text",
                        value: "parent_fund.name",
                        link: {
                            name: "FundShow",
                            params: {
                                fund_id: "parent_fund_id",
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
                                ? '<a href="/cgi-bin/koha/acquisitions/finances/fund' +
                                      row.parent_fund.fund_id +
                                      '" class="show">' +
                                      escape_str(row.parent_fund.name) +
                                      "</a>"
                                : "";
                        },
                    },
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
                    disabled: fund => fund.parent_status === false,
                },
                ...(!isSubFund.value &&
                authorisedValues.value.av_fund_type.length
                    ? [
                          {
                              name: "fund_type",
                              type: "select",
                              label: $__("Fund type"),
                              group: $__("Information and status"),
                              avCat: "av_fund_type",
                          },
                      ]
                    : []),
                {
                    name: "currency",
                    type: "display",
                    label: $__("Currency"),
                    group: $__("Financial controlling"),
                    hideIn: ["List"],
                },
                {
                    name: "fund_amount",
                    type: props.routeAction === "edit" ? "display" : "number",
                    label: $__("Fund amount"),
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
                    toolTip:
                        props.routeAction === "edit"
                            ? null
                            : $__(
                                  "Please note: you can change this amount after creating the fund record"
                              ),
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
                            value: "/api/v1/acquisitions/finances/users",
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
                    name: "fund_permission",
                    type: "select",
                    label: $__("Restrict access to"),
                    group: $__("Management in library"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        { description: $__("Owner only"), value: 1 },
                        { description: $__("Owner and users"), value: 2 },
                        {
                            description: $__(
                                "Owner, users and managing library"
                            ),
                            value: 3,
                        },
                        {
                            description: $__(
                                "Owner, users, managing library and library group"
                            ),
                            value: 4,
                        },
                    ],
                    toolTip: $__(
                        "Please note: These restrictions will override your library group configuration!"
                    ),
                    format: (val, resource, attr) => {
                        const selectedOption = attr.options.find(
                            op => op.value === val
                        );
                        return selectedOption ? selectedOption.description : "";
                    },
                    hideIn: ["List"],
                },
            ],
        });

        const tableURL = () => {
            if (props.embedded) {
                const id = isSubFund.value
                    ? baseResource.route.params.parent_fund_id
                    : baseResource.route.params.ledger_id;
                const query = {};
                query[
                    "me." + (isSubFund.value ? "parent_fund_id" : "ledger_id")
                ] = id;
                return `/api/v1/acquisitions/funds?q=` + JSON.stringify(query);
            }
            return `/api/v1/acquisitions/funds`;
        };

        const tableOptions = {
            url: tableURL(),
            table_settings: null,
            add_filters: true,
            options: { embed: "sub_funds,allocations,parent_fund" },
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
            if (!fundToSave.ledger_id) {
                setWarning($__("You have not selected a ledger."));
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
                fund.parent_fund_id =
                    baseResource.route.query.fund_id || fund.fund_id;
            }
            delete fund.owner;
            delete fund.allocations;
            delete fund.ledger;
            delete fund.fiscal_period;
            delete fund.sub_funds;
            delete fund.managing_library;
            delete fund.patron;
            delete fund.patron_str;
            delete fund.fiscal_period_name;
            delete fund.ledger_name;
            delete fund.fund_parent_name;
            delete fund.currency;
            delete fund.parent_fund;
            delete fund.modified_date;
            delete fund.created_date;
            delete fund.child_object_managing_branches;
            delete fund.parent_status;
            delete fund.ledger_locked;

            fund.fund_permission = fund.fund_permission
                ? parseInt(fund.fund_permission)
                : null;

            if (fund_id) {
                return baseResource.apiClient.update(fund, fund_id).then(
                    fund => {
                        baseResource.setMessage($__("Fund updated"));
                        return fund;
                    },
                    error => {
                        baseResource.setWarning(
                            baseResource.i18n.breachAmountMessage.format(
                                formatValueWithCurrency(
                                    error.result.breach_amount
                                )
                            )
                        );
                    }
                );
            } else {
                return baseResource.apiClient.create(fund).then(
                    fund => {
                        baseResource.setMessage($__("Fund created"));
                        return fund;
                    },
                    error => {
                        baseResource.setWarning(
                            baseResource.i18n.breachAmountMessage.format(
                                formatValueWithCurrency(
                                    error.result.breach_amount
                                )
                            )
                        );
                    }
                );
            }
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            componentData.resource.value.oe_warning_percent =
                resource.oe_warning_percent * 100;
            componentData.resource.value.fiscal_period_name =
                resource.fiscal_period.name;
            componentData.resource.value.ledger_name = resource.ledger.name;
            componentData.resource.value.fund_parent_name =
                resource.parent_fund?.name;
            componentData.resource.value.currency = resource.ledger.currency;
            componentData.resource.value.ledger_locked = resource.ledger?.locked;
            const parentKey = isSubFund.value ? "parent_fund" : "ledger";
            componentData.resource.value.parent_status =
                resource[parentKey]?.status;
            const { branchNames, groupNames } = getBranchnamesFromGroups(
                resource[parentKey].managing_library
                    ?.acquisitions_library_groups || []
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
                ),
                true
            );
            const branchAttr = baseResource.resourceAttrs.find(
                ra => ra.name === "managing_branch"
            );
            if (childManagingBranches.length) {
                branchAttr.componentProps.query = {
                    type: "object",
                    value: {
                        [resource.child_object_managing_branches
                            ? "branchcode"
                            : "branchname"]: { "-in": childManagingBranches },
                    },
                };
            }
        };

        const appendToShow = componentData => {
            const { resource } = componentData;
            let formatValueWithCurrencyHandler = formatValueWithCurrency;
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
                                                          '<a href="/cgi-bin/koha/acquisitions/finances/fund/' +
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
                                          parent_fund_id: {
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

        const afterNewResourceCreate = (
            resource,
            componentData,
            initialized
        ) => {
            const clientName = isSubFund.value ? "funds" : "ledgers";
            const searchKey = isSubFund.value ? "fund_id" : "ledger_id";
            APIClient.acquisition[clientName]
                .get(componentData.route.query[searchKey])
                .then(result => {
                    resource.fiscal_period_id = parseInt(
                        result.fiscal_period_id
                    );
                    resource.ledger_id = parseInt(result.ledger_id);
                    if (isSubFund.value) {
                        resource.parent_fund_id = parseInt(
                            componentData.route.query.fund_id
                        );
                    }
                    resource.fiscal_period_name = result.fiscal_period.name;
                    const resultLedger = isSubFund.value
                        ? result.ledger
                        : result;
                    resource.ledger_name = resultLedger.name;
                    resource.currency = resultLedger.currency;
                    resource.ledger_locked = resultLedger.locked;
                    resource.parent_status = result.status;
                    if (!result.status) resource.status = false;
                    const acqLibGroups =
                        result.managing_library?.acquisitions_library_groups ||
                        [];
                    resource.fund_parent_name = isSubFund.value
                        ? result.name
                        : null;
                    if (acqLibGroups.length) {
                        const { branchNames, groupNames } =
                            getBranchnamesFromGroups(acqLibGroups);
                        baseResource.setMessage(
                            $__("Access restriction for group(s) %s").format(
                                groupNames.join(", ")
                            ),
                            true
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
            return resource;
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            afterResourceFetch,
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
