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
import { useRouter, useRoute } from "vue-router";

export default {
    components: { FormElement, ButtonSubmit },
    props: {
        patronAttrs: Array,
    },
    setup(props) {
        const overduesStore = inject("overduesStore");
        const { authorisedValues, itemTypes, settings } = storeToRefs(overduesStore);

        const router = useRouter();
        const route = useRoute();

        const handlePatronAttrs = () => {
            if (!props.patronAttrs.length) return [];
            return props.patronAttrs.map(pa => {
                return {
                    isExtendedAttribute: true,
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
                    },
                    {
                        name: "due_date_from",
                        type: "date",
                        label: $__("From"),
                        componentProps: {
                            disabled: {
                                resourceProperty: "showall",
                            },
                        },
                    },
                    {
                        name: "due_date_to",
                        type: "date",
                        label: $__("To"),
                        componentProps: {
                            disabled: {
                                resourceProperty: "showall",
                            },
                        },
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
                ...(settings.value.patron_library_ids?.length && {
                    query: {
                        library_id: {
                            "-in": settings.value.patron_library_ids,
                        },
                    },
                }),
            },
        ];

        const generateFiltersFromQueryString = fields => {
            const queryParams = route.query;
            return fields.reduce((acc, field) => {
                if (field.hasOwnProperty("defaultValue")) {
                    acc[field.name] = field.defaultValue;
                }
                if (
                    queryParams.hasOwnProperty(field.name) &&
                    queryParams[field.name]
                ) {
                    acc[field.name] = queryParams[field.name];
                    if (queryParams[field.name] == "false") {
                        acc[field.name] = false;
                    }
                }
                if (field.subFields) {
                    const parsedSubfields = generateFiltersFromQueryString(
                        field.subFields
                    );
                    acc = { ...acc, ...parsedSubfields };
                }
                if (
                    field.isExtendedAttribute &&
                    field.repeatable &&
                    queryParams.hasOwnProperty(field.name)
                ) {
                    if (Array.isArray(queryParams[field.name])) {
                        acc[field.name] = queryParams[field.name].map(val => {
                            return { label: field.label, [field.name]: val };
                        });
                    } else {
                        acc[field.name] = [
                            {
                                label: field.label,
                                [field.name]: queryParams[field.name],
                            },
                        ];
                    }
                }
                return acc;
            }, {});
        };
        const filters = ref(generateFiltersFromQueryString(filterFormFields));

        const handleFilterFormSubmission = e => {
            e.preventDefault();
            const filterValues = JSON.parse(JSON.stringify(filters.value));
            Object.keys(filterValues).forEach(key => {
                if (!filterValues[key]) {
                    delete filterValues[key];
                }
                const filterField = filterFormFields.find(
                    field => field.name === key
                );
                if (
                    filterField &&
                    filterField.isExtendedAttribute &&
                    Array.isArray(filterValues[key])
                ) {
                    filterValues[key] = filterValues[key].reduce(
                        (acc, curr) => {
                            if (!curr[key]) return acc;
                            acc.push(curr[key]);
                            return acc;
                        },
                        []
                    );
                    if (!filterValues[key].length) delete filterValues[key];
                }
            });
            router.push({
                name: "OverduesList",
                query: filterValues,
            });
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
