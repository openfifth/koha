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
                        title: "Fiscal periods",
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/Finances/FiscalPeriodResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodList",
                                title: "List fiscal periods",
                                permission: "manageFiscalPeriods",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fiscal_period_id",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodShow",
                                title: "Show fiscal period",
                                permission: "manageFiscalPeriods",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodFormAdd",
                                title: "Add fiscal period",
                                permission: "createFiscalPeriods",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:fiscal_period_id",
                                component: markRaw(ResourceWrapper),
                                name: "FiscalPeriodFormAddEdit",
                                title: "Edit fiscal period",
                                permission: "editFiscalPeriod",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                    {
                        path: "ledger",
                        title: "Ledgers",
                        is_navigation_item: false,
                        resource: "Acquisitions/Finances/LedgerResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerList",
                                title: "List ledgers",
                                permission: "manageLedgers",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":ledger_id",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerShow",
                                title: "Show ledger",
                                permission: "manageLedgers",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerFormAdd",
                                title: "Add ledger",
                                permission: "createLedger",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:ledger_id",
                                component: markRaw(ResourceWrapper),
                                name: "LedgerFormAddEdit",
                                title: "Edit ledger",
                                permission: "editLedger",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                    {
                        path: "fund",
                        title: "Funds",
                        is_navigation_item: false,
                        resource: "Acquisitions/Finances/FundResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "FundList",
                                title: "List funds",
                                permission: "manageFunds",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "FundShow",
                                title: "Show fund",
                                permission: "manageFunds",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "FundFormAdd",
                                title: "Add fund",
                                permission: "createFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "FundFormAddEdit",
                                title: "Edit fund",
                                permission: "editFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fund_id/sub_fund/add",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundFormAdd",
                                title: "Add sub fund",
                                permission: "createFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":fund_id/sub_fund/edit/:sub_fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundFormAddEdit",
                                title: "Edit sub fund",
                                permission: "editFund",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "sub_fund/:sub_fund_id",
                                component: markRaw(ResourceWrapper),
                                name: "SubFundShow",
                                title: "Show sub fund",
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
                                title: "List funds",
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
                        title: "Suggestions",
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/OrderManagement/SuggestionResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "SuggestionList",
                                title: "List suggestions",
                                permission: "manageOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                        ],
                    },
                    {
                        path: "orderlines",
                        title: "Orderlines",
                        is_navigation_item: false,
                        resource:
                            "Acquisitions/OrderManagement/OrderlineResource.vue",
                        children: [
                            {
                                path: "",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineList",
                                title: "List orderlines",
                                permission: "manageOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: ":orderline_id",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineShow",
                                title: "Show orderline",
                                permission: "manageOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "add",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineFormAdd",
                                title: "Add orderline",
                                permission: "createOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "edit/:orderline_id",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineFormAddEdit",
                                title: "Edit orderline",
                                permission: "createOrderlines",
                                alternateLeftMenu: "AcqMenu",
                            },
                            {
                                path: "search",
                                component: markRaw(ResourceWrapper),
                                name: "OrderlineSearch",
                                title: "Search orderlines",
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
