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
import { storeToRefs } from "pinia";
import { inject } from "vue";

export default {
    props: {
        routeAction: String,
    },
    setup(props) {
        const patron_to_html = $patron_to_html;

        const overduesStore = inject("overduesStore");
        const { settings } = storeToRefs(overduesStore);

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
                list: "BranchOverduesList",
                add: null,
                edit: null,
            },
            apiClient: APIClient.circulation.checkouts,
            table: {
                resourceTableUrl:
                    APIClient.circulation.httpClient._baseURL + "checkouts",
            },
            i18n: {
                displayName: $__("Overdue"),
                emptyListMessage: $__(
                    "There are no overdues with fines at your library"
                ),
            },
            props,
            defaultToolbarButtons,
            resourceAttrs: [
                {
                    type: "date",
                    name: "due_date",
                    label: $__("Due date"),
                },
                {
                    type: "text",
                    name: "item.biblio.title",
                    label: $__("Title"),
                    tableColumnDefinition: {
                        title: $__("Title"),
                        data: "item.biblio.title",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            const biblio = row.item?.biblio;
                            if (!biblio) {
                                return (
                                    '<span class="biblio-no-record">' +
                                    $__("No bibliographic record") +
                                    "</span>"
                                );
                            }
                            let titleString = biblio.title
                                ? escape_str(biblio.title)
                                : '<span class="biblio-no-title">' +
                                  $__("No title") +
                                  "</span>";
                            if (biblio.author)
                                titleString +=
                                    " / " + escape_str(biblio.author);
                            let result =
                                '<a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=' +
                                biblio.biblio_id +
                                '" class="title">' +
                                titleString +
                                "</a>";
                            if (row.item.external_id)
                                result +=
                                    '<br /><span class="barcode">' +
                                    escape_str(row.item.external_id) +
                                    "</span>";
                            return result;
                        },
                    },
                },
                {
                    type: "text",
                    name: "patron_id",
                    label: $__("Patron"),
                    tableColumnDefinition: {
                        title: $__("Patron"),
                        data: "patron.surname:patron.firstname",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            const { patron } = row;
                            let result =
                                '<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=' +
                                patron.patron_id +
                                '">' +
                                patron_to_html(patron) +
                                "</a>";
                            result +=
                                '<br /><span class="cardnumber">' +
                                escape_str(patron.cardnumber) +
                                "</span>";
                            if (patron.phone)
                                result +=
                                    '<br /><span class="phone">' +
                                    escape_str(patron.phone) +
                                    "</span>";
                            if (patron.email)
                                result +=
                                    '<br /><a href="mailto:' +
                                    escape_str(patron.email) +
                                    '">' +
                                    escape_str(patron.email) +
                                    "</a>";
                            return result;
                        },
                    },
                },
                {
                    type: "text",
                    name: "item.home_library.name",
                    label: $__("Location"),
                    tableColumnDefinition: {
                        title: $__("Location"),
                        data: "item.home_library.name",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            let result = row.item?.home_library?.name
                                ? escape_str(row.item.home_library.name)
                                : "";
                            if (row.item?.callnumber)
                                result +=
                                    '<br /><span class="callnumber">' +
                                    escape_str(row.item.callnumber) +
                                    "</span>";
                            return result;
                        },
                    },
                },
            ],
        });

        const tableUrl = () => {
            const url = baseResource.getResourceTableUrl();
            const query = {
                "me.library_id": settings.value.library_id,
                due_date: { "<": new Date() },
                "account_lines.amount_outstanding": { "!=": "0.000000" },
                "account_lines.debit_type": "OVERDUE",
                "account_lines.status": "UNRETURNED",
            };
            if (baseResource.route.query.location) {
                query["item.location"] = baseResource.route.query.location;
            }
            return url + `?q=${JSON.stringify(query)}`;
        };

        const tableOptions = {
            options: {
                embed: "patron,item.biblio,item.home_library,library,account_lines",
            },
            url: tableUrl(),
            table_settings: branch_table_settings,
        };

        return {
            ...baseResource,
            tableOptions,
            tableUrl,
        };
    },
    name: "BranchOverduesResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
