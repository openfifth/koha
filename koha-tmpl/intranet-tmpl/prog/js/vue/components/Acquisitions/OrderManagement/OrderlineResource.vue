<template>
    <BaseResource
        v-show="readyToDisplay"
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>

<script>
import BaseResource from "../../BaseResource.vue";
import { APIClient } from "../../../fetch/api-client.js";
import { useBaseResource } from "../../../composables/base-resource";
import { $__ } from "@koha-vue/i18n";
import { computed, inject, provide, reactive, ref } from "vue";
import { storeToRefs } from "pinia";
import { useRoute } from "vue-router";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const format_date = $date;

        const acquisitionsStore = inject("acquisitionsStore");
        const { currencies, sysprefs } = storeToRefs(acquisitionsStore);
        const {
            getCurrencyConversionRate,
            getActiveCurrency,
            formatValueWithCurrency,
            differentCurrenciesInLedgers,
            applyNumberValidation,
        } = acquisitionsStore;
        const mainStore = inject("mainStore");
        const { loading, loaded } = mainStore;
        loading();

        const route = useRoute();
        const queryParams = route.query;

        const createItemsWhen = ref(sysprefs.value.acq_create_items);
        const createItems = computed(() => {
            return createItemsWhen.value;
        });
        const nonBibliographic = ref(
            route.query.no_biblio === "true" ? true : false
        );

        const subComponentsReady = reactive({ biblio: false, items: false });
        const updateSubComponentReadyState = key => {
            subComponentsReady[key] = true;
        };
        provide("subComponentsReady", {
            subComponentsReady,
            updateSubComponentReadyState,
        });
        const readyToDisplay = computed(() => {
            if (
                ["add", "edit"].includes(props.routeAction) &&
                !nonBibliographic.value
            ) {
                const ready = Object.keys(subComponentsReady).every(
                    el => subComponentsReady[el]
                );
                if (ready) {
                    loaded();
                    return true;
                } else {
                    return false;
                }
            }
            loaded();
            return true;
        });

        const orderlineStatuses = ref({
            draft: "DRAFT",
            new: "NEW",
            ordered: "ORDERED",
            continuing: "CONTINUING",
            complete: "COMPLETE",
            partial: "PARTIAL",
            unsubscribed: "UNSUBSCRIBED",
            cancelled: "CANCELLED",
        });

        const createItemsDefault = () => {
            if (nonBibliographic.value) {
                return "cataloging";
            }
            return sysprefs.value.acq_create_items;
        };

        let componentToDisplay =
            props.routeAction.charAt(0).toUpperCase() +
            props.routeAction.slice(1);
        if (["add", "edit"].includes(props.routeAction)) {
            componentToDisplay = "Form";
        }

        const baseResource = useBaseResource({
            resourceName: "orderline",
            nameAttr: "orderline_id",
            idAttr: "orderline_id",
            components: {
                show: "OrderlineShow",
                list: "OrderlineList",
                add: "OrderlineFormAdd",
                edit: "OrderlineFormAddEdit",
            },
            apiClient: APIClient.acquisition.orderlines,
            table: {
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL + "orderlines",
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this orderline?"
                ),
                deleteSuccessMessage: $__("Orderline %s deleted"),
                displayName: $__("Orderline"),
                editLabel: $__("Edit orderline #%s"),
                emptyListMessage: $__("There are no orderlines defined"),
                newLabel: $__("New orderline"),
                searchLabel: $__("Search orderlines"),
            },
            formGroupsDisplayMode: "accordion",
            showGroupsDisplayMode: "splitScreen",
            searchGroupsDisplayMode: "splitScreen",
            splitScreenGroupings: {
                show: [
                    { pane: 1, groups: ["Order information"] },
                    { pane: 2, groups: ["General information"] },
                    { pane: "break", groups: ["Catalog details"] },
                    { pane: 3, groups: ["Accounting details"] },
                ],
                search: [
                    {
                        pane: 1,
                        groups: ["Order information", "Additional fields"],
                    },
                    {
                        pane: 2,
                        groups: [
                            "Bibliographic information",
                            "Purchase order information",
                            "Payment information",
                        ],
                    },
                ],
            },
            extendedAttributesResourceType: "orderline",
            props,
            moduleStore: "acquisitionsStore",
            resourceAttrs: [
                //ACQTODO: orderline templates
                {
                    name: "orderline_id",
                    label: $__("Orderline ID"),
                    type: "text",
                    group:
                        componentToDisplay === "Search"
                            ? $__("Order information")
                            : $__("General information"),
                    displaySortOrder: {
                        Search: 6,
                    },
                    hideIn: ["Form"],
                },
                {
                    name: "is_continuous",
                    type: componentToDisplay === "Show" ? "text" : "checkbox",
                    group:
                        componentToDisplay === "Form"
                            ? $__("Order type")
                            : $__("Order information"),
                    label: ["Form", "Search"].includes(componentToDisplay)
                        ? $__("Continuous")
                        : $__("Order type"),
                    format: orderline =>
                        orderline.is_continuous
                            ? $__("Continuous")
                            : $__("One-Time"),
                    defaultValue: false,
                    toolTip:
                        componentToDisplay == "Search"
                            ? null
                            : $__(
                                  "Use continuous if you will receive multiple invoices, e.g. for serial subscriptions. If you use the option 'continuous' the option to create items when ordering is disabled. Items can be created on receiving or later in the catalog (without link to the order line)"
                              ),
                    displaySortOrder: {
                        Search: 11,
                    },
                    hideIn: ["List"],
                },
                {
                    name: "renewal_required",
                    group:
                        componentToDisplay !== "Search"
                            ? $__("Order type")
                            : $__("Order information"),
                    type: "checkbox",
                    label: $__("Renewal required"),
                    defaultValue: false,
                    disabled: resource => !resource.is_continuous,
                    displaySortOrder: {
                        Search: 12,
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "last_review_before",
                    group: $__("Order information"),
                    type: "date",
                    label: $__("Last review before"),
                    displaySortOrder: {
                        Search: 13,
                    },
                    hideIn: ["List", "Show", "Form"],
                },
                {
                    name: "planned_cancellation_date",
                    type:
                        componentToDisplay === "Search"
                            ? "indented_subfields"
                            : "date",
                    group:
                        componentToDisplay !== "Search"
                            ? $__("Order type")
                            : $__("Order information"),
                    label: $__("Planned cancellation"),
                    componentProps: {
                        disabled: {
                            resourceProperty: "is_continuous",
                            qualifier: "!",
                        },
                    },
                    subFields: [
                        {
                            name: "planned_cancellation_date_start",
                            type: "date",
                            label: $__("Between"),
                        },
                        {
                            name: "planned_cancellation_date_end",
                            type: "date",
                            label: $__("And"),
                        },
                    ],
                    displaySortOrder: {
                        Search: 14,
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "acquisition_method",
                    type: "select",
                    group:
                        componentToDisplay === "Form"
                            ? $__("Acquisition method")
                            : $__("Order information"),
                    label: $__("Acquisition method"),
                    avCat: "av_acquisition_method",
                    hideIn: ["List", "Search"],
                },
                {
                    name: "create_items",
                    group: nonBibliographic.value
                        ? $__("Item creation")
                        : $__("Catalog details"),
                    label: $__("Create items when"),
                    type: "radio",
                    options: [
                        {
                            description: $__("Ordering"),
                            value: "ordering",
                            disabled: nonBibliographic.value,
                        },
                        {
                            description: $__("Receiving"),
                            value: "receiving",
                            disabled: nonBibliographic.value,
                        },
                        { description: $__("Cataloging"), value: "cataloging" },
                    ],
                    defaultValue: createItemsDefault(),
                    onChange: resource => {
                        createItemsWhen.value = resource.create_items;
                        if (resource.create_items !== "ordering") {
                            resource.quantity_ordered = 1;
                        }
                    },
                    toolTip: nonBibliographic.value
                        ? null
                        : $__(
                              "Based on the value in the AcqCreateItem system preference"
                          ),
                    hideIn: ["List", "Show", "Search"],
                },
                ...(nonBibliographic.value
                    ? [
                          {
                              name: "material_type",
                              type: "select",
                              group: $__("Information (non-bibliographic)"),
                              label: $__("Type"),
                              avCat: "av_non_bibliographic_material_type",
                              hideIn: ["List", "Search"],
                          },
                          {
                              name: "non_bib_description",
                              type: "text",
                              group: $__("Information (non-bibliographic)"),
                              label: $__("Description"),
                              hideIn: ["List", "Search"],
                          },
                          {
                              name: "non_bib_information",
                              type: "text",
                              group: $__("Information (non-bibliographic)"),
                              label: $__("Information"),
                              hideIn: ["List", "Search"],
                          },
                          {
                              name: "product_number",
                              type: "text",
                              group: $__("Information (non-bibliographic)"),
                              label: $__("Product no."),
                              hideIn: ["List", "Search"],
                          },
                          {
                              name: "non_bib_note",
                              type: "text",
                              group: $__("Information (non-bibliographic)"),
                              label: $__("Note"),
                              hideIn: ["List", "Search"],
                          },
                      ]
                    : []),
                ...(!nonBibliographic.value
                    ? [
                          {
                              name: "biblio",
                              group:
                                  componentToDisplay === "Search"
                                      ? $__("Bibliographic information")
                                      : $__("Catalog details"),
                              type: "component",
                              componentPath:
                                  "@koha-vue/components/Acquisitions/OrderManagement/BiblioMarcFields.vue",
                              componentProps: {
                                  resource: {
                                      type: "resource",
                                      value: null,
                                  },
                                  unimarc: {
                                      type: "boolean",
                                      value:
                                          sysprefs.value.marc_flavour ===
                                          "UNIMARC",
                                  },
                                  useAcqFramework: {
                                      type: "boolean",
                                      value:
                                          sysprefs.value
                                              .use_acq_framework_for_biblio_records ===
                                          "0"
                                              ? false
                                              : true,
                                  },
                                  biblionumber: {
                                      type: "string",
                                      value: queryParams.biblionumber,
                                  },
                                  createItems: {
                                      type: "object",
                                      value: createItems,
                                  },
                                  ...(componentToDisplay === "Search" && {
                                      isSearch: {
                                          type: "boolean",
                                          value: true,
                                      },
                                  }),
                              },
                              tableColumnDefinition: {
                                  title: $__("Summary"),
                                  data: "biblio.title",
                                  searchable: true,
                                  orderable: true,
                                  render(data, type, row, meta) {
                                      return row.biblio
                                          ? '<a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=' +
                                                row.biblio.biblio_id +
                                                '" class="show">' +
                                                escape_str(row.biblio.title) +
                                                "</a>"
                                          : "";
                                  },
                              },
                              showElement: {
                                  type: "text",
                                  label: $__("ISBD / Title information"),
                                  format: biblio => {
                                      let biblioString = "";
                                      const fieldsToAppend = [
                                          "title",
                                          "author",
                                          "isbn",
                                          "publisher",
                                          "publication_year",
                                      ];
                                      fieldsToAppend.forEach(field => {
                                          if (biblioString.length)
                                              biblioString += " ";
                                          if (
                                              field == "author" &&
                                              biblio.author
                                          )
                                              biblioString += "by ";
                                          if (field == "isbn" && biblio.isbn)
                                              biblioString += "ISBN: ";

                                          if (biblio[field])
                                              biblioString += biblio[field];

                                          if (
                                              !["title"].includes(field) &&
                                              biblio[field]
                                          )
                                              biblioString += ".";
                                          if (
                                              field == "title" &&
                                              !biblio.author
                                          )
                                              biblioString += ".";
                                      });
                                      return biblioString;
                                  },
                                  link: {
                                      href: "/cgi-bin/koha/catalogue/detail.pl",
                                      params: {
                                          biblionumber: "biblionumber",
                                      },
                                  },
                              },
                              hideIn: [],
                          },
                          {
                              name: "items",
                              group: $__("Catalog details"),
                              type: "component",
                              componentPath:
                                  "@koha-vue/components/Acquisitions/OrderManagement/ItemMarcFieldsCopy.vue",
                              defaultValue: [],
                              showElement: {
                                  type: "table",
                                  label: $__("Ordered items"),
                                  hidden: resource => !!resource.items?.length,
                                  columnData: "items",
                                  columns: [
                                      {
                                          name: $__("Item ID"),
                                          value: "item_id",
                                          link: {
                                              href: "/cgi-bin/koha/catalogue/moredetail.pl",
                                              params: {
                                                  biblionumber: "biblio_id",
                                                  itemnumber: "item_id",
                                              },
                                              fragment: resource =>
                                                  `item${resource.item_id}`,
                                          },
                                      },
                                      {
                                          name: $__("Item type"),
                                          value: "item_type.description",
                                      },
                                      {
                                          name: $__("Location"),
                                          value: "location",
                                      },
                                      {
                                          name: $__("Collection"),
                                          value: "collection_code",
                                      },
                                  ],
                              },
                              componentProps: {
                                  resource: {
                                      type: "resource",
                                      value: null,
                                  },
                                  biblioNumber: {
                                      type: "string",
                                      value: queryParams.biblionumber,
                                  },
                                  orderNumber: {
                                      type: "string",
                                      value: queryParams.ordernumber,
                                  },
                                  frameworkCode: {
                                      type: "string",
                                      value: "ACQ",
                                  },
                                  createItems: {
                                      type: "object",
                                      value: createItems,
                                  },
                              },
                              hideIn: ["List"],
                          },
                      ]
                    : []),
                {
                    name: "patrons_to_notify",
                    group: $__("Patrons to notify"),
                    type: "patronSearch",
                    label: $__("Notify on receiving"),
                    componentProps: {
                        name: {
                            type: "string",
                            value: "patrons_to_notify",
                        },
                        required: {
                            type: "boolean",
                            value: false,
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        fieldName: {
                            type: "string",
                            value: "patrons_to_notify",
                        },
                        modalType: {
                            type: "string",
                            value: "add",
                        },
                    },
                    // showElement: {
                    //     type: "text",
                    //     value: "owner",
                    //     format: patron_to_html,
                    // },
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "managing_branch",
                    group:
                        componentToDisplay === "Form"
                            ? $__("Management in library")
                            : $__("Order information"),
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
                    tableColumnDefinition: {
                        title: $__("Managing library"),
                        data: "managing_library.name",
                        searchable: true,
                        orderable: true,
                        render(data, type, row, meta) {
                            return row.managing_library
                                ? '<a href="/cgi-bin/koha/admin/branches.pl?op=view&branchcode=' +
                                      row.managing_branch +
                                      '" class="show">' +
                                      escape_str(row.managing_library.name) +
                                      "</a>"
                                : row.managing_branch;
                        },
                    },
                    displaySortOrder: {
                        Search: 4,
                    },
                    hideIn: [],
                },
                {
                    name: "managed_by",
                    group: $__("Management in library"),
                    type: "patronSearch",
                    label: $__("Managed by"),
                    componentProps: {
                        name: {
                            type: "string",
                            value: "managed_by",
                        },
                        required: {
                            type: "boolean",
                            value: false,
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        fieldName: {
                            type: "string",
                            value: "managed_by",
                        },
                        modalType: {
                            type: "string",
                            value: "add",
                        },
                    },
                    // showElement: {
                    //     type: "text",
                    //     value: "owner",
                    //     format: patron_to_html,
                    // },
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "vendor_id",
                    group:
                        componentToDisplay === "Form"
                            ? $__("Vendor selection")
                            : $__("Order information"),
                    type: "relationshipSelect",
                    showElement: {
                        type: "text",
                        value: "vendor.name",
                        link: {
                            href: "/cgi-bin/koha/acquisition/vendors",
                            slug: "vendor_id",
                        },
                    },
                    label: $__("Vendor"),
                    relationshipAPIClient: APIClient.acquisition.vendors,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "id",
                    toolTip:
                        componentToDisplay == "Search"
                            ? null
                            : $__(
                                  "If you leave the vendor empty the orderline can only be saved as a draft"
                              ),
                    tableColumnDefinition: {
                        title: $__("Vendor"),
                        data: "vendor.name",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return row.vendor_id != undefined
                                ? '<a href="/cgi-bin/koha/acquisition/vendors/' +
                                      row.vendor_id +
                                      '">' +
                                      escape_str(row.vendor.name) +
                                      "</a>"
                                : "";
                        },
                    },
                    onSelected:
                        componentToDisplay === "Search"
                            ? null
                            : (e, options, resource) => {
                                  const vendor = options.find(
                                      option => option.id === e
                                  );
                                  // resource.tax_rate = vendor.tax_rate;
                                  resource.vendor = vendor;
                                  resource.fund_distributions.forEach(fd => {
                                      fd.tax_rate = vendor.tax_rate;
                                  });
                              },
                    displaySortOrder: {
                        Search: 1,
                    },
                    hideIn: [],
                },
                {
                    name: "quantity_ordered",
                    id: "quantity",
                    group: $__("Accounting details"),
                    type: "number",
                    label: $__("Quantity"),
                    defaultValue: null,
                    size: 6,
                    disabled: resource => {
                        return (
                            sysprefs.value.acq_create_items === "ordering" &&
                            resource.create_items === "ordering"
                        );
                    },
                    hideIn: ["Search"],
                },
                {
                    name: "vendor_price",
                    group: $__("Accounting details"),
                    type: "number",
                    required: true,
                    label: $__("Price"),
                    defaultValue: null,
                    size: 6,
                    ...applyNumberValidation(),
                    hideIn: ["Search"],
                },
                {
                    name: "vendor_price_currency",
                    group: $__("Accounting details"),
                    type: "select",
                    selectLabel: "currency",
                    requiredKey: "currency",
                    label: $__("Currency"),
                    options: currencies.value,
                    onSelected: (e, options, resource) => {
                        if (
                            resource.fund_distributions.length &&
                            differentCurrenciesInLedgers
                        ) {
                            resource.fund_distributions.forEach(fd => {
                                const fxRate = getCurrencyConversionRate(
                                    e,
                                    fd.fund?.currency
                                );
                                resource.distribution_exchange_rate = fxRate;
                                fd.exchange_rate = fxRate;
                            });
                        } else {
                            resource.distribution_exchange_rate =
                                getCurrencyConversionRate(e, null);
                        }
                    },
                    defaultValue: null,
                    hideIn: ["List", "Search"],
                },
                {
                    name: "uncertain_price",
                    group: $__("Accounting details"),
                    type: "checkbox",
                    label: $__("Uncertain price"),
                    defaultValue: false,
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "discount",
                    group: $__("Accounting details"),
                    type: "component",
                    label: $__("Discount"),
                    componentPath:
                        "@koha-vue/components/Acquisitions/OrderManagement/InputNumberPercentageToggle.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        percentageField: {
                            type: "string",
                            value: "discount_percentage",
                        },
                        amountField: {
                            type: "string",
                            value: "discount_amount_oc",
                        },
                    },
                    hideIn: ["List", "Show", "Search"],
                },
                // {
                //     name: "replacement_price",
                //     group: $__("Accounting details"),
                //     type: "number",
                //     label: $__("Replacement cost"),
                //     defaultValue: null,
                //     size: 6,
                //     hideIn: ["List"],
                // },
                // {
                //     name: "tax_rate",
                //     group: $__("Accounting details"),
                //     type: "select",
                //     label: $__("Tax rate"),
                //     options: gstValues.value,
                //     defaultValue: null,
                //     selectLabel: "label",
                //     requiredKey: "value",
                //     hideIn: ["List"],
                // },
                {
                    name: "price_summary",
                    group: $__("Accounting details"),
                    type: "component",
                    componentPath:
                        "@koha-vue/components/Acquisitions/OrderManagement/PriceSummary.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                    },
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "calculated_amount_oc",
                    type: "component",
                    group: $__("Fund / fund distributions"),
                    componentPath:
                        "@koha-vue/components/Acquisitions/OrderManagement/CalculatedAmount.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        currency: {
                            type: "string",
                            value: "original",
                        },
                    },
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "fund_distributions",
                    type:
                        componentToDisplay === "Search"
                            ? "relationshipSelect"
                            : "relationshipWidget",
                    defaultValue: [
                        {
                            fund_id: null,
                            percentage: null,
                            distributed_amount_oc: null,
                            exchange_rate: null,
                            distributed_amount: null,
                            tax_rate: null,
                            tax_value: null,
                            distributed_amount_tax_excluded: null,
                            distributed_amount_tax_included: null,
                        },
                    ],
                    group:
                        componentToDisplay === "Search"
                            ? $__("Order information")
                            : $__("Fund / fund distributions"),
                    apiClient: APIClient.acquisition.funds,
                    relationshipAPIClient: APIClient.acquisition.funds,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "fund_id",
                    label:
                        componentToDisplay === "Search"
                            ? $__("Fund ordered")
                            : null,
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "fund_distributions",
                        },
                        relationshipI18n: {
                            nameLowerCase: $__("fund distribution"),
                            namePlural: $__("funds"),
                            nameUpperCase: $__("Fund distribution"),
                            noneCreatedYetMessage: $__(
                                "There are no funds created yet"
                            ),
                            addNewMessage: $__("Add new fund distribution"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                fund_id: null,
                                percentage: null,
                                distributed_amount_oc: null,
                                exchange_rate: null,
                                distributed_amount: null,
                                tax_rate: null,
                                tax_value: null,
                                distributed_amount_tax_excluded: null,
                                distributed_amount_tax_included: null,
                            },
                        },
                        resource: {
                            type: "resource",
                            value: null,
                        },
                        fetchOptions: {
                            type: "boolean",
                            value: true,
                        },
                        disabled: {
                            type: "function",
                            value: resource => {
                                // if(!resource.fund_distributions?.length) return false
                                if (
                                    resource.fund_distributions?.length &&
                                    (!resource.fund_distributions[0].fund_id ||
                                        resource.totalDistributedAmount ===
                                            resource.calculated_amount_oc)
                                )
                                    return true;
                                return false;
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            type: "component",
                            componentPath:
                                "@koha-vue/components/Acquisitions/OrderManagement/FundDistributionForm.vue",
                            indexRequired: true,
                            componentProps: {
                                resource: {
                                    type: "resource",
                                    value: null,
                                },
                                options: {
                                    type: "parentProp",
                                    value: null,
                                },
                            },
                            hideIn: ["List", "Show"],
                        },
                    ],
                    tableColumnDefinition: {
                        title: $__("Fund(s)"),
                        data: "fund_distributions",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row, meta) {
                            let fundList;
                            row.fund_distributions.forEach((fd, i) => {
                                fundList +=
                                    '<a href="/cgi-bin/koha/acquisitions/finances/fund/' +
                                    fd.fund_id +
                                    '">' +
                                    escape_str(row.fund.name) +
                                    "</a>";
                                if (i + 1 !== row.fund_distributions.length)
                                    fundList += "\n";
                            });
                        },
                    },
                    displaySortOrder: {
                        Search: 5,
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "distribution_exchange_rate",
                    group: $__("Fund / fund distributions"),
                    label: $__("Exchange rate"),
                    type: "number",
                    defaultValue: 1.0,
                    size: 6,
                    hint: resource => {
                        return `(${resource.vendor_price_currency || getActiveCurrency.currency} to ${resource?.fund_distributions?.[0]?.fund?.currency || getActiveCurrency.currency})`;
                    },
                    onChange: resource => {
                        resource.fund_distributions.forEach(fd => {
                            fd.exchange_rate =
                                resource.distribution_exchange_rate;
                            fd.calculateDistributedAmount(fd);
                        });
                    },
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "replacement_price",
                    group: $__("Fund / fund distributions"),
                    label: $__("Item replacement cost"),
                    type: "number",
                    defaultValue: 1.0,
                    size: 6,
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "calculated_item_costs",
                    type: "component",
                    group: $__("Fund / fund distributions"),
                    componentPath:
                        "@koha-vue/components/Acquisitions/OrderManagement/CalculatedAmount.vue",
                    componentProps: {
                        resource: {
                            type: "resource",
                            value: null,
                        },
                    },
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "statistic1",
                    group:
                        componentToDisplay == "Search"
                            ? $__("Order information")
                            : $__("Reporting information"),
                    type: "text",
                    label: $__("Statistic 1"),
                    displaySortOrder: {
                        Search: 7,
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "statistic2",
                    group:
                        componentToDisplay == "Search"
                            ? $__("Order information")
                            : $__("Reporting information"),
                    type: "text",
                    label: $__("Statistic 2"),
                    displaySortOrder: {
                        Search: 8,
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "urgent_order",
                    group:
                        componentToDisplay === "Search"
                            ? $__("Order information")
                            : $__("Notes"),
                    type: "checkbox",
                    label: $__("Rush / urgent order"),
                    defaultValue: false,
                    displaySortOrder: {
                        Search: 9,
                    },
                    hideIn: ["List", "Show"],
                },
                {
                    name: "internal_note",
                    group:
                        componentToDisplay === "Form"
                            ? $__("Notes")
                            : $__("Order information"),
                    type: componentToDisplay === "Search" ? "text" : "textarea",
                    textAreaRows: 5,
                    label: $__("Internal note"),
                    displaySortOrder: {
                        Search: 2,
                    },
                    hideIn: [],
                },
                {
                    name: "receiving_note",
                    group: $__("Notes"),
                    type: "textarea",
                    textAreaRows: 5,
                    label: $__("Receiving note"),
                    toolTip: $__(
                        "The receiving note will be displayed when you receive the order line"
                    ),
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "vendor_note",
                    group:
                        componentToDisplay === "Form"
                            ? $__("Notes")
                            : $__("Order information"),
                    type: componentToDisplay === "Search" ? "text" : "textarea",
                    textAreaRows: 5,
                    label: $__("Vendor note"),
                    displaySortOrder: {
                        Search: 3,
                    },
                    hideIn: [],
                },
                {
                    name: "estimated_delivery_date",
                    type: "date",
                    group: $__("Notes"),
                    label: $__("Estimated delivery date"),
                    defaultValue: null,
                    hideIn: ["List", "Show", "Search"],
                },
                {
                    name: "status",
                    type: componentToDisplay === "Search" ? "select" : "text",
                    group:
                        componentToDisplay == "Search"
                            ? $__("Order information")
                            : $__("General information"),
                    label: $__("Status"),
                    format: status => orderlineStatuses.value[status],
                    defaultValue:
                        componentToDisplay === "Search" ? null : "new",
                    selectLabel: "label",
                    requiredKey: "status",
                    options: Object.keys(orderlineStatuses.value).map(
                        status => {
                            return {
                                label: orderlineStatuses.value[status],
                                status,
                            };
                        }
                    ),
                    displaySortOrder: {
                        Search: 3.1,
                    },
                    hideIn: ["List", "Form"],
                },
                {
                    name: "created_date",
                    type:
                        componentToDisplay === "Search"
                            ? "indented_subfields"
                            : "date",
                    group:
                        componentToDisplay !== "Search"
                            ? $__("General information")
                            : $__("Order information"),
                    label:
                        componentToDisplay !== "Search"
                            ? $__("Created on")
                            : $__("Created date"),
                    format: format_date,
                    subFields: [
                        {
                            name: "created_date_start",
                            type: "date",
                            label: $__("Between"),
                        },
                        {
                            name: "created_date_end",
                            type: "date",
                            label: $__("And"),
                        },
                    ],
                    displaySortOrder: {
                        Search: 10,
                    },
                    hideIn: ["List", "Form"],
                },
                {
                    name: "modified_date",
                    type: "date",
                    group: $__("General information"),
                    label: $__("Last modified"),
                    format: format_date,
                    hideIn: ["List", "Form", "Search"],
                },
            ],
        });

        const tableOptions = {
            table_settings: null,
            add_filters: true,
            options: {
                embed: "vendor,biblio,managing_library",
            },
            actions: {
                0: ["show"],
                "-1": [
                    ...(baseResource.isUserPermitted("editOrderline")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("deleteOrderline")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const handleAPIFormSubmission = (
            orderline,
            orderline_id,
            headers = {}
        ) => {
            if (orderline_id) {
                return baseResource.apiClient
                    .update(orderline, orderline_id)
                    .then(
                        orderline => {
                            baseResource.setMessage($__("Orderline updated"));
                            return orderline;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(orderline, headers).then(
                    orderline => {
                        baseResource.setMessage($__("Orderline created"));
                        return orderline;
                    },
                    error => {
                        if (error.message === "bib_match") {
                            const handleCheckboxes = (fields, key) => {
                                const relevantKeys = Object.keys(fields).filter(
                                    key =>
                                        ![
                                            "orderline",
                                            "duplicate_biblio",
                                        ].includes(key)
                                );
                                const valueOfCheckboxUsed = fields[key];
                                relevantKeys.forEach(rk => {
                                    if (valueOfCheckboxUsed && rk !== key) {
                                        fields[rk] = false;
                                    }
                                });
                            };
                            baseResource.setConfirmationDialog(
                                {
                                    title: $__("Duplicate warning"),
                                    message:
                                        $__(
                                            "The details you entered match an existing record in your catalog: "
                                        ) +
                                        `<a href='/cgi-bin/koha/catalogue/detail.pl?biblionumber=${error.duplicate_biblio.biblionumber}'>${error.duplicate_biblio.title}</a>`,
                                    accept_label: $__("Select"),
                                    cancel_label: $__("Cancel"),
                                    inputs: [
                                        {
                                            name: "duplicate_biblio",
                                            type: "hidden",
                                            value: error.duplicate_biblio,
                                        },
                                        {
                                            name: "orderline",
                                            type: "hidden",
                                            value: error.orderline,
                                        },
                                        {
                                            name: "use_existing",
                                            type: "checkbox",
                                            label: $__("Use existing record"),
                                            value: true,
                                            onChange: fields => {
                                                handleCheckboxes(
                                                    fields,
                                                    "use_existing"
                                                );
                                            },
                                            toolTip: $__(
                                                "Do not create a duplicate record. Add an order from the existing record in your catalog."
                                            ),
                                        },
                                        {
                                            name: "cancel",
                                            type: "checkbox",
                                            label: $__(
                                                "Cancel and return to order"
                                            ),
                                            value: false,
                                            onChange: fields => {
                                                handleCheckboxes(
                                                    fields,
                                                    "cancel"
                                                );
                                            },
                                            toolTip: $__(
                                                "Return to the basket without making a new order."
                                            ),
                                        },
                                        {
                                            name: "create_new",
                                            type: "checkbox",
                                            label: $__("Create new record"),
                                            value: false,
                                            onChange: fields => {
                                                handleCheckboxes(
                                                    fields,
                                                    "create_new"
                                                );
                                            },
                                            toolTip: $__(
                                                "Create a new record with the details you entered."
                                            ),
                                        },
                                    ],
                                    size: "modal-lg",
                                },
                                handleDuplicateBiblio
                            );
                        }
                    }
                );
            }
        };

        const handleDuplicateBiblio = (confirmation, inputFields) => {
            const {
                duplicate_biblio,
                orderline,
                use_existing,
                cancel,
                create_new,
            } = inputFields;

            if (cancel) return;
            if (create_new) {
                handleAPIFormSubmission(orderline, orderline.orderline_id, {
                    "x-confirm-not-duplicate": "1",
                });
            }
            if (use_existing) {
                orderline.biblionumber = duplicate_biblio.biblionumber;
                handleAPIFormSubmission(orderline, orderline.orderline_id);
            }
        };

        const onFormSave = (e, orderlineToSave) => {
            e.preventDefault();
            // TODOs:
            // Need to check all costs distributed (resource.remainderToDistribute)
            // Various new prperties added to support reactivity through different components, delete here to avoid API spec conflict

            if (!baseResource.isUserPermitted("createOrderline")) {
                setWarning(
                    $__(
                        "You do not have the required permissions to create orderlines."
                    )
                );
                return;
            }

            const orderline = JSON.parse(JSON.stringify(orderlineToSave));
            const orderline_id = orderline.orderline_id;

            delete orderline.orderline_id;
            delete orderline.distribution_exchange_rate;
            delete orderline.price_summary;
            delete orderline.remainderToDistribute;
            delete orderline.vendor;
            delete orderline.calculated_item_costs;
            delete orderline.discount;
            delete orderline.totalDistributedAmount;
            delete orderline.modified_date;
            delete orderline.created_date;
            delete orderline.last_review_before;

            if (orderline.quantity_ordered === null) {
                // Throw error if create_items === "ordering" and none created
                orderline.quantity_ordered = 1;
            }

            orderline.managed_by = orderline.managed_by?.map(mp => {
                return { borrowernumber: mp };
            });
            orderline.patrons_to_notify = orderline.patrons_to_notify?.map(
                mp => {
                    return { borrowernumber: mp };
                }
            );

            orderline.items.forEach(item => {
                Object.keys(item).forEach(key => {
                    if (!item[key]) delete item[key];
                });
            });

            return handleAPIFormSubmission(orderline, orderline_id);
        };

        const handleResourceSearch = (e, searchParams) => {
            e.preventDefault();

            const formatDateWindows = (startKey, endKey) => {
                if (searchParams[startKey] || searchParams[endKey]) {
                    const searchKey = startKey.replace("_start", "");
                    searchParams[searchKey] = {
                        ...(searchParams[startKey] && {
                            ">=": searchParams[startKey],
                        }),
                        ...(searchParams[endKey] && {
                            "<=": searchParams[endKey],
                        }),
                    };
                }
                delete searchParams[startKey];
                delete searchParams[endKey];
            };
            formatDateWindows("created_date_start", "created_date_end");
            formatDateWindows(
                "planned_cancellation_date_start",
                "planned_cancellation_date_end"
            );

            baseResource.router.push({
                name: "OrderlineList",
                query: searchParams,
            });
        };

        const navigationOnFormSaveAdditionalOptions = resource => {
            return [
                {
                    title: $__("Save as draft"),
                    action: "submit",
                    cssClass: "btn btn-default",
                    callback: () => {
                        resource.value.status = "draft";
                    },
                },
            ];
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            navigationOnFormSaveAdditionalOptions,
            handleResourceSearch,
            readyToDisplay,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "OrderlineResource",
};
</script>
