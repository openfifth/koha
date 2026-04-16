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

<style scoped>
.input-with-clear-wrapper {
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
</style>
