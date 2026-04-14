<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { inject } from "vue";
import { storeToRefs } from "pinia";
import BaseResource from "../../BaseResource.vue";
import { useBaseResource } from "../../../composables/base-resource.js";
import { APIClient } from "../../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    inheritAttrs: false,
    setup(props) {
        const patron_to_html = $patron_to_html;

        const acquisitionsStore = inject("acquisitionsStore");
        const { user } = storeToRefs(acquisitionsStore);
        const { formatValueWithCurrency } = acquisitionsStore;

        const defaultToolbarButtons = () => ({ list: [], show: [] });

        const additionalFilters = [
            {
                name: "mine_filter",
                type: "button",
                label: $__("Mine"),
                activeValue: "true",
                immediateFilter: true,
            },
            {
                name: "mine_filter",
                type: "button",
                label: $__("All"),
                activeValue: "",
                immediateFilter: true,
            },
        ];

        const baseResource = useBaseResource({
            resourceName: "suggestion",
            nameAttr: "title",
            idAttr: "suggestion_id",
            components: {
                list: "SuggestionList",
            },
            apiClient: APIClient.acquisition.suggestions,
            i18n: {
                displayName: $__("Suggestion"),
                emptyListMessage: $__("There are no accepted suggestions"),
            },
            table: {
                resourceTableUrl: "/api/v1/suggestions",
                addAdditionalFilters: true,
                additionalFilters,
                hideFilterButton: true,
            },
            props,
            defaultToolbarButtons,
            resourceAttrs: [
                {
                    name: "suggestion_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "title",
                    tableColumnDefinition: {
                        title: $__("Suggestion"),
                        data: "title",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row) {
                            if (type !== "display") return data || "";
                            let parts = [];
                            if (row.title)
                                parts.push(
                                    `<strong>${escape_str(row.title)}</strong>`
                                );
                            if (row.author) parts.push(escape_str(row.author));
                            if (row.copyright_date)
                                parts.push(
                                    `© ${escape_str(row.copyright_date)}`
                                );
                            if (row.volume_desc)
                                parts.push(escape_str(row.volume_desc));
                            if (row.isbn) parts.push(escape_str(row.isbn));
                            if (row.publisher_code)
                                parts.push(escape_str(row.publisher_code));
                            if (row.publication_year)
                                parts.push(escape_str(row.publication_year));
                            if (row.publication_place)
                                parts.push(escape_str(row.publication_place));
                            if (row.note)
                                parts.push(`<em>${escape_str(row.note)}</em>`);
                            return parts.join(" - ");
                        },
                    },
                },
                {
                    name: "item_type",
                    tableColumnDefinition: {
                        title: $__("Document type"),
                        data: "item_type",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row) {
                            const val =
                                row._strings?.item_type?.str || data || "";
                            return type === "display" ? escape_str(val) : val;
                        },
                    },
                },
                {
                    name: "suggester",
                    tableColumnDefinition: {
                        title: $__("Suggested by"),
                        data: "suggester",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row) {
                            if (type !== "display") return "";
                            if (!row.suggester) return "";
                            return `<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=${row.suggester.patron_id}">${patron_to_html(row.suggester)}</a>`;
                        },
                    },
                },
                {
                    name: "manager",
                    tableColumnDefinition: {
                        title: $__("Accepted by"),
                        data: "manager",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row) {
                            if (type !== "display") return "";
                            if (!row.manager) return "";
                            return `<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=${row.manager.patron_id}">${patron_to_html(row.manager)}</a>`;
                        },
                    },
                },
                {
                    name: "library_id",
                    tableColumnDefinition: {
                        title: $__("Library"),
                        data: "library_id",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row) {
                            const val = row.library?.name || data || "";
                            return type === "display" ? escape_str(val) : val;
                        },
                    },
                },
                {
                    name: "budget_id",
                    tableColumnDefinition: {
                        title: $__("Fund"),
                        data: "budget_id",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row) {
                            const val = row.fund?.name || "";
                            return type === "display" ? escape_str(val) : val;
                        },
                    },
                },
                {
                    name: "item_price",
                    tableColumnDefinition: {
                        title: $__("Price"),
                        data: "item_price",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row) {
                            if (type !== "display") return data ?? "";
                            return row.item_price != null
                                ? escape_str(
                                      formatValueWithCurrency(row.item_price)
                                  )
                                : "";
                        },
                    },
                },
                {
                    name: "quantity",
                    tableColumnDefinition: {
                        title: $__("Quantity"),
                        data: "quantity",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row) {
                            if (type !== "display") return data ?? "";
                            return row.quantity > 0
                                ? escape_str(row.quantity)
                                : "";
                        },
                    },
                },
                {
                    name: "total_price",
                    tableColumnDefinition: {
                        title: $__("Total"),
                        data: "total_price",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row) {
                            if (type !== "display") return data ?? "";
                            return row.total_price != null
                                ? escape_str(
                                      formatValueWithCurrency(row.total_price)
                                  )
                                : "";
                        },
                    },
                },
            ],
        });

        const tableUrl = filters => {
            const baseQuery = { "me.status": "ACCEPTED" };
            if (filters.mine_filter === "true") {
                const borrowernumber = user.value.loggedInUser.borrowernumber;
                return (
                    "/api/v1/suggestions?" +
                    new URLSearchParams({
                        q: JSON.stringify({
                            "-and": [
                                baseQuery,
                                { "me.managed_by": borrowernumber },
                            ],
                        }),
                    })
                );
            }
            return (
                "/api/v1/suggestions?" +
                new URLSearchParams({ q: JSON.stringify(baseQuery) })
            );
        };

        const filterTable = async (filters, table) => {
            let { href } = baseResource.router.resolve({
                name: "SuggestionList",
            });
            window.history.pushState(
                {},
                "",
                baseResource.build_url(href, filters)
            );
            table.redraw(tableUrl(filters));
        };

        const getTableFilterFormElementsLabel = () => $__("Filter by:");

        const tableOptions = {
            url: () =>
                tableUrl(
                    baseResource.getFilterValues(
                        baseResource.route.query,
                        additionalFilters
                    )
                ),
            add_filters: true,
            options: {
                embed: "+strings,manager,suggester,library,fund",
            },
            actions: {
                "-1": [
                    {
                        add_orderline: {
                            text: $__("Order"),
                            icon: "fa fa-plus",
                            callback: suggestion => {
                                baseResource.router.push({
                                    name: "OrderlineFormAdd",
                                    query: {
                                        suggestion_id: suggestion.suggestion_id,
                                        ...(suggestion.biblio_id && {
                                            biblionumber: suggestion.biblio_id,
                                        }),
                                    },
                                });
                            },
                        },
                    },
                ],
            },
        };

        return {
            ...baseResource,
            tableOptions,
            filterTable,
            getTableFilterFormElementsLabel,
        };
    },
    emits: ["select-resource"],
    name: "SuggestionResource",
    components: {
        BaseResource,
    },
};
</script>
