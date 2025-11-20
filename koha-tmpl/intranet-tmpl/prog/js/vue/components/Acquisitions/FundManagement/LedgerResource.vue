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
            showComponent: "LedgerShow",
            listComponent: "LedgerList",
            addComponent: "LedgerFormAdd",
            editComponent: "LedgerFormAddEdit",
            apiClient: APIClient.acquisition.ledgers,
            resourceTableUrl: APIClient.acquisition._baseURL + "ledgers",
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
                    defaultValue: true,
                },
                {
                    name: "external_id",
                    type: "text",
                    label: $__("External ID"),
                    hideIn: ["List"],
                },
                {
                    name: "currency",
                    type: "select",
                    label: $__("Currency"),
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
                    componentPath: "./PatronSearch.vue",
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

        const onSubmit = (e, ledgerToSave) => {
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

        return {
            ...baseResource,
            tableOptions,
            onSubmit,
            afterResourceFetch,
            afterNewResourceCreate,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "LedgerResource",
};
</script>
