<template>
    <input
        :id="id"
        type="text"
        v-model="model"
        :placeholder="placeholder"
        :required="required"
        :class="classNames"
        :disabled="disabled"
        :max="max"
        :min="min"
        :step="step"
        @blur="isInputActive = false"
        @focus="isInputActive = true"
    />
</template>

<script>
import { computed, ref } from "vue";
export default {
    props: {
        id: String,
        modelValue: Number | String,
        placeholder: String,
        required: Boolean,
        classNames: String,
        disabled: Boolean,
        max: Number | null,
        min: Number | null,
        step: Number | null,
        formatInputValue: Function,
        resource: Object,
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const isInputActive = ref(false);
        const model = computed({
            get() {
                if (props.formatInputValue == null) {
                    return props.modelValue;
                }
                if (isInputActive.value) {
                    return props.modelValue;
                } else {
                    return props.formatInputValue(
                        props.modelValue,
                        props.resource
                    );
                }
            },
            set(value) {
                emit("update:modelValue", value);
            },
        });
        return { model, isInputActive };
    },
    name: "InputText",
};
</script>

<style></style>
