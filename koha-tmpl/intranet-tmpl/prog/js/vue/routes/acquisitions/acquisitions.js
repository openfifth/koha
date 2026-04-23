import { markRaw } from "vue";

import Homepage from "../../components/Acquisitions/Homepage.vue";
import FinancesHome from "../../components/Acquisitions/Finances/FinancesHome.vue";
import OrderManagementHome from "../../components/Acquisitions/OrderManagement/OrderManagementHome.vue";

import ResourceWrapper from "../../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/acqui/acquisitions.pl",
        is_default: true,
        is_base: true,
        title: $__("Acquisitions"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Homepage),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/acquisitions/order_management",
                title: $__("Order management"),
                icon: "fa fa-cart-shopping",
                children: [
                    {
                        is_navigation_item: false,
                        path: "",
                        component: markRaw(OrderManagementHome),
                        name: "OrderManagementHome",
                    },
                    {
                        path: "orderlines",
                        title: $__("Orderlines"),
                        resource:
                            "Acquisitions/OrderManagement/OrderlineResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineList",
                                title: $__("List orderlines"),
                                permission: "manageOrderlines",
                                is_navigation_item: false,
                            },
                            {
                                path: ":orderline_id",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineShow",
                                title: $__("Show orderline"),
                                permission: "manageOrderlines",
                                is_navigation_item: false,
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineFormAdd",
                                title: $__("Add orderline"),
                                permission: "createOrderlines",
                                is_navigation_item: false,
                            },
                            {
                                path: "edit/:orderline_id",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineFormAddEdit",
                                title: $__("Edit orderline"),
                                permission: "createOrderlines",
                                is_navigation_item: false,
                            },
                            {
                                path: "search",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineSearch",
                                title: $__("Search orderlines"),
                                permission: "",
                                is_navigation_item: false,
                            },
                        ],
                    },
                ],
            },
            {
                path: "/cgi-bin/koha/acquisitions/suggestions",
                title: $__("Suggestions"),
                icon: "fa fa-cart-shopping",
                resource: "Acquisitions/OrderManagement/SuggestionResource.vue",
                children: [
                    {
                        path: "",
                        component: markRaw(ResourceWrapper),
                        name: "SuggestionList",
                        title: $__("Add order from a suggestion"),
                        permission: "manageOrderlines",
                        is_navigation_item: false,
                    },
                ],
            },
            {
                href: "/cgi-bin/koha/acquisition/vendors",
                title: $__("Vendors"),
                icon: "fa fa-cart-shopping",
            },
            {
                path: "/cgi-bin/koha/acquisitions/finances",
                title: $__("Finances"),
                icon: "fa fa-money-check-dollar",
                children: [
                    {
                        path: "",
                        component: markRaw(FinancesHome),
                        name: "FinancesHome",
                        is_navigation_item: false,
                    },
                    {
                        path: "fiscal_periods",
                        title: $__("Fiscal periods"),
                        resource:
                            "Acquisitions/Finances/FiscalPeriodResource.vue",
                        children: [
                            {
                                path: "",
                                is_navigation_item: false,
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodList",
                                title: $__("List fiscal periods"),
                                permission: "manageFiscalPeriods",
                            },
                            {
                                path: ":fiscal_period_id",
                                is_navigation_item: false,
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodShow",
                                title: $__("Show fiscal period"),
                                permission: "manageFiscalPeriods",
                            },
                            {
                                path: "add",
                                is_navigation_item: false,
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodFormAdd",
                                title: $__("Add fiscal period"),
                                permission: "createFiscalPeriods",
                            },
                            {
                                path: "edit/:fiscal_period_id",
                                is_navigation_item: false,
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodFormAddEdit",
                                title: $__("Edit fiscal period"),
                                permission: "editFiscalPeriod",
                            },
                        ],
                    },
                    {
                        path: "ledgers",
                        title: $__("Ledgers"),
                        resource: "Acquisitions/Finances/LedgerResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerList",
                                title: $__("List ledgers"),
                                permission: "manageLedgers",
                                is_navigation_item: false,
                            },
                            {
                                path: ":ledger_id",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerShow",
                                title: $__("Show ledger"),
                                permission: "manageLedgers",
                                is_navigation_item: false,
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerFormAdd",
                                title: $__("Add ledger"),
                                permission: "createLedger",
                                is_navigation_item: false,
                            },
                            {
                                path: "edit/:ledger_id",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerFormAddEdit",
                                title: $__("Edit ledger"),
                                permission: "editLedger",
                                is_navigation_item: false,
                            },
                        ],
                    },
                    {
                        path: "funds",
                        title: $__("Funds"),
                        resource: "Acquisitions/Finances/FundResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "FundList",
                                title: $__("List funds"),
                                permission: "manageFunds",
                                is_navigation_item: false,
                            },
                            {
                                path: ":fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "FundShow",
                                title: $__("Show fund"),
                                permission: "manageFunds",
                                is_navigation_item: false,
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "FundFormAdd",
                                title: $__("Add fund"),
                                permission: "createFund",
                                is_navigation_item: false,
                            },
                            {
                                path: "edit/:fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "FundFormAddEdit",
                                title: $__("Edit fund"),
                                permission: "editFund",
                                is_navigation_item: false,
                            },
                            {
                                path: ":fund_id/sub_fund/add",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundFormAdd",
                                title: $__("Add sub fund"),
                                permission: "createFund",
                                is_navigation_item: false,
                            },
                            {
                                path: ":fund_id/sub_fund/edit/:sub_fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundFormAddEdit",
                                title: $__("Edit sub fund"),
                                permission: "editFund",
                                is_navigation_item: false,
                            },
                            {
                                path: "sub_fund/:sub_fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundShow",
                                title: $__("Show sub fund"),
                                permission: "manageFunds",
                                is_navigation_item: false,
                            },
                        ],
                    },
                    {
                        path: ":entity/:entity_id/allocate",
                        title: $__("Allocate funds"),
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/Finances/AllocationResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "AllocationFormAdd",
                                title: $__("List funds"),
                            },
                        ],
                    },
                ],
            },
            {
                path: "/cgi-bin/koha/acquisitions/marc_order_accounts",
                title: $__("MARC order accounts"),
                icon: "fa fa-file-import",
                resource: "Acquisitions/MarcOrderAccountResource.vue",
                children: [
                    {
                        path: "",
                        component: markRaw(ResourceWrapper),
                        name: "MarcOrderAccountList",
                        title: $__("List MARC order accounts"),
                        permission: "marc_order_manage",
                        is_navigation_item: false,
                    },
                    {
                        path: ":marc_order_account_id",
                        component: markRaw(ResourceWrapper),
                        name: "MarcOrderAccountShow",
                        title: $__("Show MARC order account"),
                        permission: "marc_order_manage",
                        is_navigation_item: false,
                    },
                    {
                        path: "add",
                        component: markRaw(ResourceWrapper),
                        name: "MarcOrderAccountFormAdd",
                        title: $__("Add MARC order account"),
                        permission: "marc_order_manage",
                        is_navigation_item: false,
                    },
                    {
                        path: "edit/:marc_order_account_id",
                        component: markRaw(ResourceWrapper),
                        name: "MarcOrderAccountFormAddEdit",
                        title: $__("Edit MARC order account"),
                        permission: "marc_order_manage",
                        is_navigation_item: false,
                    },
                ],
            },
            {
                path: "/cgi-bin/koha/acquisitions/edi_accounts",
                title: $__("EDI accounts"),
                icon: "fa fa-right-left",
                resource: "Acquisitions/EdiAccountResource.vue",
                children: [
                    {
                        path: "",
                        component: markRaw(ResourceWrapper),
                        name: "EdiAccountList",
                        title: $__("List EDI accounts"),
                        permission: "edi_manage",
                        is_navigation_item: false,
                    },
                    {
                        path: ":vendor_edi_account_id",
                        component: markRaw(ResourceWrapper),
                        name: "EdiAccountShow",
                        title: $__("Show EDI account"),
                        permission: "edi_manage",
                        is_navigation_item: false,
                    },
                    {
                        path: "add",
                        component: markRaw(ResourceWrapper),
                        name: "EdiAccountFormAdd",
                        title: $__("Add EDI account"),
                        permission: "edi_manage",
                        is_navigation_item: false,
                    },
                    {
                        path: "edit/:vendor_edi_account_id",
                        component: markRaw(ResourceWrapper),
                        name: "EdiAccountFormAddEdit",
                        title: $__("Edit EDI account"),
                        permission: "edi_manage",
                        is_navigation_item: false,
                    },
                ],
            },
        ],
    },
];
