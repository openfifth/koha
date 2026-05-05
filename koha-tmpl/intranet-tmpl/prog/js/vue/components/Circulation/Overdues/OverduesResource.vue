<template>
    <div v-if="showFilterPrompt">
        <h1>{{ $__("Overdue report") }}</h1>
        <p>{{ $__("Please choose one or more filters to proceed.") }}</p>
    </div>
    <BaseResource
        v-else
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
import { inject, computed } from "vue";

export default {
    props: {
        routeAction: String,
    },
    setup(props) {
        const patron_to_html = $patron_to_html;
        const format_date = $date;

        const overduesStore = inject("overduesStore");
        const { authorisedValues, settings, itemTypes } =
            storeToRefs(overduesStore);

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
                    APIClient.circulation.httpClient._baseURL + "checkouts",
            },
            i18n: {
                displayName: $__("Overdue"),
                emptyListMessage: $__("There are no overdues"),
            },
            props,
            defaultToolbarButtons,
            additionalSlotComponents: {
                list: {
                    header: "@koha-vue/components/Circulation/Overdues/OverduesHeader.vue",
                },
            },
            resourceAttrs: [
                {
                    type: "date",
                    name: "due_date",
                    label: $__("Due date"),
                    tableColumnDefinition: {
                        title: $__("Due date"),
                        data: "due_date",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            const formatted = format_date(row.due_date);
                            if (new Date(row.due_date) < new Date()) {
                                return `<span class="overdue">${formatted}</span>`;
                            }
                            return formatted;
                        },
                    },
                },
                {
                    type: "text",
                    name: "patron_id",
                    label: $__("Patron"),
                    tableColumnDefinition: {
                        title: $__("Patron"),
                        data: "patron.firstname:patron.surname:patron.other_name:patron.preferred_name:patron.email",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            const { patron, item } = row;
                            if (!patron.cardnumber && !patron.patron_id) {
                                return escape_str(
                                    $__("A patron from library %s").format(
                                        patron.library.name
                                    )
                                );
                            }
                            let patronString =
                                '<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=' +
                                patron.patron_id +
                                '">' +
                                patron_to_html(patron) +
                                "</a>";
                            if (patron.email)
                                patronString +=
                                    `<span class="overdue_email"> [<a href="mailto:${patron.email}?subject=` +
                                    $__("Overdue") +
                                    `: ${item.biblio.title}">email</a>] </span>`;
                            const phone =
                                patron.phone ||
                                patron.mobile ||
                                patron.secondary_phone;
                            if (phone)
                                patronString += `<span class="overdue_phone">(${phone})</span>`;
                            return patronString;
                        },
                    },
                },
                {
                    type: "text",
                    name: "patron.category.name",
                    label: $__("Patron category"),
                },
                {
                    type: "text",
                    name: "library.name",
                    label: $__("Patron library"),
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
                            if (row.item.biblio) {
                                const biblioData = row.item.biblio;
                                const {
                                    IntranetBiblioDefaultView: defaultView,
                                    viewMARC,
                                    viewLabelledMARC,
                                    viewISBD,
                                } = settings.value;
                                let url = "";
                                if (defaultView === "marc" && viewMARC)
                                    url =
                                        "/cgi-bin/koha/catalogue/MARCdetail.pl?biblionumber=";
                                else if (
                                    defaultView === "labeled_marc" &&
                                    viewLabelledMARC
                                )
                                    url =
                                        "/cgi-bin/koha/catalogue/labeledMARCdetail.pl?biblionumber=";
                                else if (defaultView === "isbd" && viewISBD)
                                    url =
                                        "/cgi-bin/koha/catalogue/ISBDdetail.pl?biblionumber=";
                                else
                                    url =
                                        "/cgi-bin/koha/catalogue/detail.pl?biblionumber=";
                                url += biblioData.biblio_id;

                                let titleString = "";
                                if (!biblioData.title)
                                    titleString +=
                                        '<span class="biblio-no-title">' +
                                        $__("No title") +
                                        "</span>";
                                else
                                    titleString +=
                                        '<span class="biblio-title">%s</span>'.format(
                                            biblioData.title
                                        );

                                if (biblioData.medium)
                                    titleString +=
                                        '<span class="biblio-medium">%s</span>'.format(
                                            biblioData.medium
                                        );

                                if (biblioData.subtitles) {
                                    const subtitles =
                                        biblioData.subtitles.split(" \\| ");
                                    subtitles.forEach(st => {
                                        if (
                                            settings.value.marcflavour ===
                                            "unimarc"
                                        )
                                            titleString += ",";
                                        titleString +=
                                            '<span class="subtitle">%s</span>'.format(
                                                st
                                            );
                                    });
                                }
                                if (
                                    biblioData.part_number ||
                                    biblioData.part_name
                                ) {
                                    const partNumbers =
                                        biblioData.part_number?.split(
                                            " \\| "
                                        ) || [];
                                    const partNames =
                                        biblioData.part_name?.split(" \\| ") ||
                                        [];
                                    const iteratorValue =
                                        partNumbers.length > partNames.length
                                            ? partNumbers.length
                                            : partNames.length;
                                    let i = 0;
                                    while (i < iteratorValue) {
                                        if (partNumbers[i]) {
                                            titleString +=
                                                '<span class="part-number">%s</span>'.format(
                                                    partNumbers[i]
                                                );
                                        }
                                        if (partNames[i]) {
                                            titleString +=
                                                '<span class="part-name">%s</span>'.format(
                                                    partNames[i]
                                                );
                                        }
                                        i++;
                                    }
                                }
                                if (
                                    biblioData.author ||
                                    row.item.serial_issue_number
                                ) {
                                    let biblioTitle =
                                        '<a href="' +
                                        url +
                                        '" class="title">' +
                                        titleString +
                                        "</a>";
                                    if (biblioData.author)
                                        biblioTitle +=
                                            ", " +
                                            $__("by ") +
                                            biblioData.author;
                                    if (row.item.serial_issue_number)
                                        biblioTitle +=
                                            ", " + row.item.serial_issue_number;
                                    return biblioTitle;
                                } else {
                                    return (
                                        '<a href="' +
                                        url +
                                        '" class="title">' +
                                        titleString +
                                        "</a>"
                                    );
                                }
                            } else {
                                return (
                                    '<span class="biblio-no-record">' +
                                    $__("No bibliographic record") +
                                    "</span>"
                                );
                            }
                        },
                    },
                },
                {
                    type: "text",
                    name: "item.home_library.name",
                    label: $__("Home library"),
                },
                {
                    type: "text",
                    name: "item.holding_library.name",
                    label: $__("Holding library"),
                },
                {
                    type: "text",
                    name: "item.location",
                    label: $__("Shelving location"),
                    tableColumnDefinition: {
                        title: $__("Shelving location"),
                        data: "item.location",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return row.item.location
                                ? (authorisedValues.value.location.find(
                                      av => av.value === row.item.location
                                  )?.description ?? "")
                                : "";
                        },
                    },
                },
                {
                    type: "date",
                    name: "checkout_date",
                    label: $__("Checked out on"),
                },
                {
                    type: "text",
                    name: "item.external_id",
                    label: $__("Barcode"),
                    tableColumnDefinition: {
                        title: $__("Barcode"),
                        data: "item.external_id",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return (
                                '<a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=' +
                                row.item.biblio_id +
                                "&amp;itemnumber=" +
                                row.item.item_id +
                                "#item" +
                                row.item.item_id +
                                '">' +
                                row.item.external_id +
                                "</a>"
                            );
                        },
                    },
                },
                {
                    type: "text",
                    name: "item.callnumber",
                    label: $__("Call number"),
                },
                {
                    type: "text",
                    name: "item.item_type_id",
                    label: $__("Item type"),
                    tableColumnDefinition: {
                        title: $__("Item type"),
                        data: "item.item_type_id",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return (
                                itemTypes.value.find(
                                    it =>
                                        it.item_type_id ===
                                        row.item.item_type_id
                                )?.description ?? ""
                            );
                        },
                    },
                },
                {
                    type: "text",
                    name: "item.replacement_price",
                    label: $__("Price"),
                    tableColumnDefinition: {
                        title: $__("Price"),
                        data: "item.replacement_price",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return Number(
                                row.item.replacement_price
                            ).format_price();
                        },
                    },
                },
                {
                    type: "text",
                    name: "item.internal_notes",
                    label: $__("Non-public note"),
                },
                ...(settings.value.ClaimReturnedLostValue
                    ? [
                          {
                              type: "text",
                              name: "item.return_claim.created_on",
                              label: $__("Return claims"),
                              tableColumnDefinition: {
                                  title: $__("Return claims"),
                                  data: "item.return_claim.created_on",
                                  searchable: true,
                                  orderable: true,
                                  render: function (data, type, row, meta) {
                                      if (row.item.return_claim?.created_on) {
                                          return '<span class="badge text-bg-info">%s</span>'.format(
                                              format_date(
                                                  row.item.return_claim
                                                      .created_on
                                              )
                                          );
                                      } else {
                                          return (
                                              '<a class="btn btn-default btn-xs claim-returned-btn" data-itemnumber="' +
                                              row.item.item_id +
                                              '"> <i class="fa fa-exclamation-circle"></i> ' +
                                              $__("Claim returned") +
                                              " </a>"
                                          );
                                      }
                                  },
                              },
                          },
                      ]
                    : []),
            ],
        });

        const tableUrl = () => {
            let url = baseResource.getResourceTableUrl();
            const urlQueryParams = { ...baseResource.route.query };

            const overdueQuery = {};
            const filterToDbMapping = {
                category: "patron.categorycode",
                item_type: settings.value["item-level_itypes"]
                    ? "item.itype"
                    : "item.biblioitem.itemtype",
                item_home_library: "item.home_library_id",
                item_holding_library: "item.holding_library_id",
                patron_library: "patron.library_id",
            };
            Object.keys(urlQueryParams).forEach(key => {
                const mappedField = filterToDbMapping[key];
                if (mappedField) {
                    overdueQuery[mappedField] = urlQueryParams[key];
                    delete urlQueryParams[key];
                }
            });
            const today = new Date();
            if (urlQueryParams.patron_name) {
                const patronName = urlQueryParams.patron_name
                    .replace(/\*/g, "%")
                    .replace(/\?/g, "_");
                overdueQuery["-or"] = [];
                overdueQuery["-or"].push({
                    "patron.firstname": { "-like": patronName + "%" },
                });
                overdueQuery["-or"].push({
                    "patron.surname": { "-like": patronName + "%" },
                });
                overdueQuery["-or"].push({
                    "patron.cardnumber": { "-like": patronName + "%" },
                });
                delete urlQueryParams.patron_name;
            }
            if (urlQueryParams.patron_flag) {
                switch (urlQueryParams.patron_flag) {
                    case "gone_no_address":
                        overdueQuery["patron.incorrect_address"] = { "!=": 0 };
                        break;
                    case "debarred":
                        overdueQuery["patron.debarred"] = { ">=": today };
                        break;
                    case "lost":
                        overdueQuery["patron.patron_card_lost"] = { "!=": 0 };
                        break;
                }
                delete urlQueryParams.patron_flag;
            }
            if (
                urlQueryParams.showall === "false" &&
                !urlQueryParams.due_date_to
            )
                overdueQuery.due_date = { "<": today };
            if (urlQueryParams.due_date_from)
                overdueQuery.due_date = {
                    ">=": new Date(urlQueryParams.due_date_from),
                };
            if (urlQueryParams.due_date_to) {
                const dueDateTo = new Date(urlQueryParams.due_date_to);
                dueDateTo.setHours(23, 59, 59, 999);
                overdueQuery.due_date = { "<=": dueDateTo };
            }
            if (urlQueryParams.due_date_from && urlQueryParams.due_date_to) {
                const startDate = new Date(urlQueryParams.due_date_from);
                startDate.setDate(startDate.getDate() - 1);
                const endDate = new Date(urlQueryParams.due_date_to);
                endDate.setDate(endDate.getDate() + 1);
                overdueQuery.due_date = { "-between": [startDate, endDate] };
            }
            delete urlQueryParams.showall;
            delete urlQueryParams.due_date_from;
            delete urlQueryParams.due_date_to;

            const extendedAttributes = Object.keys(urlQueryParams);
            if (extendedAttributes.length) {
                overdueQuery["-and"] = [];
                extendedAttributes.forEach(attr => {
                    if (Array.isArray(urlQueryParams[attr])) {
                        urlQueryParams[attr].forEach(val => {
                            overdueQuery["-and"].push({
                                "patron.extended_attributes.code": attr,
                                "patron.extended_attributes.attribute": val,
                            });
                        });
                    } else {
                        overdueQuery["-and"].push({
                            "patron.extended_attributes.code": attr,
                            "patron.extended_attributes.attribute":
                                urlQueryParams[attr],
                        });
                    }
                });
            }

            url += `?q=${JSON.stringify(overdueQuery)}`;

            return url;
        };
        const tableOptions = {
            options: {
                embed: "patron,patron.library,patron.category,patron.extended_attributes,item.biblio,item.biblioitem,item.holding_library,item.home_library,library",
                pagingType: "full",
            },
            url: tableUrl(),
            table_settings,
        };

        const showFilterPrompt = computed(
            () =>
                settings.value.FilterBeforeOverdueReport == 1 &&
                !Object.keys(baseResource.route.query).length
        );

        return {
            ...baseResource,
            tableOptions,
            tableUrl,
            showFilterPrompt,
        };
    },
    name: "OverduesResource",
    emits: ["select-resource"],
    components: {
        BaseResource,
    },
};
</script>
