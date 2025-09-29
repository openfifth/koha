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

        const {
            setConfirmationDialog,
            setMessage,
            updateConfirmationDialogInputs,
        } = inject("mainStore");

        const conditionalInputs = ref([]);

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
                action_inputs: [
                    {
                        name: "expectedDeliveryDate",
                        type: "date",
                        label: $__("Expected delivery date"),
                    },
                ],
                index: 0,
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
                action_inputs: [],
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
                action_inputs: [],
            },
            {
                id: "Overdue",
                confirm_message: $__(
                    "The item currently on loan to the requesting library for this request is now overdue"
                ),
                button_label: $__("Mark as ovedue"),
                icon: "fa-box",
                next_actions: ["LoanCompleted", "CompletedWithoutReturn"], //[ 'Recalled', 'HoldReturn', 'LoanCompleted' ]
                action_inputs: [],
            },
            {
                id: "Recalled",
                confirm_message: $__(
                    "The item currently on loan to the requesting library for this request has been recalled"
                ),
                button_label: $__("Ask for recall"),
                icon: "fa-box",
                next_actions: ["LoanCompleted", "CompletedWithoutReturn"],
                action_inputs: [],
            },
            {
                id: "RetryPossible",
                confirm_message: $__(
                    "The supplying library cannot fill the request based on information provided or may be able to supply at a later date. Additional information is provided in the RetryInfo section. The requesting library may submit a Retry request which may include updated information"
                ),
                button_label: $__("Ask for retry"),
                icon: "fa-repeat",
                next_actions: [],
                action_inputs: [
                    {
                        name: "reasonRetry",
                        label: $__("Reason retry"),
                        required: true,
                        type: "select",
                        onSelected: resource => {
                            conditionalInputs.value = [];
                            if (resource.reasonRetry == "MultiVolAvail") {
                                conditionalInputs.value.push({
                                    name: "volume",
                                    type: "text",
                                    label: $__("Volume"),
                                    required: false,
                                });
                            } else if (
                                resource.reasonRetry == "MustMeetLoanCondition"
                            ) {
                                conditionalInputs.value.push({
                                    name: "loanCondition",
                                    label: $__("Loan condition"),
                                    required: false,
                                    type: "select",
                                    allowMultipleChoices: true,
                                    options: [
                                        {
                                            value: "LibraryUseOnly",
                                            description: __(
                                                "Use in library only"
                                            ),
                                        },
                                        {
                                            value: "WatchLibraryUseOnly",
                                            description: __(
                                                "Supervised use in library only"
                                            ),
                                        },
                                        {
                                            value: "NoReproduction",
                                            description: __("No reproduction"),
                                        },
                                        {
                                            value: "SignatureRequired",
                                            description:
                                                __("Signature required"),
                                        },
                                        {
                                            value: "SpecCollSupervReq",
                                            description: __(
                                                "Special collections supervision required"
                                            ),
                                        },
                                    ],
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                            } else if (
                                resource.reasonRetry == "ReqFormatNotPossible"
                            ) {
                                conditionalInputs.value.push({
                                    name: "itemFormat",
                                    type: "text",
                                    label: $__("Item format"),
                                    required: false,
                                });
                            } else if (
                                resource.reasonRetry == "ReqServTypeNotPossible"
                            ) {
                                conditionalInputs.value.push({
                                    name: "serviceType",
                                    type: "select",
                                    label: $__("Service type"),
                                    required: false,
                                    options: [
                                        //TODO: Only show the 2 options that dont match current resource's service_type
                                        {
                                            value: "Copy",
                                            description: __("Copy"),
                                        },
                                        {
                                            value: "CopyOrLoan",
                                            description: __("CopyOrLoan"),
                                        },
                                        {
                                            value: "Loan",
                                            description: __("Loan"),
                                        },
                                    ],
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                            }
                            updateConfirmationDialogInputs(
                                getDialogInputs(resource)
                            );
                        },
                        vselectStyle: {
                            dropdownMaxHeight: "150px",
                        },
                        options: [
                            {
                                value: "AtBindery",
                                description: __("At bindery"),
                            },
                            {
                                value: "CostExceedsMaxCost",
                                description: __("Cost exceeds max cost"),
                            },
                            {
                                value: "CourierNotSupp",
                                description: __("Courier not supported"),
                            },
                            {
                                value: "MultiVolAvail",
                                description: __(
                                    "More than one volume fulfil the request"
                                ),
                            },
                            {
                                value: "MustMeetLoanCondition",
                                description: __("Loan condition shall be met"),
                            },
                            {
                                value: "NotCurrentAvailableForILL",
                                description: __(
                                    "Not currently available for ILL"
                                ),
                            },
                            {
                                value: "NotFoundAsCited",
                                description: __("Not found as cited"),
                            },
                            {
                                value: "OnLoan",
                                description: __("On loan"),
                            },
                            {
                                value: "OnOrder",
                                description: __("On order"),
                            },
                            {
                                value: "ReqDelDateNotPossible",
                                description: __(
                                    "Requested delivery date not possible"
                                ),
                            },
                            {
                                value: "ReqDelMethodNotSupp",
                                description: __(
                                    "Requested delivery method not supported"
                                ),
                            },
                            {
                                value: "ReqEditionNotPossible",
                                description: __(
                                    "Requested edition cannot be provided"
                                ),
                            },
                            {
                                value: "ReqFormatNotPossible",
                                description: __(
                                    "Requested format not possible"
                                ),
                            },
                            {
                                value: "ReqPayMethodNotSupported",
                                description: __(
                                    "Requested payment method not supported"
                                ),
                            },
                            {
                                value: "ReqServLevelNotSupp",
                                description: __(
                                    "Requested service level not supported"
                                ),
                            },
                            {
                                value: "ReqServTypeNotPossible",
                                description: __(
                                    "Requested service type not possible"
                                ),
                            },
                        ],
                        requiredKey: "value",
                        selectLabel: "description",
                    },
                ],
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
                action_inputs: [
                    {
                        name: "reasonUnfilled",
                        label: $__("Reason unfilled"),
                        required: true,
                        type: "select",
                        options: [
                            {
                                value: "NonCirculating",
                                description: __(
                                    "Non-circulating (e.g. handbook)"
                                ),
                            },
                            {
                                value: "NotAvailableForILL",
                                description: __("Not available for ILL"),
                            },
                            {
                                value: "NotHeld",
                                description: __("Not held"),
                            },
                            {
                                value: "NotOnShelf",
                                description: __("Not on shelf"),
                            },
                            {
                                value: "PolicyProblem",
                                description: __("Policy problem"),
                            },
                            {
                                value: "PoorCondition",
                                description: __("Poor condition"),
                            },
                        ],
                        requiredKey: "value",
                        selectLabel: "description",
                    },
                ],
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
                index: -20,
                action_inputs: [],
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
                action_inputs: [],
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
                action_inputs: [],
            },
            {
                id: "Cancelled",
                confirm_message: $__(
                    "You are responding to this request's cancellation action (as indicated by the requesting library)"
                ),
                button_label: $__("Cancel"),
                icon: "fa-check",
                btn_class: "btn btn-danger",
                next_actions: [],
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

        const statusToUpdate = ref({});
        const action = ref();

        const progressRequest = (actionClicked, iso18626_request) => {
            statusToUpdate.value = statuses.value.find(
                status => status.id === actionClicked
            );
            action.value = actionClicked;
            setConfirmationDialog(
                {
                    size: "modal-lg",
                    title: $__(
                        "Update this request's status to <strong>%s</strong>?"
                    ).format(actionClicked),
                    message: statusToUpdate.value.confirm_message,
                    accept_label: $__("Confirm"),
                    cancel_label: $__("Cancel"),
                    inputs: getDialogInputs(),
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

        const getDialogInputs = inputValues => {
            if (inputValues && statusToUpdate.value.action_inputs) {
                for (const actionInput of statusToUpdate.value.action_inputs) {
                    if (
                        inputValues &&
                        inputValues.hasOwnProperty(actionInput.name)
                    ) {
                        actionInput.value = inputValues[actionInput.name];
                    }
                }
            }

            return [
                ...(statusToUpdate.value.action_inputs
                    ? statusToUpdate.value.action_inputs
                    : []),
                ...(conditionalInputs.value ? conditionalInputs.value : []),
                {
                    name: "messageInfoNote",
                    type: "textarea",
                    textAreaRows: 7,
                    label: $__("Message note"),
                    placeholder: $__(
                        "Note to be sent to the requesting agency"
                    ),
                    value:
                        inputValues &&
                        inputValues.hasOwnProperty("messageInfoNote")
                            ? inputValues.messageInfoNote
                            : "",
                    required: false,
                },
                {
                    name: "status",
                    type: "text",
                    hide: 1,
                    value: action.value,
                    label: $__("Status"),
                    required: false,
                },
            ];
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
                        index: nextStatusDef.index,
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
