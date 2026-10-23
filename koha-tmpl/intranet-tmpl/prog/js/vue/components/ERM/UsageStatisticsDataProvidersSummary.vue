<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="usage_data_providers_summary">
        <div id="toolbar" class="btn-toolbar">
            <router-link
                :to="{ name: 'UsageStatisticsDataProvidersList' }"
                class="btn btn-default"
            >
                <i class="fa fa-list"></i>
                {{ $__("Data providers list") }}</router-link
            >
        </div>
        <div v-if="summaryCount > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @show="showUsageDataProvider"
            ></KohaTable>
        </div>
        <div v-else class="alert alert-info">
            {{ $__("There are no harvest logs to summarize") }}
        </div>
    </div>
</template>

<script>
import { onMounted, ref, useTemplateRef } from "vue";
import { useRouter } from "vue-router";
import { APIClient } from "../../fetch/api-client.js";
import KohaTable from "../KohaTable.vue";
import { $__ } from "@koha-vue/i18n";
import { getHarvestStatus } from "./harvestStatus.js";

export default {
    setup() {
        const router = useRouter();
        const table = useTemplateRef("table");
        const { badge } = getHarvestStatus();

        const summaryCount = ref(0);
        const initialized = ref(false);
        const buildingTable = ref(false);

        const monthNames = [
            $__("Jan"),
            $__("Feb"),
            $__("Mar"),
            $__("Apr"),
            $__("May"),
            $__("Jun"),
            $__("Jul"),
            $__("Aug"),
            $__("Sep"),
            $__("Oct"),
            $__("Nov"),
            $__("Dec"),
        ];

        const tableUrl = () => "/api/v1/erm/counter_logs/summary";

        const getTableColumns = () => {
            const monthColumns = monthNames.map((monthName, index) => {
                const field = `month_${index + 1}`;
                return {
                    title: monthName,
                    data: field,
                    render: (data, type, row, meta) => badge(row[field]),
                    searchable: false,
                    orderable: false,
                };
            });
            return [
                {
                    title: $__("Harvest year"),
                    data: "report_year",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Provider"),
                    data: "provider_name",
                    render: (data, type, row, meta) =>
                        '<a role="button" class="show">' +
                        escape_str(row.provider_name) +
                        "</a>",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Report type"),
                    data: "report_type",
                    render: (data, type, row, meta) =>
                        escape_str(row.report_type),
                    searchable: true,
                    orderable: true,
                },
                ...monthColumns,
            ];
        };

        const showUsageDataProvider = (summary, dt, event) => {
            router.push({
                name: "UsageStatisticsDataProvidersShow",
                params: {
                    erm_usage_data_provider_id: summary.usage_data_provider_id,
                },
            });
        };

        const getSummaryCount = async () => {
            const client = APIClient.erm;
            await client.counter_log_summaries.count().then(
                count => {
                    summaryCount.value = count;
                    initialized.value = true;
                },
                error => {
                    initialized.value = true;
                }
            );
        };

        const tableOptions = ref({
            columns: getTableColumns(),
            options: {
                order: [
                    [0, "desc"],
                    [1, "asc"],
                    [2, "asc"],
                ],
            },
            url: () => tableUrl(),
            table_settings: counter_log_summary_table_settings,
            add_filters: true,
            actions: {
                1: ["show"],
            },
        });

        onMounted(() => {
            if (!buildingTable.value) {
                buildingTable.value = true;
                getSummaryCount();
            }
        });

        return {
            table,
            summaryCount,
            initialized,
            buildingTable,
            tableOptions,
            showUsageDataProvider,
        };
    },
    components: { KohaTable },
    name: "UsageStatisticsDataProvidersSummary",
};
</script>
