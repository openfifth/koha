<template>
    <input
        :id="id"
        type="text"
        v-model="model"
        :placeholder="placeholder"
        :required="required"
        :class="classNames"
    />
</template>

<script>
import { computed } from "vue";
export default {
    props: {
        id: String,
        modelValue: Number | String,
        placeholder: String,
        required: Boolean,
        classNames: String,
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const model = computed({
            get() {
                return props.modelValue;
            },
            set(value) {
                emit("update:modelValue", value);
            },
        });
        return { model };
    },
    name: "InputText",
};
</script>

<style></style>
