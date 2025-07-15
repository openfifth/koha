/**
 * EDIFACT Display Module
 * Provides reusable functions for displaying EDIFACT messages in tree format
 */

/* global __ interface theme $ */
var EdifactDisplay = (function () {
    "use strict";

    // Configuration defaults
    var defaultInterface =
        typeof window.interface !== "undefined"
            ? window.interface
            : "/intranet-tmpl";
    var defaultTheme =
        typeof window.theme !== "undefined" ? window.theme : "prog";
    var defaults = {
        modalId: "#EDI_modal",
        modalBodySelector: ".modal-body",
        loadingHtml:
            '<div class="edi-loading"><img src="' +
            defaultInterface +
            "/" +
            defaultTheme +
            '/img/spinner-small.gif" alt="" /> Loading</div>',
        errorHtml:
            '<div class="alert alert-danger">Failed to load message</div>',
        jsonEndpoint: "/cgi-bin/koha/acqui/edimsg.pl",
        expandByDefault: true,
        showLineNumbers: false,
        showElementDetails: false,
    };

    /**
     * Initialize EDIFACT display functionality
     * @param {Object} options - Configuration options
     */
    function init(options) {
        options = options || {};
        var config = $.extend({}, defaults, options);

        // Handle generic EDIFACT message buttons
        $("body").on("click", ".view_edifact_message", function (e) {
            e.preventDefault();
            var messageId = $(this).data("message-id");
            var customUrl = $(this).data("url");

            if (messageId) {
                showMessage(messageId, config);
            } else if (customUrl) {
                showMessageFromUrl(customUrl, config);
            }
        });

        // Handle legacy view_message buttons
        $("body").on("click", ".view_message_enhanced", function (e) {
            e.preventDefault();
            var href = $(this).attr("href");
            showMessageFromUrl(href, config);
        });

        // Initialize modal behavior
        initializeModal(config);
    }

    /**
     * Show EDIFACT message by ID
     * @param {string} messageId - The message ID to display
     * @param {Object} config - Configuration options
     */
    function showMessage(messageId, config) {
        var url =
            config.jsonEndpoint +
            "?id=" +
            encodeURIComponent(messageId) +
            "&format=json";
        showMessageFromUrl(url, config);
    }

    /**
     * Show EDIFACT message from URL
     * @param {string} url - The URL to fetch JSON from
     * @param {Object} config - Configuration options
     */
    function showMessageFromUrl(url, config) {
        var modal = $(config.modalId);
        var modalBody = modal.find(config.modalBodySelector);

        // Add format=json if not present
        var jsonUrl =
            url + (url.indexOf("?") !== -1 ? "&" : "?") + "format=json";

        // Show loading state
        modalBody.html(config.loadingHtml);
        modal.modal("show");

        // Fetch and display using jQuery AJAX for better compatibility
        $.ajax({
            url: jsonUrl,
            type: "GET",
            dataType: "json",
            success: function (data) {
                modalBody.empty().append(buildEdiDisplay(data, config));
            },
            error: function (xhr, status, error) {
                console.error("Error loading EDIFACT message:", error);
                modalBody.html(config.errorHtml);
            },
        });
    }

    /**
     * Build complete EDIFACT display with toggle and views
     * @param {Object} data - EDIFACT JSON data
     * @param {Object} config - Configuration options
     * @returns {HTMLElement} - The display container
     */
    function buildEdiDisplay(data, config) {
        var container = document.createElement("div");
        container.className = "edi-display-container";

        // Add toolbar
        var toolbar = document.createElement("div");
        toolbar.className = "edi-toolbar";
        toolbar.innerHTML =
            '<div class="edi-toolbar-left">' +
            '<button type="button" class="btn btn-sm btn-outline-secondary expand-all-btn" title="Expand all sections">' +
            '<i class="fa fa-expand"></i> Expand All' +
            "</button>" +
            '<button type="button" class="btn btn-sm btn-outline-secondary collapse-all-btn" title="Collapse all sections">' +
            '<i class="fa fa-compress"></i> Collapse All' +
            "</button>" +
            "</div>" +
            '<div class="edi-toolbar-right">' +
            '<div class="btn-group" role="group">' +
            '<button type="button" class="btn btn-sm btn-outline-primary active" data-view="tree">Tree View</button>' +
            '<button type="button" class="btn btn-sm btn-outline-primary" data-view="raw">Raw View</button>' +
            "</div>" +
            "</div>";

        // Create tree view
        var treeView = buildEdiTree(data, config);

        // Create raw view
        var rawView = buildEdiRaw(data, config);
        rawView.className += " hidden";

        container.appendChild(toolbar);
        container.appendChild(treeView);
        container.appendChild(rawView);

        // Initialize functionality
        setTimeout(function () {
            initializeViewToggle(container, data);
            initializeExpandCollapse(container);
        }, 0);

        return container;
    }

    /**
     * Build raw text view of EDIFACT data
     * @param {Object} data - EDIFACT JSON data
     * @param {Object} config - Configuration options
     * @returns {HTMLElement} - The raw view element
     */
    function buildEdiRaw(data, config) {
        var rawDiv = document.createElement("div");
        rawDiv.className = "edi-raw-view";

        var content = "";

        // Add header
        if (data.header) {
            content +=
                '<div class="segment-line"><span class="segment-tag">UNB</span>' +
                data.header.substring(3) +
                "</div>";
        }

        // Add message segments
        for (var i = 0; i < data.messages.length; i++) {
            var message = data.messages[i];

            // Message header
            if (message.header) {
                content +=
                    '<div class="segment-line"><span class="segment-tag">UNH</span>' +
                    message.header.substring(3) +
                    "</div>";
            }

            // Message segments
            for (var j = 0; j < message.segments.length; j++) {
                var segment = message.segments[j];
                var tag = segment.tag || "";
                var raw = segment.raw || "";
                var segmentContent = raw.substring(tag.length);

                content +=
                    '<div class="segment-line"><span class="segment-tag">' +
                    escapeHtml(tag) +
                    "</span>" +
                    escapeHtml(segmentContent) +
                    "</div>";
            }

            // Message trailer
            if (message.trailer) {
                content +=
                    '<div class="segment-line"><span class="segment-tag">UNT</span>' +
                    message.trailer.substring(3) +
                    "</div>";
            }
        }

        // Add trailer
        if (data.trailer) {
            content +=
                '<div class="segment-line"><span class="segment-tag">UNZ</span>' +
                data.trailer.substring(3) +
                "</div>";
        }

        rawDiv.innerHTML = content;
        return rawDiv;
    }

    /**
     * Initialize view toggle functionality
     * @param {HTMLElement} container - The display container
     * @param {Object} data - EDIFACT JSON data for raw download
     */
    function initializeViewToggle(container, data) {
        var toggleButtons = container.querySelectorAll("[data-view]");
        var treeView = container.querySelector(".edi-tree");
        var rawView = container.querySelector(".edi-raw-view");
        var expandCollapseButtons = container.querySelectorAll(
            ".expand-all-btn, .collapse-all-btn"
        );

        // Store data for download functionality
        container.edifactData = data;

        for (var i = 0; i < toggleButtons.length; i++) {
            toggleButtons[i].addEventListener("click", function () {
                var viewType = this.getAttribute("data-view");

                // Update button states
                for (var j = 0; j < toggleButtons.length; j++) {
                    if (toggleButtons[j].classList) {
                        toggleButtons[j].classList.remove("active");
                    } else {
                        toggleButtons[j].className = toggleButtons[
                            j
                        ].className.replace(" active", "");
                    }
                }

                if (this.classList) {
                    this.classList.add("active");
                } else {
                    this.className += " active";
                }

                // Show/hide views and buttons
                if (viewType === "tree") {
                    if (treeView.classList) {
                        treeView.classList.remove("hidden");
                        rawView.classList.add("hidden");
                    } else {
                        treeView.className = treeView.className.replace(
                            " hidden",
                            ""
                        );
                        rawView.className += " hidden";
                    }

                    // Show expand/collapse buttons
                    for (var k = 0; k < expandCollapseButtons.length; k++) {
                        expandCollapseButtons[k].style.display = "inline-block";
                    }
                } else {
                    if (treeView.classList) {
                        treeView.classList.add("hidden");
                        rawView.classList.remove("hidden");
                    } else {
                        treeView.className += " hidden";
                        rawView.className = rawView.className.replace(
                            " hidden",
                            ""
                        );
                    }

                    // Hide expand/collapse buttons
                    for (var k = 0; k < expandCollapseButtons.length; k++) {
                        expandCollapseButtons[k].style.display = "none";
                    }
                }
            });
        }
    }

    /**
     * Initialize expand/collapse functionality using Bootstrap collapse
     * @param {HTMLElement} container - The display container
     */
    function initializeExpandCollapse(container) {
        var expandButton = container.querySelector(".expand-all-btn");
        var collapseButton = container.querySelector(".collapse-all-btn");
        var treeView = container.querySelector(".edi-tree");

        if (expandButton) {
            expandButton.addEventListener("click", function () {
                var collapseElements = treeView.querySelectorAll(".collapse");
                for (var i = 0; i < collapseElements.length; i++) {
                    if (typeof bootstrap !== "undefined") {
                        var collapse = bootstrap.Collapse.getOrCreateInstance(
                            collapseElements[i]
                        );
                        collapse.show();
                    } else {
                        // Fallback for older Bootstrap versions
                        collapseElements[i].classList.add("show");
                    }
                }
            });
        }

        if (collapseButton) {
            collapseButton.addEventListener("click", function () {
                var collapseElements = treeView.querySelectorAll(".collapse");
                for (var i = 0; i < collapseElements.length; i++) {
                    if (typeof bootstrap !== "undefined") {
                        var collapse = bootstrap.Collapse.getOrCreateInstance(
                            collapseElements[i]
                        );
                        collapse.hide();
                    } else {
                        // Fallback for older Bootstrap versions
                        collapseElements[i].classList.remove("show");
                    }
                }
            });
        }
    }

    /**
     * Build hierarchical tree from EDIFACT JSON data
     * @param {Object} data - EDIFACT JSON data
     * @param {Object} config - Configuration options
     * @returns {HTMLElement} - The tree DOM element
     */
    function buildEdiTree(data, config) {
        config = config || {};
        var rootUl = document.createElement("ul");
        rootUl.className = "edi-tree list-unstyled";

        // Build interchange level
        var interchangeLi = buildInterchangeLevel(data, config);
        rootUl.appendChild(interchangeLi);

        // Bootstrap collapse handles the collapsible behavior automatically

        return rootUl;
    }

    /**
     * Build interchange level of the tree
     */
    function buildInterchangeLevel(data, config) {
        var interchangeLi = document.createElement("li");
        var interchangeId = "interchange_" + Date.now();

        // Interchange header
        var headerDiv = createSegmentDiv(
            "header",
            data.header,
            config.expandByDefault,
            true,
            interchangeId
        );
        interchangeLi.appendChild(headerDiv);

        // Messages container with Bootstrap collapse
        var messagesUl = document.createElement("ul");
        messagesUl.id = interchangeId;
        messagesUl.className =
            "collapse " + (config.expandByDefault ? "show" : "");

        for (var i = 0; i < data.messages.length; i++) {
            var messageLi = buildMessageLevel(data.messages[i], i, config);
            messagesUl.appendChild(messageLi);
        }

        // Interchange trailer
        var trailerDiv = createSegmentDiv("trailer", data.trailer, false, true);

        interchangeLi.appendChild(messagesUl);
        interchangeLi.appendChild(trailerDiv);

        return interchangeLi;
    }

    /**
     * Build message level of the tree
     */
    function buildMessageLevel(message, index, config) {
        var messageLi = document.createElement("li");
        var messageId = "message_" + index + "_" + Date.now();

        // Message header
        var headerDiv = createSegmentDiv(
            "header",
            message.header || "UNH",
            config.expandByDefault,
            true,
            messageId
        );
        messageLi.appendChild(headerDiv);

        // Segments container with Bootstrap collapse
        var segmentsUl = document.createElement("ul");
        segmentsUl.id = messageId;
        segmentsUl.className =
            "collapse " + (config.expandByDefault ? "show" : "");

        // Group segments by line_id
        var groupedSegments = groupSegmentsByLineId(message.segments);

        for (var i = 0; i < groupedSegments.length; i++) {
            var group = groupedSegments[i];
            if (group.isLineGroup) {
                var lineGroupLi = buildLineGroup(
                    group,
                    config,
                    messageId + "_line_" + i
                );
                segmentsUl.appendChild(lineGroupLi);
            } else {
                for (var j = 0; j < group.segments.length; j++) {
                    var segmentLi = buildSegmentElement(
                        group.segments[j],
                        config
                    );
                    segmentsUl.appendChild(segmentLi);
                }
            }
        }

        // Message trailer
        var trailerDiv = createSegmentDiv(
            "trailer",
            message.trailer || "UNT",
            false,
            true
        );

        messageLi.appendChild(segmentsUl);
        messageLi.appendChild(trailerDiv);

        return messageLi;
    }

    /**
     * Build line group (LIN + related segments)
     */
    function buildLineGroup(group, config, lineId) {
        var lineGroupLi = document.createElement("li");

        // Line group header - simplified without "LIN Block #" prefix
        var linSegment = group.segments[0];
        var headerText = linSegment.raw;
        var headerDiv = createSegmentDiv(
            "header",
            headerText,
            config.expandByDefault,
            true,
            lineId
        );
        lineGroupLi.appendChild(headerDiv);

        // Line group segments - skip the first segment (LIN) since it's already shown as header
        var lineSegmentsUl = document.createElement("ul");
        lineSegmentsUl.id = lineId;
        lineSegmentsUl.className =
            "collapse " + (config.expandByDefault ? "show" : "");

        for (var i = 1; i < group.segments.length; i++) {
            var segmentLi = buildSegmentElement(group.segments[i], config);
            lineSegmentsUl.appendChild(segmentLi);
        }

        lineGroupLi.appendChild(lineSegmentsUl);
        return lineGroupLi;
    }

    /**
     * Build individual segment element
     */
    function buildSegmentElement(segment, config) {
        var segmentLi = document.createElement("li");
        var segmentDiv = createSegmentDiv("content", segment.raw, false, true);

        // Add metadata
        if (segment.line_id) {
            segmentDiv.dataset.lineId = segment.line_id;
        }

        // Add element details if enabled
        if (config.showElementDetails && segment.elements) {
            var detailsDiv = document.createElement("div");
            detailsDiv.className = "segment-details";
            detailsDiv.innerHTML =
                "<small>Elements: " +
                JSON.stringify(segment.elements) +
                "</small>";
            segmentDiv.appendChild(detailsDiv);
        }

        segmentLi.appendChild(segmentDiv);
        return segmentLi;
    }

    /**
     * Create segment div with appropriate styling using Bootstrap collapse
     */
    function createSegmentDiv(
        type,
        content,
        expandByDefault,
        boldTag,
        targetId
    ) {
        expandByDefault = expandByDefault !== false;
        var div = document.createElement("div");
        div.className = "segment " + type;

        if (type === "header" && targetId) {
            // Use Bootstrap collapse
            div.setAttribute("data-bs-toggle", "collapse");
            div.setAttribute("data-bs-target", "#" + targetId);
            div.setAttribute(
                "aria-expanded",
                expandByDefault ? "true" : "false"
            );
            div.setAttribute("aria-controls", targetId);
            div.style.cursor = "pointer";

            // Bold the segment tag for headers
            if (boldTag && content.length >= 3) {
                var tag = content.substring(0, 3);
                var rest = content.substring(3);
                div.innerHTML =
                    '<i class="fa fa-chevron-down me-1"></i> <span class="segment-tag">' +
                    escapeHtml(tag) +
                    "</span>" +
                    escapeHtml(rest);
            } else {
                div.innerHTML =
                    '<i class="fa fa-chevron-down me-1"></i> ' +
                    escapeHtml(content);
            }
        } else {
            // Bold the segment tag for content
            if (boldTag && content.length >= 3) {
                var tag = content.substring(0, 3);
                var rest = content.substring(3);
                div.innerHTML =
                    '<span class="segment-tag">' +
                    escapeHtml(tag) +
                    "</span>" +
                    escapeHtml(rest);
            } else {
                div.textContent = content;
            }
        }

        return div;
    }

    /**
     * Group segments by line_id
     */
    function groupSegmentsByLineId(segments) {
        var groups = [];
        var currentGroup = null;

        for (var i = 0; i < segments.length; i++) {
            var segment = segments[i];
            if (segment.tag === "LIN") {
                // Start new line group
                if (currentGroup) {
                    groups.push(currentGroup);
                }
                currentGroup = {
                    isLineGroup: true,
                    lineId: segment.line_id,
                    segments: [segment],
                };
            } else if (
                currentGroup &&
                segment.line_id === currentGroup.lineId
            ) {
                // Add to current line group
                currentGroup.segments.push(segment);
            } else {
                // Segment doesn't belong to line group
                if (currentGroup) {
                    groups.push(currentGroup);
                    currentGroup = null;
                }

                // Find or create non-line group
                var nonLineGroup = null;
                for (var j = 0; j < groups.length; j++) {
                    if (!groups[j].isLineGroup) {
                        nonLineGroup = groups[j];
                        break;
                    }
                }
                if (!nonLineGroup) {
                    nonLineGroup = { isLineGroup: false, segments: [] };
                    groups.push(nonLineGroup);
                }
                nonLineGroup.segments.push(segment);
            }
        }

        if (currentGroup) {
            groups.push(currentGroup);
        }

        return groups;
    }

    // Removed initializeCollapsible - now using Bootstrap collapse

    /**
     * Initialize modal behavior
     */
    function initializeModal(config) {
        var modal = $(config.modalId);

        // Reset modal content when hidden
        modal.on("hidden.bs.modal", function () {
            $(this).find(config.modalBodySelector).html(config.loadingHtml);
        });
    }

    /**
     * Utility function to escape HTML
     */
    function escapeHtml(str) {
        if (!str) return "";
        return str.replace(/[&<>"']/g, function (match) {
            var escapeMap = {
                "&": "&amp;",
                "<": "&lt;",
                ">": "&gt;",
                '"': "&quot;",
                "'": "&#039;",
            };
            return escapeMap[match];
        });
    }

    // Public API
    return {
        init: init,
        showMessage: showMessage,
        showMessageFromUrl: showMessageFromUrl,
        buildEdiTree: buildEdiTree,
    };
})();

// Auto-initialize with default settings when jQuery is ready
if (typeof $ !== "undefined") {
    $(document).ready(function () {
        // Default initialization will be handled by individual pages
    });
}
