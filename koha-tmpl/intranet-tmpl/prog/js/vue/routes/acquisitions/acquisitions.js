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
                path: "/cgi-bin/koha/acquisitions/finances",
                moduleName: "funds",
                title: $__("Finances"),
                icon: "fa fa-money-check-dollar",
                children: [
                    {
                        path: "",
                        component: markRaw(FinancesHome),
                        name: "FinancesHome",
                        is_navigation_item: false,
                        alternateLeftMenu: "AcqMenu",
                    },
                    {
                        path: "fiscal_period",
                        title: $__("Fiscal periods"),
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/Finances/FiscalPeriodResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodList",
                                title: $__("List fiscal periods"),
                                permission: "manageFiscalPeriods",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fiscal_period_id",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodShow",
                                title: $__("Show fiscal period"),
                                permission: "manageFiscalPeriods",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodFormAdd",
                                title: $__("Add fiscal period"),
                                permission: "createFiscalPeriods",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:fiscal_period_id",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodFormAddEdit",
                                title: $__("Edit fiscal period"),
                                permission: "editFiscalPeriod",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                    {
                        path: "ledger",
                        title: $__("Ledgers"),
                        is_navigation_item: false,
                        resource: "Acquisitions/Finances/LedgerResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerList",
                                title: $__("List ledgers"),
                                permission: "manageLedgers",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":ledger_id",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerShow",
                                title: $__("Show ledger"),
                                permission: "manageLedgers",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerFormAdd",
                                title: $__("Add ledger"),
                                permission: "createLedger",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:ledger_id",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerFormAddEdit",
                                title: $__("Edit ledger"),
                                permission: "editLedger",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                    {
                        path: "fund",
                        title: $__("Funds"),
                        is_navigation_item: false,
                        resource: "Acquisitions/Finances/FundResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "FundList",
                                title: $__("List funds"),
                                permission: "manageFunds",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "FundShow",
                                title: $__("Show fund"),
                                permission: "manageFunds",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "FundFormAdd",
                                title: $__("Add fund"),
                                permission: "createFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "FundFormAddEdit",
                                title: $__("Edit fund"),
                                permission: "editFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fund_id/sub_fund/add",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundFormAdd",
                                title: $__("Add sub fund"),
                                permission: "createFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fund_id/sub_fund/edit/:sub_fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundFormAddEdit",
                                title: $__("Edit sub fund"),
                                permission: "editFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "sub_fund/:sub_fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundShow",
                                title: $__("Show sub fund"),
                                permission: "manageFunds",
                                alternateLeftMenu: "AcqMenu",
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
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                ],
            },
            {
                path: "/cgi-bin/koha/acquisitions/order_management",
                moduleName: "ordering",
                title: $__("Order management"),
                icon: "fa fa-cart-shopping",
                children: [
                    {
                        path: "",
                        component: markRaw(OrderManagementHome),
                        name: "OrderManagementHome",
                        is_navigation_item: false,
                        alternateLeftMenu: "AcqMenu",
                    },
                    {
                        path: "suggestions",
                        title: $__("Add order from a suggestion"),
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/OrderManagement/SuggestionResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "SuggestionList",
                                title: $__("List suggestions"),
                                permission: "manageOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                    {
                        path: "orderlines",
                        title: $__("Orderlines"),
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/OrderManagement/OrderlineResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineList",
                                title: $__("List orderlines"),
                                permission: "manageOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":orderline_id",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineShow",
                                title: $__("Show orderline"),
                                permission: "manageOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineFormAdd",
                                title: $__("Add orderline"),
                                permission: "createOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:orderline_id",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineFormAddEdit",
                                title: $__("Edit orderline"),
                                permission: "createOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "search",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineSearch",
                                title: $__("Search orderlines"),
                                permission: "",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                ],
            },
        ],
    },
];
