<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { inject, onBeforeMount } from "vue";
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const DisplayStore = inject("DisplayStore");
        const { displayReturnOverMapping, config } = storeToRefs(DisplayStore);
        const { setError } = inject("mainStore");

        const filters = [];

        const additionalToolbarButtons = resource => {
            return {
                list: [
                    {
                        to: { name: "DisplaysBatchAddItems" },
                        icon: "plus",
                        title: $__("Batch add items from list"),
                    },
                    {
                        to: { name: "DisplaysBatchRemoveItems" },
                        icon: "minus",
                        title: $__("Batch remove items from list"),
                    },
                ],
            };
        };

        const baseResource = useBaseResource({
            resourceName: "displays",
            nameAttr: "display_name",
            idAttr: "display_id",
            components: {
                show: "DisplaysShow",
                list: "DisplaysList",
                add: "DisplaysFormAdd",
                edit: "DisplaysFormAddEdit",
            },
            apiClient: APIClient.display.displays,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this display?"
                ),
                deleteSuccessMessage: $__("Display %s deleted"),
                displayName: $__("Display"),
                editLabel: $__("Edit display #%s"),
                emptyListMessage: $__("There are no displays defined"),
                newLabel: $__("New display"),
            },
            table: {
                addFilters: true,
                resourceTableUrl:
                    APIClient.display.httpClientDisplays._baseURL + "",
                filters,
            },
            embedded: props.embedded,
            config,
            props,
            resourceAttrs: [
                {
                    name: "display_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "display_name",
                    label: $__("Name"),
                    type: "text",
                    required: true,
                },
                {
                    name: "display_branch",
                    label: $__("Home library"),
                    type: "relationshipSelect",
                    relationshipAPIClient:
                        APIClient.library.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    tableColumnDefinition: {
                        title: $__("Home library"),
                        data: "display_branch",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.home_library === null)
                                return (escape_str(
                                    ``
                                ));
                            else
                                return (escape_str(
                                    `${row["home_library"]["name"]}`
                                ));
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "home_library.name"
                    },
                },
                {
                    name: "display_holding_branch",
                    label: $__("Holding library"),
                    type: "relationshipSelect",
                    relationshipAPIClient:
                        APIClient.library.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    tableColumnDefinition: {
                        title: $__("Holding library"),
                        data: "display_holding_branch",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.holding_library === null)
                                return (escape_str(
                                    ``
                                ));
                            else
                                return (escape_str(
                                    `${row["holding_library"]["name"]}`
                                ));
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "holding_library.name"
                    },
                },
                {
                    name: "display_location",
                    label: $__("Shelving location"),
                    type: "select",
                    avCat: "av_loc",
                },
                {
                    name: "display_code",
                    label: $__("Collection code"),
                    type: "select",
                    avCat: "av_ccode",
                },
                {
                    name: "display_itype",
                    label: $__("Item type"),
                    type: "relationshipSelect",
                    relationshipAPIClient:
                        APIClient.item_type.item_types,
                    relationshipOptionLabelAttr: "description",
                    relationshipRequiredKey: "item_type_id",
                    tableColumnDefinition: {
                        title: $__("Item type"),
                        data: "display_itype",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.item_type === null)
                                return (escape_str(
                                    ``
                                ));
                            else
                                return (escape_str(
                                    `${row["item_type"]["description"]}`
                                ));
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "item_type.description"
                    },
                },
                {
                    name: "display_return_over",
                    label: $__("Return behaviour"),
                    hint: $__("Remove items from display on checkin"),
                    type: "select",
                    selectLabel: "value",
                    requiredKey: "variable",
                    options: displayReturnOverMapping.value,
                    defaultValue: null,
                    required: true,
                    tableColumnDefinition: {
                        title: $__("Return behaviour"),
                        data: "display_return_over",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            let this_value = '';

                            DisplayStore.displayReturnOverMapping.forEach(mapping => {
                                if(mapping.variable == data) this_value = mapping.value;
                            });

                            return (escape_str(
                                `${this_value}`
                            ));
                        },
                    },
                },
                {
                    name: "start_date",
                    label: $__("Start of display"),
                    hint: $__("When the display becomes effective"),
                    type: "date",
                },
                {
                    name: "end_date",
                    label: $__("End of display"),
                    hint: $__("When the display's effectiveness ends"),
                    type: "date",
                },
                {
                    name: "display_days",
                    label: $__("Duration of display"),
                    hint: $__("Days in which items will remain on display"),
                    type: "number",
                    hideIn: ["List"],
                },
                {
                    name: "staff_note",
                    label: $__("Staff note"),
                    hint: $__("Notes only visible on staff client"),
                    type: "textarea",
                    hideIn: ["List"],
                },
                {
                    name: "public_note",
                    label: $__("Public note"),
                    hint: $__("Notes visible on both staff client and OPAC"),
                    type: "textarea",
                    hideIn: ["List"],
                },
                {
                    name: "enabled",
                    label: $__("Enabled"),
                    type: "boolean",
                    required: true,
                },
                {
                    name: "display_items",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "display_items",
                        hidden: display => !!display.display_items?.length,
                        columns: [
                            {
                                name: $__("Record number"),
                                value: "biblionumber",
                                link: {
                                    href: "/cgi-bin/koha/catalogue/detail.pl",
                                    params: {
                                        biblionumber: "biblionumber",
                                    },
                                },
                            },
                            {
                                name: $__("Internal item number"),
                                value: "itemnumber",
                                link: {
                                    href: "/cgi-bin/koha/catalogue/moredetail.pl",
                                    params: {
                                        itemnumber: "itemnumber",
                                    },
                                },
                            },
                            {
                                name: $__("Item barcode"),
                                value: "barcode",
                                link: {
                                    href: "/cgi-bin/koha/catalogue/moredetail.pl",
                                    params: {
                                        itemnumber: "itemnumber",
                                    },
                                },
                            },
                            {
                                name: $__("Date added"),
                                value: "date_added",
                                format: $date,
                            },
                            {
                                name: $__("Date to remove"),
                                value: "date_remove",
                                format: $date,
                            },
                        ],
                    },
                    group: $__("Display items"),
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "display_items",
                        },
                        relationshipI18n: {
                            nameUpperCase: __("Display item"),
                            removeThisMessage: __(
                                "Remove this display item"
                            ),
                            addNewMessage: __("Add new display item"),
                            noneCreatedYetMessage: __(
                                "There are no display items created yet"
                            ),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                biblionumber: null,
                                itemnumber: null,
                                barcode: null,
                                date_added: null,
                                date_remove: null,
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            name: "barcode",
                            type: "text",
                            label: $__("Item barcode"),
                            required: true,
                            indexRequired: true,
                        },
                        {
                            name: "date_added",
                            type: "date",
                            label: $__("Date added"),
                            required: false,
                            indexRequired: true,
                        },
                        {
                            name: "date_remove",
                            type: "date",
                            label: $__("Date to remove"),
                            required: false,
                            indexRequired: true,
                        },
                    ],
                    hideIn: ["List"],
                },
            ],
            additionalToolbarButtons,
            moduleStore: "DisplayStore",
            props: props,
        });

        const tableOptions = {
            url: "/api/v1/displays/",
            options: {
                embed: "home_library,holding_library,item_type,+strings",
            },
            add_filters: true,
            actions: {
                0: ["show"],
                1: ["show"],
                "-1": ["edit", "delete"]
            },
        };

        const getItemFromId = (async id => {
            const itemsApiClient = APIClient.item.items;
            let item = undefined;

            await itemsApiClient.get(id)
            .then(data => {
                item = data;
            })
            .catch(error => {
                console.error(error);
            });

            return item;
        });

        const getItemFromExternalId = (async external_id => {
            const itemsApiClient = APIClient.item.items;
            let item = undefined;

            await itemsApiClient.getByExternalId(external_id)
            .then(data => {
                if (data.length == 1)
                    item = data[0];
            })
            .catch(error => {
                console.error(error);
            });

            return item;
        });

        const checkForm = (async display => {
            let errors = [];

            let display_items = display.display_items;
            // Do not use di.display_item.name here! Its name is not the one linked with di.display_item_id
            // At this point di.display_item is meaningless, form/template only modified di.display_item_id
            const display_item_ids = display_items.map(di => di.display_item_id);
            const duplicate_display_item_ids = display_item_ids.filter(
                (id, i) => display_item_ids.indexOf(id) !== i
            );

            if (duplicate_display_item_ids.length) {
                errors.push($__("A display item is used several times"));
            }

            for await (const display_item of display_items) {
                const item = await getItemFromExternalId(display_item.barcode);
                
                if (item == undefined || item.item_id === undefined || item.external_id !== display_item.barcode)
                    errors.push($__("The barcode entered does not match an item"));
            }

            baseResource.setWarning(errors.join("<br>"));
            return !errors.length;
        });
        const onFormSave = (async (e, displayToSave) => {
            e.preventDefault();

            const display = JSON.parse(JSON.stringify(displayToSave));
            const displayId = display.display_id;
            const epoch = new Date();

            if (!await checkForm(display)) {
                return false;
            }

            delete display.display_id;
            delete display.item_type;
            delete display.home_library;
            delete display.holding_library;
            delete display._strings;

            display.display_items = display.display_items.map(
                ({ display_item_id, ...keepAttrs }) =>
                    keepAttrs
            );

            let display_items = display.display_items;
            delete display.display_items;
            display.display_items = [];

            for await (const display_item of display_items) {
                const item = await getItemFromExternalId(display_item.barcode);

                delete display_item.barcode;

                display_item.biblionumber = item.biblio_id;
                display_item.itemnumber = item.item_id;

                await display.display_items.push(display_item);
            }

            if (display.start_date == null) display.start_date = epoch.toISOString().substr(0, 10);
            if (display.end_date == null && display.display_days != undefined) {
                let calculated_date = epoch;
                calculated_date.setDate(epoch.getDate() + Number(display.display_days));

                display.end_date = calculated_date.toISOString().substr(0, 10);
            }
            if (display.display_days == "") display.display_days = null;
            if (display.public_note == "") display.public_note = null;
            if (display.staff_note == "") display.staff_note = null;

            if (displayId) {
                baseResource.apiClient
                    .update(display, displayId)
                    .then(
                        success => {
                            baseResource.setMessage($__("Display updated"));
                            baseResource.router.push({ name: "DisplaysList" });
                        },
                        error => {}
                );
            } else {
                baseResource.apiClient.create(display).then(
                    success => {
                        baseResource.setMessage($__("Display created"));
                        baseResource.router.push({ name: "DisplaysList" });
                    },
                    error => {}
                );
            }
        });
        const afterResourceFetch = ((componentData, resource, caller) => {
            if(caller === "show" || caller === "form") {
                resource.display_items.forEach((display_item, idx) => {
                    getItemFromId(display_item.itemnumber)
                    .then(item => {
                        componentData.resource.value.display_items[idx] = {
                            barcode: item.external_id,
                            ...display_item,
                        };
                    })
                    .catch(error => {
                        console.error(error);
                    });
                });
            }
        });

        onBeforeMount(() => {});

        return {
            ...baseResource,
            tableOptions,
            checkForm,
            onFormSave,
            afterResourceFetch,
        };
    },
    emits: ["select-resource"],
    name: "DisplaysResource",
    components: {
        BaseResource,
    },
};
</script>
