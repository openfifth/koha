<template>
    <v-select
        v-if="kohaField === 'branchcode'"
        :modelValue="modelValue"
        :options="librariesArray"
        label="label"
        :reduce="o => o.value"
        :placeholder="$__('Select a library...')"
        @update:modelValue="onUpdate"
    />
    <v-select
        v-else-if="kohaField === 'categorycode'"
        :modelValue="modelValue"
        :options="categoriesArray"
        label="label"
        :reduce="o => o.value"
        :placeholder="$__('Select a category...')"
        @update:modelValue="onUpdate"
    />
    <input
        v-else
        type="text"
        class="form-control"
        :value="modelValue ?? ''"
        :placeholder="$__('Leave empty for no default')"
        @input="onUpdate($event.target.value)"
    />
</template>

<script>
import { computed, watch } from "vue";

export default {
    name: "PatronFieldValueInput",
    props: {
        modelValue: { type: String, default: "" },
        resource: { type: Object, required: true },
        librariesArray: { type: Array, default: () => [] },
        categoriesArray: { type: Array, default: () => [] },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const kohaField = computed(() => props.resource?.koha_field);

        // Reset the default value when the target Koha field changes, since a
        // stored value (e.g. a branchcode) is meaningless for a different field.
        watch(kohaField, () => {
            emit("update:modelValue", "");
        });

        const onUpdate = value => emit("update:modelValue", value ?? "");

        return { kohaField, onUpdate };
    },
};
</script>
