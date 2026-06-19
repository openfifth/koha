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

export default {
    setup() {
        const router = useRouter();
        const acquisitionsStore = inject("acquisitionsStore");
        const { isUserPermitted } = acquisitionsStore;

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
                    title: $__("Fiscal period"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data =>
                        data?.period
                            ? `<a href="#" class="showFiscalPeriod">${escape_str(data.period)}</a>`
                            : "",
                },
                {
                    title: $__("Ledger"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data =>
                        data?.ledger
                            ? `<a href="#" class="showLedger">${escape_str(data.ledger)}</a>`
                            : "",
                },
                {
                    title: $__("Code"),
                    data: "code",
                    searchable: true,
                    orderable: true,
                    render: data =>
                        data
                            ? `<a href="#" class="showFund">${escape_str(data)}</a>`
                            : "",
                },
                {
                    title: $__("Name"),
                    data: "name",
                    searchable: true,
                    orderable: true,
                    render: data =>
                        data
                            ? `<a href="#" class="showFund">${escape_str(data)}</a>`
                            : "",
                },
                {
                    title: $__("Managing library"),
                    data: "managing_library",
                    searchable: false,
                    orderable: false,
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
                },
                {
                    title: $__("Pre-encumbered"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data => data?.orders_status_new ?? 0,
                },
                {
                    title: $__("Ordered"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data => data?.ordered ?? 0,
                },
                {
                    title: $__("Spent"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data => data?.spent ?? 0,
                },
            ],
            actions: {
                0: ["showFiscalPeriod"],
                1: ["showLedger"],
                2: ["showFund"],
                3: ["showFund"],
            },
            url: "/api/v1/acquisitions/funds",
            options: {
                embed: "summary,ledger,managing_library",
                order: [[2, "asc"]],
                dom: '<"top pager"<"table_entries"ip>>tr<"bottom pager"ip>',
            },
            table_settings: null,
            add_filters: true,
            default_filters: { "me.status": true },
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
