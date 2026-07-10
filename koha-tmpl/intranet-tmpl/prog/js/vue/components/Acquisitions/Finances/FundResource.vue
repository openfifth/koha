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
import { inject, ref } from "vue";
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

        const acquisitionsStore = inject("acquisitionsStore");
        const { user, authorisedValues } = storeToRefs(acquisitionsStore);
        const {
            formatValueWithCurrency,
            getBranchnamesFromGroups,
            useAllocationModal,
            useAllocationTableConfig,
            useFundTableConfig,
        } = acquisitionsStore;

        const { setConfirmationDialog, setWarning, setMessage } =
            inject("mainStore");

        let refetchResource;
        const { getAllocationToolbarButtons } = useAllocationModal({
            entity: "fund",
            setConfirmationDialog,
            setWarning,
            setMessage,
            onSuccess: () => refetchResource?.(),
        });

        const defaultToolbarButtons = (defaultButtons, resource, router) => {
            return {
                list: [],
                show: defaultButtons.show.map(button => {
                    if (
                        button.action === "delete" &&
                        resource.sub_funds?.length
                    )
                        return {
                            ...button,
                            disabled: true,
                            hint: $__(
                                "This fund has sub-funds and cannot be deleted"
                            ),
                        };
                    if (button.action === "edit" && resource.ledger_locked)
                        return {
                            ...button,
                            disabled: true,
                            hint: $__("The parent ledger is locked"),
                        };
                    return button;
                }),
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
                                  disabled:
                                      resource.ledger_locked ||
                                      !resource.status,
                                  hint:
                                      resource.ledger_locked && !resource.status
                                          ? $__(
                                                "The parent ledger is locked and this fund is inactive"
                                            )
                                          : resource.ledger_locked
                                            ? $__("The parent ledger is locked")
                                            : $__("This fund is inactive"),
                              },
                          ]
                        : []),
                    ...getAllocationToolbarButtons(resource),
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
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL + "funds",
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
            showGroupsDisplayMode: "splitScreen",
            splitScreenGroupings: [
                { pane: 1, groups: ["Information and status"] },
                { pane: 2, groups: ["Financial controlling"] },
                { pane: "break", groups: ["Management in library"] },
            ],
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
                                fiscal_period_id:
                                    "fiscal_period.fiscal_period_id",
                            },
                        },
                    },
                    tableColumnDefinition: {
                        title: $__("Fiscal period"),
                        data: "fiscal_period.name",
                        searchable: true,
                        orderable: true,
                        render(data, type, row, meta) {
                            if (!row.fiscal_period)
                                return escape_str($__("No fiscal period"));
                            const href = baseResource.router.resolve({
                                name: "FiscalPeriodShow",
                                params: {
                                    fiscal_period_id:
                                        row.fiscal_period.fiscal_period_id,
                                },
                            }).href;
                            return (
                                '<a href="' +
                                href +
                                '" class="fiscal-period-show">' +
                                escape_str(row.fiscal_period.name) +
                                "</a>"
                            );
                        },
                    },
                    hideIn: [],
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
                    tableColumnDefinition: {
                        title: $__("Ledger"),
                        data: "ledger.name",
                        searchable: true,
                        orderable: true,
                        render(data, type, row, meta) {
                            if (!row.ledger)
                                return escape_str($__("No ledger"));
                            const href = baseResource.router.resolve({
                                name: "LedgerShow",
                                params: {
                                    ledger_id: row.ledger_id,
                                },
                            }).href;
                            return (
                                '<a href="' +
                                href +
                                '" class="ledger-show">' +
                                escape_str(row.ledger.name) +
                                "</a>"
                            );
                        },
                    },
                    hideIn: [],
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
                    hideIn: ["List"],
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
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    toolTip:
                        props.routeAction === "edit"
                            ? null
                            : $__(
                                  "Please note: you can change this amount after creating the fund record"
                              ),
                    tableColumnDefinition: {
                        title: $__("Fund amount"),
                        data: "fund_amount",
                        searchable: true,
                        orderable: true,
                        render(data, type, row, meta) {
                            return formatValueWithCurrency(
                                row.fund_amount,
                                row.currency
                            );
                        },
                    },
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

        const buildTabUrl = status => {
            if (props.embedded) {
                const id = isSubFund.value
                    ? baseResource.route.params.parent_fund_id
                    : baseResource.route.params.ledger_id;
                const key = isSubFund.value
                    ? "me.parent_fund_id"
                    : "me.ledger_id";
                return (
                    APIClient.acquisition.httpClient._baseURL +
                    "funds?" +
                    new URLSearchParams({
                        q: JSON.stringify({ [key]: id, "me.status": status }),
                    })
                );
            }
            return (
                APIClient.acquisition.httpClient._baseURL +
                "funds?" +
                new URLSearchParams({
                    q: JSON.stringify({
                        "me.parent_fund_id": null,
                        "me.status": status,
                    }),
                })
            );
        };

        baseResource.table.listTabs = [
            { name: $__("Active"), url: buildTabUrl(true) },
            { name: $__("Inactive"), url: buildTabUrl(false) },
        ];

        const tableOptions = {
            table_settings: fund_table_settings,
            add_filters: true,
            options: {
                embed: "sub_funds,allocations,parent_fund,fiscal_period,ledger",
            },
            filters_options: {
                ...(authorisedValues.value.av_fund_type.length && {
                    fund_type: () =>
                        baseResource.map_av_dt_filter("av_fund_type"),
                }),
            },
            ...(!props.embedded && {
                actions: {
                    0: ["show"],
                    2: ["fiscal-period-show"],
                    3: ["ledger-show"],
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
                                              !row.sub_funds?.length,
                                      },
                                  },
                              ]
                            : []),
                    ],
                },
            }),
            tree: {
                childrenField: "sub_funds",
                idField: "fund_id",
                parentField: "parent_fund_id",
                defaultExpanded: false,
            },
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
            fund.fund_amount = fund.fund_amount || 0;

            if (isSubFund.value) {
                fund.parent_fund_id =
                    baseResource.route.query.fund_id || fund_id;
            }
            delete fund.fund_id;
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
                resource.fiscal_period?.name;
            componentData.resource.value.ledger_name = resource.ledger?.name;
            componentData.resource.value.fund_parent_name =
                resource.parent_fund?.name;
            componentData.resource.value.currency = resource.ledger?.currency;
            componentData.resource.value.ledger_locked =
                resource.ledger?.locked;
            const parentKey = isSubFund.value ? "parent_fund" : "ledger";
            componentData.resource.value.parent_status =
                resource[parentKey]?.status;
            const { branchNames, groupNames } = getBranchnamesFromGroups(
                resource[parentKey]?.managing_library
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
            if (groupNames.length) {
                baseResource.setMessage(
                    $__("Access restriction for group(s) %s").format(
                        groupNames.join(", ")
                    ),
                    true
                );
            }
            const branchAttr = baseResource.resourceAttrs.find(
                ra => ra.name === "managing_branch"
            );
            if (childManagingBranches.length) {
                branchAttr.componentProps.query = {
                    type: "object",
                    value: {
                        [resource.child_object_managing_branches.length
                            ? "branchcode"
                            : "branchname"]: { "-in": childManagingBranches },
                    },
                };
            }
        };

        const appendToShow = componentData => {
            const { resource } = componentData;
            return [
                ...(resource.allocations?.length
                    ? [useAllocationTableConfig({ entity: "fund" })]
                    : []),
                ...(resource.sub_funds?.length
                    ? [
                          useFundTableConfig({
                              name: $__("Sub funds"),
                              hidden: fund => fund.fund_id,
                              filterKey: "parent_fund_id",
                              filterProperty: "fund_id",
                              resourceName: $__("sub fund"),
                              resourceNamePlural: $__("sub funds"),
                              tree: {
                                  childrenField: "sub_funds",
                                  idField: "fund_id",
                                  parentField: "parent_fund_id",
                                  defaultExpanded: false,
                              },
                              router: baseResource.router,
                          }),
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
                        if (groupNames.length) {
                            baseResource.setMessage(
                                $__(
                                    "Access restriction for group(s) %s"
                                ).format(groupNames.join(", ")),
                                true
                            );
                        }

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

        refetchResource = baseResource.refetchResource;

        const customTableEvents = {
            "fiscal-period-show": (row, dt, e) => {
                e.preventDefault();
                baseResource.router.push({
                    name: "FiscalPeriodShow",
                    params: {
                        fiscal_period_id: row.fiscal_period?.fiscal_period_id,
                    },
                });
            },
            "ledger-show": (row, dt, e) => {
                e.preventDefault();
                baseResource.router.push({
                    name: "LedgerShow",
                    params: { ledger_id: row.ledger_id },
                });
            },
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            afterResourceFetch,
            isSubFund,
            appendToShow,
            afterNewResourceCreate,
            customTableEvents,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "FundResource",
};
</script>
