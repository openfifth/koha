<template>
    <span v-if="clearable" class="textarea-with-clear-wrapper">
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
            :title="$__('Clear')"
            tabindex="-1"
        >
            <i class="fa fa-xmark" aria-hidden="true"></i>
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

        return { model, clearInput };
    },
    name: "TextArea",
};
</script>
