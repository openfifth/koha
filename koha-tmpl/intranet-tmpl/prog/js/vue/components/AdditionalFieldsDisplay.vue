<template>
    <template v-if="additional_field_values.length">
        <li class="additional-fields-header">
            <label></label>
            <h3>{{ $__("Additional fields") }}</h3>
        </li>
        <li
            v-for="additional_field_value in additional_field_values"
            v-bind:key="additional_field_value.id"
        >
            <label :for="`additional_field_` + additional_field_value.field_id">
                {{ additional_field_value.field_label }}:
            </label>
            <template v-if="isMultipleValues(additional_field_value.value_str)">
                <div class="additional-field-values">
                    <div
                        v-for="(value, index) in splitValues(
                            additional_field_value.value_str
                        )"
                        :key="index"
                        class="value-item"
                    >
                        {{ value }}
                    </div>
                </div>
            </template>
            <span v-else> {{ additional_field_value.value_str }} </span>
        </li>
    </template>
</template>

<script>
import { ref } from "vue";
export default {
    setup() {
        const fields_to_display = ref([]);

        const isMultipleValues = value_str => {
            return value_str && value_str.includes(",");
        };

        const splitValues = value_str => {
            if (!value_str) return [];
            return value_str
                .split(",")
                .map(v => v.trim())
                .filter(v => v);
        };

        return {
            fields_to_display,
            isMultipleValues,
            splitValues,
        };
    },
    name: "AdditionalFieldsDisplay",
    props: {
        extended_attributes_resource_type: String,
        additional_field_values: Array,
    },
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

/* Multiple values display aligned with single values */
.additional-field-values {
    display: inline-block;
    margin: 0;
    padding: 0;
}

.value-item {
    margin: 0;
    padding: 0;
    line-height: 1.5;
}
</style>
