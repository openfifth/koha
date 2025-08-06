<template>
    <h2>{{ $__("Progress request") }}</h2>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <template v-if="initialized">
        <div class="page-section">
            <p>
                This request's status is
                <strong>{{ iso18626_request.status }}</strong
                >.
            </p>
            <p>Below are the possible actions in order to progress it.</p>
        </div>
        <fieldset class="rows">
            <table id="request-status" class="table table-bordered">
                <thead>
                    <tr>
                        <th>{{ $__("Action") }}</th>
                        <th>{{ $__("Description") }}</th>
                    </tr>
                </thead>
                <tbody>
                    <tr v-for="(status, key) in statuses" :key="key">
                        <template
                            v-if="
                                status.show_if_status_in.includes(
                                    iso18626_request.status
                                )
                            "
                        >
                            <td>
                                <button
                                    class="btn"
                                    :class="`${status.btn_class ? status.btn_class : 'btn-default'}`"
                                    @click="progressRequest(key)"
                                >
                                    <span
                                        :class="`fa-solid ${status.icon}`"
                                    ></span>
                                    {{ status.button_label }}
                                </button>
                            </td>
                            <td>
                                {{ status.description }}
                            </td>
                        </template>
                    </tr>
                </tbody>
            </table>
        </fieldset>
        <div
            v-if="iso18626_request.status == 'CopyCompleted'"
            class="page-section"
        >
            <p>This request has been completed. Nothing to do here.</p>
        </div>
    </template>
</template>

<script>
import { useRoute, useRouter } from "vue-router";
import { createVNode, onBeforeMount, onMounted, ref, render } from "vue";
import { APIClient } from "../../fetch/api-client.js";
import { useDataTable } from "../../composables/datatables";
import { inject } from "vue";
import { $__ } from "@koha-vue/i18n";

export default {
    setup() {
        const initialized = ref(false);
        const status = ref("RequestReceived"); // <--- define it here
        const iso18626_request = ref(null);
        const router = useRouter();

        const { setConfirmationDialog, setMessage, setError } =
            inject("mainStore");

        const statuses = ref({
            ExpectToSupply: {
                confirm_message: $__("TODO: Write this"),
                description: $__(
                    "Supplying library expects to fill the request, based on e.g. information in the local OPAC"
                ),
                button_label: $__("Expect to supply"),
                icon: "fa-calendar-days",
                show_if_status_in: ["RequestReceived"],
            },
            CopyCompleted: {
                confirm_message: $__(
                    "By changing this request's status to CopyCompleted, a message will be sent to the requesting library notifying them that the transaction has concluded."
                ),
                description: $__(
                    "The supplying library has sent the requested item (this status is used when there is no need to return the item supplied)"
                ),
                button_label: $__("Copy completed"),
                icon: "fa-check",
                btn_class: "btn-primary",
                show_if_status_in: ["RequestReceived"],
            },
            Loaned: {
                confirm_message: $__(
                    "By changing this request's status to Loaned, a message will be sent to the requesting library notifying them that the item has been supplied."
                ),
                description: $__(
                    "The item is currently on loan to the requesting library for this request"
                ),
                button_label: $__("Mark as loaned"),
                icon: "fa-box",
                show_if_status_in: [
                    "RequestReceived",
                    "ExpectToSupply",
                    "WillSupply",
                ],
            },
            RetryPossible: {
                confirm_message: $__(
                    "By changing this request's status to RetryPossible, a message will be sent to the requesting library and they can submit a Retry request."
                ),
                description: $__(
                    "The supplying library cannot fill the request based on information provided or may be able to supply at a later date. The requesting library may submit a Retry request which may include updated information"
                ),
                button_label: $__("Ask for retry"),
                icon: "fa-repeat",
                show_if_status_in: [
                    "RequestReceived",
                    "WillSupply",
                    "ExpectToSupply",
                ],
            },
            WillSupply: {
                confirm_message: $__(
                    "By changing this request's status to WillSupply, a message will be sent to the requesting library notifying them that the item will be supplied."
                ),
                description: $__(
                    "Supplying library has located the item but has not sent it yet"
                ),
                button_label: $__("Will supply"),
                icon: "fa-calendar-days",
                show_if_status_in: ["RequestReceived", "ExpectToSupply"],
            },
            Unfilled: {
                confirm_message: $__(
                    "By changing this request's status to Unfilled, a message will be sent to the requesting library notifying them that the item will not be supplied."
                ),
                description: $__(
                    "The supplying library cannot fill the request. The explanation may be provided in the ReasonUnfilled data element"
                ),
                button_label: $__("Unfilled"),
                icon: "fa-calendar-days",
                btn_class: "btn-danger",
                show_if_status_in: ["RequestReceived"],
            },
        });

        const progressRequest = action => {
            setConfirmationDialog(
                {
                    title: $__(
                        "Update this request's status to <strong>%s</strong>?"
                    ).format(action),
                    message: statuses.value[action].confirm_message,
                    accept_label: $__("Yes, update"),
                    cancel_label: $__("No, do not update"),
                    inputs: [
                        {
                            name: "status",
                            type: "hidden",
                            value: action,
                            label: $__("Status"),
                            required: false,
                        },
                    ],
                },
                (callback_result, inputFields) => {
                    const client = APIClient.ill.supplying;
                    client
                        .patch(
                            { status: inputFields.status },
                            iso18626_request.value.iso18626_request_id
                        )
                        .then(
                            success => {
                                router.push({
                                    name: "SupplyingShow",
                                    params: {
                                        iso18626_request_id:
                                            iso18626_request.value
                                                .iso18626_request_id,
                                    },
                                });
                            },
                            error => {}
                        );
                }
            );
        };

        onBeforeMount(() => {
            const route = useRoute();
            const client = APIClient.ill.supplying;
            client.get(route.params.iso18626_request_id).then(
                result => {
                    iso18626_request.value = result;
                    initialized.value = true;
                },
                error => {}
            );
        });
        onMounted(() => {
            // buildDatatable();
        });
        return {
            status,
            initialized,
            progressRequest,
            statuses,
            iso18626_request,
        };
    },
    name: "ProgressRequest",
};
</script>
