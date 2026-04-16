<template>
    <span v-if="clearable" class="input-with-clear-wrapper">
        <input
            :id="id"
            type="text"
            v-model="model"
            :placeholder="placeholder"
            :required="required"
            class="input-with-clear"
        />
        <button
            v-if="model"
            type="button"
            class="clear-button"
            @click="clearInput"
            :aria-label="$__('Clear')"
            :title="$__('Clear')"
            tabindex="-1"
        >
            <i class="fa fa-xmark" aria-hidden="true"></i>
        </button>
    </span>
    <input
        v-else
        :id="id"
        type="text"
        v-model="model"
        :placeholder="placeholder"
        :required="required"
    />
</template>

<script>
import { computed } from "vue";
export default {
    props: {
        id: String,
        modelValue: String,
        placeholder: String,
        required: Boolean,
        clearable: {
            type: Boolean,
            default: true,
        },
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

        const clearInput = () => {
            model.value = "";
        };

        return { model, clearInput };
    },
    name: "InputText",
};
</script>
