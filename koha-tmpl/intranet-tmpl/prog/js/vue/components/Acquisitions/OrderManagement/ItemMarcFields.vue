<template>
    <div v-if="createItems.value === 'ordering'">
        <!-- <fieldset v-if="initialized" class="rows" id="itemfieldset"> -->
        <input type="hidden" id="vueItemForm" />
        <div id="items_list" class="page-section">
            <p>
                <strong>{{ $__("Items list") }}</strong>
            </p>
            <div style="width: 100%; overflow: auto">
                <table>
                    <thead>
                        <tr>
                            <th class="no-export">Actions</th>
                            <th>Barcode</th>
                            <th>Home library</th>
                            <th>Holding library</th>
                            <th>Not for loan</th>
                            <th>Restricted</th>
                            <th>Location</th>
                            <th>Call number</th>
                            <th>Copy number</th>
                            <th>Inventory number</th>
                            <th>Collection</th>
                            <th>Item type</th>
                            <th>Materials</th>
                            <th>Notes</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr
                            v-for="item in items"
                            :key="item.item_id"
                            :idblock="`itemblock${item.item_id}`"
                        >
                            <td>&nbsp;</td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                            <td></td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        <fieldset class="rows" id="itemfieldset">
            <legend>{{ $__("Item") }}</legend>
            <div id="outeritemblock" class="marc_editor">
                <!-- <ol>
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
                                :id="attr.id"
                                :class="`buttonDot tag_editor framework_plugin ${attr.noPopup ? 'disabled' : ''}`"
                                :title="
                                    attr.noPopup ? 'No popup' : 'Tag editor'
                                "
                                :data-plugin="attr.dataPlugin"
                            ></a>
                        </div>
                    </li>
                </ol> -->
            </div>
        </fieldset>
    </div>
</template>

<script>
import { onBeforeMount, onMounted, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import FormElement from "../../FormElement.vue";
export default {
    props: {
        orderNumber: String,
        biblioNumber: String,
        frameworkCode: String,
        createItems: Object,
        items: Array,
    },
    setup(props) {
        const frameworkFields = ref(null);
        const initialized = ref(false);
        const fieldValues = ref({});
        // const valueBuilders = ref("");

        // const buildOptionsArray = field => {
        //     field.labels[0] = "";
        //     return Object.keys(field.labels).map((key, index) => ({
        //         label: field.labels[key],
        //         value: field.values[index],
        //     }));
        // };

        // const formatMarcFields = fields => {
        //     const visibleFields = fields.reduce((acc, field) => {
        //         if (field.hidden) return acc;
        //         let type =
        //             typeof field.marc_value === "object"
        //                 ? "select"
        //                 : field.marc_value.includes("<script>")
        //                   ? "valueBuilder"
        //                   : "text";
        //         const usesFlatpickr =
        //             typeof field.marc_value === "string" &&
        //             field.marc_value.includes("flatpickr");
        //         const fieldDefinition = {
        //             name: field.kohafield.split(".").pop(),
        //             label: field.subfield + " - " + field.marc_lib,
        //             required: resource => {
        //                 if (props.createItems.value !== "ordering")
        //                     return false;
        //                 return field.mandatory ? true : false;
        //             },
        //             type,
        //             placeholder: "",
        //             subfield: field.subfield,
        //             ...(type === "select" && {
        //                 options: buildOptionsArray(field.marc_value),
        //                 selectLabel: "label",
        //                 requiredKey: "value",
        //             }),
        //             ...(type === "valueBuilder" && {
        //                 type: usesFlatpickr ? "date" : "text",
        //                 valueBuilder: true,
        //                 dataPlugin: [
        //                     field.marc_value
        //                         .split('data-plugin="')[1]
        //                         .split('"')[0],
        //                 ],
        //                 class: "input_marceditor framework_plugin noEnterSubmit",
        //             }),
        //             id: usesFlatpickr ? `flatpickr-${field.id}` : field.id,
        //         };
        //         if (type === "valueBuilder") {
        //             const valueScript = field.marc_value
        //                 .split("<script>")[1]
        //                 .split("<\/script>")[0];
        //             valueBuilders.value += "\n" + valueScript;
        //             const noPopup = field.marc_value.includes("No popup");
        //             fieldDefinition.noPopup = noPopup;
        //         }
        //         fieldValues.value[fieldDefinition.name] = null;
        //         return [...acc, fieldDefinition];
        //     }, []);
        //     return visibleFields;
        // };

        onMounted(() => {
            cloneItemBlock(0, "barcode");
        });

        onBeforeMount(() => {
            // APIClient.marc_framework.frameworkMarcFields
            //     .get(props.frameworkCode)
            //     .then(
            //         frameworkMarcFields => {
            //             frameworkFields.value = formatMarcFields(
            //                 frameworkMarcFields.iteminformation
            //             );
            //             initialized.value = true;
            //             eval(valueBuilders.value);
            $(document).ready(function () {
                function callClickPluginEventHandler(event) {
                    event.preventDefault();
                    callPluginEventHandler.call(this, event);
                }

                function callPluginEventHandler(event) {
                    event.stopPropagation();

                    const plugin = event.target.getAttribute("data-plugin");
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
                            event.target.classList.contains("buttonDot")
                        ) {
                            event.data.id = event.target
                                .closest(".subfield_line")
                                .querySelector("input.input_marceditor").id;
                        } else {
                            event.data.id = event.target.id;
                        }

                        Koha.frameworkPlugins[plugin][event.type].call(
                            this,
                            event
                        );
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
            //     },
            //     error => {}
            // );
        });

        return {
            frameworkFields,
            initialized,
            fieldValues,
        };
    },
    components: {
        FormElement,
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
</style>
