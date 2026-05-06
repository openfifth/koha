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
        <KohaTable ref="fundSummaryTable" v-bind="tableOptions" />
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue";
import ToolbarLink from "../../ToolbarLink.vue";
import KohaTable from "../../KohaTable.vue";
import { inject, ref, useTemplateRef } from "vue";
import { storeToRefs } from "pinia";
import { $__ } from "@koha-vue/i18n";

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore");
        const { isUserPermitted } = acquisitionsStore;
        const { authorisedValues } = storeToRefs(acquisitionsStore);

        const fundSummaryTable = useTemplateRef("fundSummaryTable");

        const tableOptions = ref({
            columns: [
                {
                    title: $__("Fiscal period"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data => data?.period ?? "",
                },
                {
                    title: $__("Ledger"),
                    data: "summary",
                    searchable: false,
                    orderable: false,
                    render: data => data?.ledger ?? "",
                },
                {
                    title: $__("Code"),
                    data: "code",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Name"),
                    data: "name",
                    searchable: true,
                    orderable: true,
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
            url: "/api/v1/acquisitions/funds",
            options: {
                embed: "summary",
                order: [[2, "asc"]],
                dom: '<"top pager"<"table_entries"ip>>tr<"bottom pager"ip>',
            },
            table_settings: null,
            add_filters: true,
        });

        return {
            isUserPermitted,
            authorisedValues,
            fundSummaryTable,
            tableOptions,
        };
    },
    components: {
        Toolbar,
        ToolbarLink,
        KohaTable,
    },
};
</script>

<style scoped>
.ledgers-and-funds {
    display: flex;
    gap: 1em;
    width: 100%;
}
.flex-table {
    margin-top: 0px;
    width: 50%;
}
.filters-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    padding: 1em;
    gap: 1em;
    width: 90%;
}
.filter-grid-cell {
    display: flex;
    gap: 1em;
    justify-content: centre;
    width: 100%;
}
.filter-label {
    min-width: 25%;
}
.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not(
        [type="checkbox"]
    ),
textarea {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 60%;
}
</style>
