<template>
    <input
        :id="id"
        inputmode="numeric"
        v-model="model"
        :placeholder="placeholder"
        :required="required"
        :size="size"
        :maxlength="maxlength"
        :disabled="disabled"
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
        size: Number | null,
        maxlength: Number | null,
        disabled: Boolean,
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
    name: "InputNumber",
};
</script>

<style></style>
