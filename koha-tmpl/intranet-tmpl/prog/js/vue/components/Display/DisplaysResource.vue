<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>

<script>
import { inject } from "vue";
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
        const displayStore = inject("displayStore");
        const { isUserPermitted } = displayStore;
        const { config } = storeToRefs(displayStore);
        const { setError } = inject("mainStore");

        const filters = [];

        const additionalToolbarButtons = resource => {
            const additionalButtons = {
                list: [
                    {
                        action: "batch-add",
                        to: { name: "DisplaysBatchAddItems" },
                        icon: "plus",
                        title: $__("Batch add items from list"),
                    },
                    {
                        action: "batch-delete",
                        to: { name: "DisplaysBatchRemoveItems" },
                        icon: "minus",
                        title: $__("Batch remove items from list"),
                    },
                ],
            };

            return {
                list: additionalButtons.list.filter(
                    button =>
                        (button.action == "batch-add" &&
                            isUserPermitted(
                                "CAN_user_displays_manage_display_items"
                            )) ||
                        (button.action == "batch-delete" &&
                            isUserPermitted(
                                "CAN_user_displays_manage_display_items"
                            ))
                ),
            };
        };
        const defaultToolbarButtons = (defaultButtons, resource) => {
            return {
                list: defaultButtons.list.filter(
                    button =>
                        button.action == "add" &&
                        isUserPermitted("CAN_user_displays_add_displays")
                ),
                show: defaultButtons.show.filter(
                    button =>
                        (button.action == "edit" &&
                            isUserPermitted(
                                "CAN_user_displays_edit_displays"
                            )) ||
                        (button.action == "delete" &&
                            isUserPermitted(
                                "CAN_user_displays_delete_displays"
                            ))
                ),
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
                    tableColumnDefinition: {
                        title: $__("ID"),
                        data: "display_id",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return '<a href="/cgi-bin/koha/display/displays/%s">%s</a>'.format(
                                data,
                                data
                            );
                        },
                    },
                    hideIn: ["Form", "Show"],
                },
                {
                    group: $__("Display"),
                    name: "display_name",
                    label: $__("Name"),
                    type: "text",
                    required: true,
                },
                {
                    group: $__("Display"),
                    name: "display_branch",
                    label: $__("Display library"),
                    type: "relationshipSelect",
                    toolTip: $__(
                        "Optionally, specify a branch to restrict Display access to"
                    ),
                    breakAfter: true,
                    relationshipAPIClient: APIClient.library.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    tableColumnDefinition: {
                        title: $__("Display library"),
                        data: "display_branch",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.display_library === null)
                                return escape_str(``);
                            else
                                return escape_str(
                                    `${row["display_library"]["name"]}`
                                );
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "display_library.name",
                    },
                },
                {
                    group: $__("Display"),
                    name: "display_home_branch",
                    label: $__("Home library"),
                    type: "relationshipSelect",
                    toolTip: $__(
                        "Specifies the home library to use whilst an item is on display"
                    ),
                    relationshipAPIClient: APIClient.library.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    tableColumnDefinition: {
                        title: $__("Home library"),
                        data: "display_home_branch",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.home_library === null)
                                return escape_str(``);
                            else
                                return escape_str(
                                    `${row["home_library"]["name"]}`
                                );
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "home_library.name",
                    },
                },
                {
                    group: $__("Display"),
                    name: "display_holding_branch",
                    label: $__("Holding library"),
                    type: "relationshipSelect",
                    toolTip: $__(
                        "Specifies the holding library to use whilst an item is on display"
                    ),
                    relationshipAPIClient: APIClient.library.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    tableColumnDefinition: {
                        title: $__("Holding library"),
                        data: "display_holding_branch",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.holding_library === null)
                                return escape_str(``);
                            else
                                return escape_str(
                                    `${row["holding_library"]["name"]}`
                                );
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "holding_library.name",
                    },
                },
                {
                    group: $__("Display"),
                    name: "display_location",
                    label: $__("Shelving location"),
                    type: "select",
                    toolTip: $__(
                        "Specifies the shelving location to use whilst an item is on display"
                    ),
                    avCat: "av_loc",
                },
                {
                    group: $__("Display"),
                    name: "display_code",
                    label: $__("Collection code"),
                    type: "select",
                    toolTip: $__(
                        "Specifies the collection code to use whilst an item is on display"
                    ),
                    avCat: "av_ccode",
                },
                {
                    group: $__("Display"),
                    name: "display_itype",
                    label: $__("Item type"),
                    type: "relationshipSelect",
                    toolTip: $__(
                        "Specifies the item type to use whilst an item is on display"
                    ),
                    breakAfter: true,
                    relationshipAPIClient: APIClient.item_type.item_types,
                    relationshipOptionLabelAttr: "description",
                    relationshipRequiredKey: "item_type_id",
                    tableColumnDefinition: {
                        title: $__("Item type"),
                        data: "display_itype",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            if (row.item_type === null) return escape_str(``);
                            else
                                return escape_str(
                                    `${row["item_type"]["description"]}`
                                );
                        },
                    },
                    showElement: {
                        type: "text",
                        value: "item_type.description",
                    },
                },
                {
                    group: $__("Display"),
                    name: "display_days",
                    label: $__("Duration of display"),
                    type: "number",
                    toolTip: $__(
                        "Days in which items will remain on display. Blank value converts to 14 days"
                    ),
                    hideIn: ["List"],
                },
                {
                    group: $__("Display"),
                    name: "start_date",
                    label: $__("Start of display"),
                    type: "date",
                    toolTip: $__(
                        "When the display becomes effective. Blank value calculates to today"
                    ),
                    showElement: {
                        type: "text",
                        value: "start_date",
                        format: $date,
                    },
                },
                {
                    group: $__("Display"),
                    name: "end_date",
                    label: $__("End of display"),
                    type: "date",
                    toolTip: $__(
                        "When the display's effectiveness ends. Blank value calculates to today plus duration of display"
                    ),
                    breakAfter: true,
                    showElement: {
                        type: "text",
                        value: "end_date",
                        format: $date,
                    },
                },
                {
                    group: $__("Display"),
                    name: "staff_note",
                    label: $__("Staff note"),
                    type: "textarea",
                    toolTip: $__("Notes only visible on staff client"),
                    hideIn: ["List"],
                },
                {
                    group: $__("Display"),
                    name: "public_note",
                    label: $__("Public note"),
                    type: "textarea",
                    toolTip: $__("Notes visible on both staff client and OPAC"),
                    breakAfter: true,
                    hideIn: ["List"],
                },
                {
                    group: $__("Display"),
                    name: "display_return_over",
                    label: $__("Check in behaviour"),
                    type: "select",
                    required: true,
                    avCat: "av_display_return_over",
                    toolTip:
                        $__(
                            "Should we remove items from display on check-in?"
                        ) +
                        " " +
                        $__(
                            "This will initiate a transfer to their permenant home library, if applicable"
                        ),
                },
                {
                    group: $__("Display"),
                    name: "enabled",
                    label: $__("Enabled"),
                    type: "boolean",
                    tableColumnDefinition: {
                        title: $__("Enabled"),
                        data: "enabled",
                        searchable: false,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return data ? __("Yes") : __("No");
                        },
                    },
                    defaultValue: null,
                    required: true,
                },
                {
                    group: $__("Display items"),
                    name: "display_items",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "display_items",
                        hidden: display => !!display.display_items?.length,
                        columns: [
                            {
                                name: $__("Record title"),
                                value: "title",
                                link: {
                                    href: "/cgi-bin/koha/catalogue/detail.pl",
                                    params: {
                                        biblionumber: "biblionumber",
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
                            removeThisMessage: __("Remove this display item"),
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
                            label: $__("Date added"),
                            type: "date",
                            toolTip: $__(
                                "Date item becomes active on display. Blank value calculates to today"
                            ),
                            required: false,
                            indexRequired: true,
                        },
                        {
                            name: "date_remove",
                            label: $__("Date to remove"),
                            type: "date",
                            toolTip: $__(
                                "Date item becomes inactive on display. Blank value calculates to today plus duration of display"
                            ),
                            required: false,
                            indexRequired: true,
                        },
                    ],
                    hideIn: () => {
                        let hiddenIn = ["List"];

                        if (
                            !baseResource.isUserPermitted(
                                "CAN_user_displays_manage_display_items"
                            )
                        )
                            hiddenIn.push("Form");

                        return hiddenIn;
                    },
                },
            ],
            additionalToolbarButtons,
            defaultToolbarButtons,
            moduleStore: "displayStore",
            props: props,
        });

        const tableActions = () => {
            const canEdit = isUserPermitted("CAN_user_displays_edit_displays");
            const canDelete = isUserPermitted(
                "CAN_user_displays_delete_displays"
            );
            let actions = [];

            if (canEdit) actions.push("edit");
            if (canDelete) actions.push("delete");
            if (!canEdit && !canDelete) actions.push("show");

            return actions;
        };
        const tableOptions = {
            url: "/api/v1/displays/",
            options: {
                embed: "display_items,display_library,home_library,holding_library,item_type,+strings",
            },
            add_filters: true,
            actions: {
                0: ["show"],
                1: ["show"],
                "-1": tableActions(),
            },
        };

        const getDisplayFromId = async id => {
            const displaysApiClient = APIClient.display.displays;
            let display = undefined;

            await displaysApiClient
                .get(id)
                .then(data => {
                    display = data;
                })
                .catch(error => {
                    console.error(error);
                });

            return display;
        };

        const getBiblioFromId = async id => {
            const bibliosApiClient = APIClient.biblio.biblios;
            let biblio = undefined;

            await bibliosApiClient
                .get(id)
                .then(data => {
                    biblio = data;
                })
                .catch(error => {
                    console.error(error);
                });

            return biblio;
        };

        const getItemFromId = async id => {
            const itemsApiClient = APIClient.item.items;
            let item = undefined;

            await itemsApiClient
                .get(id)
                .then(data => {
                    item = data;
                })
                .catch(error => {
                    console.error(error);
                });

            return item;
        };

        const getItemFromExternalId = async external_id => {
            const itemsApiClient = APIClient.item.items;
            let item = undefined;

            await itemsApiClient
                .getByExternalId(external_id)
                .then(data => {
                    if (data.length > 0) item = data[0];
                })
                .catch(error => {
                    console.error(error);
                });

            return item;
        };

        const checkForm = async display => {
            let errors = [];

            let display_items = display.display_items;
            // Do not use display_item.name here! Its name is not the one linked with display_item.barcode
            // At this point display_item is meaningless, form/template only modified display_item.barcode
            const display_items_barcode = display_items.map(
                display_item => display_item.barcode
            );
            const duplicate_display_items_barcode =
                display_items_barcode.filter(
                    (barcode, i) => display_items_barcode.indexOf(barcode) !== i
                );
            if (duplicate_display_items_barcode.length)
                errors.push($__("A display item is used several times"));

            if (display.enabled == undefined)
                errors.push(
                    $__(
                        "Check that you have specified whether or not the display should be enabled"
                    )
                );

            for await (const [idx, display_item] of display_items.entries()) {
                const item = await getItemFromExternalId(display_item.barcode);
                display.display_items[idx].item = item; // store for use during onFormSave

                if (
                    item == undefined ||
                    item.item_id === undefined ||
                    item.external_id !== display_item.barcode
                ) {
                    errors.push(
                        $__("The barcode entered does not match an item")
                    );
                } else {
                    const dt_added = Date.parse(display_item.date_added);
                    const dt_remove = Date.parse(display_item.date_remove);

                    if (dt_remove < dt_added)
                        errors.push(
                            $__(
                                "You cannot have a date to remove before the date added"
                            )
                        );

                    if (
                        item.active_display &&
                        item.active_display.display_id !=
                            display_item.display_id
                    ) {
                        const active_display = await getDisplayFromId(
                            item.active_display.display_id
                        );

                        const errorStr = $__(
                            "The item entered is already on another active display. Set a date added for this item after the date added of the active display, or remove the item from the other display."
                        );

                        if (display_item.date_added == undefined)
                            errors.push(errorStr);

                        for (const active_display_item of active_display.display_items) {
                            if (active_display_item.itemnumber != item.item_id)
                                continue;

                            const dt_old = Date.parse(
                                active_display_item.date_added
                            );
                            const dt_new = Date.parse(display_item.date_added);

                            if (dt_new < dt_old) errors.push(errorStr);
                        }
                    }
                }
            }

            baseResource.setWarning(errors.join("<br>"));
            return !errors.length;
        };
        const onFormSave = async (e, displayToSave) => {
            e.preventDefault();

            const display = JSON.parse(JSON.stringify(displayToSave));
            const display_id = display.display_id;

            if (!(await checkForm(display))) {
                return false;
            }

            delete display.display_id;
            delete display.active;
            delete display.item_type;
            delete display.display_library;
            delete display.home_library;
            delete display.holding_library;
            delete display._strings;

            display.display_items = display.display_items.map(
                ({ display_item_id, barcode, ...keepAttrs }) => keepAttrs
            );

            let display_items = display.display_items;
            delete display.display_items;

            if (isUserPermitted("CAN_user_displays_manage_display_items")) {
                display.display_items = [];

                for await (const display_item of display_items) {
                    const item = display_item.item;
                    delete display_item.item;

                    display_item.biblionumber = item.biblio_id;
                    display_item.itemnumber = item.item_id;

                    await display.display_items.push(display_item);
                }
            }

            Object.entries(display).forEach(([key, value]) => {
                if (key == "enabled") return;
                if (value == "") display[key] = null;
            });

            if (display_id) {
                baseResource.apiClient.update(display, display_id).then(
                    success => {
                        baseResource.setMessage($__("Display updated"));
                        baseResource.router.push({ name: "DisplaysList" });
                    },
                    error => {
                        if (
                            error.message.includes(
                                "You do not have permission to manage display items"
                            )
                        )
                            setError(
                                $__(
                                    "Error: You do not have permission to manage display items"
                                ),
                                true
                            );
                        else
                            setError(
                                $__(
                                    "An error occurred while saving the display"
                                ),
                                true
                            );
                    }
                );
            } else {
                baseResource.apiClient.create(display).then(
                    success => {
                        baseResource.setMessage($__("Display created"));
                        baseResource.router.push({ name: "DisplaysList" });
                    },
                    error => {
                        if (
                            error.message.includes(
                                "You do not have permission to manage display items"
                            )
                        )
                            setError(
                                $__(
                                    "Error: You do not have permission to manage display items"
                                ),
                                true
                            );
                        else
                            setError(
                                $__(
                                    "An error occurred while saving the display"
                                ),
                                true
                            );
                    }
                );
            }
        };
        const afterResourceFetch = (componentData, resource, caller) => {
            if (caller === "show" || caller === "form") {
                resource.display_items.forEach((display_item, idx) => {
                    componentData.resource.value.display_items[idx].title =
                        __("Loading");
                    componentData.resource.value.display_items[idx].barcode =
                        __("Loading");

                    getItemFromId(display_item.itemnumber)
                        .then(item => {
                            componentData.resource.value.display_items[
                                idx
                            ].title =
                                item.biblio?.title || __("Unknown biblio");
                            componentData.resource.value.display_items[
                                idx
                            ].barcode = item.external_id;
                        })
                        .catch(error => {
                            console.error(error);
                        });
                });
            }
        };

        return {
            ...baseResource,
            isUserPermitted,
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
