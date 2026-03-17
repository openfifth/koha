<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import BaseResource from "../../BaseResource.vue";
import { useBaseResource } from "../../../composables/base-resource.js";
import { APIClient } from "../../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
    },
    setup(props) {
        const defaultToolbarButtons = () => {
            return {
                list: [],
            };
        };

        const baseResource = useBaseResource({
            resourceName: "overdue",
            idAttr: "issue_id",
            components: {
                show: null,
                list: "OverduesList",
                add: null,
                edit: null,
            },
            apiClient: APIClient.circulation.checkouts,
            table: {
                resourceTableUrl:
                    APIClient.circulation.httpClient._baseURL +
                    "api/v1/checkouts",
            },
            i18n: {
                displayName: $__("Overdue"),
                emptyListMessage: $__("There are no overdues"),
            },
            props,
            defaultToolbarButtons,
            resourceAttrs: [],
        });

        const tableUrl = () => {};
        const tableOptions = {
            options: {},
            url: tableUrl(),
            actions: {
                "-1": [],
            },
        };

        return {
            ...baseResource,
            tableOptions,
            tableUrl,
        };
    },
    name: "OverduesResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
