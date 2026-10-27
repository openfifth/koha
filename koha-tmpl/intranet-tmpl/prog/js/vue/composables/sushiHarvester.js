import { inject } from "vue";
import monthSelectPlugin from "flatpickr/dist/plugins/monthSelect";
import "flatpickr/dist/plugins/monthSelect/style.css";
import { APIClient } from "../fetch/api-client.js";
import { $__, $__n } from "@koha-vue/i18n/";

/**
 * The "Run now" dialog of a usage data provider: asks for a first and a last
 * month, queues one SUSHI harvest job per report type and month, and reports
 * the queued jobs. Shared by the data providers list and the provider page.
 * Call it inside setup(), it injects the main store.
 */
export function useSushiHarvester() {
    const { setConfirmationDialog, setMessage } = inject("mainStore");

    const toYearMonth = date =>
        `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;

    const previousMonth = () => {
        const date = new Date();
        date.setDate(1);
        date.setMonth(date.getMonth() - 1);
        return toYearMonth(date);
    };

    const firstDayOf = yearMonth => `${yearMonth}-01`;

    const lastDayOf = yearMonth => {
        const [year, month] = yearMonth.split("-").map(Number);
        const lastDay = new Date(year, month, 0).getDate();
        return `${yearMonth}-${String(lastDay).padStart(2, "0")}`;
    };

    // Only months up to the previous one can be harvested: the current month
    // is not complete yet. The calendar is rendered next to its input (static)
    // and not at the end of the body: outside the modal, a click in it moves
    // the focus out of the modal and the Bootstrap focus trap sends it back to
    // the first field, which opens the begin picker again. The begin picker is linked to the end picker through
    // data-date_to, so the staff flatpickr defaults set the begin month as the
    // minDate of the end picker. The month plugin only refreshes the disabled
    // months on a year change, so the check is run again when a picker opens.
    const lastDayOfPreviousMonth = () => {
        const today = new Date();
        return new Date(today.getFullYear(), today.getMonth(), 0);
    };

    const refreshDisabledMonths = (selectedDates, dateStr, fp) => {
        if (!fp.rContainer) return;
        fp.rContainer
            .querySelectorAll(".flatpickr-monthSelect-month")
            .forEach(month => {
                month.dateObj.setFullYear(fp.currentYear);
                const disabled =
                    (fp.config.minDate && month.dateObj < fp.config.minDate) ||
                    (fp.config.maxDate && month.dateObj > fp.config.maxDate);
                month.classList.toggle("flatpickr-disabled", !!disabled);
            });
    };

    const monthInput = (name, label, value, dateTo = null) => ({
        name,
        type: "date",
        value,
        label,
        required: true,
        componentProps: {
            required: {
                type: "boolean",
                value: true,
            },
            ...(dateTo ? { date_to: { type: "string", value: dateTo } } : {}),
            config: {
                type: "object",
                value: {
                    allowInput: false,
                    static: true,
                    maxDate: lastDayOfPreviousMonth(),
                    onOpen: [
                        ...[].concat(flatpickr_defaults.onOpen || []),
                        refreshDisabledMonths,
                    ],
                    plugins: [
                        monthSelectPlugin({
                            shorthand: true,
                            dateFormat: "Y-m",
                            altFormat: "F Y",
                        }),
                    ],
                },
            },
        },
    });

    const queuedJobsMessage = jobs => {
        const jobsByReportType = jobs.reduce((acc, job) => {
            (acc[job.report_type] ||= []).push(job);
            return acc;
        }, {});
        let message = "";
        Object.entries(jobsByReportType).forEach(([reportType, typeJobs]) => {
            const jobLinks = typeJobs
                .map(
                    job =>
                        '<a href="/cgi-bin/koha/admin/background_jobs.pl?op=view&id=' +
                        job.job_id +
                        '" target="_blank">' +
                        escape_str(job.begin_date.substring(0, 7)) +
                        "</a>"
                )
                .join(", ");
            message +=
                "<li>" +
                $__n(
                    "%s job queued for report type <strong>%s</strong>: %s",
                    "%s jobs queued for report type <strong>%s</strong>: %s",
                    typeJobs.length
                ).format(typeJobs.length, reportType, jobLinks) +
                "</li>";
        });
        return message;
    };

    const runHarvester = (usageDataProviderId, name) => {
        setConfirmationDialog(
            {
                title: $__(
                    "Are you sure you want to run the harvester for this data provider?"
                ),
                message: name,
                accept_label: $__("Yes, run"),
                cancel_label: $__("No, do not run"),
                inputs: [
                    monthInput(
                        "begin_date",
                        $__("Begin month"),
                        null,
                        "end_date"
                    ),
                    monthInput("end_date", $__("End month"), previousMonth()),
                ],
            },
            (callback_result, inputFields) => {
                const client = APIClient.erm;
                return client.usage_data_providers
                    .process_SUSHI_response(usageDataProviderId, {
                        begin_date: firstDayOf(inputFields.begin_date),
                        end_date: lastDayOf(inputFields.end_date),
                    })
                    .then(
                        success => {
                            setMessage(queuedJobsMessage(success.jobs), true);
                        },
                        error => {}
                    );
            }
        );
    };

    return { runHarvester };
}
