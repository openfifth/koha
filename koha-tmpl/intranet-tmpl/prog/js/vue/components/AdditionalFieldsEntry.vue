<template>
    <template v-if="available_fields.length">
        <li class="additional-fields-header">
            <label></label>
            <h3>{{ $__("Additional fields") }}</h3>
        </li>
        <template
            v-for="available_field in available_fields"
            v-bind:key="available_field.extended_attribute_type_id"
        >
            <template
                v-if="
                    available_field.authorised_value_category_name &&
                    !available_field.repeatable
                "
            >
                <li>
                    <label
                        :for="
                            `additional_field_` +
                            available_field.extended_attribute_type_id
                        "
                        >{{ available_field.name }}:
                    </label>
                    <v-select
                        :id="
                            `additional_field_` +
                            available_field.extended_attribute_type_id
                        "
                        :name="available_field.name"
                        v-model="
                            current_additional_fields_values[
                                available_field.extended_attribute_type_id
                            ]
                        "
                        :options="
                            av_options[
                                available_field.authorised_value_category_name
                            ]
                        "
                    />
                </li>
            </template>
            <template
                v-if="
                    available_field.authorised_value_category_name &&
                    available_field.repeatable
                "
            >
                <li>
                    <label
                        :for="
                            `additional_field_` +
                            available_field.extended_attribute_type_id
                        "
                        >{{ available_field.name }}:
                    </label>
                    <v-select
                        :id="
                            `additional_field_` +
                            available_field.extended_attribute_type_id
                        "
                        :name="available_field.name"
                        :multiple="available_field.repeatable"
                        v-model="
                            current_additional_fields_values[
                                available_field.extended_attribute_type_id
                            ]
                        "
                        :options="
                            av_options[
                                available_field.authorised_value_category_name
                            ]
                        "
                    />
                </li>
            </template>

            <template v-if="!available_field.authorised_value_category_name">
                <li
                    v-for="current in current_additional_fields_values[
                        available_field.extended_attribute_type_id
                    ]"
                    v-bind:key="current.id"
                >
                    <label
                        :for="
                            `additional_field_` +
                            available_field.extended_attribute_type_id
                        "
                        >{{ available_field.name }}:
                    </label>
                    <span class="input-group">
                        <input
                            type="text"
                            v-model="current.value"
                            :id="
                                `additional_field_` +
                                available_field.extended_attribute_type_id
                            "
                            class="input-with-clear"
                        />
                        <button
                            v-if="current.value"
                            type="button"
                            class="clear-button"
                            @click="clearField(current, $event)"
                            :aria-label="$__('Clear')"
                            :title="$__('Clear')"
                            tabindex="-1"
                        >
                            <svg
                                xmlns="http://www.w3.org/2000/svg"
                                width="10"
                                height="10"
                                viewBox="0 0 10 10"
                            >
                                <path
                                    d="M6.895455 5l2.842897-2.842898c.348864-.348863.348864-.914488 0-1.263636L9.106534.261648c-.348864-.348864-.914489-.348864-1.263636 0L5 3.104545 2.157102.261648c-.348863-.348864-.914488-.348864-1.263636 0L.261648.893466c-.348864.348864-.348864.914489 0 1.263636L3.104545 5 .261648 7.842898c-.348864.348863-.348864.914488 0 1.263636l.631818.631818c.348864.348864.914773.348864 1.263636 0L5 6.895455l2.842898 2.842897c.348863.348864.914772.348864 1.263636 0l.631818-.631818c.348864-.348864.348864-.914489 0-1.263636L6.895455 5z"
                                ></path>
                            </svg>
                        </button>
                    </span>
                    <template v-if="available_field.repeatable">
                        <a
                            href="#"
                            class="btn btn-default btn-sm"
                            @click="
                                cloneField(available_field, current, $event)
                            "
                        >
                            <i class="fa fa-fw fa-plus"></i>
                            {{ $__("New") }}
                        </a>
                    </template>
                </li>
            </template>
        </template>
    </template>
</template>

<script>
import { onBeforeMount, watch, ref, reactive, nextTick } from "vue";
import { APIClient } from "../fetch/api-client.js";

export default {
    setup(props, { emit }) {
        const initialized = ref(false);
        const available_fields = ref([]);
        const av_options = ref([]);
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

        const clearField = (current_field, event) => {
            if (event) {
                event.preventDefault();
            }
            current_field.value = "";
        };
        const cloneField = (available_field, current, event) => {
            event.preventDefault();
            const fieldArray =
                current_additional_fields_values[
                    available_field.extended_attribute_type_id
                ];
            fieldArray.push({
                value: "",
                label: available_field.name,
            });

            // Focus the newly created field after DOM updates
            nextTick(() => {
                const fieldId = `additional_field_${available_field.extended_attribute_type_id}`;
                const inputs = document.querySelectorAll(
                    `input[id="${fieldId}"]`
                );
                if (inputs.length > 0) {
                    // Focus the last input (the newly added one)
                    inputs[inputs.length - 1].focus();
                }
            });
        };

        const updateParentAdditionalFieldValues =
            current_additional_fields_values => {
                let updatedAdditionalFields = [];
                Object.keys(current_additional_fields_values).forEach(
                    field_id => {
                        if (
                            !Array.isArray(
                                current_additional_fields_values[field_id]
                            ) &&
                            current_additional_fields_values[field_id]
                        ) {
                            current_additional_fields_values[field_id] = [
                                current_additional_fields_values[field_id],
                            ];
                        }
                        if (current_additional_fields_values[field_id]) {
                            let new_extended_attributes =
                                current_additional_fields_values[field_id].map(
                                    value => ({
                                        field_id: field_id,
                                        value: value.value,
                                    })
                                );
                            updatedAdditionalFields =
                                updatedAdditionalFields.concat(
                                    new_extended_attributes
                                );
                        }
                    }
                );

                emit(
                    "additional-fields-changed",
                    updatedAdditionalFields,
                    props.resource
                );
            };

        watch(current_additional_fields_values, (newValue, oldValue) => {
            updateParentAdditionalFieldValues(newValue);
        });
        watch(available_fields, (newValue, oldValue) => {
            if (newValue) {
                const client_av = APIClient.authorised_values;
                let av_cat_array = newValue
                    .map(field => field.authorised_value_category_name)
                    .filter(field => field);

                client_av.values
                    .getCategoriesWithValues([
                        ...new Set(
                            av_cat_array.map(av_cat => '"' + av_cat + '"')
                        ),
                    ]) // unique
                    .then(av_categories => {
                        av_cat_array.forEach(av_cat => {
                            let av_match = av_categories.find(
                                element => element.category_name == av_cat
                            );
                            av_options.value[av_cat] =
                                av_match.authorised_values.map(av => ({
                                    value: av.value,
                                    label: av.description,
                                }));
                        });

                        // Iterate on available fields
                        newValue.forEach(available_field => {
                            // Initialize current field as empty array
                            current_additional_fields_values[
                                available_field.extended_attribute_type_id
                            ] = [];

                            // Grab all existing field values of this field
                            let existing_field_values =
                                props.additional_field_values.filter(
                                    afv =>
                                        afv.field_id ==
                                            available_field.extended_attribute_type_id &&
                                        afv.value
                                );

                            // If there are existing field values for this field, add them to current_additional_fields_values
                            if (existing_field_values.length) {
                                existing_field_values.forEach(
                                    existing_field_value => {
                                        let label = "";
                                        if (
                                            available_field.authorised_value_category_name
                                        ) {
                                            let av_value = av_options.value[
                                                available_field
                                                    .authorised_value_category_name
                                            ].filter(
                                                av_option =>
                                                    av_option.value ==
                                                    existing_field_value.value
                                            );
                                            label = av_value.length
                                                ? av_value[0].label
                                                : "";
                                        }
                                        current_additional_fields_values[
                                            existing_field_value.field_id
                                        ].push({
                                            value: existing_field_value.value,
                                            label: label,
                                        });
                                    }
                                );

                                // Otherwise add them as empty if not AV field
                            } else {
                                if (
                                    !available_field.authorised_value_category_name
                                ) {
                                    current_additional_fields_values[
                                        available_field.extended_attribute_type_id
                                    ] = [
                                        {
                                            label: "",
                                            value: "",
                                        },
                                    ];
                                }
                            }
                        });
                    });
            }
        });

        return {
            available_fields,
            av_options,
            current_additional_fields_values,
            clearField,
            cloneField,
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

<style scoped>
/* Header for additional fields section */
.additional-fields-header {
    border-top: 1px solid #ddd;
    margin-top: 1em;
    padding-top: 1em;
}

.additional-fields-header h3 {
    margin: 0;
    font-size: 110%;
    font-weight: bold;
    color: #696969;
}

.additional-fields-header label {
    /* Empty label for alignment with other fields */
    width: 10rem;
}

/* Input group container for positioning */
.input-group {
    position: relative;
    display: inline;
}

/* Input with clear button gets padding for the button and matches select2 styling */
input.input-with-clear {
    padding: 0.375rem 2rem 0.375rem 0.75rem;
    line-height: 1.5;
}

.clear-button {
    position: absolute;
    right: 0.25rem;
    top: 50%;
    transform: translateY(-50%);
    background: transparent;
    border: none;
    color: #999;
    cursor: pointer;
    padding: 0.25rem 0.5rem;
    line-height: 1;
    transition: color 0.15s ease-in-out;
    z-index: 10;
    height: 1.5rem;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0;
}

.clear-button:hover {
    color: #333;
}

.clear-button:focus {
    outline: 2px solid #007bff;
    outline-offset: 2px;
    border-radius: 2px;
}

.clear-button svg {
    fill: currentColor;
}

/* New button spacing */
.btn.btn-sm {
    margin-left: 0.5rem;
}
</style>
