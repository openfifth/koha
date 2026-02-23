<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>
<script>
import { useRouter } from "vue-router";
import { ISO18626 } from "./ISO18626.js";
import BaseResource from "../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { inject, ref } from "vue";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
    },

    setup(props) {
        const router = useRouter();
        const { getCodesForElement } = ISO18626();

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
                dont_show: iso18626_request => true, //This is handled by creating a new hold
                // confirm_message: $__(
                //     "Supplying library expects to fill the request, based on e.g. information in the local OPAC. The message may include the ExpectedDeliveryDate"
                // ),
                // button_label: $__("Expect to supply"),
                // icon: "fa-calendar-days",
                next_actions: [
                    "Loaned",
                    "WillSupply",
                    "RetryPossible",
                    "Unfilled",
                ],
                // action_inputs: [
                //     {
                //         name: "expectedDeliveryDate",
                //         type: "date",
                //         label: $__("Expected delivery date"),
                //         toolTip: $__(
                //             "Date and time the supplying library expects to deliver the item."
                //         ),
                //     },
                // ],
                // index: 0,
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
                dont_show: iso18626_request => true, //This is handled by Koha check out
                // confirm_message: $__(
                //     "The item is currently on loan to the requesting library for this request"
                // ),
                // button_label: $__("Mark as loaned"),
                // icon: "fa-box",
                next_actions: [
                    "Overdue",
                    "LoanCompleted",
                    "CompletedWithoutReturn",
                ], //[ 'Recalled', 'HoldReturn' ]
                // action_inputs: [],
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
                next_actions: ["Cancelled", "Unfilled"],
                action_inputs: [
                    {
                        name: "retryBefore",
                        label: $__("Retry before"),
                        type: "date",
                        toolTip: $__(
                            "Specify that a retry should be attempted before the specified date."
                        ),
                    },
                    {
                        name: "retryAfter",
                        label: $__("Retry after"),
                        type: "date",
                        toolTip: $__(
                            "Specify that a retry should be attempted only after the specified date."
                        ),
                    },
                    {
                        name: "reasonRetry",
                        label: $__("Reason for retry"),
                        required: true,
                        toolTip: $__(
                            "Specify the reason why a retry from the requesting agency is necessary"
                        ),
                        type: "select",
                        onSelected: resource => {
                            conditionalInputs.value = [];
                            if (resource.reasonRetry == "CostExceedsMaxCost") {
                                conditionalInputs.value.push({
                                    name: "offeredCostsCurrencyCode",
                                    type: "select",
                                    label: $__("Currency code"),
                                    required: true,
                                    toolTip: $__(
                                        "Specify the currency code for the offered costs"
                                    ),
                                    options: [
                                        {
                                            value: "USD",
                                            description: __("USD"),
                                        },
                                        {
                                            value: "EUR",
                                            description: __("EUR"),
                                        },
                                        {
                                            value: "GBP",
                                            description: __("GBP"),
                                        },
                                        {
                                            value: "AUD",
                                            description: __("AUD"),
                                        },
                                        {
                                            value: "SEK",
                                            description: __("SEK"),
                                        },
                                    ],
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                                conditionalInputs.value.push({
                                    name: "offeredCostsMonetaryValue",
                                    type: "number",
                                    label: $__("Monetary value"),
                                    required: true,
                                    toolTip: $__(
                                        "Specify the monetary value for the offered costs"
                                    ),
                                });
                            } else if (
                                resource.reasonRetry == "MultiVolAvail"
                            ) {
                                conditionalInputs.value.push({
                                    name: "volume",
                                    type: "text",
                                    label: $__("Volume(s)"),
                                    required: true,
                                    placeholder: "14,15",
                                    toolTip: $__(
                                        "Specify which volume(s) are available, separated by comma ','"
                                    ),
                                });
                            } else if (
                                resource.reasonRetry == "MustMeetLoanCondition"
                            ) {
                                conditionalInputs.value.push({
                                    name: "loanCondition",
                                    label: $__("Loan condition(s)"),
                                    required: true,
                                    type: "select",
                                    toolTip: $__(
                                        "Specify the condition(s) of use that need to be met once the requested item is delivered"
                                    ),
                                    allowMultipleChoices: true,
                                    options:
                                        getCodesForElement("loanCondition"),
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                            } else if (
                                resource.reasonRetry == "ReqDelMethodNotSupp"
                            ) {
                                conditionalInputs.value.push({
                                    name: "deliveryMethod",
                                    type: "select",
                                    vselectStyle: {
                                        dropdownMaxHeight: "150px",
                                    },
                                    toolTip: $__(
                                        "Specify which delivery method(s) can be supplied"
                                    ),
                                    allowMultipleChoices: true,
                                    label: $__("Delivery method(s)"),
                                    required: true,
                                    options:
                                        getCodesForElement("deliveryMethod"),
                                    requiredKey: "value",
                                    selectLabel: "description",
                                    onUpdated: inputValues => {
                                        const deliveryMethods =
                                            inputValues.deliveryMethod;
                                        if (
                                            deliveryMethods &&
                                            deliveryMethods.includes("Courier")
                                        ) {
                                            const existingInput =
                                                conditionalInputs.value.find(
                                                    input =>
                                                        input.name ===
                                                        "courierName"
                                                );
                                            if (!existingInput) {
                                                conditionalInputs.value.push({
                                                    name: "courierName",
                                                    type: "select",
                                                    vselectStyle: {
                                                        dropdownMaxHeight:
                                                            "150px",
                                                    },
                                                    allowMultipleChoices: true,
                                                    toolTip: $__(
                                                        "Specify which courier(s) can be used"
                                                    ),
                                                    label: $__(
                                                        "Courier name(s)"
                                                    ),
                                                    required: true,
                                                    options:
                                                        getCodesForElement(
                                                            "courierName"
                                                        ),
                                                    requiredKey: "value",
                                                    selectLabel: "description",
                                                });
                                                updateConfirmationDialogInputs(
                                                    getDialogInputs(inputValues)
                                                );
                                            }
                                        } else {
                                            const existingInput =
                                                conditionalInputs.value.find(
                                                    input =>
                                                        input.name ===
                                                        "courierName"
                                                );
                                            if (existingInput) {
                                                const index =
                                                    conditionalInputs.value.indexOf(
                                                        existingInput
                                                    );
                                                if (index > -1) {
                                                    conditionalInputs.value.splice(
                                                        index,
                                                        1
                                                    );
                                                    updateConfirmationDialogInputs(
                                                        getDialogInputs(
                                                            inputValues
                                                        )
                                                    );
                                                }
                                            }
                                        }
                                    },
                                });
                            } else if (
                                resource.reasonRetry == "ReqEditionNotPossible"
                            ) {
                                conditionalInputs.value.push({
                                    name: "edition",
                                    type: "text",
                                    toolTip: $__(
                                        "Specify which edition(s) are available, separated by comma ','"
                                    ),
                                    label: $__("Edition(s)"),
                                    required: true,
                                    placeholder: "14,15",
                                });
                            } else if (
                                resource.reasonRetry == "ReqFormatNotPossible"
                            ) {
                                conditionalInputs.value.push({
                                    name: "itemFormat",
                                    type: "select",
                                    vselectStyle: {
                                        dropdownMaxHeight: "150px",
                                    },
                                    toolTip: $__(
                                        "Specify which format(s) can be supplied"
                                    ),
                                    allowMultipleChoices: true,
                                    label: $__("Item format(s)"),
                                    required: true,
                                    options: getCodesForElement("itemFormat"),
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                            } else if (
                                resource.reasonRetry ==
                                "ReqPayMethodNotSupported"
                            ) {
                                conditionalInputs.value.push({
                                    name: "paymentMethod",
                                    type: "select",
                                    toolTip: $__(
                                        "Specify which payment method(s) can be used"
                                    ),
                                    allowMultipleChoices: true,
                                    label: $__("Payment method(s)"),
                                    required: true,
                                    options:
                                        getCodesForElement("paymentMethod"),
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                            } else if (
                                resource.reasonRetry == "ReqServLevelNotSupp"
                            ) {
                                conditionalInputs.value.push({
                                    name: "serviceLevel",
                                    type: "select",
                                    toolTip: $__(
                                        "Select which service level(s) are supported"
                                    ),
                                    allowMultipleChoices: true,
                                    label: $__("Service level(s)"),
                                    required: true,
                                    options: getCodesForElement("serviceLevel"),
                                    requiredKey: "value",
                                    selectLabel: "description",
                                });
                            } else if (
                                resource.reasonRetry == "ReqServTypeNotPossible"
                            ) {
                                conditionalInputs.value.push({
                                    name: "serviceType",
                                    type: "select",
                                    toolTip: $__(
                                        "Select the service type which can be supplied"
                                    ),
                                    label: $__("Service type"),
                                    required: true,
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
                        options: getCodesForElement("reasonRetry"),
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
                icon: "fa-ban",
                btn_class: "btn btn-danger",
                next_actions: [],
                action_inputs: [
                    {
                        name: "reasonUnfilled",
                        label: $__("Reason unfilled"),
                        required: true,
                        type: "select",
                        options: getCodesForElement("reasonUnfilled"),
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
                icon: "fa-xmark",
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
            conditionalInputs.value = [];
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
                                baseResource.refreshTemplateState();
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

            if (inputValues && conditionalInputs.value) {
                for (const conditionalInput of conditionalInputs.value) {
                    if (
                        inputValues &&
                        inputValues.hasOwnProperty(conditionalInput.name)
                    ) {
                        conditionalInput.value =
                            inputValues[conditionalInput.name];
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
                    type: "hidden",
                    value: action.value,
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

            if (resource?.hold?.item_id) {
                show_buttons.push({
                    cssClass: "btn btn-primary",
                    title: "Mark as loaned (Checkout)",
                    icon: "fa-box",
                    onClick: () => {
                        if (resource.hold.item_id) {
                            getItem(resource.hold.item_id).then(
                                result => {
                                    const item_barcode = result.external_id;
                                    performCheckout({
                                        borrowernumber:
                                            resource.requesting_agency
                                                .patron_id,
                                        branch: userenv?.branch,
                                        barcode: item_barcode,
                                        supplyill: resource.iso18626_request_id,
                                    });
                                },
                                error => {}
                            );
                        }
                    },
                });
            }

            if (resource.status == "RequestReceived") {
                show_buttons.push({
                    cssClass: "btn btn-primary",
                    title: "Search to hold",
                    icon: "fa-calendar-days",
                    onClick: () => {
                        // !Copy pasted from member-menu.js
                        var date = new Date();
                        date.setTime(date.getTime() + 10 * 60 * 1000);
                        Cookies.set(
                            "holdfor",
                            resource.requesting_agency.patron_id,
                            {
                                path: "/",
                                expires: date,
                                sameSite: "Lax",
                            }
                        );
                        Cookies.set(
                            "holdforsupplyill",
                            resource.iso18626_request_id,
                            {
                                path: "/",
                                expires: date,
                                sameSite: "Lax",
                            }
                        );
                        location.href =
                            "/cgi-bin/koha/catalogue/search.pl?context=supplyill:" +
                            resource.iso18626_request_id;
                    },
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

        const performCheckout = params => {
            const url = "/cgi-bin/koha/circ/circulation.pl";
            const csrfMeta = document.querySelector('meta[name="csrf-token"]');
            params.csrf_token = csrfMeta
                ? csrfMeta.getAttribute("content")
                : "";
            params.op = "cud-checkout";

            const form = document.createElement("form");
            form.method = "POST";
            form.action = url;

            for (const key in params) {
                if (params.hasOwnProperty(key)) {
                    const hiddenField = document.createElement("input");
                    hiddenField.type = "hidden";
                    hiddenField.name = key;
                    hiddenField.value = params[key];
                    form.appendChild(hiddenField);
                }
            }

            document.body.appendChild(form);
            form.submit();
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
                    name: "iso18626_requesting_agency_id",
                    label: $__("Requesting Agency"),
                    type: "relationshipSelect",
                    showElement: {
                        type: "text",
                        value: "requesting_agency.name",
                        link: {
                            href: "/cgi-bin/koha/ill/iso18626_requesting_agencies",
                            slug: "iso18626_requesting_agency_id",
                        },
                    },
                    relationshipAPIClient: APIClient.ill.requesting_agencies,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "iso18626_requesting_agency_id",
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
                    name: "hold_id",
                    label: $__("Hold on biblio"),
                    type: "boolean",
                    hideIn: ["List", "Form"],
                    group: $__("Request details"),
                },
                {
                    name: "issue_id",
                    label: $__("Checkout"),
                    type: "boolean",
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
                        componentPath:
                            "@koha-vue/components/ILL/ISO18626MessageDisplay.vue",
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
            options: { embed: "requesting_agency,messages" },
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
                        columnname: "requesting_agency",
                        render: function (data, type, row, meta) {
                            return (
                                '<a target="_blank" href="/cgi-bin/koha/ill/ill-requests.pl?' +
                                "op=illview&amp;illrequest_id=" +
                                encodeURIComponent(data) +
                                '">' +
                                escape_str(row.id_prefix) +
                                escape_str(data) +
                                "</a>"
                            );
                        },
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

        const getItem = async item_id => {
            const client = APIClient.item;
            return await client.items.get(item_id).then(
                result => {
                    return result;
                },
                error => {}
            );
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
