<template>
    <div id="checkin-app">
        <h1>{{ $__("Check in") }}</h1>

        <div v-if="lastError" class="alert alert-danger" role="alert">
            {{ lastError }}
        </div>

        <BarcodeInput
            ref="barcodeInputRef"
            :disabled="isInputBlocked"
            :dropbox-mode="checkinOptions.dropbox_mode"
            :exempt-fine="checkinOptions.exempt_fine"
            @submit="onBarcodeScan"
            @toggle-options="showOptions = !showOptions"
        />

        <CheckinOptions
            v-show="showOptions"
            ref="checkinOptionsRef"
            class="mt-2"
            @update:options="onOptionsUpdate"
        />

        <!-- Pending items count indicator -->
        <div
            v-if="pendingItems.length > 1"
            class="alert alert-warning mt-3"
            role="alert"
        >
            <i class="fa fa-exclamation-triangle"></i>
            {{
                $__("%s items require attention").replace(
                    "%s",
                    pendingItems.length
                )
            }}
        </div>

        <CheckedInItems
            :checkins="checkins"
            class="mt-4"
            @show-modal="showModalFor"
        />

        <!-- Confirmation panel — shows one pending item at a time -->
        <ConfirmationModal
            :item="activeModalItem"
            :confirming="processing"
            @confirm="onConfirm"
            @dismiss="onDismiss"
            @resolve="onResolve"
        />
    </div>
</template>

<script>
import {
    computed,
    nextTick,
    onBeforeUnmount,
    onMounted,
    reactive,
    ref,
    watch,
} from "vue";
import { storeToRefs } from "pinia";
import { useCheckinStore } from "../../../stores/checkin.js";
import BarcodeInput from "./BarcodeInput.vue";
import CheckedInItems from "./CheckedInItems.vue";
import CheckinOptions from "./CheckinOptions.vue";
import ConfirmationModal from "./ConfirmationModal.vue";
import { $__ } from "@koha-vue/i18n";

export default {
    components: {
        BarcodeInput,
        CheckedInItems,
        CheckinOptions,
        ConfirmationModal,
    },
    setup() {
        const store = useCheckinStore();
        const {
            checkins,
            processing,
            lastError,
            pendingItems,
            nextModalItem,
            policy,
        } = storeToRefs(store);
        const barcodeInputRef = ref(null);
        const checkinOptionsRef = ref(null);
        const activeModalItem = ref(null);
        const showOptions = ref(false);

        const checkinOptions = reactive({
            dropbox_mode: false,
            exempt_fine: false,
            forgive_hold_fees: false,
            return_date: null,
        });

        function onOptionsUpdate(options) {
            Object.assign(checkinOptions, options);
        }

        // Block barcode input when a blocking modal is active
        const isInputBlocked = computed(() => {
            if (!activeModalItem.value) return false;
            const actionType = activeModalItem.value._action_type;
            // Holds always block (original UI behavior)
            if (actionType === "hold") return true;
            // Transfers block only when policy says so
            if (actionType === "transfer" && policy.value.transfers_block)
                return true;
            return false;
        });

        // Refocus barcode input when focus leaves to non-interactive elements
        // (e.g., sidebar toggle button, page chrome clicks)
        function handleDocumentClick(e) {
            // Refocus only when the sidebar collapse toggle is clicked
            if (e.target.closest(".sidebar-toggle")) {
                nextTick(() => refocusInput());
            }
        }

        onMounted(() => {
            document.addEventListener("click", handleDocumentClick);
        });

        onBeforeUnmount(() => {
            document.removeEventListener("click", handleDocumentClick);
        });

        // Watch for new pending items — auto-show panel for the first one
        watch(nextModalItem, newItem => {
            if (newItem && !activeModalItem.value) {
                activeModalItem.value = newItem;
                nextTick(() => refocusInput());
            }
        });

        function onBarcodeScan(barcode) {
            // Fire and forget — don't block the input
            store.checkin(barcode, { ...checkinOptions });
            // Clear return date if "remember" is not checked
            if (checkinOptionsRef.value) {
                checkinOptionsRef.value.afterCheckin();
            }
            nextTick(() => refocusInput());
        }

        function showModalFor(item) {
            activeModalItem.value = item;
        }

        async function onConfirm(item) {
            await store.confirmPending(item);
            _advanceModal();
        }

        function onDismiss(item) {
            store.dismissPending(item);
            _advanceModal();
        }

        async function onResolve(item, action, params = {}) {
            await store.resolveAction(item, action, params);
            _advanceModal();
        }

        function _advanceModal() {
            activeModalItem.value = null;
            setTimeout(() => {
                if (nextModalItem.value) {
                    activeModalItem.value = nextModalItem.value;
                } else {
                    refocusInput();
                }
            }, 100);
        }

        function refocusInput() {
            if (barcodeInputRef.value) {
                barcodeInputRef.value.focus();
            }
        }

        return {
            checkins,
            processing,
            lastError,
            pendingItems,
            activeModalItem,
            isInputBlocked,
            showOptions,
            barcodeInputRef,
            checkinOptionsRef,
            checkinOptions,
            onOptionsUpdate,
            onBarcodeScan,
            showModalFor,
            onConfirm,
            onDismiss,
            onResolve,
            $__,
        };
    },
};
</script>
