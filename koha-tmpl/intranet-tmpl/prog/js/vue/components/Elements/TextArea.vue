<template>
    <span v-if="clearable" class="textarea-group">
        <textarea
            :id="id"
            v-model="model"
            :rows="rows"
            :cols="cols"
            :placeholder="placeholder"
            :required="required"
            class="textarea-with-clear"
        />
        <button
            v-if="model"
            type="button"
            class="clear-button"
            @click="clearInput"
            :aria-label="$__('Clear')"
            tabindex="-1"
        >
            <i class="fa fa-times"></i>
        </button>
    </span>
    <textarea
        v-else
        :id="id"
        v-model="model"
        :rows="rows"
        :cols="cols"
        :placeholder="placeholder"
        :required="required"
    />
</template>

<script>
import { computed } from "vue";
import { $__ } from "@koha-vue/i18n";
export default {
    props: {
        id: String,
        modelValue: String,
        placeholder: String,
        required: Boolean,
        rows: {
            type: Number,
            default: 10,
        },
        cols: {
            type: Number,
            default: 50,
        },
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

        return { model, clearInput, $__ };
    },
    name: "TextArea",
};
</script>

<style scoped>
.textarea-group {
    position: relative;
    display: inline-block;
}

/* Textarea with clear button gets padding for the button */
textarea.textarea-with-clear {
    padding-right: 2rem;
}

.clear-button {
    position: absolute;
    right: 0.5rem;
    top: 0.5rem;
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
