<template>
    <span v-if="clearable" class="input-with-clear-wrapper">
        <input
            :id="id"
            inputmode="numeric"
            v-model="model"
            :placeholder="placeholder"
            :required="required"
            :size="size"
            class="input-with-clear"
        />
        <button
            v-if="model !== null && model !== undefined && model !== ''"
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
        inputmode="numeric"
        v-model="model"
        :placeholder="placeholder"
        :required="required"
        :size="size"
        :maxlength="maxlength"
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
        size: Number | null,
        maxlength: Number | null,
        clearable: {
            type: Boolean,
            default: true,
        },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const model = computed({
            get() {
                return typeof props.modelValue !== "undefined" &&
                    props.modelValue !== null &&
                    props.modelValue !== ""
                    ? parseFloat(props.modelValue)
                    : props.modelValue;
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
    name: "InputNumber",
};
</script>
