<template>
    <fieldset
        v-if="available_fields.length"
        class="rows"
        id="additional_fields"
    >
        <legend>{{ $__("Additional fields") }}</legend>
        <ol>
            <template
                v-for="available_field in available_fields"
                v-bind:key="available_field.extended_attribute_type_id"
            >
                <li>
                    <FormElement
                        v-if="available_field.authorised_value_category_name"
                        :resource="current_additional_fields_values"
                        :attr="{
                            type: 'select',
                            id:
                                'additional_field_' +
                                available_field.extended_attribute_type_id,
                            name: String(
                                available_field.extended_attribute_type_id
                            ),
                            label: available_field.name,
                            options:
                                av_options[
                                    available_field
                                        .authorised_value_category_name
                                ],
                            repeatable: available_field.repeatable,
                            selectLabel: 'label',
                            requiredKey: null,
                        }"
                        :index="0"
                    />
                    <FormElement
                        v-else
                        :resource="current_additional_fields_values"
                        :attr="{
                            type: 'text',
                            id:
                                'additional_field_' +
                                available_field.extended_attribute_type_id,
                            name: String(
                                available_field.extended_attribute_type_id
                            ),
                            label: available_field.name,
                            repeatable: available_field.repeatable,
                            clearable: true,
                        }"
                        :index="0"
                    />
                </li>
            </template>
        </ol>
    </fieldset>
</template>

<script>
import { defineAsyncComponent, onBeforeMount, watch, ref, reactive } from "vue";
import { APIClient } from "../fetch/api-client.js";

const FormElement = defineAsyncComponent(() => import("./FormElement.vue"));

export default {
    components: { FormElement },
    setup(props, { emit }) {
        const initialized = ref(false);
        const available_fields = ref([]);
        const av_options = ref({});
        const current_additional_fields_values = reactive({});

        onBeforeMount(() => {
            const client = APIClient.additional_fields;
            client.additional_fields
                .getAll(props.extended_attributes_resource_type)
                .then(
                    response => {
                        available_fields.value = response;
                        initialized.value = true;
                    },
                    error => {}
                );
        });

        const updateParentAdditionalFieldValues = current => {
            let updatedFields = [];
            available_fields.value.forEach(field => {
                const fieldId = field.extended_attribute_type_id;
                const fieldValue = current[fieldId];

                if (field.authorised_value_category_name) {
                    // AV field: value is a single {value, label} object (non-repeatable)
                    // or an array of {value, label} objects (repeatable)
                    const arr = Array.isArray(fieldValue)
                        ? fieldValue
                        : fieldValue
                          ? [fieldValue]
                          : [];
                    arr.forEach(
                        v =>
                            v &&
                            updatedFields.push({
                                field_id: fieldId,
                                value: v.value,
                            })
                    );
                } else if (field.repeatable) {
                    // Repeatable text: array of { [fieldId]: "text", label: "" }
                    (fieldValue || []).forEach(v =>
                        updatedFields.push({
                            field_id: fieldId,
                            value: v[fieldId],
                        })
                    );
                } else {
                    // Non-repeatable text: scalar string
                    if (fieldValue)
                        updatedFields.push({
                            field_id: fieldId,
                            value: fieldValue,
                        });
                }
            });
            emit("additional-fields-changed", updatedFields, props.resource);
        };

        watch(current_additional_fields_values, (newValue, oldValue) => {
            updateParentAdditionalFieldValues(newValue);
        });

        watch(available_fields, newValue => {
            if (newValue) {
                const client_av = APIClient.authorised_values;
                const av_cat_array = newValue
                    .map(field => field.authorised_value_category_name)
                    .filter(field => field);

                client_av.values
                    .getCategoriesWithValues([
                        ...new Set(
                            av_cat_array.map(av_cat => '"' + av_cat + '"')
                        ),
                    ])
                    .then(av_categories => {
                        av_cat_array.forEach(av_cat => {
                            const av_match = av_categories.find(
                                element => element.category_name == av_cat
                            );
                            av_options.value[av_cat] =
                                av_match.authorised_values.map(av => ({
                                    value: av.value,
                                    label: av.description,
                                }));
                        });

                        newValue.forEach(available_field => {
                            const fieldId =
                                available_field.extended_attribute_type_id;
                            const existing_field_values =
                                props.additional_field_values.filter(
                                    afv => afv.field_id == fieldId && afv.value
                                );

                            if (
                                available_field.authorised_value_category_name
                            ) {
                                const av_options_for_field =
                                    av_options.value[
                                        available_field
                                            .authorised_value_category_name
                                    ];
                                const mapped = existing_field_values.map(
                                    existing => {
                                        const av_match =
                                            av_options_for_field.find(
                                                opt =>
                                                    opt.value == existing.value
                                            );
                                        return {
                                            value: existing.value,
                                            label: av_match
                                                ? av_match.label
                                                : "",
                                        };
                                    }
                                );
                                current_additional_fields_values[fieldId] =
                                    available_field.repeatable
                                        ? mapped
                                        : mapped.length
                                          ? mapped[0]
                                          : null;
                            } else if (available_field.repeatable) {
                                current_additional_fields_values[fieldId] =
                                    existing_field_values.length
                                        ? existing_field_values.map(v => ({
                                              [fieldId]: v.value,
                                              label: "",
                                          }))
                                        : [{ [fieldId]: "", label: "" }];
                            } else {
                                current_additional_fields_values[fieldId] =
                                    existing_field_values.length
                                        ? existing_field_values[0].value
                                        : "";
                            }
                        });
                    });
            }
        });

        return {
            available_fields,
            av_options,
            current_additional_fields_values,
            initialized,
        };
    },
    name: "AdditionalFieldsEntry",
    props: {
        extended_attributes_resource_type: String,
        additional_field_values: Array,
        resource: Object,
    },
    emits: ["additional-fields-changed"],
};
</script>
