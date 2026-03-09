/**
 * EDIFACT Errors Display Module
 */
const EdifactErrorsDisplay = (() => {
    "use strict";

    const defaults = {
        modalId: "#EDI_errors_modal",
        modalBodySelector: ".modal-body",
        filenameSelectorInTitle: ".filename",
    };

    const init = (options = {}) => {
        const settings = { ...defaults, ...options };
        initializeModal(settings);
    };

    const initializeModal = settings => {
        const modal = $(settings.modalId);
        if (!modal.length) return;

        modal.on("show.bs.modal", event => {
            const button = event.relatedTarget;
            if (!button) return;

            const filename =
                button.getAttribute("data-bs-filename") ||
                button.getAttribute("data-filename");
            const errors =
                button.getAttribute("data-bs-errors") ||
                button.getAttribute("data-errors");

            updateFilename(modal, settings, filename);
            updateErrorsContent(modal, settings, errors);
        });

        modal.on("hidden.bs.modal", () => {
            resetModalContent(modal, settings);
        });
    };

    const updateFilename = (modal, settings, filename) => {
        const filenameSpan = modal.find(settings.filenameSelectorInTitle);
        if (filenameSpan.length && filename) {
            filenameSpan.text(filename);
        }
    };

    const updateErrorsContent = (modal, settings, errors) => {
        const modalBody = modal.find(settings.modalBodySelector);
        if (!modalBody.length) return;

        if (errors) {
            try {
                const errorsData = JSON.parse(errors.replace(/&quot;/g, '"'));
                modalBody.html(buildErrorsDisplay(errorsData));
            } catch (e) {
                console.error("Error parsing errors JSON:", e);
                modalBody.html(
                    `<div class="alert alert-danger">Error loading error details: ${e.message.escapeHtml()}</div>`
                );
            }
        } else {
            modalBody.html(
                '<div class="alert alert-info">No errors found for this interchange.</div>'
            );
        }
    };

    const buildErrorsDisplay = errorsData => {
        if (!errorsData?.length) {
            return '<div class="alert alert-info">No errors found for this interchange.</div>';
        }

        const errorItems = errorsData
            .map(
                error => `
            <li class="list-group-item list-group-item-danger">
                <strong>Error:</strong> ${(error.details || "Unknown error").escapeHtml()}
                ${
                    error.section
                        ? `
                    <br><small><strong>Section:</strong></small>
                    <pre class="mt-1 mb-0" style="font-size: 0.85em; background-color: #f8f9fa; padding: 0.5rem; border-radius: 0.25rem;">${error.section.escapeHtml()}</pre>
                `
                        : ""
                }
                ${
                    error.date
                        ? `
                    <br><small class="text-muted"><strong>Date:</strong> ${error.date.escapeHtml()}</small>
                `
                        : ""
                }
            </li>
        `
            )
            .join("");

        return `<ul class="list-group">${errorItems}</ul>`;
    };

    const resetModalContent = (modal, settings) => {
        const modalBody = modal.find(settings.modalBodySelector);
        const filenameSpan = modal.find(settings.filenameSelectorInTitle);

        modalBody.html(`
            <div class="edi-loading">
                <img src="/intranet-tmpl/${window.theme || "prog"}/img/spinner-small.gif" alt="" />
                Loading errors...
            </div>
        `);
        filenameSpan.text("");
    };

    return { init };
})();

$(document).ready(() => {
    EdifactErrorsDisplay.init();
});
