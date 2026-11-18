<template>
    <FormElement
        :resource="messageFilterOptions"
        :attr="{
            label: $__('Show confirmations'),
            name: 'showConfirmationRows',
            type: 'checkbox',
        }"
    />
    <table id="iso18626_messages">
        <thead>
            <tr>
                <th>{{ $__("Type") }}</th>
                <th>{{ $__("Information") }}</th>
                <th>{{ $__("Timestamp") }}</th>
                <th>{{ $__("Content") }}</th>
            </tr>
        </thead>
        <tbody>
            <tr
                v-for="message in filteredMessages"
                v-bind:key="message.iso18626_message_id"
            >
                <td>
                    <div class="d-flex gap-2">
                        <i
                            v-if="message.type.includes('request')"
                            class="fas fa-download mt-1"
                            aria-hidden="true"
                        ></i>
                        <i
                            v-else
                            class="fas fa-upload mt-1"
                            aria-hidden="true"
                        ></i>
                        <span>{{
                            getCodeDescription("messageType", message.type)
                        }}</span>
                    </div>
                </td>
                <td>
                    <div class="fw-bold">
                        {{ getMessageSummary(message.content) }}
                    </div>
                    <div
                        v-for="(line, index) in getMessageData(message.content)"
                        v-bind:key="index"
                        class="text-muted"
                    >
                        {{ line }}
                    </div>
                </td>
                <td>
                    {{ format_datetime(message.timestamp) }}
                </td>
                <td>
                    <button
                        class="btn btn-default btn-xs"
                        :title="$__('View message')"
                        @click="openModal(message.content)"
                    >
                        <i class="fas fa-envelope" aria-hidden="true"></i>
                        {{ $__("View") }}
                    </button>
                </td>
            </tr>
        </tbody>
    </table>
</template>

<script>
import FormElement from "../FormElement.vue";
import { inject, ref, computed } from "vue";
import { $__ } from "@koha-vue/i18n";
import { ISO18626 } from "./ISO18626.js";

export default {
    props: {
        iso18626_request: Object,
    },
    setup(props) {
        const format_datetime = $datetime;
        const { getCodeDescription } = ISO18626();

        const modalVisible = ref(false);
        const messageFilterOptions = ref({
            showConfirmationRows: false,
        });
        const prettifiedMessage = ref(null);
        const { setConfirmationDialog, setMessage, setError } =
            inject("mainStore");

        const filteredMessages = computed(() => {
            return props.iso18626_request.messages.filter(message => {
                if (messageFilterOptions.value.showConfirmationRows) {
                    return true;
                }
                return !message.type.toLowerCase().includes("confirmation");
            });
        });

        const parseMessage = message => {
            const parsedMessage = JSON.parse(message);
            return {
                messageType: Object.keys(parsedMessage)[0],
                content: Object.values(parsedMessage)[0] || {},
            };
        };

        const getMessageSummary = message => {
            const { messageType, content } = parseMessage(message);
            const messageInfo = content.messageInfo || {};
            const status = content.statusInfo?.status
                ? getCodeDescription("status", content.statusInfo.status)
                : null;
            const reasonForMessage =
                messageInfo.reasonForMessage || content.reasonForMessage;

            if (messageType === "request") {
                return $__("Request received");
            }

            if (messageType === "requestingAgencyMessage") {
                const actions = {
                    StatusRequest: $__(
                        "Requesting agency asked for a status update"
                    ),
                    Received: $__("Requesting agency confirmed receipt"),
                    Cancel: $__("Requesting agency asked to cancel"),
                    Renew: $__("Requesting agency asked to renew"),
                    ShippedReturn: $__("Requesting agency returned the item"),
                    ShippedForward: $__("Requesting agency forwarded the item"),
                    Notification: $__("Requesting agency sent a notification"),
                };
                return (
                    actions[content.action] ||
                    $__("Action: %s").format(content.action)
                );
            }

            if (messageType === "supplyingAgencyMessage") {
                if (reasonForMessage === "CancelResponse") {
                    return messageInfo.answerYesNo === "Y"
                        ? $__("Cancellation accepted")
                        : $__("Cancellation declined");
                }
                if (reasonForMessage === "RenewResponse") {
                    return messageInfo.answerYesNo === "Y"
                        ? $__("Renewal accepted")
                        : $__("Renewal declined");
                }
                if (reasonForMessage === "Notification") {
                    return $__("Notification sent");
                }
                if (reasonForMessage === "StatusChange" && status) {
                    return $__("Status changed to %s").format(status);
                }
                if (reasonForMessage === "RequestResponse" && status) {
                    return $__("Replied to request: %s").format(status);
                }
                if (reasonForMessage === "StatusRequestResponse" && status) {
                    return $__("Replied to status update request: %s").format(
                        status
                    );
                }
            }

            if (content.confirmationHeader) {
                return content.confirmationHeader.messageStatus === "ERROR"
                    ? $__("Message rejected")
                    : $__("Message acknowledged");
            }

            if (content.action) {
                return $__("Action: %s").format(content.action);
            }
            if (reasonForMessage) {
                return $__("Reason: %s").format(reasonForMessage);
            }
            return "";
        };

        const getMessageData = message => {
            const { content } = parseMessage(message);
            const messageInfo = content.messageInfo || {};
            const statusInfo = content.statusInfo || {};
            const errorData = content.errorData || {};
            const lines = [];
            const addLine = (label, value) => {
                if (value !== undefined && value !== null && value !== "") {
                    lines.push(label.format(value));
                }
            };

            addLine($__("Title: %s"), content.bibliographicInfo?.title);
            addLine(
                $__("Service type: %s"),
                content.serviceInfo?.serviceType
                    ? getCodeDescription(
                          "serviceType",
                          content.serviceInfo.serviceType
                      )
                    : null
            );
            addLine(
                $__("Reason unfilled: %s"),
                messageInfo.reasonUnfilled
                    ? getCodeDescription(
                          "reasonUnfilled",
                          messageInfo.reasonUnfilled
                      )
                    : null
            );
            addLine(
                $__("Reason for retry: %s"),
                messageInfo.reasonRetry
                    ? getCodeDescription("reasonRetry", messageInfo.reasonRetry)
                    : null
            );
            addLine(
                $__("Expected delivery date: %s"),
                statusInfo.expectedDeliveryDate
                    ? format_datetime(statusInfo.expectedDeliveryDate)
                    : null
            );
            addLine(
                $__("Due date: %s"),
                statusInfo.dueDate ? format_datetime(statusInfo.dueDate) : null
            );
            addLine($__("Item: %s"), content.deliveryInfo?.itemId);
            addLine(
                $__("Note: %s"),
                messageInfo.note || content.note || content.serviceInfo?.note
            );
            addLine($__("Error: %s"), errorData.errorType);
            addLine($__("Error details: %s"), errorData.errorValue);

            return lines;
        };

        function openModal(message) {
            const messageObj = Object.values(JSON.parse(message))[0];
            const container = document.createElement("div");
            container.classList.add("accordion");
            generateCollapsibleTabs(messageObj, container);
            const message_type = Object.keys(JSON.parse(message))[0];
            setConfirmationDialog({
                title: $__("ISO18626 message: %s").format(message_type),
                message: container.outerHTML,
                size: "modal-lg",
            });
        }

        function generateCollapsibleTabs(obj, parent) {
            const sortedKeys = Object.keys(obj).sort((a, b) => {
                const order = [
                    "action",
                    "header",
                    "confirmationHeader",
                    "bibliographicInfo",
                    "messageInfo",
                    "statusInfo",
                ];
                const indexA =
                    order.indexOf(a) !== -1 ? order.indexOf(a) : Infinity;
                const indexB =
                    order.indexOf(b) !== -1 ? order.indexOf(b) : Infinity;
                return indexA - indexB;
            });

            const top_level_key_number = Object.keys(obj).length;
            for (const key of sortedKeys) {
                if (typeof obj[key] === "object") {
                    const details = document.createElement("fieldset");
                    details.classList.add("rows");

                    const summary = document.createElement("legend");
                    const keySpan = document.createElement("span");
                    keySpan.textContent =
                        key.charAt(0).toUpperCase() + key.slice(1);
                    summary.appendChild(keySpan);
                    summary.setAttribute("data-bs-toggle", "collapse");
                    summary.setAttribute("data-bs-target", "#collapse_" + key);

                    if (key === "header") {
                        summary.setAttribute("aria-expanded", "false");
                        summary.classList.add("collapsed");
                    }
                    summary.classList.add("expanded");

                    summary.setAttribute("aria-controls", "collapseExample");
                    summary.innerHTML =
                        '<i class="fa fa-caret-down"></i> ' + summary.innerHTML;

                    const nestedContainer = document.createElement("ol");
                    nestedContainer.setAttribute("id", "collapse_" + key);
                    nestedContainer.classList.add("collapse");
                    if (key !== "header") {
                        nestedContainer.classList.add("show");
                    }
                    const nestedTable = document.createElement("table");

                    // Call generateTableRows for the nested object
                    generateTableRows(obj[key], nestedTable);

                    nestedContainer.appendChild(nestedTable);
                    details.appendChild(summary);
                    details.appendChild(nestedContainer);

                    parent.appendChild(details);
                } else {
                    // Handle regular top-level items
                    const div = document.createElement("div");
                    div.textContent =
                        key.charAt(0).toUpperCase() +
                        key.slice(1) +
                        ": " +
                        obj[key];
                    div.classList.add("fs-2", "fw-bold", "p-2");
                    parent.appendChild(div);
                }
            }
        }

        function generateTableRows(obj, parent) {
            for (const key in obj) {
                if (typeof obj[key] === "object") {
                    const tr = document.createElement("tr");
                    const th = document.createElement("th");
                    th.textContent = key;
                    tr.appendChild(th);

                    const td = document.createElement("td");
                    tr.appendChild(td);

                    const nestedTable = document.createElement("table");
                    nestedTable.classList.add("nested-table");
                    nestedTable.style.paddingLeft = "20px";
                    nestedTable.style.borderLeft = "1px solid #ccc";

                    generateTableRows(obj[key], nestedTable);

                    td.appendChild(nestedTable);

                    parent.appendChild(tr);
                } else {
                    const tr = document.createElement("tr");
                    const th = document.createElement("th");
                    th.textContent = key;
                    tr.appendChild(th);

                    const td = document.createElement("td");
                    td.textContent = obj[key];
                    tr.appendChild(td);

                    parent.appendChild(tr);
                }
            }
        }

        return {
            modalVisible,
            prettifiedMessage,
            openModal,
            filteredMessages,
            messageFilterOptions,
            getMessageData,
            getMessageSummary,
            getCodeDescription,
            format_datetime,
        };
    },
    components: {
        FormElement,
    },
    name: "ResourceFormSave",
};
</script>
