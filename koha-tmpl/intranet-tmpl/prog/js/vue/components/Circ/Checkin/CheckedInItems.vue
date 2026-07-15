<template>
    <table
        v-if="checkins.length"
        class="table table-striped"
        id="checkins-table"
    >
        <thead>
            <tr>
                <th>{{ $__("Due date") }}</th>
                <th>{{ $__("Title") }}</th>
                <th>{{ $__("Author") }}</th>
                <th>{{ $__("Barcode") }}</th>
                <th>{{ $__("Home library") }}</th>
                <th>{{ $__("Patron") }}</th>
                <th>{{ $__("Status / Messages") }}</th>
            </tr>
        </thead>
        <tbody>
            <tr
                v-for="(checkin, index) in checkins"
                :key="checkin.checkin_id || `pending-${index}`"
                :class="rowClass(checkin)"
            >
                <td v-html="formatDueDate(checkin)"></td>
                <td>
                    <a
                        v-if="checkin.item && checkin.item.biblio"
                        :href="`/cgi-bin/koha/catalogue/detail.pl?biblionumber=${checkin.item.biblio.biblio_id}`"
                    >
                        {{ checkin.item.biblio.title }}
                    </a>
                    <span v-else>—</span>
                </td>
                <td>
                    {{
                        checkin.item && checkin.item.biblio
                            ? checkin.item.biblio.author
                            : ""
                    }}
                </td>
                <td>
                    {{
                        checkin.item
                            ? checkin.item.external_id
                            : checkin._barcode || ""
                    }}
                </td>
                <td>{{ checkin.item ? checkin.item.home_library_id : "" }}</td>
                <td>
                    {{ patronDisplay(checkin) }}
                    <button
                        v-if="
                            checkin._status === 'success' &&
                            checkin.checkout &&
                            checkin.checkout.patron_id &&
                            checkin.checkout.patron
                        "
                        class="btn btn-xs btn-outline-secondary ms-1"
                        :title="$__('Print checkin slip')"
                        @click="printCheckinSlip(checkin.checkout.patron_id)"
                    >
                        <i class="fa fa-print"></i>
                        {{ $__("Print checkin slip") }}
                    </button>
                </td>
                <td>
                    <!-- Status indicator for pending items -->
                    <span
                        v-if="checkin._status === 'pending_confirmation'"
                        class="badge text-bg-warning"
                    >
                        <i class="fa fa-exclamation-triangle"></i>
                        {{ $__("Not checked in") }}
                    </span>
                    <span
                        v-else-if="checkin._status === 'needs_action'"
                        class="badge text-bg-warning"
                    >
                        <i class="fa fa-hand-paper"></i>
                        {{ actionLabel(checkin) }}
                    </span>
                    <span
                        v-else-if="checkin._status === 'blocked'"
                        class="badge text-bg-danger"
                    >
                        <i class="fa fa-ban"></i>
                        {{ $__("Blocked") }}
                    </span>
                    <span
                        v-else-if="checkin._status === 'dismissed'"
                        class="badge text-bg-secondary"
                    >
                        <i class="fa fa-times"></i>
                        {{ $__("Not checked in") }}
                    </span>

                    <!-- Confirmation details for pending items -->
                    <template v-if="checkin._status === 'pending_confirmation'">
                        <span
                            v-if="checkin._confirms.item_parts"
                            class="text-muted ms-2"
                        >
                            {{ $__("Materials:") }}
                            {{ checkin._confirms.item_parts }}
                        </span>
                    </template>

                    <!-- Action details for needs_action items -->
                    <template v-if="checkin._status === 'needs_action'">
                        <span
                            v-if="transferDestination(checkin)"
                            class="text-muted ms-2"
                        >
                            → {{ transferDestination(checkin) }}
                        </span>
                    </template>

                    <!-- Inline action buttons (visible when no modal is showing for this item) -->
                    <div
                        v-if="
                            checkin._status === 'pending_confirmation' ||
                            checkin._status === 'needs_action'
                        "
                        class="mt-1"
                    >
                        <button
                            class="btn btn-xs btn-outline-primary"
                            :title="$__('Resolve')"
                            @click="$emit('show-modal', checkin)"
                        >
                            <i class="fa fa-arrow-right"></i>
                            {{ $__("Resolve") }}
                        </button>
                    </div>

                    <!-- Regular messages for successful checkins -->
                    <template v-if="checkin._status === 'success'">
                        <span
                            v-for="msg in displayMessages(checkin)"
                            :key="msg.message"
                            class="badge ms-1"
                            :class="badgeClass(msg)"
                        >
                            {{ formatMessage(msg) }}
                        </span>
                    </template>

                    <!-- Audio alert trigger -->
                    <span
                        v-if="audioAlertClass(checkin) && index === 0"
                        :class="audioAlertClass(checkin)"
                        style="display: none"
                    ></span>
                </td>
            </tr>
        </tbody>
    </table>
    <p v-else class="text-muted">
        {{ $__("No items have been checked in yet.") }}
    </p>
</template>

<script>
import { $__ } from "@koha-vue/i18n";
import { printCheckinSlip } from "./slip-printer.js";
import { useCheckinStore } from "../../../stores/checkin.js";

export default {
    props: {
        checkins: {
            type: Array,
            required: true,
        },
    },
    emits: ["show-modal"],
    setup() {
        const store = useCheckinStore();

        function formatDueDate(checkin) {
            if (!checkin.checkout || !checkin.checkout.due_date) return "—";
            const dueDate = new Date(checkin.checkout.due_date);
            const formatted = dueDate.toLocaleDateString();
            const now = new Date();
            if (dueDate < now) {
                return `<span class="overdue">${formatted} (${$__("overdue")})</span>`;
            }
            return formatted;
        }

        function isOverdue(checkin) {
            if (!checkin.checkout || !checkin.checkout.due_date) return false;
            return new Date(checkin.checkout.due_date) < new Date();
        }

        function audioAlertClass(checkin) {
            if (!store.policy.global?.audio_alerts) return null;
            if (
                checkin._status === "blocked" ||
                checkin._status === "dismissed"
            ) {
                return "audio-alert-warning";
            }
            if (checkin._status === "success") {
                return "audio-alert-success";
            }
            return null;
        }

        function rowClass(checkin) {
            switch (checkin._status) {
                case "pending_confirmation":
                    return "table-warning";
                case "needs_action":
                    return "table-warning";
                case "blocked":
                    return "table-danger";
                case "dismissed":
                    return "table-secondary";
                default:
                    // Successful checkin — highlight overdue
                    if (checkin.messages?.some(m => m.type === "warning")) {
                        return "table-info";
                    }
                    return "";
            }
        }

        function patronDisplay(checkin) {
            if (!checkin.checkout?.patron_id) return "";
            // If patron data is embedded
            if (checkin.checkout?.patron) {
                const p = checkin.checkout.patron;
                return `${p.surname}, ${p.firstname}`;
            }
            return "";
        }

        function actionLabel(checkin) {
            switch (checkin._action_type) {
                case "hold":
                    return $__("Hold found");
                case "transfer":
                    return $__("Transfer needed");
                case "recall":
                    return $__("Recall found");
                default:
                    return $__("Action needed");
            }
        }

        function transferDestination(checkin) {
            const msg = (checkin.messages || []).find(
                m =>
                    m.message === "needs_transfer" ||
                    m.message === "transferred" ||
                    m.message === "wrong_transfer"
            );
            return msg?.payload?.to_library || "";
        }

        function displayMessages(checkin) {
            // Filter out messages that are already shown via action_type
            const actionMsgs = [
                "hold_found",
                "needs_transfer",
                "wrong_transfer",
                "recall_found",
            ];
            return (checkin.messages || []).filter(
                m => !actionMsgs.includes(m.message)
            );
        }

        function badgeClass(msg) {
            if (msg.type === "warning") return "text-bg-warning";
            if (msg.type === "error") return "text-bg-danger";
            return "text-bg-info";
        }

        function formatMessage(msg) {
            const labels = {
                not_issued: $__("Not checked out"),
                local_use: $__("Local use"),
                was_lost: $__("Was lost"),
                withdrawn: $__("Withdrawn"),
                transferred: $__("Transferred"),
                transfer_arrived: $__("Transfer arrived"),
                was_returned: $__("Already returned"),
                debarred: $__("Patron restricted"),
                previously_debarred: $__("Patron was restricted"),
                indefinitely_debarred: $__("Patron restricted indefinitely"),
                lost_item_fee_refunded: $__("Lost fee refunded"),
                lost_item_fee_charged: $__("Lost fee charged"),
                lost_item_fee_restored: $__("Lost fee restored"),
                processing_fee_refunded: $__("Processing fee refunded"),
            };
            return labels[msg.message] || msg.message.replace(/_/g, " ");
        }

        return {
            formatDueDate,
            isOverdue,
            audioAlertClass,
            rowClass,
            patronDisplay,
            actionLabel,
            transferDestination,
            displayMessages,
            badgeClass,
            formatMessage,
            printCheckinSlip,
            $__,
        };
    },
};
</script>

<style scoped>
.btn-xs {
    padding: 0.125rem 0.375rem;
    font-size: 0.75rem;
}
</style>
