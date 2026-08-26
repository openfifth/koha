<template>
    <div
        v-if="item"
        class="modal modal-lg show d-block audio-alert-action non-blocking"
        tabindex="-1"
        role="dialog"
        aria-modal="false"
    >
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title">{{ modalTitle }}</h1>
                </div>

                <div class="modal-body">
                    <!-- Item info (not shown for transfers - they render their own) -->
                    <p v-if="itemTitle && item._action_type !== 'transfer'">
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
                        <div
                            v-if="item._confirms.items_bundle"
                            class="alert alert-info"
                        >
                            <strong>{{
                                $__(
                                    "This item is a bundle. Please verify bundle contents before confirming check in."
                                )
                            }}</strong>
                        </div>
                    </template>

                    <!-- Post-checkin: Hold found -->
                    <template v-if="item._action_type === 'hold'">
                        <h4>{{ $__("Hold for:") }}</h4>
                        <ul
                            v-if="item.hold && item.hold.patron"
                            class="list-unstyled"
                        >
                            <li>
                                <strong>
                                    <a
                                        :href="`/cgi-bin/koha/circ/circulation.pl?borrowernumber=${item.hold.patron.patron_id}`"
                                    >
                                        {{ item.hold.patron.surname }},
                                        {{ item.hold.patron.firstname }}
                                    </a>
                                </strong>
                                <span
                                    v-if="item.hold.patron.category_id"
                                    class="patron-category"
                                >
                                    — {{ item.hold.patron.category_id }}
                                </span>
                            </li>
                            <li
                                v-if="
                                    item.hold.patron.address ||
                                    item.hold.patron.city
                                "
                            >
                                {{
                                    [
                                        item.hold.patron.address,
                                        item.hold.patron.city,
                                        item.hold.patron.state,
                                        item.hold.patron.postal_code,
                                    ]
                                        .filter(Boolean)
                                        .join(", ")
                                }}
                            </li>
                            <li v-if="item.hold.patron.phone">
                                {{ item.hold.patron.phone }}
                            </li>
                            <li v-if="item.hold.patron.email">
                                <a :href="`mailto:${item.hold.patron.email}`">{{
                                    item.hold.patron.email
                                }}</a>
                            </li>
                            <li v-if="item.hold.patron.sms_number">
                                <a
                                    :href="`tel:${item.hold.patron.sms_number}`"
                                    >{{ item.hold.patron.sms_number }}</a
                                >
                            </li>
                            <li
                                v-if="item.hold.patron.restricted"
                                class="text-danger"
                            >
                                <strong>{{
                                    $__("Patron is RESTRICTED")
                                }}</strong>
                            </li>
                            <li
                                v-if="item.hold.patron.incorrect_address"
                                class="text-danger"
                            >
                                {{ $__("Patron's address is in doubt") }}
                            </li>
                        </ul>
                        <p v-else-if="holdInfo">
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
                    </template>

                    <!-- Post-checkin: Transfer needed -->
                    <template v-if="item._action_type === 'transfer'">
                        <!-- Item info -->
                        <p>
                            <a
                                v-if="item.item && item.item.biblio"
                                :href="`/cgi-bin/koha/catalogue/detail.pl?biblionumber=${item.item.biblio.biblio_id}`"
                                >{{ itemBarcode }}: {{ itemTitle }}</a
                            >
                            <span v-else>{{ itemBarcode }}</span>
                        </p>

                        <!-- Reason for transfer -->
                        <div
                            v-if="transferInfo && transferInfo.trigger"
                            class="alert alert-info"
                        >
                            <h5>{{ $__("Reason for transfer") }}</h5>
                            <p>
                                {{
                                    formatTransferTrigger(transferInfo.trigger)
                                }}
                            </p>
                        </div>

                        <!-- Check in messages -->
                        <div
                            v-if="item.messages && item.messages.length"
                            class="alert alert-warning"
                        >
                            <h5>{{ $__("Check in message") }}</h5>
                            <p>{{ itemBarcode }}: {{ itemTitle }}</p>
                            <p
                                v-for="msg in item.messages.filter(
                                    m =>
                                        m.message !== 'wrong_transfer' &&
                                        m.message !== 'needs_transfer' &&
                                        m.message !== 'transferred'
                                )"
                                :key="msg.message"
                                class="text-danger"
                            >
                                {{ formatMessage(msg) }}
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

                    <!-- Post-checkin: Return claim -->
                    <template v-if="item._action_type === 'claim'">
                        <h4>{{ $__("Item was claimed returned") }}</h4>
                        <p>
                            {{
                                $__(
                                    "This item has an active return claim. Please resolve it."
                                )
                            }}
                        </p>
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
                        <select
                            v-if="holdCancellationReasons.length"
                            v-model="selectedCancelReason"
                            class="form-select form-select-sm d-inline-block"
                            style="width: auto"
                        >
                            <option value="">
                                {{ $__("No reason given") }}
                            </option>
                            <option
                                v-for="reason in holdCancellationReasons"
                                :key="reason.authorised_value"
                                :value="reason.authorised_value"
                            >
                                {{ reason.description }}
                            </option>
                        </select>
                        <button
                            type="button"
                            class="btn btn-danger"
                            :disabled="confirming"
                            accesskey="x"
                            @click="cancelHold"
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

                    <!-- Claim action buttons -->
                    <template v-if="item._action_type === 'claim'">
                        <button
                            type="button"
                            class="btn btn-warning"
                            accesskey="y"
                            @click="$emit('resolve-claim', item)"
                        >
                            <i class="fa fa-gavel"></i>
                            {{ $__("Resolve claim (Y)") }}
                        </button>
                        <button
                            type="button"
                            class="btn btn-default deny"
                            accesskey="n"
                            @click="$emit('dismiss', item)"
                        >
                            <i class="fa fa-times"></i>
                            {{ $__("Dismiss (N)") }}
                        </button>
                    </template>
                </div>
            </div>
        </div>
    </div>
    <!-- Backdrop -->
</template>

<script>
import { computed, onBeforeUnmount, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import { useCheckinStore } from "../../../stores/checkin.js";
import { $__ } from "@koha-vue/i18n";
import { printHoldSlip, printTransferSlip } from "./slip-printer.js";
import { APIClient } from "../../../fetch/api-client.js";

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
    emits: ["confirm", "dismiss", "resolve", "resolve-claim"],
    setup(props, { emit }) {
        const store = useCheckinStore();
        const { policy } = storeToRefs(store);

        const autoConfirmTimer = ref(null);
        const holdCancellationReasons = ref([]);
        const selectedCancelReason = ref("");

        // Fetch HOLD_CANCELLATION authorised values once
        APIClient.authorised_values.values
            .get("HOLD_CANCELLATION")
            .then(reasons => {
                holdCancellationReasons.value = reasons || [];
            })
            .catch(() => {});

        function cancelHold() {
            emit("resolve", props.item, "cancel_hold", {
                reason: selectedCancelReason.value || undefined,
            });
            selectedCancelReason.value = "";
        }

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
            if (props.item._action_type === "transfer") {
                const msgs = props.item.messages || [];
                const wrongTransfer = msgs.find(
                    m => m.message === "wrong_transfer"
                );
                if (wrongTransfer) {
                    const dest = wrongTransfer.payload?.to_library || "";
                    return $__(
                        "Wrong transfer detected, please return item to: %s"
                    ).replace("%s", dest);
                }
                return $__("Please return this item to: %s").replace(
                    "%s",
                    transferInfo.value?.to_library || ""
                );
            }
            if (props.item._action_type === "recall")
                return $__("Recall found");
            if (props.item._action_type === "claim") return $__("Return claim");
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

        function formatTransferTrigger(trigger) {
            const triggers = {
                Manual: $__("Manual"),
                StockrotationAdvance: $__("Stock rotation advance"),
                StockrotationRepatriation: $__("Stock rotation repatriation"),
                ReturnToHome: $__("Return to home library"),
                ReturnToHolding: $__("Return to holding library"),
                RotatingCollection: $__("Rotating collection"),
                Reserve: $__("Hold"),
                LostReserve: $__("Lost hold"),
                CancelReserve: $__("Cancelled hold"),
                TransferCancellation: $__(
                    "Transfer was cancelled whilst in transit"
                ),
                Recall: $__("Recall"),
                RecallCancellation: $__("Cancelled recall"),
            };
            return triggers[trigger] || trigger;
        }

        function formatMessage(msg) {
            const labels = {
                not_issued: $__("Not checked out."),
                local_use: $__("Local use recorded"),
                was_lost: $__("Was lost, now found"),
                withdrawn: $__("Item is withdrawn"),
                was_returned: $__("Already returned"),
            };
            return labels[msg.message] || msg.message.replace(/_/g, " ");
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
            formatTransferTrigger,
            formatMessage,
            holdCancellationReasons,
            selectedCancelReason,
            cancelHold,
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
