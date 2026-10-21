<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="counter_logs_list">
        <div v-if="counter_logs_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @delete="delete_counter_file"
                @download="download_counter_file"
            ></KohaTable>
        </div>
        <div v-else-if="initialized" class="alert alert-info">
            {{ $__("There are no import logs defined") }}
        </div>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js";
import { inject, onMounted, ref, useTemplateRef } from "vue";
import KohaTable from "../KohaTable.vue";
import { useRoute } from "vue-router";
import { $__ } from "@koha-vue/i18n";

export default {
    setup() {
        const route = useRoute();
        const { setConfirmationDialog, setMessage } = inject("mainStore");

        const table = useTemplateRef("table");
        const format_datetime = $datetime;
        const counter_logs_count = ref(0);
        const initialized = ref(false);
        const building_table = ref(false);

        const statusLabels = {
            success: $__("Success"),
            no_usage: $__("No usage"),
            no_data: $__("No data"),
            retry: $__("Retry needed"),
            error: $__("Error"),
        };
        const statusClasses = {
            success: "bg-success",
            no_usage: "bg-success-subtle",
            no_data: "bg-orange",
            retry: "bg-warning text-dark",
            error: "bg-danger",
        };
        const statusFilterOptions = Object.entries(statusLabels).map(
            ([id, label]) => ({ _id: id, _str: label })
        );

        const formatPeriod = (year, month) =>
            year && month ? `${year}-${String(month).padStart(2, "0")}` : "";
        const parseLogDetails = logdetails => {
            if (!logdetails) return {};
            try {
                const parsed = JSON.parse(logdetails);
                return parsed && typeof parsed === "object" ? parsed : {};
            } catch (e) {
                return {};
            }
        };
        const exceptionText = exception =>
            [exception.code, exception.message]
                .filter(
                    value =>
                        value !== null && value !== undefined && value !== ""
                )
                .join(": ");
        const logDetailLines = logdetails => {
            const details = parseLogDetails(logdetails);
            const lines = (details.exceptions || []).map(exceptionText);
            if (details.message) lines.push(details.message);
            return lines.filter(line => line !== "");
        };

        const table_url = () => {
            let url = `/api/v1/erm/counter_logs?usage_data_provider_id=${route.params.erm_usage_data_provider_id}`;
            return url;
        };
        const download_counter_file = (counter_log, dt, event) => {
            window.location.href =
                "/api/v1/erm/counter_files/" +
                counter_log.counter_files_id +
                "/file/content";
        };
        const delete_counter_file = (counter_log, dt, event) => {
            setConfirmationDialog(
                {
                    title: $__("Are you sure you want to remove this file?"),
                    message: counter_log.filename,
                    accept_label: $__("Yes, delete"),
                    cancel_label: $__("No, do not delete"),
                },
                () => {
                    const client = APIClient.erm;
                    client.counter_files
                        .delete(counter_log.counter_files_id)
                        .then(
                            success => {
                                setMessage(
                                    $__("File %s deleted").format(
                                        counter_log.filename
                                    ),
                                    true
                                );
                                dt.draw();
                            },
                            error => {}
                        );
                }
            );
        };
        const getTableColumns = () => {
            return [
                {
                    title: $__("Filename"),
                    data: "filename",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Report type"),
                    data: "report_type",
                    render: (data, type, row, meta) =>
                        escape_str(row.report_type || ""),
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Period"),
                    data: "report_year:report_month",
                    render: (data, type, row, meta) =>
                        formatPeriod(row.report_year, row.report_month),
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Status"),
                    data: "status",
                    dataFilter: "status",
                    render: (data, type, row, meta) => {
                        const label = statusLabels[row.status] || row.status;
                        const badgeClass =
                            statusClasses[row.status] || "bg-secondary";
                        const tooltip = logDetailLines(row.logdetails).join(
                            "\n"
                        );
                        return `<span class="badge ${badgeClass}" title="${escape_str(tooltip)}">${escape_str(label)}</span>`;
                    },
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Details"),
                    data: "logdetails",
                    render: (data, type, row, meta) =>
                        logDetailLines(row.logdetails)
                            .map(line => escape_str(line))
                            .join("<br />"),
                    searchable: false,
                    orderable: false,
                },
                {
                    data: "importdate",
                    title: $__("Import date"),
                    render: (data, type, row, meta) =>
                        format_datetime(row.importdate),
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Imported by"),
                    render: function (data, type, row, meta) {
                        const { patron } = row;
                        const importer = patron
                            ? '<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=' +
                              patron.patron_id +
                              '">' +
                              $patron_to_html(patron) +
                              "</a>"
                            : $__("Cronjob");
                        return importer;
                    },
                    searchable: true,
                    orderable: true,
                },
                {
                    title: $__("Job"),
                    data: "background_job_id",
                    render: (data, type, row, meta) =>
                        row.background_job_id
                            ? `<a href="/cgi-bin/koha/admin/background_jobs.pl?op=view&id=${encodeURIComponent(row.background_job_id)}">#${escape_str(row.background_job_id)}</a>`
                            : "",
                    searchable: true,
                    orderable: true,
                },
            ];
        };

        const getCounterLogs = async () => {
            const client = APIClient.erm;
            await client.counter_logs
                .count({
                    usage_data_provider_id:
                        route.params.erm_usage_data_provider_id,
                })
                .then(
                    count => {
                        counter_logs_count.value = count;
                        initialized.value = true;
                    },
                    error => {}
                );
        };

        const tableOptions = ref({
            columns: getTableColumns(),
            options: {
                embed: "patron",
            },
            url: () => table_url(),
            table_settings: counter_log_table_settings,
            add_filters: true,
            filters_options: {
                status: statusFilterOptions,
            },
            actions: {
                0: ["show"],
                "-1": [
                    {
                        download: {
                            text: $__("Download"),
                            icon: "fa fa-download",
                            should_display: row => !!row.counter_files_id,
                        },
                    },
                    {
                        delete: {
                            text: $__("Delete"),
                            icon: "fa fa-trash",
                            should_display: row => !!row.counter_files_id,
                        },
                    },
                ],
            },
        });

        onMounted(() => {
            if (!building_table.value) {
                building_table.value = true;
                getCounterLogs();
            }
        });
        return {
            table,
            setConfirmationDialog,
            setMessage,
            counter_logs_count,
            initialized,
            building_table,
            tableOptions,
            download_counter_file,
            delete_counter_file,
        };
    },
    components: { KohaTable },
    name: "UsageStatisticsDataProvidersCounterLogs",
};
</script>
