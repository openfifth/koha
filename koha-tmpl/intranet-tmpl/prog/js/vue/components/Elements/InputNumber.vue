<template>
    <span v-if="clearable" class="input-group">
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
            tabindex="-1"
        >
            <i class="fa fa-times"></i>
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
import { $__ } from "@koha-vue/i18n";
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

        return { model, clearInput, $__ };
    },
    name: "InputNumber",
};
</script>

<style scoped>
.input-group {
    position: relative;
    display: inline;
}

/* Input with clear button gets padding for the button */
input.input-with-clear {
    padding-right: 2rem;
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

.clear-button i {
    font-size: 1rem;
}
</style>
