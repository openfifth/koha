<template>
    <div v-if="createItems.value === 'ordering'">
        <div v-show="items.length" id="items_list" class="page-section">
            <p>
                <strong>{{ $__("Items list") }}</strong>
            </p>
            <ShowElement
                :resource="itemTableResource"
                :attr="{
                    type: 'table',
                    hidden: resource => !!resource.items.length,
                    columnData: 'items',
                    columns: tableColumns,
                }"
                :instancedResource="{}"
            />
        </div>
        <fieldset v-if="initialized" class="rows" id="itemfieldset">
            <legend>{{ $__("Item") }}</legend>
            <div id="outeritemblock" class="marc_editor">
                <ol>
                    <li
                        v-for="(attr, index) in frameworkFields"
                        v-bind:key="index"
                    >
                        <div
                            class="subfield_line"
                            :id="`subfield${attr.subfield}`"
                        >
                            <FormElement
                                :resource="fieldValues"
                                :attr="attr"
                                :index="index"
                            />
                            <a
                                v-if="attr.valueBuilder"
                                href="#"
                                :id="`buttonDot_${attr.id}`"
                                :class="`buttonDot tag_editor framework_plugin ${attr.noPopup ? 'disabled' : ''}`"
                                :title="
                                    attr.noPopup ? 'No popup' : 'Tag editor'
                                "
                                :data-plugin="attr.dataPlugin"
                            ></a>
                        </div>
                    </li>
                </ol>
            </div>
        </fieldset>
        <fieldset class="action">
            <InputButton
                :title="updatingItem ? $__('Update item') : $__('Add item')"
                :callback="addItem"
                cssClass="btn btn-default item_form_buttons"
            />
            <InputButton
                :title="$__('Clear')"
                cssClass="btn btn-default item_form_buttons"
                :callback="clearFields"
            />
            <InputButton
                :title="$__('Add multiple items')"
                cssClass="btn btn-default item_form_buttons"
                :callback="
                    () => {
                        addingMultipleItems = !addingMultipleItems;
                    }
                "
            />
            <template v-if="addingMultipleItems">
                <InputNumber
                    v-model="numberOfItemsToAdd"
                    :size="6"
                    id="multipleItemsNumberInput"
                />
                <InputButton
                    :title="$__('Add')"
                    cssClass="btn btn-default item_form_buttons"
                    :callback="addItem"
                />
                <div class="alert alert-info" style="margin: 1em 0">
                    {{
                        $__(
                            "NOTE: Fields listed in the 'UniqueItemFields' system preference will not be copied"
                        )
                    }}
                </div>
            </template>
        </fieldset>
    </div>
</template>

<script>
import { inject, onBeforeMount, reactive, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import FormElement from "../../FormElement.vue";
import ShowElement from "../../ShowElement.vue";
import InputButton from "../../InputButton.vue";
import { $__ } from "@koha-vue/i18n";
import { storeToRefs } from "pinia";
import InputNumber from "../../Elements/InputNumber.vue";

export default {
    props: {
        orderNumber: String,
        biblioNumber: String,
        frameworkCode: String,
        createItems: Object,
        resource: Object,
    },
    setup(props) {
        const items = props.resource.items;
        const frameworkFields = ref(null);
        const initialized = ref(false);
        const fieldValues = ref({});
        const valueBuilders = ref("");
        const itemTableResource = reactive({ items: items });
        const selectOptions = ref({});
        const updatingItem = ref(false);
        let indexOfItemBeingUpdated = null;
        const addingMultipleItems = ref(false);
        const numberOfItemsToAdd = ref(0);

        const { setWarning } = inject("mainStore");
        const acquisitionsStore = inject("acquisitionsStore");
        const { sysprefs } = storeToRefs(acquisitionsStore);

        const { updateSubComponentReadyState } = inject("subComponentsReady");

        const buildOptionsArray = (field, name) => {
            const definedValues = field.values.filter(value => value);
            const options = Object.keys(field.labels).reduce(
                (acc, key, index) => {
                    if (definedValues[index]) {
                        acc.push({
                            label: field.labels[key],
                            value: definedValues[index],
                        });
                    }
                    return acc;
                },
                []
            );
            selectOptions.value[name] = options;
            return options;
        };
        const formatMarcFields = fields => {
            const visibleFields = fields.reduce((acc, field) => {
                if (field.hidden) return acc;
                let type =
                    typeof field.marc_value === "object"
                        ? "select"
                        : field.marc_value.includes("<script>")
                          ? "valueBuilder"
                          : "text";
                const usesFlatpickr =
                    typeof field.marc_value === "string" &&
                    field.marc_value.includes("flatpickr");
                const name = field.api_name;
                const fieldDefinition = {
                    name,
                    label: field.subfield + " - " + field.marc_lib,
                    required: resource => {
                        if (props.createItems.value !== "ordering")
                            return false;
                        return field.mandatory ? true : false;
                    },
                    type,
                    placeholder: "",
                    subfield: field.subfield,
                    ...(type === "select" && {
                        options: buildOptionsArray(field.marc_value, name),
                        selectLabel: "label",
                        requiredKey: "value",
                    }),
                    ...(type === "valueBuilder" && {
                        type: usesFlatpickr ? "date" : "text",
                        valueBuilder: true,
                        dataPlugin: [
                            field.marc_value
                                .split('data-plugin="')[1]
                                .split('"')[0],
                        ],
                        class: "input_marceditor framework_plugin noEnterSubmit",
                    }),
                    id: usesFlatpickr ? `flatpickr-${field.id}` : field.id,
                };
                if (type === "valueBuilder") {
                    const valueScript = field.marc_value
                        .split("<script>")[1]
                        .split("<\/script>")[0];
                    valueBuilders.value += "\n" + valueScript;
                    const noPopup = field.marc_value.includes("No popup");
                    fieldDefinition.noPopup = noPopup;
                }
                fieldValues.value[fieldDefinition.name] = null;
                return [...acc, fieldDefinition];
            }, []);
            return visibleFields;
        };

        onBeforeMount(() => {
            APIClient.marc_framework.frameworkMarcFields
                .get({ frameworkcode: props.frameworkCode })
                .then(
                    frameworkMarcFields => {
                        frameworkFields.value = formatMarcFields(
                            frameworkMarcFields.iteminformation
                        );
                        initialized.value = true;
                        updateSubComponentReadyState("items");
                        eval(valueBuilders.value);
                        $(document).ready(function () {
                            function callClickPluginEventHandler(event) {
                                event.preventDefault();
                                callPluginEventHandler.call(this, event);
                            }

                            function callPluginEventHandler(event) {
                                event.stopPropagation();

                                const plugin = event.target.getAttribute(
                                    "data-plugin"
                                )
                                    ? event.target.getAttribute("data-plugin")
                                    : $("#buttonDot_" + event.target.id).attr(
                                          "data-plugin"
                                      );
                                if (
                                    plugin &&
                                    plugin in Koha.frameworkPlugins &&
                                    event.type in Koha.frameworkPlugins[plugin]
                                ) {
                                    event.data = {};
                                    if (
                                        event.target.classList.contains(
                                            "framework_plugin"
                                        ) ||
                                        event.target.classList.contains(
                                            "buttonDot"
                                        )
                                    ) {
                                        event.data.id = event.target
                                            .closest(".subfield_line")
                                            .querySelector(
                                                "input.input_marceditor"
                                            ).id;
                                    } else {
                                        event.data.id = event.target.id;
                                    }

                                    Koha.frameworkPlugins[plugin][
                                        event.type
                                    ].call(this, event);
                                }
                            }

                            // We use delegated event handlers here so that dynamically added elements
                            // (like when cloning a field or a subfield) respond to these events
                            // without having to re-attach events manually
                            $(".marc_editor").on(
                                "click",
                                ".tag_editor.framework_plugin",
                                callClickPluginEventHandler
                            );
                            $(".marc_editor").on(
                                "focusin focusout change mousedown mouseup keydown keyup",
                                "input.input_marceditor.framework_plugin",
                                callPluginEventHandler
                            );
                        });
                    },
                    error => {}
                );
        });

        const checkMandatoryFields = () => {
            const emptyMandatoryFields = frameworkFields.value.reduce(
                (acc, field) => {
                    if (field.required() && !fieldValues.value[field.name])
                        acc.push(field);
                    return acc;
                },
                []
            );
            if (emptyMandatoryFields.length) {
                const errorString = $__(
                    "There are %s mandatory item fields that have not been filled"
                ).format(emptyMandatoryFields.length);
                setWarning(errorString);
                return false;
            }
            return true;
        };

        const checkUniqueFields = async uniqueItemFields => {
            const uniqueFieldsFromForm = uniqueItemFields.reduce(
                (acc, field) => {
                    if (fieldValues.value[field]) {
                        acc.field.push(field);
                        acc.value.push(fieldValues.value[field]);
                    }
                    return acc;
                },
                { field: [], value: [] }
            );
            if (addingMultipleItems.value) {
                uniqueFieldsFromForm.field.forEach(field => {
                    fieldValues.value[field] = "";
                });
            }

            let endpoint = "/cgi-bin/koha/acqui/check_uniqueness.pl?";
            Object.keys(uniqueFieldsFromForm).forEach(key => {
                const propertyValues = uniqueFieldsFromForm[key];
                propertyValues.forEach(pv => {
                    endpoint += key + "[]=" + pv + "&";
                });
            });
            endpoint = endpoint.substring(0, endpoint.length - 1);

            const result = await APIClient.default.koha.get({ endpoint });
            if (Object.keys(result).length) {
                let errorString = "";
                Object.entries(result).forEach(([field, values]) => {
                    values.forEach(val => {
                        errorString +=
                            field +
                            " '" +
                            val +
                            "' " +
                            $__("already exists in the database") +
                            "<br />";
                    });
                });
                setWarning(errorString);
                return false;
            }
            return true;
        };

        const addItem = async () => {
            if (
                addingMultipleItems.value &&
                (isNaN(numberOfItemsToAdd.value) ||
                    numberOfItemsToAdd.value <= 0)
            ) {
                setWarning(
                    $__(
                        "Invalid number of copies. Please enter a number greater than or equal to 1"
                    )
                );
                return;
            }
            const mandatoryFieldsVerified = checkMandatoryFields();
            if (!mandatoryFieldsVerified) return false;

            const uniqueItemFields =
                sysprefs.value.unique_item_fields.split("|");
            const uniqueFieldsVerified =
                await checkUniqueFields(uniqueItemFields);
            if (!uniqueFieldsVerified) return false;

            if (updatingItem.value) {
                items.splice(indexOfItemBeingUpdated, 1, {
                    ...fieldValues.value,
                });
                updatingItem.value = false;
                indexOfItemBeingUpdated = null;
            } else {
                const numberOfItems = addingMultipleItems.value
                    ? parseInt(numberOfItemsToAdd.value)
                    : 1;
                props.resource.quantity_ordered = items.length + numberOfItems;
                items.push(
                    ...new Array(numberOfItems).fill({ ...fieldValues.value })
                );
            }
            Object.keys(fieldValues.value).forEach(key => {
                if (uniqueItemFields.includes(key)) fieldValues.value[key] = "";
            });
            addingMultipleItems.value = false;
            numberOfItemsToAdd.value = 0;
        };
        const clearFields = () => {
            Object.keys(fieldValues.value).forEach(field => {
                fieldValues.value[field] = "";
            });
            const dateFields = frameworkFields.value.filter(
                ff => ff.type === "date"
            );
            dateFields.forEach(dateField => {
                const fp = document.querySelector(
                    "#" + dateField.id
                )._flatpickr;
                fp.clear();
            });
        };

        const handleSelectColumn = (value, resource, attr) => {
            const selectOptionList = selectOptions.value[attr.value];
            if (selectOptionList) {
                const selectedOption = selectOptionList.find(
                    so => so.value === value
                );
                return selectedOption ? selectedOption.label : "";
            }
            return value;
        };
        const tableColumns = [
            {
                name: $__("Barcode"),
                value: "external_id",
            },
            {
                name: $__("Home library"),
                value: "home_library_id",
            },
            {
                name: $__("Holding library"),
                value: "holding_library_id",
            },
            {
                name: $__("Not for loan"),
                value: "not_for_loan_status",
            },
            {
                name: $__("Restricted"),
                value: "restricted_status",
            },
            {
                name: $__("Location"),
                value: "location",
            },
            {
                name: $__("Call number"),
                value: "callnumber",
            },
            {
                name: $__("Copy number"),
                value: "copy_number",
            },
            {
                name: $__("Inventory number"),
                value: "inventory_number",
            },
            {
                name: $__("Collection"),
                value: "collection_code",
            },
            {
                name: $__("Item type"),
                value: "item_type_id",
            },
            {
                name: $__("Materials"),
                value: "materials_notes",
            },
            {
                name: $__("Notes"),
                value: "public_notes",
            },
        ].map(tc => {
            return { ...tc, format: handleSelectColumn };
        });
        tableColumns.unshift({
            name: $__("Actions"),
            cssClass: "actions",
            value: "",
            buttons: [
                {
                    title: $__("Edit"),
                    callback: counter => {
                        updatingItem.value = true;
                        indexOfItemBeingUpdated = counter;
                        const itemToUpdate = items[counter];
                        fieldValues.value = { ...itemToUpdate };
                    },
                },
                {
                    title: $__("Delete"),
                    callback: counter => {
                        items.splice(counter, 1);
                    },
                },
            ],
        });
        return {
            frameworkFields,
            initialized,
            fieldValues,
            addItem,
            tableColumns,
            itemTableResource,
            updatingItem,
            clearFields,
            addingMultipleItems,
            numberOfItemsToAdd,
            items,
        };
    },
    components: {
        FormElement,
        ShowElement,
        InputButton,
        InputNumber,
    },
};
</script>

<style>
#itemfieldset label,
#itemfieldset span.label {
    flex-basis: 25%;
    font-weight: 700;
    margin-right: 1rem;
    text-align: right;
    width: 9rem;
    font-size: 100%;
    width: 25%;
}

/* #itemfieldset .input_marceditor {
    flex-basis: 50%;
} */

#itemfieldset .input_marceditor.flatpickr-input {
    width: 50%;
}

#itemfieldset .subfield_line {
    display: flex;
    flex-basis: 100%;
}
.item_form_buttons {
    margin: 0 0.5em;
}
#multipleItemsNumberInput {
    min-width: 0%;
}
.item_table_buttons {
    padding: 3px 5px;
}
</style>
