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

        <!-- Active settings indicators (visible when panel is collapsed) -->
        <div
            v-if="!showOptions && hasActiveSettings"
            class="checkin-active-settings mt-1"
        >
            <span
                v-if="checkinOptions.exempt_fine"
                class="badge text-bg-warning me-1"
            >
                <i class="fa fa-check"></i> {{ $__("Fines forgiven") }}
            </span>
            <span
                v-if="checkinOptions.dropbox_mode"
                class="badge text-bg-warning me-1"
            >
                <i class="fa fa-check"></i> {{ $__("Book drop mode") }}
            </span>
            <span
                v-if="checkinOptions.return_date"
                class="badge text-bg-warning me-1"
            >
                <i class="fa fa-check"></i> {{ $__("Return date:") }}
                {{ checkinOptions.return_date }}
            </span>
        </div>

        <CheckinOptions
            v-show="showOptions"
            ref="checkinOptionsRef"
            class="mt-2"
            @update:options="onOptionsUpdate"
        />

        <!-- Detailed messages for the last checkin -->
        <div
            v-if="lastCheckinMessages.length"
            class="mt-3"
            @click="onMessagesClick"
        >
            <div
                v-for="msg in lastCheckinMessages"
                :key="msg.message"
                class="alert"
                :class="msg.alertClass"
            >
                <p class="mb-0" v-html="msg.text"></p>
            </div>
        </div>

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
            @resolve-claim="onResolveClaimFromRow"
        />

        <!-- Confirmation panel — shows one pending item at a time -->
        <ConfirmationModal
            :item="activeModalItem"
            :confirming="processing"
            @confirm="onConfirm"
            @dismiss="onDismiss"
            @resolve="onResolve"
            @resolve-claim="onResolveClaimFromModal"
        />

        <ResolveClaimModal
            :claim-id="activeClaimId"
            :visible="showClaimModal"
            @resolved="onClaimResolved"
            @close="showClaimModal = false"
        />

        <BundleVerificationModal
            :visible="showBundleModal"
            :item-id="bundleItemId"
            :barcode="bundleBarcode"
            @confirm="onBundleConfirm"
            @cancel="showBundleModal = false"
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
import ResolveClaimModal from "./ResolveClaimModal.vue";
import BundleVerificationModal from "./BundleVerificationModal.vue";
import { $__ } from "@koha-vue/i18n";

export default {
    components: {
        BarcodeInput,
        CheckedInItems,
        CheckinOptions,
        ConfirmationModal,
        ResolveClaimModal,
        BundleVerificationModal,
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
        const showClaimModal = ref(false);
        const activeClaimId = ref(null);
        const showBundleModal = ref(false);
        const bundleItemId = ref(null);
        const bundleBarcode = ref("");

        const checkinOptions = reactive({
            dropbox_mode: false,
            exempt_fine: false,
            forgive_hold_fees: false,
            return_date: null,
        });

        function onOptionsUpdate(options) {
            Object.assign(checkinOptions, options);
        }

        // Async mode: input is never blocked. Staff can keep scanning
        // while modals are showing. Items needing attention queue as
        // yellow rows and modals show one at a time.
        const isInputBlocked = computed(() => false);

        const hasActiveSettings = computed(
            () =>
                checkinOptions.exempt_fine ||
                checkinOptions.dropbox_mode ||
                checkinOptions.return_date
        );

        // Detailed messages for the most recent checkin (shown as alert boxes)
        const lastCheckinMessages = computed(() => {
            if (!checkins.value.length) return [];
            const latest = checkins.value[0];
            if (latest._status !== "success") return [];
            const messages = latest.messages || [];
            const detailed = [];
            const feeMessages = {
                lost_item_fee_refunded: {
                    text: $__(
                        "A refund for the lost item charge has been applied to the borrowing patron's account."
                    ),
                    alertClass: "alert-info",
                },
                lost_item_fee_charged: {
                    text: $__(
                        "A refund for the lost item charge has been applied, and a new overdue charge has been calculated."
                    ),
                    alertClass: "alert-info",
                },
                lost_item_fee_restored: {
                    text: $__(
                        "A refund for the lost item charge has been applied and any forgiven overdue fines have been reverted."
                    ),
                    alertClass: "alert-info",
                },
                lost_item_payment_not_refunded: {
                    text: $__(
                        "The payment for the lost item is older than the refund threshold. No refund applied."
                    ),
                    alertClass: "alert-warning",
                },
                processing_fee_refunded: {
                    text: $__(
                        "A refund for the lost item processing charge has been applied to the borrowing patron's account."
                    ),
                    alertClass: "alert-info",
                },
                was_lost: {
                    text: $__("Item was lost, now found."),
                    alertClass: "alert-info",
                },
                debarred: {
                    text: $__("Patron is now restricted."),
                    alertClass: "alert-warning",
                },
                previously_debarred: {
                    text: $__("Reminder: Patron was earlier restricted."),
                    alertClass: "alert-warning",
                },
                indefinitely_debarred: {
                    text: $__(
                        "Reminder: Patron has an indefinite restriction."
                    ),
                    alertClass: "alert-warning",
                },
            };
            for (const msg of messages) {
                if (feeMessages[msg.message]) {
                    detailed.push(feeMessages[msg.message]);
                }
                if (msg.message === "in_bundle" && msg.payload) {
                    detailed.push({
                        text: $__(
                            'This item belongs to a bundle. <a href="/cgi-bin/koha/catalogue/detail.pl?biblionumber=%s">View host item</a> — <button class="btn btn-xs btn-warning remove-from-bundle" data-item-id="%s">Remove from bundle</button>'
                        )
                            .replace("%s", latest.item?.biblio?.biblio_id || "")
                            .replace("%s", msg.payload.host_item_id || ""),
                        alertClass: "alert-warning",
                    });
                }
                if (msg.message === "item_type_checkinmsg" && msg.payload) {
                    detailed.push({
                        text: msg.payload.text,
                        alertClass:
                            msg.type === "alert"
                                ? "alert-warning"
                                : "alert-info",
                    });
                }
                if (msg.message === "patron_has_fines" && msg.payload) {
                    detailed.push({
                        text: $__(
                            'Patron has outstanding fines of %s. <a href="/cgi-bin/koha/members/pay.pl?borrowernumber=%s">Make payment</a>'
                        )
                            .replace("%s", msg.payload.balance)
                            .replace("%s", msg.payload.patron_id),
                        alertClass: "alert-warning",
                    });
                }
                if (msg.message === "patron_has_waiting_holds" && msg.payload) {
                    detailed.push({
                        text: $__(
                            'Patron has %s hold(s) waiting for pickup. <a href="/cgi-bin/koha/circ/circulation.pl?borrowernumber=%s">Check out to this patron</a>'
                        )
                            .replace("%s", msg.payload.waiting_count)
                            .replace("%s", msg.payload.patron_id),
                        alertClass: "alert-info",
                    });
                }
                // return_claim is handled by the row (yellow + resolve button)
                // No alert needed
                if (msg.message === "claim_auto_resolved") {
                    detailed.push({
                        text: $__(
                            "Previously claimed returned item has been checked in. Claim automatically resolved."
                        ),
                        alertClass: "alert-info",
                    });
                }
            }
            return detailed;
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

        function onMessagesClick(e) {
            const btn = e.target.closest(".resolve-claim-btn");
            if (btn) {
                activeClaimId.value = parseInt(btn.dataset.claimId);
                showClaimModal.value = true;
            }
        }

        function onResolveClaimFromRow(checkin) {
            const claimMsg = (checkin.messages || []).find(
                m => m.message === "return_claim"
            );
            if (claimMsg && claimMsg.payload) {
                activeClaimId.value = claimMsg.payload.claim_id;
                showClaimModal.value = true;
            }
        }

        function onResolveClaimFromModal(item) {
            // Close the confirmation modal and open the resolve claim modal
            activeModalItem.value = null;
            const claimMsg = (item.messages || []).find(
                m => m.message === "return_claim"
            );
            if (claimMsg && claimMsg.payload) {
                activeClaimId.value = claimMsg.payload.claim_id;
                showClaimModal.value = true;
            }
        }

        function onClaimResolved() {
            showClaimModal.value = false;
            // Mark the claim row as resolved
            const idx = checkins.value.findIndex(
                c => c._action_type === "claim" && c._status === "needs_action"
            );
            if (idx !== -1) {
                checkins.value[idx] = {
                    ...checkins.value[idx],
                    _status: "success",
                    _action_type: null,
                };
            }
            activeClaimId.value = null;
        }

        async function onConfirm(item) {
            // For bundle items, show the verification modal instead of confirming directly
            if (item._confirms && item._confirms.items_bundle) {
                activeModalItem.value = null;
                bundleItemId.value = item.item?.item_id || null;
                bundleBarcode.value =
                    item._barcode || item.item?.external_id || "";
                showBundleModal.value = true;
                // Store the item for later confirmation
                _pendingBundleItem = item;
                return;
            }
            await store.confirmPending(item);
            _advanceModal();
        }

        let _pendingBundleItem = null;

        async function onBundleConfirm(result) {
            showBundleModal.value = false;
            if (_pendingBundleItem) {
                // Pass verified barcodes through options — they will be
                // included in the POST /checkins body alongside the JWT
                if (result.verify) {
                    _pendingBundleItem._options.verified_bundle_barcodes =
                        result.scanned || [];
                }
                await store.confirmPending(_pendingBundleItem);
                _pendingBundleItem = null;
            }
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
            hasActiveSettings,
            lastCheckinMessages,
            showOptions,
            showClaimModal,
            activeClaimId,
            showBundleModal,
            bundleItemId,
            bundleBarcode,
            barcodeInputRef,
            checkinOptionsRef,
            checkinOptions,
            onOptionsUpdate,
            onBarcodeScan,
            showModalFor,
            onMessagesClick,
            onResolveClaimFromRow,
            onResolveClaimFromModal,
            onClaimResolved,
            onBundleConfirm,
            onConfirm,
            onDismiss,
            onResolve,
            $__,
        };
    },
};
</script>
