<template>
    <BaseResource
        v-if="configLoaded"
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { ref, onBeforeMount, inject } from "vue";
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
        const matchers = ref([]);

        const acquisitionsStore = inject("acquisitionsStore");
        const { buildFundTreeOptions } = acquisitionsStore;

        onBeforeMount(async () => {
            const config =
                await APIClient.acquisition.marcOrderAccountsConfig.get();
            matchers.value = config.matchers || [];
            configLoaded.value = true;
        });

        const baseResource = useBaseResource({
            resourceName: "marc_order_account",
            nameAttr: "description",
            idAttr: "marc_order_account_id",
            components: {
                show: "MarcOrderAccountShow",
                list: "MarcOrderAccountList",
                add: "MarcOrderAccountFormAdd",
                edit: "MarcOrderAccountFormAddEdit",
            },
            apiClient: APIClient.acquisition.marcOrderAccounts,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this MARC order account?"
                ),
                deleteSuccessMessage: $__("MARC order account %s deleted"),
                displayName: $__("MARC order account"),
                editLabel: $__("Edit MARC order account #%s"),
                emptyListMessage: $__(
                    "There are no MARC order accounts defined"
                ),
                newLabel: $__("New MARC order account"),
            },
            table: {
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL +
                    "marc_order_accounts",
                addAdditionalFilters: false,
            },
            embedded: props.embedded,
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "marc_order_account_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "description",
                    label: $__("Description"),
                    type: "text",
                    group: $__("Account details"),
                    required: true,
                },
                {
                    name: "vendor_id",
                    label: $__("Vendor"),
                    group: $__("Account details"),
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
                    name: "budget_id",
                    label: $__("Fund"),
                    group: $__("Account details"),
                    type: "relationshipSelect",
                    showElement: {
                        type: "text",
                        value: "budget.name",
                    },
                    relationshipAPIClient: APIClient.acquisition.funds,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "fund_id",
                    treeSelect: true,
                    treeSelectOptionsHandler: buildFundTreeOptions,
                    toolTip: $__(
                        "This fund will be used as the fallback if the MARC records do not contain a mapped fund code."
                    ),
                    tableColumnDefinition: {
                        title: $__("Fund"),
                        data: "budget.name",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row) {
                            return escape_str(row.budget?.name ?? "");
                        },
                    },
                },
                {
                    name: "download_directory",
                    label: $__("Download directory"),
                    type: "text",
                    group: $__("Account details"),
                    toolTip: $__(
                        "The directory in your Koha installation that should be searched for new files."
                    ),
                    hideIn: ["List"],
                },
                {
                    name: "match_field",
                    label: $__("Match field"),
                    type: "text",
                    group: $__("Account details"),
                    toolTip: $__(
                        "(Optional) MARC field used to match this account when multiple vendors share a directory, e.g. 245$a"
                    ),
                    hideIn: ["List"],
                },
                {
                    name: "match_value",
                    label: $__("Match value"),
                    type: "text",
                    group: $__("Account details"),
                    toolTip: $__(
                        "(Optional) Value checked against the match field to determine whether this account should process the file."
                    ),
                    hideIn: ["List"],
                },
                {
                    name: "basket_name_field",
                    label: $__("Basket name field"),
                    type: "text",
                    group: $__("Account details"),
                    toolTip: $__(
                        "(Optional) MARC field containing the basket name, e.g. 245$a. Read from the first record in the file."
                    ),
                    hideIn: ["List"],
                },
                {
                    name: "record_type",
                    label: $__("Record type"),
                    type: "select",
                    group: $__("File import settings"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        { value: "biblio", description: $__("Bibliographic") },
                        { value: "auth", description: $__("Authority") },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.value === val);
                        return opt ? opt.description : val;
                    },
                    hideIn: ["List"],
                },
                {
                    name: "encoding",
                    label: $__("Character encoding"),
                    type: "select",
                    group: $__("File import settings"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        { value: "UTF-8", description: $__("UTF-8 (Default)") },
                        { value: "MARC-8", description: $__("MARC 8") },
                        { value: "ISO_5426", description: $__("ISO 5426") },
                        { value: "ISO_6937", description: $__("ISO 6937") },
                        { value: "ISO_8859-1", description: $__("ISO 8859-1") },
                        { value: "EUC-KR", description: $__("EUC-KR") },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.value === val);
                        return opt ? opt.description : val;
                    },
                    hideIn: ["List"],
                },
                {
                    name: "matcher_id",
                    label: $__("Record matching rule"),
                    type: "select",
                    group: $__("Record matching settings"),
                    selectLabel: "code",
                    requiredKey: "matcher_id",
                    options: matchers.value,
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(
                            o => o.matcher_id === val
                        );
                        return opt
                            ? `${opt.code} (${opt.description})`
                            : (val ?? "");
                    },
                    hideIn: ["List"],
                },
                {
                    name: "overlay_action",
                    label: $__("Action if matching record found"),
                    type: "select",
                    group: $__("Record matching settings"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        {
                            value: "replace",
                            description: $__(
                                "Replace existing record with incoming record"
                            ),
                        },
                        {
                            value: "create_new",
                            description: $__("Add incoming record"),
                        },
                        {
                            value: "ignore",
                            description: $__(
                                "Ignore incoming record (its items may still be processed)"
                            ),
                        },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.value === val);
                        return opt ? opt.description : (val ?? "");
                    },
                    hideIn: ["List"],
                },
                {
                    name: "nomatch_action",
                    label: $__("Action if no match is found"),
                    type: "select",
                    group: $__("Record matching settings"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        {
                            value: "create_new",
                            description: $__("Add incoming record"),
                        },
                        {
                            value: "ignore",
                            description: $__("Ignore incoming record"),
                        },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.value === val);
                        return opt ? opt.description : (val ?? "");
                    },
                    hideIn: ["List"],
                },
                {
                    name: "parse_items",
                    label: $__("Check for embedded item record data"),
                    type: "radio",
                    group: $__("Item processing"),
                    options: [
                        { value: true, description: $__("Yes") },
                        { value: false, description: $__("No") },
                    ],
                    defaultValue: true,
                    hideIn: ["List"],
                },
                {
                    name: "item_action",
                    label: $__("How to process items"),
                    type: "select",
                    group: $__("Item processing"),
                    selectLabel: "description",
                    requiredKey: "value",
                    options: [
                        {
                            value: "always_add",
                            description: $__("Always add items"),
                        },
                        {
                            value: "add_only_for_matches",
                            description: $__(
                                "Add items only if matching bib was found"
                            ),
                        },
                        {
                            value: "add_only_for_new",
                            description: $__(
                                "Add items only if no matching bib was found"
                            ),
                        },
                        {
                            value: "replace",
                            description: $__(
                                "Replace items if matching bib was found (only for existing items)"
                            ),
                        },
                        {
                            value: "ignore",
                            description: $__("Ignore items"),
                        },
                    ],
                    format: (val, resource, attr) => {
                        const opt = attr.options.find(o => o.value === val);
                        return opt ? opt.description : (val ?? "");
                    },
                    hideIn: ["List"],
                },
            ],
        });

        const tableOptions = {
            options: {
                embed: "vendor,budget",
            },
            url: baseResource.getResourceTableUrl(),
            table_settings: baseResource.marc_order_account_table_settings,
            add_filters: false,
            actions: {
                "-1": ["edit", "delete"],
            },
        };

        const onFormSave = (e, accountToSave) => {
            e.preventDefault();

            const account = JSON.parse(JSON.stringify(accountToSave));
            const marc_order_account_id = account.marc_order_account_id;

            delete account.marc_order_account_id;
            delete account.vendor;
            delete account.budget;

            if (marc_order_account_id) {
                return baseResource.apiClient
                    .update(account, marc_order_account_id)
                    .then(
                        updated => {
                            baseResource.setMessage(
                                $__("MARC order account updated")
                            );
                            return updated;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(account).then(
                    created => {
                        baseResource.setMessage(
                            $__("MARC order account created")
                        );
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
    name: "MarcOrderAccountResource",
    components: {
        BaseResource,
    },
};
</script>
