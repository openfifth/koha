<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { useRoute } from "vue-router";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
    },
    setup(props, { emit }) {
        const route = useRoute();
        const item_list_id = route.params.id;

        const baseResource = useBaseResource({
            emit: emit,
            resourceName: "items",
            nameAttr: "external_id",
            idAttr: "item_id",
            components: {
                show: null,
                list: "ItemListItemsList",
                add: "ItemListItemsAdd",
                edit: null,
            },
            parentResource: {
                apiClient: APIClient.item_lists.item_lists,
                idAttr: "id",
            },
            apiClient: APIClient.item_lists.items(item_list_id),
            table: {
                resourceTableUrl:
                    APIClient.item_lists.httpClient._baseURL +
                    "/" +
                    item_list_id +
                    "/items",
            },
            i18n: {
                removeConfirmationMessage: $__(
                    "Are you sure you want to remove this item from the list?"
                ),
                removeSuccessMessage: $__("Item %s removed"),
                displayName: $__("Item list"),
                editLabel: $__("Edit item list #%s"),
                emptyListMessage: $__("There are no items defined"),
                newLabel: $__("Add items"),
            },
            props,
            navigationOnFormSave: "ItemListItemsList",
            resourceAttrs: [
                {
                    name: "external_ids",
                    required: true,
                    type: "textarea",
                    label: $__("Barcodes"),
                    hideIn: ["List"],
                },
                {
                    name: "external_id",
                    type: "text",
                    required: true,
                    label: $__("Barcode"),
                    hideIn: ["Form"],
                    tableColumnDefinition: {
                        title: $__("Barcode"),
                        data: "external_id",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return (
                                '<a href="/cgi-bin/koha/catalogue/moredetail.pl?itemnumber=' +
                                row.item_id +
                                '">' +
                                row.external_id +
                                "</a>"
                            );
                        },
                    },
                },
                {
                    name: "callnumber",
                    required: true,
                    type: "text",
                    label: $__("Call Number"),
                    hideIn: ["Form"],
                },
                {
                    name: "holding_library.name",
                    required: true,
                    type: "text",
                    label: $__("Holding Library"),
                    hideIn: ["Form"],
                },
                {
                    name: "_strings.location.str",
                    required: true,
                    type: "text",
                    label: $__("Location"),
                    hideIn: ["Form"],
                },
                {
                    name: "item_type.description",
                    required: true,
                    type: "text",
                    label: $__("Item Type"),
                    hideIn: ["Form"],
                },
                {
                    name: "biblio.title",
                    required: true,
                    type: "text",
                    label: $__("Title"),
                    hideIn: ["Form"],
                    tableColumnDefinition: {
                        title: $__("Title"),
                        data: "biblio.title",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            let result = [row.biblio.title];
                            if (row.biblio.subtitle) {
                                result.push(...row.biblio.subtitle.split("|"));
                            }
                            return escape_str(result.join(" "));
                        },
                    },
                },
                {
                    name: "biblio.author",
                    required: true,
                    type: "text",
                    label: $__("Author"),
                    hideIn: ["Form"],
                },
            ],
        });

        const postVirtualForm = (action, data) => {
            let form = document.createElement("form");
            form.action = action;
            form.method = "POST";

            data["csrf_token"] = document.querySelector(
                'meta[name="csrf-token"]'
            ).content;

            for (const name in data) {
                let value = data[name];
                if (!Array.isArray(value)) {
                    value = [value];
                }
                for (const v of value) {
                    let input = document.createElement("input");
                    input.name = name;
                    input.type = "hidden";
                    input.value = v;
                    form.appendChild(input);
                }
            }
            document.body.appendChild(form);
            form.submit();
        };

        const batchEdit = ids => {
            const path = "/cgi-bin/koha/tools/batchMod.pl";
            return postVirtualForm(path, {
                itemnumber: ids,
                op: "cud-show",
            });
        };

        const batchDelete = ids => {
            const path = "/cgi-bin/koha/tools/batchMod.pl";
            return postVirtualForm(path, {
                itemnumber: ids,
                op: "cud-show",
                del: "1",
            });
        };

        const tableOptions = {
            options: {
                embed: "biblio,holding_library,item_type,+strings",
                order: [[1, "asc"]],
                additionalButtons: [
                    {
                        text: "Batch edit",
                        action: (e, dt, node, config) =>
                            batchEdit(
                                dt
                                    .rows({ selected: true })
                                    .data()
                                    .map(row => row.item_id)
                                    .toArray()
                            ),
                    },
                    {
                        text: "Batch delete",
                        action: (e, dt, node, config) =>
                            batchDelete(
                                dt
                                    .rows({ selected: true })
                                    .data()
                                    .map(row => row.item_id)
                                    .toArray()
                            ),
                    },
                ],
            },
            select: true,
            add_filters: true,
            url: baseResource.getResourceTableUrl(),
            actions: {
                "-1": ["remove"],
            },
        };

        const onFormSave = (e, itemToSave) => {
            e.preventDefault();
            const item = JSON.parse(JSON.stringify(itemToSave)); // copy
            const external_ids = item.external_ids.split("\n");

            return baseResource.apiClient.add(external_ids).then(
                resource => {
                    baseResource.setMessage($__("Items added!"));
                    return resource;
                },
                error => {}
            );
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
        };
    },
    name: "ItemListItemsResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
