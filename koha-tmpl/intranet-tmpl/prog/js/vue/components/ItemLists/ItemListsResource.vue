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
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
    },
    setup(props) {
        const visibilityLabels = {
            private: $__("Private"),
            group: $__("Group"),
            public: $__("Public"),
        };

        const baseResource = useBaseResource({
            resourceName: "item_list",
            nameAttr: "name",
            idAttr: "id",
            components: {
                show: "ItemListItemsList",
                list: "ItemListsList",
                add: "ItemListsFormAdd",
                edit: "ItemListsFormAddEdit",
            },
            apiClient: APIClient.item_lists.item_lists,
            table: {
                resourceTableUrl: APIClient.item_lists.httpClient._baseURL,
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this item list?"
                ),
                deleteSuccessMessage: $__("Item list %s deleted"),
                displayName: $__("Item list"),
                editLabel: $__("Edit item list #%s"),
                emptyListMessage: $__("There are no item lists defined"),
                newLabel: $__("New item list"),
            },
            props,
            navigationOnFormSave: "ItemListsList",
            resourceAttrs: [
                {
                    name: "id",
                    required: true,
                    type: "text",
                    label: $__("ID"),
                    hideIn: ["Form"],
                },
                {
                    name: "name",
                    required: true,
                    type: "text",
                    label: $__("Name"),
                },
                {
                    name: "item_list_contents_count",
                    required: true,
                    type: "number",
                    label: $__("Items"),
                    hideIn: ["Form"],
                },
                {
                    name: "owner",
                    required: true,
                    type: "patronAutoComplete",
                    label: $__("Owner"),
                    hideIn: ["List"],
                },
                {
                    name: "visibility",
                    required: true,
                    type: "select",
                    options: Object.entries(visibilityLabels).map(x => ({
                        value: x[0],
                        description: x[1],
                    })),
                    requiredKey: "value",
                    selectLabel: "description",
                    label: $__("Visibility"),
                    tableColumnDefinition: {
                        title: $__("Visibility"),
                        data: "visibility",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            let result = visibilityLabels[row.visibility];
                            if (row.item_list_shares_count == 1) {
                                result = $__("%s (%s share)").format(
                                    visibilityLabels[row.visibility],
                                    row.item_list_shares_count
                                );
                            } else if (row.item_list_shares_count > 1) {
                                result = $__("%s (%s shares)").format(
                                    visibilityLabels[row.visibility],
                                    row.item_list_shares_count
                                );
                            }
                            return (
                                '<a href="/cgi-bin/koha/lists/items/' +
                                row.id +
                                '/shares">' +
                                escape_str(result) +
                                "</a>"
                            );
                        },
                    },
                },
                {
                    name: "created_date",
                    type: "date",
                    label: $__("Created Date"),
                    required: false,
                    hideIn: ["Form"],
                },
                {
                    name: "updated_date",
                    type: "date",
                    label: $__("Updated Date"),
                    required: false,
                    hideIn: ["Form"],
                },
            ],
        });

        const tableOptions = {
            options: {
                embed: "item_list_contents+count,item_list_shares+count",
            },
            url: baseResource.getResourceTableUrl(),
            actions: {
                "-1": ["edit", "delete"],
            },
        };

        const onFormSave = (e, itemListToSave) => {
            e.preventDefault();
            const itemList = JSON.parse(JSON.stringify(itemListToSave)); // copy
            const itemListId = itemList.id;

            delete itemList.id;
            delete itemList.item_list_contents_count;
            delete itemList.created_date;
            delete itemList.updated_date;

            if (itemListId) {
                // update
                return baseResource.apiClient.update(itemList, itemListId).then(
                    resource => {
                        baseResource.setMessage($__("Item list updated!"));
                        return resource;
                    },
                    error => {}
                );
            } else {
                return baseResource.apiClient.create(itemList).then(
                    resource => {
                        baseResource.setMessage($__("Item list created!"));
                        return resource;
                    },
                    error => {}
                );
            }
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
        };
    },
    name: "ItemListsResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
