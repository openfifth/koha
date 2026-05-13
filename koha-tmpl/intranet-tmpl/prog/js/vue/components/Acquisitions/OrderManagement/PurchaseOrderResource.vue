<template>
    <BaseResource
        :routeAction="routeAction"
        :instancedResource="this"
    ></BaseResource>
</template>

<script>
import BaseResource from "../../BaseResource.vue";
import { APIClient } from "../../../fetch/api-client.js";
import { useBaseResource } from "../../../composables/base-resource";
import { $__ } from "@koha-vue/i18n";
import { inject, ref } from "vue";
import { storeToRefs } from "pinia";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const acquisitionsStore = inject("acquisitionsStore");
        const { user } = storeToRefs(acquisitionsStore);

        const vendorContracts = ref([]);

        const contractAttr = {
            name: "contract_id",
            type: "select",
            label: $__("Contract"),
            selectLabel: "contractname",
            requiredKey: "contractnumber",
            options: vendorContracts,
            disabled: resource => !resource.vendor_id,
            hideIn: ["List"],
            showElement: {
                type: "text",
                value: "contract.contractname",
                link: {
                    href: "/cgi-bin/koha/admin/aqcontract.pl",
                    params: {
                        op: "add_form",
                        contractnumber: "contract_id",
                        booksellerid: "vendor_id",
                    },
                },
            },
            format: (val, resource) => {
                const contract = resource.contract;
                return contract ? contract.contractname : val;
            },
        };

        const baseResource = useBaseResource({
            resourceName: "purchase_order",
            nameAttr: "po_name",
            idAttr: "purchase_order_id",
            components: {
                show: "PurchaseOrderShow",
                list: "PurchaseOrderList",
                add: "PurchaseOrderFormAdd",
                edit: "PurchaseOrderFormAddEdit",
            },
            apiClient: APIClient.acquisition.purchaseOrders,
            extendedAttributesResourceType: "purchase_order",
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this purchase order?"
                ),
                deleteSuccessMessage: $__("Purchase order %s deleted"),
                displayName: $__("Purchase order"),
                editLabel: $__("Edit purchase order #%s"),
                emptyListMessage: $__("There are no purchase orders defined"),
                newLabel: $__("New purchase order"),
            },
            table: {
                resourceTableUrl:
                    APIClient.acquisition.httpClient._baseURL +
                    "purchase_orders",
            },
            moduleStore: "acquisitionsStore",
            props,
            resourceAttrs: [
                {
                    name: "purchase_order_id",
                    label: $__("ID"),
                    type: "text",
                    hideIn: ["Form", "Show"],
                },
                {
                    name: "vendor_id",
                    type: "relationshipSelect",
                    label: $__("Vendor"),
                    relationshipAPIClient: APIClient.acquisition.vendors,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "id",
                    required: true,
                    onSelected: (e, options, resource) => {
                        const vendor = options.find(v => v.id === e);
                        vendorContracts.value = vendor?.contracts || [];
                        resource.contract_id = null;
                    },
                    showElement: {
                        type: "text",
                        value: "vendor.name",
                        link: {
                            href: "/cgi-bin/koha/acquisition/vendors",
                            slug: "vendor_id",
                        },
                    },
                },
                {
                    name: "po_name",
                    type: "text",
                    label: $__("PO name"),
                },
                {
                    name: "external_po_number",
                    type: "text",
                    label: $__("External PO number"),
                },
                {
                    name: "billing_branch",
                    type: "relationshipSelect",
                    label: $__("Billing place"),
                    relationshipAPIClient: APIClient.libraries.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    showElement: {
                        type: "text",
                        value: "billing_library.name",
                        link: {
                            href: "/cgi-bin/koha/admin/branches.pl",
                            params: {
                                op: "view",
                                branchcode: "billing_branch",
                            },
                        },
                    },
                },
                {
                    name: "delivery_branch",
                    type: "relationshipSelect",
                    label: $__("Delivery place"),
                    relationshipAPIClient: APIClient.libraries.libraries,
                    relationshipOptionLabelAttr: "name",
                    relationshipRequiredKey: "library_id",
                    showElement: {
                        type: "text",
                        value: "delivery_library.name",
                        link: {
                            href: "/cgi-bin/koha/admin/branches.pl",
                            params: {
                                op: "view",
                                branchcode: "delivery_branch",
                            },
                        },
                    },
                },
                {
                    name: "po_internal_note",
                    type: "textarea",
                    label: $__("Internal note"),
                    hideIn: ["List"],
                },
                {
                    name: "po_vendor_note",
                    type: "textarea",
                    label: $__("Vendor note"),
                    hideIn: ["List"],
                },
                contractAttr,
            ],
        });

        const tableOptions = {
            table_settings: null,
            add_filters: true,
            options: {
                embed: "vendor,billing_library,delivery_library,extended_attributes,+strings",
            },
            actions: {
                0: ["show"],
                "-1": [
                    ...(baseResource.isUserPermitted("managePurchaseOrders")
                        ? ["edit"]
                        : []),
                    ...(baseResource.isUserPermitted("managePurchaseOrders")
                        ? ["delete"]
                        : []),
                ],
            },
        };

        const onFormSave = (e, purchaseOrderToSave) => {
            e.preventDefault();

            const purchase_order = JSON.parse(
                JSON.stringify(purchaseOrderToSave)
            );
            const purchase_order_id = purchase_order.purchase_order_id;

            delete purchase_order.purchase_order_id;
            delete purchase_order.vendor;
            delete purchase_order.contract;
            delete purchase_order.billing_library;
            delete purchase_order.delivery_library;
            delete purchase_order.created_date;
            delete purchase_order.modified_date;
            delete purchase_order._strings;

            if (purchase_order_id) {
                return baseResource.apiClient
                    .update(purchase_order, purchase_order_id)
                    .then(
                        purchaseOrder => {
                            baseResource.setMessage(
                                $__("Purchase order updated")
                            );
                            return purchaseOrder;
                        },
                        error => {}
                    );
            } else {
                return baseResource.apiClient.create(purchase_order).then(
                    purchaseOrder => {
                        baseResource.setMessage($__("Purchase order created"));
                        return purchaseOrder;
                    },
                    error => {}
                );
            }
        };

        const afterNewResourceCreate = (
            resource,
            componentData,
            initialized
        ) => {
            resource.billing_branch = user.value.loggedInUser.loggedInBranch;
            resource.delivery_branch = user.value.loggedInUser.loggedInBranch;
            initialized.value = true;
            return resource;
        };

        const afterResourceFetch = (componentData, resource) => {
            vendorContracts.value = resource.vendor?.contracts || [];
        };

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            afterNewResourceCreate,
            afterResourceFetch,
        };
    },
    components: { BaseResource },
    emits: ["select-resource"],
    name: "PurchaseOrderResource",
};
</script>
