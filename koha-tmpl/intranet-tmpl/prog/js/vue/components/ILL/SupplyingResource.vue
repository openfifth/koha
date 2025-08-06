<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { useRoute, useRouter } from "vue-router";
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { inject, ref } from "vue";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
    },

    setup(props) {
        const router = useRouter();

        const { setConfirmationDialog, setMessage, setError } =
            inject("mainStore");

        const statuses = ref([
            {
                id: "RequestReceived",
                next_actions: [
                    "ExpectToSupply",
                    "CopyCompleted",
                    "Loaned",
                    "RetryPossible",
                    "WillSupply",
                    "Unfilled",
                    "Cancelled",
                ],
            },
            {
                id: "ExpectToSupply",
                confirm_message: $__(
                    "Supplying library expects to fill the request, based on e.g. information in the local OPAC. The message may include the ExpectedDeliveryDate"
                ),
                button_label: $__("Expect to supply"),
                icon: "fa-calendar-days",
                next_actions: [
                    "Loaned",
                    "WillSupply",
                    "RetryPossible",
                    "Unfilled",
                ],
            },
            {
                id: "WillSupply",
                confirm_message: $__(
                    "Supplying library has located the item but has not sent it yet."
                ),
                button_label: $__("Will supply"),
                icon: "fa-calendar-days",
                next_actions: [
                    "Loaned",
                    "RetryPossible",
                    "CopyCompleted",
                    "Unfilled",
                ],
            },
            {
                id: "Loaned",
                confirm_message: $__(
                    "The item is currently on loan to the requesting library for this request"
                ),
                button_label: $__("Mark as loaned"),
                icon: "fa-box",
                next_actions: [
                    "Overdue",
                    "LoanCompleted",
                    "CompletedWithoutReturn",
                ], //[ 'Recalled', 'HoldReturn' ]
            },
            {
                id: "Overdue",
                confirm_message: $__(
                    "The item currently on loan to the requesting library for this request is now overdue"
                ),
                button_label: $__("Mark as ovedue"),
                icon: "fa-box",
                next_actions: ["LoanCompleted", "CompletedWithoutReturn"], //[ 'Recalled', 'HoldReturn', 'LoanCompleted' ]
            },
            {
                id: "Recalled",
                confirm_message: $__(
                    "The item currently on loan to the requesting library for this request has been recalled"
                ),
                button_label: $__("Ask for recall"),
                icon: "fa-box",
                next_actions: ["LoanCompleted", "CompletedWithoutReturn"],
            },
            {
                id: "RetryPossible",
                confirm_message: $__(
                    "The supplying library cannot fill the request based on information provided or may be able to supply at a later date. Additional information is provided in the RetryInfo section. The requesting library may submit a Retry request which may include updated information"
                ),
                button_label: $__("Ask for retry"),
                icon: "fa-repeat",
                next_actions: [],
            },
            {
                id: "Unfilled",
                confirm_message: $__(
                    "The supplying library cannot fill the request. The explanation may be provided in the ReasonUnfilled data element"
                ),
                button_label: $__("Unfilled"),
                icon: "fa-calendar-days",
                btn_class: "btn btn-danger",
                next_actions: [],
            },
            //HoldReturn
            //ReleaseHoldReturn
            {
                id: "CopyCompleted",
                confirm_message: $__(
                    "The supplying library has sent the requested item (this status is used when there is no need to return the item supplied)"
                ),
                button_label: $__("Copy completed"),
                icon: "fa-check",
                btn_class: "btn btn-primary",
                next_actions: [],
                dont_show: iso18626_request =>
                    iso18626_request.service_type === "Loan",
            },
            {
                id: "LoanCompleted",
                confirm_message: $__(
                    "The supplying library has received the borrowed item from the requesting agency (this status is used for requests when the item supplied shall be returned by the requesting library, i.e. a loan)"
                ),
                button_label: $__("Loan completed"),
                icon: "fa-check",
                btn_class: "btn btn-primary",
                next_actions: [],
            },
            {
                id: "CompletedWithoutReturn",
                confirm_message: $__(
                    "The supplying library has closed the request without the return of supplied item, e.g. because of loss or damage"
                ),
                button_label: $__("Complete without return"),
                icon: "fa-check",
                btn_class: "btn btn-primary",
                next_actions: [],
            },
            {
                id: "Cancelled",
                confirm_message: $__(
                    "The supplying library has cancelled the request (as indicated by the requesting library)"
                ),
                button_label: $__("Cancel"),
                icon: "fa-check",
                btn_class: "btn btn-danger",
                action_inputs: [
                    {
                        name: "answerYesNo",
                        type: "boolean",
                        label: $__("Can cancel?"),
                        value: true,
                    },
                ],
                dont_show: iso18626_request =>
                    iso18626_request.pending_requesting_agency_action !==
                    "Cancel",
            },
        ]);

        const progressRequest = (action, iso18626_request) => {
            const statusToUpdate = statuses.value.find(
                status => status.id === action
            );
            setConfirmationDialog(
                {
                    title: $__(
                        "Update this request's status to <strong>%s</strong>?"
                    ).format(action),
                    message: statusToUpdate.confirm_message,
                    accept_label: $__("Confirm"),
                    cancel_label: $__("Cancel"),
                    inputs: [
                        ...(statusToUpdate.action_inputs
                            ? statusToUpdate.action_inputs
                            : []),
                        {
                            name: "messageInfoNote",
                            type: "textarea",
                            label: $__("Message note"),
                            required: false,
                        },
                        {
                            name: "status",
                            type: "text",
                            hide: 1,
                            value: action,
                            label: $__("Status"),
                            required: false,
                        },
                    ],
                },
                (callback_result, inputFields) => {
                    const client = APIClient.ill.supplying;
                    inputFields.answerYesNo =
                        inputFields.answerYesNo === true
                            ? "Y"
                            : inputFields.answerYesNo === false
                              ? "N"
                              : undefined;

                    client
                        .patch(
                            inputFields,
                            iso18626_request.iso18626_request_id
                        )
                        .then(
                            success => {
                                for (const key in success) {
                                    if (iso18626_request.hasOwnProperty(key)) {
                                        iso18626_request[key] = success[key];
                                    }
                                }
                                setMessage(
                                    $__("ISO18626 request #%s updated").format(
                                        iso18626_request.iso18626_request_id
                                    ),
                                    true
                                );
                            },
                            error => {}
                        );
                }
            );
        };

        const additionalToolbarButtons = resource => {
            const show_buttons = [];
            const currentStatus = statuses.value.find(
                status => status.id === resource.status
            );
            if (currentStatus) {
                currentStatus.next_actions.forEach(nextStatus => {
                    const nextStatusDef = statuses.value.find(
                        status => status.id === nextStatus
                    );

                    if (
                        nextStatusDef.dont_show &&
                        nextStatusDef.dont_show(resource)
                    ) {
                        return;
                    }

                    show_buttons.push({
                        cssClass: nextStatusDef.btn_class,
                        title: nextStatusDef.button_label,
                        icon: nextStatusDef.icon,
                        onClick: () =>
                            progressRequest(nextStatusDef.id, resource),
                    });
                });
            }

            return {
                show: show_buttons,
            };
        };

        const defaultToolbarButtons = () => {
            return {
                list: [],
                show: [],
            };
        };

        const baseResource = useBaseResource({
            resourceName: "iso18626_request",
            nameAttr: "iso18626_request_id",
            idAttr: "iso18626_request_id",
            components: {
                show: "SupplyingShow",
                list: "SupplyingList",
            },
            apiClient: APIClient.ill.supplying,
            additionalToolbarButtons,
            defaultToolbarButtons,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this supplying ILL?"
                ),
                deleteSuccessMessage: $__("Supplying ILL %s deleted"),
                displayName: $__("Supplying ILL"),
                editLabel: $__("Edit supplying ILL #%s"),
                emptyListMessage: $__("There are no supplying ILLs defined"),
                newLabel: $__("New supplying ILL"),
            },
            table: {
                resourceTableUrl:
                    APIClient.ill.httpClient._baseURL + "iso18626_requests",
            },
            resourceAttrs: [
                {
                    name: "iso18626_request_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form"],
                    group: $__("Request details"),
                },
                {
                    name: "supplyingAgencyId",
                    label: $__("Supplying Agency ID"),
                    type: "text",
                    hideIn: ["Form"],
                    group: $__("Request details"),
                },
                {
                    name: "requestingAgencyId",
                    label: $__("Requesting Agency ID"),
                    type: "text",
                    hideIn: ["Form"],
                    group: $__("Request details"),
                },
                {
                    name: "status",
                    label: $__("Status"),
                    type: "text",
                    hideIn: ["Form"],
                    group: $__("Request details"),
                },
                {
                    name: "service_type",
                    label: $__("Service type"),
                    type: "text",
                    hideIn: ["Form"],
                    group: $__("Request details"),
                },
                {
                    name: "pending_requesting_agency_action",
                    label: $__("Pending RA action"),
                    type: "text",
                    hideIn: ["List", "Show", "Form"],
                    group: $__("Request details"),
                },
                {
                    name: "timestamp",
                    label: $__("Last modified"),
                    type: "date",
                    hideIn: ["Form"],
                    group: $__("Request details"),
                },
                {
                    name: "requestingAgencyRequestId",
                    label: $__("Requesting Agency Request ID"),
                    type: "text",
                    hideIn: ["List", "Form"],
                    group: $__("Request details"),
                },
                {
                    group: $__("ISO18626 Messages"),
                    name: "messages",
                    label: "",
                    type: "relationshipWidget",
                    hideIn: ["List"],
                    type: "component",
                    columnData: "messages",
                    hidden: iso18626_request => 1,
                    showElement: {
                        componentPath: "./ILL/ISO18626MessageDisplay.vue",
                        componentProps: {
                            iso18626_request: {
                                type: "resource",
                                value: null,
                            },
                        },
                    },
                },
            ],
            moduleStore: "ILLStore",
            props: props,
        });

        const tableOptions = {
            url: () => tableUrl(),
            //table_settings: supplying_ill_table_settings, #FIXME: This causes error from datatables.js -> out of this scope
            table_settings: {
                columns: [
                    {
                        columnname: "iso18626_request_id",
                        cannot_be_modified: 0,
                        is_hidden: 0,
                        cannot_be_toggled: 0,
                    },
                    {
                        columnname: "supplyingAgencyId",
                        is_hidden: 0,
                        cannot_be_modified: 0,
                        cannot_be_toggled: 0,
                    },
                    {
                        is_hidden: 0,
                        cannot_be_toggled: 0,
                        cannot_be_modified: 0,
                        columnname: "requestingAgencyId",
                    },
                    {
                        is_hidden: 0,
                        cannot_be_toggled: 0,
                        cannot_be_modified: 0,
                        columnname: "status",
                    },
                    {
                        is_hidden: 0,
                        cannot_be_modified: 0,
                        cannot_be_toggled: 0,
                        columnname: "timestamp",
                    },
                    {
                        is_hidden: 0,
                        cannot_be_toggled: 0,
                        cannot_be_modified: 0,
                        columnname: "requestingAgencyRequestId",
                    },
                ],
                default_display_length: null,
                table: "iso18626_requests",
                module: "ill",
                default_save_state: 1,
                page: "ill",
                default_sort_order: null,
                default_save_state_search: 0,
            },
            actions: {
                0: ["show"],
                1: [],
                "-1": [
                    {
                        receive: {
                            text: $__("Manage request"),
                            icon: "fa fa-pencil",
                            should_display: row => 1,
                            callback: ({ iso18626_request_id }, dt, event) => {
                                event.preventDefault();
                                router.push({
                                    name: "SupplyingShow",
                                    params: {
                                        iso18626_request_id:
                                            iso18626_request_id,
                                    },
                                });
                            },
                        },
                    },
                ],
            },
        };

        const afterResourceFetch = (componentData, resource, caller) => {
            if (caller === "show") {
                //TODO: Use dateformat sys pref?
                resource.timestamp = new Date(
                    resource.timestamp
                ).toLocaleString();
            }
        };

        const onFormSave = (e, supplyingILLToSave) => {
            e.preventDefault();
            // Nothing to do here
        };
        const tableUrl = filters => {
            return baseResource.getResourceTableUrl();
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            tableUrl,
            afterResourceFetch,
        };
    },
    emits: ["select-resource"],
    name: "SupplyingResource",
    components: {
        BaseResource,
    },
};
</script>
