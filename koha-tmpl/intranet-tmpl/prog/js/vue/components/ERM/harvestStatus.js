import { $__ } from "@koha-vue/i18n";

/**
 * Labels, badge classes and a badge renderer for the harvest status of a
 * counter log (success, no_usage, no_data, retry, error). Shared by the
 * import logs tab and the data providers summary.
 */
export const getHarvestStatus = () => {
    const labels = {
        success: $__("Success"),
        no_usage: $__("No usage"),
        no_data: $__("No data"),
        retry: $__("Retry"),
        error: $__("Error"),
    };
    const classes = {
        success: "bg-success",
        no_usage: "bg-success-subtle",
        no_data: "bg-orange",
        retry: "bg-warning text-dark",
        error: "bg-danger",
    };
    const filterOptions = Object.entries(labels).map(([id, label]) => ({
        _id: id,
        _str: label,
    }));
    const badge = (status, tooltip = "") => {
        if (!status) return "";
        const label = labels[status] || status;
        const badgeClass = classes[status] || "bg-secondary";
        const title = tooltip ? ` title="${escape_str(tooltip)}"` : "";
        return `<span class="badge ${badgeClass}"${title}>${escape_str(label)}</span>`;
    };
    return { labels, classes, filterOptions, badge };
};
