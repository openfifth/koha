<template>
    <aside>
        <form @submit="handleFilterFormSubmission($event)">
            <fieldset class="brief">
                <h4>{{ $__("Filter on") }}:</h4>
                <ol>
                    <li
                        v-for="(field, index) in filterFormFields"
                        v-bind:key="index"
                    >
                        <FormElement
                            :resource="filters"
                            :attr="field"
                            :index="index"
                        />
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <ButtonSubmit :title="$__('Apply filter')" />
            </fieldset>
        </form>
    </aside>
</template>

<script>
import { inject, ref } from "vue";
import FormElement from "../../FormElement.vue";
import { $__ } from "@koha-vue/i18n";
import { APIClient } from "../../../fetch/api-client.js";
import ButtonSubmit from "../../ButtonSubmit.vue";
import { storeToRefs } from "pinia";

export default {
    components: { FormElement, ButtonSubmit },
    props: {
        patronAttrs: Array,
    },
    setup(props) {
        const overduesStore = inject("overduesStore");
        const { authorisedValues, itemTypes } = storeToRefs(overduesStore);

        const handlePatronAttrs = () => {
            if (!props.patronAttrs.length) return [];
            return props.patronAttrs.map(pa => {
                return {
                    type: "text",
                    label: pa.description,
                    name: pa.code,
                    ...(pa.authorised_value_category && {
                        type: "select",
                        avCat: pa.authorised_value_category,
                        options: authorisedValues.value[pa.code],
                        requiredKey: "value",
                        selectLabel: "description",
                    }),
                    ...(pa.is_date && { type: "date" }),
                    ...(pa.repeatable && {
                        repeatable: true,
                        defaultValue: [
                            { label: pa.description, [pa.code]: "" },
                        ],
                    }),
                };
            });
        };
        const filterFormFields = [
            {
                type: "indented_subfields",
                legend: $__("Date due"),
                subFields: [
                    {
                        name: "showall",
                        type: "checkbox",
                        label: $__("Show any items currently checked out"),
                        defaultValue: null,
                    },
                    {
                        name: "dateduefrom",
                        type: "date",
                        label: $__("From"),
                    },
                    {
                        name: "datedueto",
                        type: "date",
                        label: $__("To"),
                    },
                ],
            },
            {
                type: "text",
                name: "patron_name",
                label: $__("Name or card number"),
            },
            {
                name: "category",
                type: "relationshipSelect",
                label: $__("Patron category"),
                relationshipAPIClient: APIClient.patron.categories,
                relationshipOptionLabelAttr: "name",
                relationshipRequiredKey: "patron_category_id",
            },
            {
                name: "patron_flag",
                type: "select",
                label: $__("Patron flags"),
                options: [
                    {
                        value: "gone_no_address",
                        description: $__("Address in question"),
                    },
                    { value: "debarred", description: $__("Restricted") },
                    { value: "lost", description: $__("Lost card") },
                ],
                requiredKey: "value",
                selectLabel: "description",
            },
            ...handlePatronAttrs(),
            {
                name: "item_type",
                type: "select",
                selectLabel: "description",
                requiredKey: "item_type_id",
                options: itemTypes.value,
                label: $__("Item type"),
            },
            {
                name: "item_home_library",
                type: "relationshipSelect",
                relationshipAPIClient: APIClient.library.libraries,
                relationshipOptionLabelAttr: "name",
                relationshipRequiredKey: "library_id",
                label: $__("Item home library"),
            },
            {
                name: "item_holding_library",
                type: "relationshipSelect",
                relationshipAPIClient: APIClient.library.libraries,
                relationshipOptionLabelAttr: "name",
                relationshipRequiredKey: "library_id",
                label: $__("Item holding library"),
            },
            {
                name: "patron_library",
                type: "relationshipSelect",
                relationshipAPIClient: APIClient.library.libraries,
                relationshipOptionLabelAttr: "name",
                relationshipRequiredKey: "library_id",
                label: $__("Library of the patron"),
            },
        ];

        const filters = ref(
            filterFormFields.reduce((acc, curr) => {
                if (curr.hasOwnProperty("defaultValue")) {
                    acc[curr.name] = curr.defaultValue;
                }
                return acc;
            }, {})
        );

        const handleFilterFormSubmission = e => {
            e.preventDefault();
        };
        return {
            filterFormFields,
            filters,
            handleFilterFormSubmission,
        };
    },
};
</script>

<style scoped>
:deep(form .v-select) {
    width: 90% !important;
}
:deep(.vs__dropdown-option) {
    padding: 3px 20px;
}
:deep(.repeatableFieldList) {
    height: 100% !important;
}
.clone_attribute {
    margin-top: 3px;
}
:deep(.repeatableFieldList input) {
    width: 80% !important;
}
</style>
