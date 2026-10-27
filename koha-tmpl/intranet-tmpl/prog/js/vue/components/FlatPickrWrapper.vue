<template>
    <flatPickr
        :id="id"
        v-model="model"
        :required="required"
        :config="fp_config"
        :data-date_to="date_to"
    />
</template>

<script>
import { computed } from "vue";
import flatPickr from "vue-flatpickr-component";

export default {
    props: {
        id: String,
        modelValue: String,
        required: Boolean,
        date_to: String,
        config: {
            type: Object,
            default: null,
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
        // Callers override single keys of the staff interface defaults, for
        // example to add a flatpickr plugin; the defaults stay the base.
        const fp_config = computed(() => ({
            ...flatpickr_defaults,
            ...(props.config || {}),
        }));
        return {
            fp_config,
            model,
        };
    },
    components: { flatPickr },
    name: "FlatPickrWrapper",
};
</script>

<style></style>
