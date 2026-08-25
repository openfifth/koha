<template>
    <div
        class="toast-container position-fixed bottom-0 end-0 p-3"
        style="z-index: 1090"
    >
        <div
            v-if="modelValue"
            class="toast show"
            :class="'text-bg-' + variant"
            role="status"
            aria-live="polite"
            aria-atomic="true"
        >
            <div class="toast-header" :class="'text-bg-' + variant">
                <strong class="me-auto">{{ title }}</strong>
                <button
                    type="button"
                    class="btn-close"
                    :class="{ 'btn-close-white': variant !== 'light' }"
                    :aria-label="$__('Close')"
                    @click="dismiss"
                ></button>
            </div>
            <div class="toast-body">{{ message }}</div>
        </div>
    </div>
</template>

<script>
import { onBeforeUnmount, watch } from "vue";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        modelValue: Boolean,
        title: { type: String, default: () => $__("Success") },
        message: { type: String, default: "" },
        variant: { type: String, default: "success" },
        // Auto-dismiss after this many ms. Pass 0 to require a manual close.
        duration: { type: Number, default: 6000 },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        let timer = null;

        const dismiss = () => {
            clearTimeout(timer);
            emit("update:modelValue", false);
        };

        watch(
            () => props.modelValue,
            visible => {
                clearTimeout(timer);
                if (visible && props.duration > 0) {
                    timer = setTimeout(dismiss, props.duration);
                }
            },
            { immediate: true }
        );

        onBeforeUnmount(() => clearTimeout(timer));

        return { dismiss };
    },
    name: "Toast",
};
</script>

<style></style>
