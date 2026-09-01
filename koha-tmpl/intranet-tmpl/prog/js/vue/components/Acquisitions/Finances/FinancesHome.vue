<template>
    <Toolbar>
        <ToolbarLink
            :to="{ name: 'FiscalPeriodList' }"
            icon="pen-to-square"
            :title="$__('Manage fiscal periods')"
            v-if="isUserPermitted('manageFiscalPeriods')"
        />
        <ToolbarLink
            :to="{ name: 'LedgerList' }"
            icon="pen-to-square"
            :title="$__('Manage ledgers')"
            v-if="isUserPermitted('manageLedgers')"
        />
        <ToolbarLink
            :to="{ name: 'FundList' }"
            icon="pen-to-square"
            :title="$__('Manage funds')"
            v-if="isUserPermitted('manageFunds')"
        />
    </Toolbar>
    <div class="page-section">
        <KohaTable
            ref="fundSummaryTable"
            v-bind="tableOptions"
            @showFiscalPeriod="
                (row, _dt, e) => navigateToResource('FiscalPeriodShow', row, e)
            "
            @showLedger="
                (row, _dt, e) => navigateToResource('LedgerShow', row, e)
            "
            @showFund="(row, _dt, e) => navigateToResource('FundShow', row, e)"
        />
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue";
import ToolbarLink from "../../ToolbarLink.vue";
import KohaTable from "../../KohaTable.vue";
import { inject, ref, useTemplateRef } from "vue";
import { useRouter } from "vue-router";
import { $__ } from "@koha-vue/i18n";
import { APIClient } from "../../../fetch/api-client.js";

export default {
    setup() {
        const router = useRouter();
        const acquisitionsStore = inject("acquisitionsStore");
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore;

        const fundSummaryTable = useTemplateRef("fundSummaryTable");

        const routeParams = {
            FiscalPeriodShow: row => ({
                fiscal_period_id: row.ledger.fiscal_period_id,
            }),
            LedgerShow: row => ({ ledger_id: row.ledger_id }),
            FundShow: row => ({ fund_id: row.fund_id }),
        };

        const navigateToResource = (routeName, row, event) => {
            event?.preventDefault();
            router.push({
                name: routeName,
                params: routeParams[routeName](row),
            });
        };

        const tableOptions = ref({
            columns: [
                {
                    title: $__("Fund name"),
                    data: "name",
                    searchable: true,
                    orderable: true,
                    render: data =>
                        data
                            ? `<a href="#" class="showFund">${escape_str(data)}</a>`
                            : "",
                },
                {
                    title: $__("Fiscal period"),
                    data: "ledger.fiscal_period.name",
                    searchable: true,
                    orderable: true,
                    render: data =>
                        data
                            ? `<a href="#" class="showFiscalPeriod">${escape_str(data)}</a>`
                            : "",
                },
                {
                    title: $__("Ledger"),
                    data: "ledger.name",
                    searchable: true,
                    orderable: true,
                    render: data =>
                        data
                            ? `<a href="#" class="showLedger">${escape_str(data)}</a>`
                            : "",
                },
                {
                    title: $__("Fund code"),
                    data: "code",
                    searchable: true,
                    orderable: true,
                    render: data =>
                        data
                            ? `<a href="#" class="showFund">${escape_str(data)}</a>`
                            : "",
                },
                {
                    title: $__("Managing library"),
                    data: "managing_library.name",
                    dataFilter: "managing_library",
                    searchable: true,
                    orderable: true,
                    render: (data, type, row) =>
                        row.managing_library
                            ? `<a href="/cgi-bin/koha/admin/branches.pl?op=view&branchcode=${row.managing_branch}">${escape_str(row.managing_library.name)}</a>`
                            : "",
                },
                {
                    title: $__("Fund amount"),
                    data: "fund_amount",
                    searchable: false,
                    orderable: true,
                    render: (data, type, row) =>
                        formatValueWithCurrency(row.fund_amount, row.currency),
                },
                {
                    title: $__("Pre-encumbered"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: (data, type, row) =>
                        formatValueWithCurrency(
                            data?.orders_status_new ?? 0,
                            row.currency
                        ),
                },
                {
                    title: $__("Ordered"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: (data, type, row) =>
                        formatValueWithCurrency(
                            data?.ordered ?? 0,
                            row.currency
                        ),
                },
                {
                    title: $__("Spent"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: (data, type, row) =>
                        formatValueWithCurrency(data?.spent ?? 0, row.currency),
                },
            ],
            actions: {
                0: ["showFund"],
                1: ["showFiscalPeriod"],
                2: ["showLedger"],
                3: ["showFund"],
            },
            // Only root funds are rows; their descendants arrive via the
            // all_sub_funds embed and are rendered as tree children. A null value
            // cannot go through default_filters, which skips falsy values.
            url:
                "/api/v1/acquisitions/funds?" +
                new URLSearchParams({
                    q: JSON.stringify({ "me.parent_fund_id": null }),
                }),
            options: {
                embed: [
                    "summary",
                    "ledger.fiscal_period",
                    "managing_library",
                    "all_sub_funds",
                    "all_sub_funds.summary",
                    "all_sub_funds.ledger.fiscal_period",
                    "all_sub_funds.managing_library",
                ].join(","),
                order: [[3, "asc"]],
                dom: '<"top pager"<"table_entries"ip>>tr<"bottom pager"ip>',
            },
            table_settings: null,
            add_filters: true,
            default_filters: { "me.status": true },
            filters_options: {
                managing_library: () =>
                    APIClient.libraries.libraries.getAll().then(res => {
                        return res.map(lib => {
                            return { _id: lib.library_id, _str: lib.name };
                        });
                    }),
            },
            tree: {
                childrenField: "all_sub_funds",
                idField: "fund_id",
                parentField: "parent_fund_id",
                defaultExpanded: true,
                column: "name",
            },
        });

        return {
            isUserPermitted,
            fundSummaryTable,
            tableOptions,
            navigateToResource,
        };
    },
    components: {
        Toolbar,
        ToolbarLink,
        KohaTable,
    },
};
</script>
