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
            resourceName: "item_list_shares",
            nameAttr: "borrowernumber",
            idAttr: "borrowernumber",
            components: {
                show: null,
                list: "ItemListSharesList",
                add: "ItemListSharesAdd",
                edit: null,
            },
            parentResource: {
                apiClient: APIClient.item_lists.item_lists,
                idAttr: "id",
            },
            apiClient: APIClient.item_lists.shares(item_list_id),
            table: {
                resourceTableUrl:
                    APIClient.item_lists.httpClient._baseURL +
                    "/" +
                    item_list_id +
                    "/shares",
            },
            i18n: {
                removeConfirmationMessage: $__(
                    "Are you sure you want to remove this share from the list?"
                ),
                removeSuccessMessage: $__("Share %s removed"),
                displayName: $__("Item list shares"),
                editLabel: $__("Edit share #%s"),
                emptyListMessage: $__("There are no shares defined"),
                newLabel: $__("Add share"),
            },
            props,
            navigationOnFormSave: "ItemListSharesList",
            resourceAttrs: [
                {
                    name: "patron_id",
                    required: true,
                    type: "patronAutoComplete",
                    label: $__("Patron"),
                    hideIn: ["List"],
                },
                {
                    name: "patron.cardnumber",
                    type: "patronAutoComplete",
                    patronEmbedName: "patron",
                    label: $__("Patron"),
                    hideIn: ["Form"],
                },
                {
                    name: "permission",
                    required: true,
                    type: "select",
                    options: [
                        {
                            value: "view",
                            description: $__("View"),
                        },
                        {
                            value: "edit",
                            description: $__("Edit"),
                        },
                    ],
                    requiredKey: "value",
                    selectLabel: "description",
                    label: $__("Permission"),
                },
            ],
        });

        const tableOptions = {
            options: {
                embed: "patron",
            },
            url: baseResource.getResourceTableUrl(),
            actions: {
                "-1": ["remove"],
            },
        };

        const onFormSave = (e, shareToSave) => {
            e.preventDefault();
            const item = JSON.parse(JSON.stringify(shareToSave)); // copy

            return baseResource.apiClient
                .add(item.patron_id, item.permission)
                .then(
                    resource => {
                        baseResource.setMessage($__("Shared!"));
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
    name: "ItemListSharesResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
