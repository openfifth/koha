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
    },
    setup(props) {
        const patron_to_html = $patron_to_html;
        const format_date = $date;

        const acquisitionsStore = inject("acquisitionsStore");
        const { currencies, user, sysprefs } = storeToRefs(acquisitionsStore);

        const {
            formatValueWithCurrency,
            getBranchnamesFromGroups,
            differentCurrenciesInLedgers,
            useAllocationModal,
            useRolloverModal,
            useAllocationTableConfig,
            useFundTableConfig,
        } = acquisitionsStore;

        const { setConfirmationDialog, setWarning, setMessage } =
            inject("mainStore");

        let refetchResource;
        const { getAllocationToolbarButtons } = useAllocationModal({
            entity: "ledger",
            setConfirmationDialog,
            setWarning,
            setMessage,
            onSuccess: () => refetchResource?.(),
        });

        const { openRolloverModal } = useRolloverModal({
            setConfirmationDialog,
            setWarning,
            setMessage,
            onSuccess: () => refetchResource?.(),
        });

        const additionalToolbarButtons = (resource, componentData) => {
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
                        disabled: resource.locked || !resource.status,
                        hint:
                            resource.locked && !resource.status
                                ? $__("This ledger is locked and inactive")
                                : resource.locked
                                  ? $__("This ledger is locked")
                                  : $__("This ledger is inactive"),
                    },
                    ...getAllocationToolbarButtons(resource),
                    {
                        onClick: () =>
                            openRolloverModal(
                                resource,
                                baseResource.resourceAttrs
                            ),
                        title: $__("Rollover"),
                        icon: "rotate",
                        disabled: !resource.status,
                        hint: $__("This ledger is inactive"),
                    },
                ],
            };
        };

        const defaultToolbarButtons = (defaultButtons, resource) => {
            return {
                list: [],
                show: defaultButtons.show,
            };
        };

        const specifiedActiveCurrency = currencies.value.find(
            curr => curr.active
        );
        const activeCurrency = specifiedActiveCurrency
            ? specifiedActiveCurrency.currency
            : null;

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
            showGroupsDisplayMode: "splitScreen",
            splitScreenGroupings: [
                { pane: 1, groups: ["Information and status"] },
                { pane: 2, groups: ["Financial controlling"] },
                { pane: "break", groups: ["Management in library"] },
            ],
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
                    disabled: ledger => ledger.parent_status === false,
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
                    type: differentCurrenciesInLedgers ? "select" : "display",
                    label: $__("Currency"),
                    group: $__("Financial controlling"),
                    selectLabel: "currency",
                    requiredKey: "currency",
                    options: currencies.value,
                    defaultValue: activeCurrency,
                    required: differentCurrenciesInLedgers ? true : false,
                    disabled: ledger => !!ledger.ledger_id,
                    hideIn: ["List"],
                },
                {
                    name: "ledger_amount",
                    type: props.routeAction === "edit" ? "display" : "number",
                    label: $__("Ledger amount"),
                    group: $__("Financial controlling"),
                    size: 6,
                    format: (value, resource) =>
                        formatValueWithCurrency(value, resource.currency),
                    toolTip:
                        props.routeAction === "edit"
                            ? null
                            : $__(
                                  "Please note: you can change this amount after creating the ledger record"
                              ),
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

        const buildTabUrl = status => {
            const q = props.embedded
                ? {
                      "me.fiscal_period_id":
                          baseResource.route.params.fiscal_period_id,
                      "me.status": status,
                  }
                : { "me.status": status };
            return (
                APIClient.acquisition.httpClient._baseURL +
                "ledgers?q=" +
                JSON.stringify(q)
            );
        };

        baseResource.table.listTabs = [
            { name: $__("Active"), url: buildTabUrl(true) },
            { name: $__("Inactive"), url: buildTabUrl(false) },
        ];

        const tableOptions = {
            table_settings: null,
            add_filters: true,
            options: { embed: "funds" },
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
                        {
                            rollover: {
                                icon: "fa fa-rotate",
                                text: $__("Rollover"),
                                should_display: row => row.status,
                                callback: (ledger, dt, e) => {
                                    openRolloverModal(
                                        {
                                            ...ledger,
                                            oe_warning_percent:
                                                (ledger.oe_warning_percent ||
                                                    0) * 100,
                                        },
                                        baseResource.resourceAttrs
                                    );
                                },
                            },
                        },
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
            ledger.ledger_amount = ledger.ledger_amount || 0;

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
            delete ledger.parent_status;

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
                resource.fiscal_period?.name;
            componentData.resource.value.parent_status =
                resource.fiscal_period?.status;
            const { branchNames, groupNames } = getBranchnamesFromGroups(
                resource.fiscal_period?.managing_library
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
                        resource.parent_status = fiscalPeriod.status;
                        if (!fiscalPeriod.status) resource.status = false;
                        if (
                            fiscalPeriod.managing_library
                                ?.acquisitions_library_groups.length
                        ) {
                            const { branchNames, groupNames } =
                                getBranchnamesFromGroups(
                                    fiscalPeriod.managing_library
                                        ?.acquisitions_library_groups
                                );
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
            } else {
                initialized.value = true;
            }
            return resource;
        };

        const appendToShow = componentData => {
            const { resource } = componentData;
            return [
                ...(resource.allocations?.length
                    ? [useAllocationTableConfig({ entity: "ledger" })]
                    : []),
                ...(resource.funds?.length
                    ? [
                          useFundTableConfig({
                              name: $__("Funds"),
                              filterKey: "ledger_id",
                              filterProperty: "ledger_id",
                              resourceName: "fund",
                              resourceNamePlural: "funds",
                              router: baseResource.router,
                          }),
                      ]
                    : []),
            ];
        };

        refetchResource = baseResource.refetchResource;

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
