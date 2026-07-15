<template>
    <div
        v-if="item"
        class="modal modal-lg show d-block audio-alert-action"
        :class="{ 'non-blocking': isNonBlockingTransfer }"
        tabindex="-1"
        role="dialog"
        :aria-modal="isNonBlockingTransfer ? 'false' : 'true'"
        data-bs-backdrop="static"
        data-bs-keyboard="false"
    >
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title">{{ modalTitle }}</h1>
                </div>

                <div class="modal-body">
                    <!-- Item info -->
                    <p v-if="itemTitle">
                        <a
                            v-if="biblioId"
                            :href="`/cgi-bin/koha/catalogue/detail.pl?biblionumber=${biblioId}`"
                        >
                            {{ itemBarcode }}: {{ itemTitle }}
                        </a>
                        <span v-else>{{ itemBarcode }}</span>
                    </p>

                    <!-- Pre-checkin confirmation: CircConfirmItemParts -->
                    <template v-if="isPreCheckin">
                        <div
                            v-if="item._confirms.item_parts"
                            class="alert alert-info"
                        >
                            <strong>{{
                                $__(
                                    "Please confirm that the accompanying materials are present:"
                                )
                            }}</strong>
                            {{ item._confirms.item_parts }}
                        </div>
                    </template>

                    <!-- Post-checkin: Hold found -->
                    <template v-if="item._action_type === 'hold'">
                        <h4>{{ $__("Hold found") }}</h4>
                        <div v-if="holdInfo" class="mb-3">
                            <p>
                                <strong>{{ $__("Hold for:") }}</strong>
                                {{ holdPatronDescription }}
                            </p>
                            <p v-if="holdLibrary">
                                <strong>{{
                                    needsTransfer
                                        ? $__("Transfer to:")
                                        : $__("Hold at:")
                                }}</strong>
                                {{ holdLibrary }}
                            </p>
                        </div>
                    </template>

                    <!-- Post-checkin: Transfer needed -->
                    <template v-if="item._action_type === 'transfer'">
                        <h4>{{ $__("Transfer required") }}</h4>
                        <div v-if="transferInfo" class="mb-3">
                            <p>
                                <strong>{{
                                    $__("Please return this item to:")
                                }}</strong>
                                {{ transferInfo.to_library }}
                            </p>
                        </div>
                    </template>

                    <!-- Post-checkin: Recall found -->
                    <template v-if="item._action_type === 'recall'">
                        <h4>{{ $__("Recall found") }}</h4>
                        <div v-if="recallInfo" class="mb-3">
                            <p v-if="recallInfo.needs_transfer">
                                <strong>{{
                                    $__("Transfer required for recall")
                                }}</strong>
                            </p>
                        </div>
                    </template>

                    <!-- Warnings -->
                    <div
                        v-for="(value, key) in item._warnings"
                        :key="key"
                        class="alert alert-warning"
                    >
                        {{ formatWarning(key, value) }}
                    </div>
                </div>

                <div class="modal-footer">
                    <!-- Pre-checkin confirmation buttons -->
                    <template v-if="isPreCheckin">
                        <button
                            type="button"
                            class="btn btn-primary approve"
                            :disabled="confirming"
                            accesskey="y"
                            @click="$emit('confirm', item)"
                        >
                            <i class="fa fa-check"></i>
                            {{ $__("Yes, check in (Y)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default deny"
                            :disabled="confirming"
                            accesskey="n"
                            @click="$emit('dismiss', item)"
                        >
                            <i class="fa fa-times"></i>
                            {{ $__("No, don't check in (N)") }}
                        </button>
                    </template>

                    <!-- Hold action buttons -->
                    <template v-if="item._action_type === 'hold'">
                        <button
                            type="button"
                            class="btn btn-primary approve"
                            :disabled="confirming"
                            accesskey="y"
                            @click="$emit('resolve', item, 'confirm_hold')"
                        >
                            <i class="fa fa-check"></i>
                            {{
                                needsTransfer
                                    ? $__("Confirm hold and transfer (Y)")
                                    : $__("Confirm hold (Y)")
                            }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default"
                            :disabled="confirming"
                            accesskey="p"
                            @click="printAndResolveHold"
                        >
                            <i class="fa fa-print"></i>
                            {{ $__("Print slip and confirm (P)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default deny"
                            :disabled="confirming"
                            accesskey="i"
                            @click="$emit('dismiss', item)"
                        >
                            <i class="fa fa-times"></i>
                            {{ $__("Ignore (I)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-danger"
                            :disabled="confirming"
                            accesskey="x"
                            @click="$emit('resolve', item, 'cancel_hold')"
                        >
                            <i class="fa fa-trash-can"></i>
                            {{ $__("Cancel hold (X)") }}
                        </button>
                    </template>

                    <!-- Transfer action buttons -->
                    <template v-if="item._action_type === 'transfer'">
                        <button
                            type="button"
                            class="btn btn-primary approve"
                            :disabled="confirming"
                            accesskey="y"
                            @click="$emit('resolve', item, 'confirm_transfer')"
                        >
                            <i class="fa fa-check"></i>
                            {{ $__("Yes, transfer (Y)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default"
                            :disabled="confirming"
                            accesskey="p"
                            @click="printAndResolveTransfer"
                        >
                            <i class="fa fa-print"></i>
                            {{ $__("Print slip and transfer (P)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default deny"
                            :disabled="confirming"
                            accesskey="n"
                            @click="$emit('resolve', item, 'cancel_transfer')"
                        >
                            <i class="fa fa-times"></i>
                            {{ $__("No, don't transfer (N)") }}
                        </button>
                    </template>

                    <!-- Recall action buttons -->
                    <template v-if="item._action_type === 'recall'">
                        <button
                            type="button"
                            class="btn btn-primary approve"
                            :disabled="confirming"
                            accesskey="y"
                            @click="$emit('resolve', item, 'confirm_recall')"
                        >
                            <i class="fa fa-check"></i>
                            {{ $__("Confirm recall (Y)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default"
                            :disabled="confirming"
                            accesskey="p"
                            @click="printAndResolveRecall"
                        >
                            <i class="fa fa-print"></i>
                            {{ $__("Print slip and confirm (P)") }}
                        </button>
                    </template>
                </div>
            </div>
        </div>
    </div>
    <!-- Backdrop -->
    <div
        v-if="item && !isNonBlockingTransfer"
        class="modal-backdrop show"
    ></div>
</template>

<script>
import { computed, onBeforeUnmount, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import { useCheckinStore } from "../../../stores/checkin.js";
import { $__ } from "@koha-vue/i18n";
import { printHoldSlip, printTransferSlip } from "./slip-printer.js";

export default {
    props: {
        item: {
            type: Object,
            default: null,
        },
        confirming: {
            type: Boolean,
            default: false,
        },
    },
    emits: ["confirm", "dismiss", "resolve"],
    setup(props, { emit }) {
        const store = useCheckinStore();
        const { policy } = storeToRefs(store);

        const autoConfirmTimer = ref(null);

        // Non-blocking transfer: muted style when transfers_block is false
        const isNonBlockingTransfer = computed(
            () =>
                props.item &&
                props.item._action_type === "transfer" &&
                !policy.value.transfers_block
        );

        // Auto-confirm transfers when policy.auto_confirm_transfer is true
        watch(
            () => props.item,
            newItem => {
                _clearAutoConfirm();
                if (
                    newItem &&
                    newItem._action_type === "transfer" &&
                    policy.value.auto_confirm_transfer
                ) {
                    autoConfirmTimer.value = setTimeout(() => {
                        emit("resolve", newItem, "confirm_transfer");
                    }, 1000);
                }
            },
            { immediate: true }
        );

        onBeforeUnmount(() => {
            _clearAutoConfirm();
        });

        function _clearAutoConfirm() {
            if (autoConfirmTimer.value) {
                clearTimeout(autoConfirmTimer.value);
                autoConfirmTimer.value = null;
            }
        }

        const isPreCheckin = computed(
            () => props.item && props.item._status === "pending_confirmation"
        );

        const itemBarcode = computed(
            () => props.item?.item?.external_id || props.item?._barcode || ""
        );

        const itemTitle = computed(() => props.item?.item?.biblio?.title || "");

        const biblioId = computed(
            () => props.item?.item?.biblio?.biblio_id || null
        );

        const modalTitle = computed(() => {
            if (!props.item) return "";
            if (isPreCheckin.value) return $__("Please confirm check in");
            if (props.item._action_type === "hold") return $__("Hold found");
            if (props.item._action_type === "transfer")
                return $__("Transfer required");
            if (props.item._action_type === "recall")
                return $__("Recall found");
            return $__("Action required");
        });

        const holdInfo = computed(() => {
            if (!props.item || props.item._action_type !== "hold") return null;
            const msg = (props.item.messages || []).find(
                m => m.message === "hold_found"
            );
            return msg?.payload || null;
        });

        const holdPatronDescription = computed(() => {
            if (!holdInfo.value) return "";
            // If hold is embedded with patron info
            if (props.item.hold?.patron) {
                const p = props.item.hold.patron;
                return `${p.surname}, ${p.firstname}`;
            }
            return holdInfo.value.patron_id
                ? `Patron #${holdInfo.value.patron_id}`
                : "";
        });

        const holdLibrary = computed(() => {
            return holdInfo.value?.library_id || "";
        });

        const needsTransfer = computed(() => {
            if (!props.item || props.item._action_type !== "hold") return false;
            const msgs = props.item.messages || [];
            return msgs.some(
                m =>
                    m.message === "needs_transfer" ||
                    m.message === "transferred"
            );
        });

        const transferInfo = computed(() => {
            if (!props.item) return null;
            const msg = (props.item.messages || []).find(
                m =>
                    m.message === "needs_transfer" ||
                    m.message === "wrong_transfer" ||
                    m.message === "transferred"
            );
            return msg?.payload || null;
        });

        const recallInfo = computed(() => {
            if (!props.item) return null;
            const msg = (props.item.messages || []).find(
                m => m.message === "recall_found"
            );
            return msg?.payload || null;
        });

        function formatWarning(key, value) {
            const labels = {
                not_issued: $__("Item was not checked out"),
                withdrawn: $__("Item is withdrawn"),
            };
            return labels[key] || key.replace(/_/g, " ");
        }

        function printAndResolveHold() {
            const reserveId = holdInfo.value?.reserve_id || props.item?.hold_id;
            if (reserveId) {
                printHoldSlip(reserveId);
            }
            emit("resolve", props.item, "confirm_hold", { print: true });
        }

        function printAndResolveTransfer() {
            const itemId = props.item?.item?.item_id;
            const destination = transferInfo.value?.to_library || "";
            if (itemId && destination) {
                printTransferSlip(itemId, destination);
            }
            emit("resolve", props.item, "confirm_transfer", { print: true });
        }

        function printAndResolveRecall() {
            const reserveId =
                recallInfo.value?.reserve_id || props.item?.hold_id;
            if (reserveId) {
                printHoldSlip(reserveId);
            }
            emit("resolve", props.item, "confirm_recall", { print: true });
        }

        return {
            isNonBlockingTransfer,
            isPreCheckin,
            itemBarcode,
            itemTitle,
            biblioId,
            modalTitle,
            holdInfo,
            holdPatronDescription,
            holdLibrary,
            needsTransfer,
            transferInfo,
            recallInfo,
            formatWarning,
            printAndResolveHold,
            printAndResolveTransfer,
            printAndResolveRecall,
            $__,
        };
    },
};
</script>

<style scoped>
/* Non-blocking transfers: no backdrop, pointer-events pass through */
.non-blocking {
    pointer-events: none;
}

.non-blocking .modal-dialog {
    pointer-events: auto;
}
</style>
