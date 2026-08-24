import { defineStore } from "pinia";
import { computed, reactive, ref } from "vue";
import { APIClient } from "../fetch/api-client.js";

export const useCheckinStore = defineStore("checkin", () => {
    const policy = reactive(window.__MODULE_POLICY__ || {});
    const libraryId = window.__LIBRARY_ID__ || null;
    const checkins = ref([]);
    const processing = ref(false);
    const lastError = ref(null);
    const _inflight = new Set();

    const maxItems = policy.max_returned_items || 20;

    /**
     * Items in the queue that need staff attention (modal or inline action).
     * Computed from checkins with pending statuses.
     */
    const pendingItems = computed(() =>
        checkins.value.filter(
            c =>
                c._status === "pending_confirmation" ||
                c._status === "needs_action"
        )
    );

    /**
     * The first pending item that should be shown in a modal.
     * Only one modal at a time — the rest stay as yellow rows.
     */
    const nextModalItem = computed(() => pendingItems.value[0] || null);

    /**
     * Perform a checkin. Adds entry to table regardless of outcome.
     * On 412: stores JWT and confirmation details for later resolution.
     * On 200 with hold/transfer/recall: marks as needs_action.
     */
    async function checkin(barcode, options = {}) {
        // Prevent double-scan: reject if this barcode has a request in-flight
        if (_inflight.has(barcode)) {
            return { status: "duplicate", data: null };
        }
        _inflight.add(barcode);

        processing.value = true;
        lastError.value = null;

        const body = { external_id: barcode };
        if (libraryId) body.library_id = libraryId;
        if (options.exempt_fine) body.exempt_fine = true;
        if (options.dropbox_mode) body.dropbox_mode = true;
        if (options.return_date) body.return_date = options.return_date;

        try {
            const client = APIClient.checkin;
            const response = await client.checkins.create(body, {
                confirmation: options.confirmation || null,
            });

            const data = await response.json();

            if (response.status === 412) {
                // Confirmation required — add to table as pending
                _addEntry({
                    checkin_id: null,
                    item: data.item || null,
                    checkout: data.checkout || null,
                    messages: [],
                    _status: "pending_confirmation",
                    _confirmation_token: data.confirmation_token,
                    _confirms: data.confirms || {},
                    _warnings: data.warnings || {},
                    _action_type: null,
                    _barcode: barcode,
                    _options: options,
                });
                return { status: "pending_confirmation", data };
            }

            if (response.status === 403) {
                // Check if the server sent an updated policy (capability revoked)
                _refreshPolicyFromResponse(response);

                // Blocked — add as blocked row
                _addEntry({
                    checkin_id: null,
                    item: data.item || null,
                    checkout: null,
                    messages: [
                        {
                            message: data.error_code || "checkin_blocked",
                            type: "error",
                        },
                    ],
                    _status: "blocked",
                    _confirmation_token: null,
                    _confirms: {},
                    _warnings: {},
                    _action_type: null,
                    _barcode: barcode,
                    _options: options,
                });
                return { status: "blocked", data };
            }

            if (response.status === 404) {
                lastError.value = "Item not found";
                return { status: "not_found", data };
            }

            if (!response.ok) {
                lastError.value = data.error || "An error occurred";
                return { status: "error", data };
            }

            // Success — determine if post-checkin action needed
            const actionType = _detectActionType(data);
            const status = actionType ? "needs_action" : "success";

            _addEntry({
                ...data,
                _status: status,
                _confirmation_token: null,
                _confirms: {},
                _warnings: {},
                _action_type: actionType,
                _barcode: barcode,
                _options: options,
            });

            return { status, data };
        } catch (error) {
            lastError.value = "Network error. Please try again.";
            return { status: "error", data: null };
        } finally {
            _inflight.delete(barcode);
            processing.value = false;
        }
    }

    /**
     * Confirm a pre-checkin confirmation (412 flow).
     * Re-issues the checkin request with the stored JWT.
     */
    async function confirmPending(entry) {
        const idx = checkins.value.indexOf(entry);
        if (idx === -1) return { status: "error", message: "Entry not found" };

        processing.value = true;

        try {
            const client = APIClient.checkin;
            const body = { external_id: entry._barcode };
            if (libraryId) body.library_id = libraryId;
            if (entry._options.exempt_fine) body.exempt_fine = true;
            if (entry._options.dropbox_mode) body.dropbox_mode = true;
            if (entry._options.return_date)
                body.return_date = entry._options.return_date;

            const response = await client.checkins.create(body, {
                confirmation: entry._confirmation_token,
            });

            const data = await response.json();

            if (!response.ok) {
                // Confirmation failed — keep as pending
                lastError.value = data.error || "Confirmation failed";
                return { status: "error", data };
            }

            // Confirmed successfully — update entry in place
            const actionType = _detectActionType(data);
            const status = actionType ? "needs_action" : "success";

            checkins.value[idx] = {
                ...data,
                _status: status,
                _confirmation_token: null,
                _confirms: {},
                _warnings: {},
                _action_type: actionType,
                _barcode: entry._barcode,
                _options: entry._options,
            };

            return { status, data };
        } catch (error) {
            lastError.value = "Network error during confirmation.";
            return { status: "error", data: null };
        } finally {
            processing.value = false;
        }
    }

    /**
     * Dismiss a pending confirmation without confirming (staff said "No").
     * Marks the row as dismissed.
     */
    function dismissPending(entry) {
        const idx = checkins.value.indexOf(entry);
        if (idx === -1) return;
        checkins.value[idx] = {
            ...entry,
            _status: "dismissed",
            _confirmation_token: null,
        };
    }

    /**
     * Resolve a post-checkin action (hold, transfer, recall).
     */
    async function resolveAction(entry, action, params = {}) {
        const idx = checkins.value.indexOf(entry);
        if (idx === -1) return { status: "error", message: "Entry not found" };

        try {
            const client = APIClient.checkin;
            const checkinId = entry.checkin_id;
            let data;

            switch (action) {
                case "confirm_hold":
                    data = await client.checkins.confirmHold(checkinId);
                    break;
                case "cancel_hold":
                    data = await client.checkins.cancelHold(
                        checkinId,
                        params.reason
                    );
                    break;
                case "confirm_transfer":
                    if (entry.transfer_id) {
                        data = await client.checkins.confirmTransfer(checkinId);
                    }
                    break;
                case "cancel_transfer":
                    if (entry.transfer_id) {
                        data = await client.checkins.cancelTransfer(checkinId);
                    }
                    break;
                case "confirm_recall":
                    data = await client.checkins.confirmRecall(checkinId);
                    break;
            }

            // Update entry in place — action resolved
            // Preserve item/checkout data from the original response
            // since sub-resource endpoints may not embed them fully
            const existing = checkins.value[idx];
            checkins.value[idx] = {
                ...existing,
                _status: "success",
                _action_type: null,
            };

            return { status: "ok", data };
        } catch (error) {
            return { status: "error", message: error.message };
        }
    }

    /**
     * Detect if a successful checkin requires post-action (hold/transfer/recall).
     */
    function _detectActionType(data) {
        const messages = data.messages || [];
        if (data.hold_id && messages.some(m => m.message === "hold_found")) {
            return "hold";
        }
        if (messages.some(m => m.message === "wrong_transfer")) {
            return "transfer";
        }
        if (
            data.transfer_id &&
            messages.some(
                m =>
                    m.message === "needs_transfer" ||
                    m.message === "transferred"
            )
        ) {
            return "transfer";
        }
        if (
            data.recall_id &&
            messages.some(m => m.message === "recall_found")
        ) {
            return "recall";
        }
        return null;
    }

    /**
     * If the response carries an X-Koha-Module-Policy header, decode the
     * JWT payload and update the reactive policy. This happens only on
     * 403 responses where the server signals a capability has been revoked.
     */
    function _refreshPolicyFromResponse(response) {
        const header = response.headers.get("X-Koha-Module-Policy");
        if (!header) return;

        try {
            // JWT payload is the second base64url-encoded segment
            const payload = header.split(".")[1];
            const decoded = JSON.parse(atob(payload));
            // Update the reactive policy in place
            Object.assign(policy, decoded);
        } catch (e) {
            // Malformed JWT — ignore, policy stays as-is
        }
    }

    /**
     * Add entry to the checkins list (most recent first), trim to max.
     */
    function _addEntry(entry) {
        checkins.value.unshift(entry);
        if (checkins.value.length > maxItems) {
            checkins.value = checkins.value.slice(0, maxItems);
        }
    }

    return {
        policy,
        checkins,
        processing,
        lastError,
        pendingItems,
        nextModalItem,
        checkin,
        confirmPending,
        dismissPending,
        resolveAction,
    };
});
