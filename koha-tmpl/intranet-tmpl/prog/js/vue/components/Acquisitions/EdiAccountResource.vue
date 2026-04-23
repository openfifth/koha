<template>
    <BaseResource
        v-if="configLoaded"
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { ref, onBeforeMount } from "vue";
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },

    setup(props) {
        const configLoaded = ref(false);
        const fileTransports = ref([]);
        const plugins = ref([]);

        onBeforeMount(async () => {
            const config = await APIClient.acquisition.ediAccountsConfig.get();
            fileTransports.value = config.file_transports || [];
            plugins.value = config.plugins || [];
            configLoaded.value = true;
        });

        const baseResource = useBaseResource({
            resourceName: "vendor_edi_account",
            nameAttr: "description",
            idAttr: "vendor_edi_account_id",
            components: {
                show: "EdiAccountShow",
                list: "EdiAccountList",
                add: "EdiAccountFormAdd",
                edit: "EdiAccountFormAddEdit",
            },
            apiClient: APIClient.acquisition.ediAccounts,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this EDI account?"
                ),
                deleteSuccessMessage: $__("EDI account %s deleted"),
                displayName: $__("EDI account"),
                editLabel: $__("Edit EDI account #%s"),
                emptyListMessage: $__("There are no EDI accounts defined"),
                newLabel: $__("New EDI account"),
            },
            table: {
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL + "edi_accounts",
                addAdditionalFilters: false,
            },
            embedded: props.embedded,
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "vendor_edi_account_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "vendor_id",
                    label: $__("Vendor"),
                    group: $__("Basic information"),
                    type: "relationshipSelect",
                    showElement: {
                        type: "text",
                        value: "vendor.name",
                        link: {
                            href: "/cgi-bin/koha/acquisition/vendors",
                            slug: "vendor_id",
                        },
                    },
                    relationshipAPIClient: APIClient.acquisition.vendors,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "id",
                    tableColumnDefinition: {
                        title: $__("Vendor"),
                        data: "vendor.name",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row) {
                            return row.vendor_id != null
                                ? '<a href="/cgi-bin/koha/acquisition/vendors/' +
                                      escape_str(row.vendor_id) +
                                      '">' +
                                      escape_str(row.vendor?.name ?? "") +
                                      "</a>"
                                : "";
                        },
                    },
                },
                {
                    name: "description",
                    label: $__("Description"),
                    type: "text",
                    group: $__("Basic information"),
                },
                ...(plugins.value.length
                    ? [
                          {
                              name: "plugin",
                              label: $__("Plugin"),
                              type: "select",
                              group: $__("Basic information"),
                              selectLabel: "name",
                              requiredKey: "class",
                              options: [
                                  { class: "", name: $__("Do not use plugin") },
                                  ...plugins.value,
                              ],
                              format: (val, resource, attr) => {
                                  if (!val) return $__("Do not use plugin");
                                  const opt = attr.options.find(
                                      o => o.class === val
                                  );
                                  return opt ? opt.name : val;
                              },
                              hideIn: ["List"],
                          },
                      ]
                    : []),
                {
                    name: "id_code_qualifier",
                    label: $__("Qualifier"),
                    type: "select",
                    group: $__("Basic information"),
                    selectLabel: "description",
                    requiredKey: "code",
                    options: [
                        {
                            code: "14",
                            description: $__("EAN International (14)"),
                        },
                        {
                            code: "31B",
                            description: $__("US SAN Agency (31B)"),
                        },
                        {
                            code: "91",
                            description: $__("Assigned by supplier (91)"),
                        },
                        {
                            code: "92",
                            description: $__("Assigned by buyer (92)"),
                        },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.code === val);
                        return opt ? opt.description : (val ?? "");
                    },
                    tableColumnDefinition: {
                        title: $__("Qualifier"),
                        data: "id_code_qualifier",
                        render: function (data) {
                            const qualifiers = {
                                14: $__("EAN International (14)"),
                                "31B": $__("US SAN Agency (31B)"),
                                91: $__("Assigned by supplier (91)"),
                                92: $__("Assigned by buyer (92)"),
                            };
                            return escape_str(qualifiers[data] ?? data ?? "");
                        },
                    },
                },
                {
                    name: "san",
                    label: $__("SAN"),
                    type: "text",
                    group: $__("Basic information"),
                },
                {
                    name: "standard",
                    label: $__("Standard"),
                    type: "select",
                    group: $__("Basic information"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        { value: "EUR", description: $__("EDItEUR") },
                        { value: "BIC", description: $__("BiC") },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.value === val);
                        return opt ? opt.description : (val ?? "");
                    },
                    tableColumnDefinition: {
                        title: $__("Standard"),
                        data: "standard",
                        render: function (data) {
                            return escape_str(
                                data === "BIC" ? "BiC" : "EDItEUR"
                            );
                        },
                    },
                },
                {
                    name: "file_transport_id",
                    label: $__("File transport"),
                    type: "select",
                    group: $__("Transport settings"),
                    selectLabel: "name",
                    requiredKey: "file_transport_id",
                    options: fileTransports.value,
                    format: (val, resource, attr) => {
                        if (val == null) return "";
                        const opt = attr.options.find(
                            o => o.file_transport_id === val
                        );
                        if (!opt) return String(val);
                        const suffix =
                            opt.transport && opt.host
                                ? ` (${opt.transport.toUpperCase()} - ${opt.host})`
                                : opt.transport
                                  ? ` (${opt.transport.toUpperCase()})`
                                  : "";
                        return `${opt.name}${suffix}`;
                    },
                    defaultValue: null,
                    toolTip: $__(
                        "File transports can be managed in Administration > File transports."
                    ),
                    tableColumnDefinition: {
                        title: $__("File transport"),
                        data: "file_transport.name",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row) {
                            return escape_str(row.file_transport?.name ?? "");
                        },
                    },
                },
                {
                    name: "quotes_enabled",
                    label: $__("Quotes enabled"),
                    type: "checkbox",
                    group: $__("Message types"),
                    tableColumnDefinition: {
                        title: $__("Quotes"),
                        data: "quotes_enabled",
                        render: function (data) {
                            return data ? $__("Yes") : $__("No");
                        },
                    },
                },
                {
                    name: "orders_enabled",
                    label: $__("Orders enabled"),
                    type: "checkbox",
                    group: $__("Message types"),
                    tableColumnDefinition: {
                        title: $__("Orders"),
                        data: "orders_enabled",
                        render: function (data) {
                            return data ? $__("Yes") : $__("No");
                        },
                    },
                },
                {
                    name: "invoices_enabled",
                    label: $__("Invoices enabled"),
                    type: "checkbox",
                    group: $__("Message types"),
                    tableColumnDefinition: {
                        title: $__("Invoices"),
                        data: "invoices_enabled",
                        render: function (data) {
                            return data ? $__("Yes") : $__("No");
                        },
                    },
                },
                {
                    name: "responses_enabled",
                    label: $__("Responses enabled"),
                    type: "checkbox",
                    group: $__("Message types"),
                    tableColumnDefinition: {
                        title: $__("Responses"),
                        data: "responses_enabled",
                        render: function (data) {
                            return data ? $__("Yes") : $__("No");
                        },
                    },
                },
                {
                    name: "auto_orders",
                    label: $__("Automatic ordering"),
                    type: "checkbox",
                    group: $__("Functional switches"),
                    toolTip: $__(
                        "With automatic ordering, quotes generate orders without staff intervention."
                    ),
                    tableColumnDefinition: {
                        title: $__("Auto ordering"),
                        data: "auto_orders",
                        render: function (data) {
                            return data ? $__("Yes") : $__("No");
                        },
                    },
                },
                {
                    name: "po_is_basketname",
                    label: $__("Use purchase order numbers"),
                    type: "checkbox",
                    group: $__("Functional switches"),
                    toolTip: $__(
                        "When enabled, basket names are used as purchase order numbers."
                    ),
                    hideIn: ["List"],
                },
            ],
        });

        const tableOptions = {
            options: {
                embed: "vendor,file_transport",
            },
            url: baseResource.getResourceTableUrl(),
            table_settings: baseResource.vendor_edi_account_table_settings,
            add_filters: false,
            actions: {
                "-1": ["edit", "delete"],
            },
        };

        const onFormSave = (e, accountToSave) => {
            e.preventDefault();

            const account = JSON.parse(JSON.stringify(accountToSave));
            const vendor_edi_account_id = account.vendor_edi_account_id;

            delete account.vendor_edi_account_id;
            delete account.vendor;
            delete account.file_transport;

            if (vendor_edi_account_id) {
                return baseResource.apiClient
                    .update(account, vendor_edi_account_id)
                    .then(
                        updated => {
                            baseResource.setMessage($__("EDI account updated"));
                            return updated;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(account).then(
                    created => {
                        baseResource.setMessage($__("EDI account created"));
                        return created;
                    },
                    error => {}
                );
            }
        };

        return {
            ...baseResource,
            configLoaded,
            tableOptions,
            onFormSave,
        };
    },

    emits: ["select-resource"],
    name: "EdiAccountResource",
    components: {
        BaseResource,
    },
};
</script>
