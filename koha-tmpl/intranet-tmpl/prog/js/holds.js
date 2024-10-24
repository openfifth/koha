function display_pickup_location(state) {
    var $text;
    if (state.needs_override === true) {
        $text = $(
            "<span>" +
                state.text +
                '</span> <span style="float:right;" title="' +
                __(
                    "This pickup location is not allowed according to circulation rules"
                ) +
                '"><i class="fa fa-exclamation-circle" aria-hidden="true"></i></span>'
        );
    } else {
        $text = $("<span>" + state.text + "</span>");
    }

    return $text;
}

(function ($) {
    /**
     * Generate a Select2 dropdown for pickup locations
     *
     * It expects the select object to contain several data-* attributes
     * - data-pickup-location-source: 'biblio', 'item' or 'hold' (default)
     * - data-patron-id: required for 'biblio' and 'item'
     * - data-biblio-id: required for 'biblio' only
     * - data-item-id: required for 'item' only
     *
     * @return {Object} The Select2 instance
     */

    $.fn.pickup_locations_dropdown = function () {
        var select = $(this);
        var pickup_location_source = $(this).data("pickup-location-source");
        var patron_id = $(this).data("patron-id");
        var biblio_id = $(this).data("biblio-id");
        var item_id = $(this).data("item-id");
        var hold_id = $(this).data("hold-id");

        var url;

        if (pickup_location_source === "biblio") {
            url =
                "/api/v1/biblios/" +
                encodeURIComponent(biblio_id) +
                "/pickup_locations";
        } else if (pickup_location_source === "item") {
            url =
                "/api/v1/items/" +
                encodeURIComponent(item_id) +
                "/pickup_locations";
        } else {
            // hold
            url =
                "/api/v1/holds/" +
                encodeURIComponent(hold_id) +
                "/pickup_locations";
        }

        select.kohaSelect({
            width: "style",
            allowClear: false,
            ajax: {
                url: url,
                delay: 300, // wait 300 milliseconds before triggering the request
                cache: true,
                dataType: "json",
                data: function (params) {
                    var search_term =
                        params.term === undefined ? "" : params.term;
                    var query = {
                        q: JSON.stringify({
                            name: { "-like": "%" + search_term + "%" },
                        }),
                        _order_by: "name",
                        _page: params.page,
                    };

                    if (pickup_location_source !== "hold") {
                        query["patron_id"] = patron_id;
                    }

                    return query;
                },
                processResults: function (data) {
                    var results = [];
                    data.results.forEach(function (pickup_location) {
                        results.push({
                            id: pickup_location.library_id.escapeHtml(),
                            text: pickup_location.name.escapeHtml(),
                            needs_override: pickup_location.needs_override,
                        });
                    });
                    return {
                        results: results,
                        pagination: { more: data.pagination.more },
                    };
                },
            },
            templateResult: display_pickup_location,
        });

        return select;
    };
})(jQuery);

/* global __ borrowernumber SuspendHoldsIntranet */
$(document).ready(function () {
    function suspend_hold(hold_id, end_date) {
        var params;
        if (end_date !== null && end_date !== "")
            params = JSON.stringify({ end_date: end_date });

        return $.ajax({
            method: "POST",
            url: "/api/v1/holds/" + encodeURIComponent(hold_id) + "/suspension",
            contentType: "application/json",
            data: params,
        });
    }

    function resume_hold(hold_id) {
        return $.ajax({
            method: "DELETE",
            url: "/api/v1/holds/" + encodeURIComponent(hold_id) + "/suspension",
        });
    }

    var holdsTable;

    // Don't load holds table unless it is clicked on
    $("#holds-tab").on("click", function () {
        load_holds_table();
    });

    // If the holds tab is preselected on load, we need to load the table
    if ($("#holds-tab").parent().hasClass("active")) {
        load_holds_table();
    }

    function load_holds_table() {
        var holds = new Array();
        if (!holdsTable) {
            var title;
            holdsTable = $("#holds-table").kohaTable(
                {
                    autoWidth: false,
                    dom: '<"table_controls"B>rt',
                    columns: [
                        {
                            data: {
                                _: "reservedate_formatted",
                                sort: "reservedate",
                            },
                        },
                        {
                            data: function (oObj) {
                                title =
                                    "<a href='/cgi-bin/koha/reserve/request.pl?biblionumber=" +
                                    oObj.biblionumber +
                                    "'>" +
                                    (oObj.title ? oObj.title.escapeHtml() : "");

                                $.each(oObj.subtitle, function (index, value) {
                                    title += " " + value.escapeHtml();
                                });

                                title +=
                                    " " +
                                    oObj.part_number +
                                    " " +
                                    oObj.part_name;

                                if (oObj.enumchron) {
                                    title +=
                                        " (" +
                                        oObj.enumchron.escapeHtml() +
                                        ")";
                                }

                                title += "</a>";

                                if (oObj.author) {
                                    title +=
                                        " " +
                                        __("by _AUTHOR_").replace(
                                            "_AUTHOR_",
                                            oObj.author.escapeHtml()
                                        );
                                }

                                if (oObj.itemnotes) {
                                    var span_class = "";
                                    if (
                                        flatpickr.formatDate(
                                            new Date(oObj.issuedate),
                                            "Y-m-d"
                                        ) == ymd
                                    ) {
                                        span_class = "circ-hlt";
                                    }
                                    title +=
                                        " - <span class='" +
                                        span_class +
                                        "'>" +
                                        oObj.itemnotes.escapeHtml() +
                                        "</span>";
                                }

                                return title;
                            },
                        },
                        {
                            data: function (oObj) {
                                return (
                                    (oObj.itemcallnumber &&
                                        oObj.itemcallnumber.escapeHtml()) ||
                                    ""
                                );
                            },
                        },
                        {
                            data: function (oObj) {
                                var data = "";
                                if (oObj.itemtype) {
                                    data += oObj.itemtype_description;
                                }
                                return data;
                            },
                        },
                        {
                            data: function (oObj) {
                                var data = "";
                                if (oObj.barcode) {
                                    data +=
                                        " <a href='/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=" +
                                        oObj.biblionumber +
                                        "&itemnumber=" +
                                        oObj.itemnumber +
                                        "#item" +
                                        oObj.itemnumber +
                                        "'>" +
                                        oObj.barcode.escapeHtml() +
                                        "</a>";
                                }
                                return data;
                            },
                        },
                        {
                            data: function (oObj) {
                                if (
                                    oObj.branches.length > 1 &&
                                    oObj.found !== "W" &&
                                    oObj.found !== "T"
                                ) {
                                    var branchSelect =
                                        "<select priority=" +
                                        oObj.priority +
                                        ' class="hold_location_select" data-hold-id="' +
                                        oObj.reserve_id +
                                        '" reserve_id="' +
                                        oObj.reserve_id +
                                        '" name="pick-location" data-pickup-location-source="hold">';
                                    for (
                                        var i = 0;
                                        i < oObj.branches.length;
                                        i++
                                    ) {
                                        var selectedbranch;
                                        var setbranch;
                                        if (oObj.branches[i].selected) {
                                            selectedbranch =
                                                " selected='selected' ";
                                            setbranch = __(" (current) ");
                                        } else if (
                                            oObj.branches[i].pickup_location ==
                                            0
                                        ) {
                                            continue;
                                        } else {
                                            selectedbranch = "";
                                            setbranch = "";
                                        }
                                        branchSelect +=
                                            '<option value="' +
                                            oObj.branches[
                                                i
                                            ].branchcode.escapeHtml() +
                                            '"' +
                                            selectedbranch +
                                            ">" +
                                            oObj.branches[
                                                i
                                            ].branchname.escapeHtml() +
                                            setbranch +
                                            "</option>";
                                    }
                                    branchSelect += "</select>";
                                    return branchSelect;
                                } else {
                                    return oObj.branchcode.escapeHtml() || "";
                                }
                            },
                        },
                        {
                            data: {
                                _: "expirationdate_formatted",
                                sort: "expirationdate",
                            },
                        },
                        {
                            data: function (oObj) {
                                if (
                                    oObj.priority &&
                                    parseInt(oObj.priority) &&
                                    parseInt(oObj.priority) > 0
                                ) {
                                    return oObj.priority;
                                } else {
                                    return "";
                                }
                            },
                        },
                        {
                            data: function (oObj) {
                                return (
                                    (oObj.reservenotes &&
                                        oObj.reservenotes.escapeHtml()) ||
                                    ""
                                );
                            },
                        },
                        {
                            orderable: false,
                            data: function (oObj) {
                                return (
                                    "<select name='rank-request'>" +
                                    "<option value='n'>" +
                                    __("No") +
                                    "</option>" +
                                    "<option value='del'>" +
                                    __("Yes") +
                                    "</option>" +
                                    "</select>" +
                                    "<input type='hidden' name='biblionumber' value='" +
                                    oObj.biblionumber +
                                    "'>" +
                                    "<input type='hidden' name='borrowernumber' value='" +
                                    borrowernumber +
                                    "'>" +
                                    "<input type='hidden' name='reserve_id' value='" +
                                    oObj.reserve_id +
                                    "'>"
                                );
                            },
                        },
                        {
                            orderable: false,
                            visible: SuspendHoldsIntranet,
                            data: function (oObj) {
                                holds[oObj.reserve_id] = oObj; //Store holds for later use

                                if (oObj.found) {
                                    return "";
                                } else if (oObj.suspend == 1) {
                                    return (
                                        "<a class='hold-resume btn btn-default btn-xs' data-hold-id='" +
                                        oObj.reserve_id +
                                        "'>" +
                                        "<i class='fa fa-play'></i> " +
                                        __("Resume") +
                                        "</a>"
                                    );
                                } else {
                                    return (
                                        "<a class='hold-suspend btn btn-default btn-xs' data-hold-id='" +
                                        oObj.reserve_id +
                                        "' data-hold-title='" +
                                        oObj.title +
                                        "'>" +
                                        "<i class='fa fa-pause'></i> " +
                                        __("Suspend") +
                                        "</a>"
                                    );
                                }
                            },
                        },
                        {
                            data: function (oObj) {
                                var data = "";

                                if (oObj.suspend == 1) {
                                    data +=
                                        "<p>" +
                                        __(
                                            "Hold is <strong>suspended</strong>"
                                        );
                                    if (oObj.suspend_until) {
                                        data +=
                                            " " +
                                            __("until %s").format(
                                                oObj.suspend_until_formatted
                                            );
                                    }
                                    data += "</p>";
                                }

                                if (oObj.itemtype_limit) {
                                    data += __("Next available %s item").format(
                                        oObj.itemtype_limit
                                    );
                                }

                                if (oObj.item_group_id) {
                                    data += __(
                                        "Next available item group <strong>%s</strong> item"
                                    ).format(oObj.item_group_description);
                                }

                                if (oObj.barcode) {
                                    data += "<em>";
                                    if (oObj.found == "W") {
                                        if (oObj.waiting_here) {
                                            data += __(
                                                "Item is <strong>waiting here</strong>"
                                            );
                                            if (oObj.desk_name) {
                                                data +=
                                                    ", " +
                                                    __("at %s").format(
                                                        oObj.desk_name.escapeHtml()
                                                    );
                                            }
                                        } else {
                                            data += __(
                                                "Item is <strong>waiting</strong>"
                                            );
                                            data +=
                                                " " +
                                                __("at %s").format(
                                                    oObj.waiting_at
                                                );
                                            if (oObj.desk_name) {
                                                data +=
                                                    ", " +
                                                    __("at %s").format(
                                                        oObj.desk_name.escapeHtml()
                                                    );
                                            }
                                        }
                                    } else if (
                                        oObj.found == "T" &&
                                        oObj.transferred
                                    ) {
                                        data += __(
                                            "Item is <strong>in transit</strong> from %s since %s"
                                        ).format(
                                            oObj.from_branch,
                                            oObj.date_sent
                                        );
                                    } else if (
                                        oObj.found == "T" &&
                                        oObj.not_transferred
                                    ) {
                                        data += __(
                                            "Item hasn't been transferred yet from %s"
                                        ).format(oObj.not_transferred_by);
                                    }
                                    data += "</em>";
                                }
                                return data;
                            },
                        },
                    ],
                    paging: false,
                    processing: true,
                    serverSide: false,
                    ajax: {
                        url: "/cgi-bin/koha/svc/holds",
                        data: function (d) {
                            d.borrowernumber = borrowernumber;
                        },
                    },
                    bKohaAjaxSVC: true,
                },
                table_settings_holds_table
            );

            $("#holds-table").on("draw.dt", function () {
                $(".hold-suspend").on("click", function () {
                    var hold_id = $(this).data("hold-id");
                    var hold_title = $(this).data("hold-title");
                    $("#suspend-modal-title").html(hold_title);
                    $("#suspend-modal-submit").data("hold-id", hold_id);
                    $("#suspend-modal").modal("show");
                });

                $(".hold-resume").on("click", function () {
                    var hold_id = $(this).data("hold-id");
                    resume_hold(hold_id)
                        .success(function () {
                            holdsTable.api().ajax.reload();
                        })
                        .error(function (jqXHR, textStatus, errorThrown) {
                            if (jqXHR.status === 404) {
                                alert(__("Unable to resume, hold not found"));
                            } else {
                                alert(
                                    __(
                                        "Your request could not be processed. Check the logs for details."
                                    )
                                );
                            }
                            holdsTable.api().ajax.reload();
                        });
                });

                $(".hold_location_select").each(function () {
                    $(this).pickup_locations_dropdown();
                });

                $(".hold_location_select").on("change", function () {
                    $(this).prop("disabled", true);
                    var cur_select = $(this);
                    var res_id = $(this).attr("reserve_id");
                    $(this).after(
                        '<div id="updating_reserveno' +
                            res_id +
                            '" class="waiting"><img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>'
                    );
                    var api_url =
                        "/api/v1/holds/" +
                        encodeURIComponent(res_id) +
                        "/pickup_location";
                    $.ajax({
                        method: "PUT",
                        url: api_url,
                        data: JSON.stringify({
                            pickup_library_id: $(this).val(),
                        }),
                        headers: { "x-koha-override": "any" },
                        success: function (data) {
                            holdsTable.api().ajax.reload();
                        },
                        error: function (jqXHR, textStatus, errorThrown) {
                            alert(
                                "There was an error:" +
                                    textStatus +
                                    " " +
                                    errorThrown
                            );
                            cur_select.prop("disabled", false);
                            $("#updating_reserveno" + res_id).remove();
                            cur_select.val(
                                cur_select
                                    .children('option[selected="selected"]')
                                    .val()
                            );
                        },
                    });
                });
            });

            if ($("#holds-table").length) {
                $("#holds-table_processing").position({
                    of: $("#holds-table"),
                    collision: "none",
                });
            }
        }
    }

    $("body").append(
        "\
        <div id='suspend-modal' class='modal' role='dialog' aria-hidden='true'>\
            <div class='modal-dialog'>\
            <div class='modal-content'>\
            <form id='suspend-modal-form' class='form-inline'>\
                <div class='modal-header'>\
                    <h1 class='modal-title' id='suspend-modal-label'>" +
            __("Suspend hold on") +
            " <i><span id='suspend-modal-title'></span></i></h1>\
                    <button type='button' class='btn-close' data-bs-dismiss='modal' aria-label='Close'></button>\
                </div>\
\
                <div class='modal-body'>\
                    <input type='hidden' id='suspend-modal-reserve_id' name='reserve_id' />\
\
                    <label for='suspend-modal-until'>" +
            __("Suspend until:") +
            "</label>\
                    <input name='suspend_until' id='suspend-modal-until' class='suspend-until flatpickr' data-flatpickr-futuredate='true' size='10' />\
\
                    <p><a class='btn btn-link' id='suspend-modal-clear-date' >" +
            __("Clear date to suspend indefinitely") +
            "</a></p>\
\
                </div>\
\
                <div class='modal-footer'>\
                    <button id='suspend-modal-submit' class='btn btn-primary' type='submit' name='submit'>" +
            __("Suspend") +
            "</button>\
                    <button type='button' class='btn btn-default' data-bs-dismiss='modal'>" +
            __("Cancel") +
            "</button>\
                </div>\
            </form>\
            </div>\
            </div>\
        </div>\
    "
    );

    $("#suspend-modal-clear-date").on("click", function () {
        $("#suspend-modal-until").flatpickr().clear();
    });

    $("#suspend-modal-submit").on("click", function (e) {
        e.preventDefault();
        var suspend_until_date = $("#suspend-modal-until").val();
        if (suspend_until_date !== null)
            suspend_until_date = $date(suspend_until_date, {
                dateformat: "rfc3339",
            });
        suspend_hold($(this).data("hold-id"), suspend_until_date)
            .success(function () {
                holdsTable.api().ajax.reload();
            })
            .error(function (jqXHR, textStatus, errorThrown) {
                if (jqXHR.status === 404) {
                    alert(__("Unable to suspend, hold not found."));
                } else {
                    alert(
                        __(
                            "Your request could not be processed. Check the logs for details."
                        )
                    );
                }
                holdsTable.api().ajax.reload();
            })
            .done(function () {
                $("#suspend-modal-until").flatpickr().clear(); // clean the input
                $("#suspend-modal").modal("hide");
            });
    });

    function toggle_suspend(node, inputs) {
        let reserve_id = $(node).data("reserve-id");
        let biblionumber = $(node).data("biblionumber");
        let suspendForm = $("#hold-actions-form").attr({
            action: "request.pl",
            method: "post",
        });
        let sus_bn = $("<input />").attr({
            type: "hidden",
            name: "biblionumber",
            value: biblionumber,
        });
        let sus_ri = $("<input />").attr({
            type: "hidden",
            name: "reserve_id",
            value: reserve_id,
        });
        inputs.push(sus_bn, sus_ri);
        suspendForm.append(inputs);
        $("#hold-actions-form").submit();
        return false;
    }
    $(".suspend-hold").on("click", function (e) {
        e.preventDefault();
        let reserve_id = $(this).data("reserve-id");
        let suspend_until = $("#suspend_until_" + reserve_id).val();
        let inputs = [
            $("<input />").attr({
                type: "hidden",
                name: "op",
                value: "cud-suspend",
            }),
            $("<input />").attr({
                type: "hidden",
                name: "suspend_until",
                value: suspend_until,
            }),
        ];
        return toggle_suspend(this, inputs);
    });
    $(".unsuspend-hold").on("click", function (e) {
        e.preventDefault();
        let inputs = [
            $("<input />").attr({
                type: "hidden",
                name: "op",
                value: "cud-unsuspend",
            }),
        ];
        return toggle_suspend(this, inputs);
    });
});

async function load_patron_holds_table(biblio_id, split_data) {
    const { name: split_name, value: split_value } = split_data;
    const table_id = `#patron_holds_table_${biblio_id}_${split_value}`;
    hold_table_settings.table = `patron_holds_table_${biblio_id}_${split_data.value}`;
    let url = `/api/v1/holds/?q={"me.biblio_id":${biblio_id}`;

    if (split_name === "branch" && split_value !== "any") {
        url += `, "me.pickup_library_id":"${split_value}"`;
    } else if (split_name === "itemtype" && split_value !== "any") {
        url += `, "me.itemtype":"${split_value}"`;
    } else if (split_name === "branch_itemtype") {
        const [branch, itemtype] = split_value.split("_");
        url +=
            itemtype === "any"
                ? `, "me.pickup_library_id":"${branch}"`
                : `, "me.pickup_library_id":"${branch}", "me.itemtype":"${itemtype}"`;
    }

    url += "}";
    const totalHolds = $(table_id).data("total-holds");
    const totalHoldsSelect = parseInt(totalHolds) + 1;
    let pageStart;
    var holdsQueueTable = $(table_id).kohaTable(
        {
            ajax: {
                url: url,
                data: function (params) {
                    pageStart = params.start;
                    var query = {
                        _per_page: params.length,
                        _page: params.start / params.length + 1,
                        _order_by: "priority",
                        _match: "exact",
                    };
                    return query;
                },
            },
            embed: ["patron", "item", "item_group"],
            columnDefs: [
                {
                    targets: [2, 3],
                    className: "dt-body-nowrap",
                },
                {
                    targets: [3, 9],
                    visible: CAN_user_reserveforothers_modify_holds_priority
                        ? true
                        : false,
                },
            ],
            columns: [
                {
                    data: "hold_id",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        return (
                            '<input type="checkbox" class="select_hold" data-id="' +
                            data +
                            '"/>'
                        );
                    },
                },
                {
                    data: "priority",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        let select =
                            '<select name="rank-request" class="rank-request" data-id="' +
                            row.hold_id;
                        if (
                            CAN_user_reserveforothers_modify_holds_priority &&
                            split_name == "any"
                        ) {
                            for (var i = 0; i < totalHoldsSelect; i++) {
                                let selected;
                                let value;
                                let desc;
                                if (data == i && row.status == "T") {
                                    select += '" disabled="disabled">';
                                    selected = " selected='selected' ";
                                    value = "T";
                                    desc = "In transit";
                                } else if (data == i && row.status == "P") {
                                    select += '" disabled="disabled">';
                                    selected = " selected='selected' ";
                                    value = "P";
                                    desc = "In processing";
                                } else if (data == i && row.status == "W") {
                                    select += '" disabled="disabled">';
                                    selected = " selected='selected' ";
                                    value = "W";
                                    desc = "Waiting";
                                } else if (data == i && !row.status) {
                                    select += '">';
                                    selected = " selected='selected' ";
                                    value = data;
                                    desc = data;
                                } else {
                                    if (i != 0) {
                                        select += '">';
                                        value = i;
                                        desc = i;
                                    } else {
                                        select += '">';
                                    }
                                }
                                if (value) {
                                    select +=
                                        '<option value="' +
                                        value +
                                        '"' +
                                        selected +
                                        ">" +
                                        desc +
                                        "</option>";
                                }
                            }
                        } else {
                            if (row.status == "T") {
                                select +=
                                    '" disabled="disabled"><option value="T" selected="selected">In transit</option></select>';
                            } else if (row.status == "P") {
                                select +=
                                    '" disabled="disabled"><option value="P" selected="selected">In processing</option></select>';
                            } else if (row.status == "W") {
                                select +=
                                    '" disabled="disabled"><option value="W" selected="selected">Waiting</option></select>';
                            } else {
                                if (
                                    HoldsSplitQueue !== "nothing" &&
                                    HoldsSplitQueueNumbering === "virtual"
                                ) {
                                    let virtualPriority =
                                        pageStart + meta.row + 1;
                                    select +=
                                        '" disabled="disabled"><option value="' +
                                        data +
                                        '" selected="selected">' +
                                        virtualPriority +
                                        "</option></select>";
                                } else {
                                    select +=
                                        '" disabled="disabled"><option value="' +
                                        data +
                                        '" selected="selected">' +
                                        data +
                                        "</option></select>";
                                }
                            }
                        }
                        select += "</select>";
                        return select;
                    },
                },
                {
                    data: "",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        if (row.status) {
                            return null;
                        }
                        let buttons =
                            '<a class="hold-arrow move-hold" title="Move hold up" href="#" data-move-hold="up" data-priority="' +
                            row.priority +
                            '" reserve_id="' +
                            row.hold_id +
                            '"><i class="fa fa-lg icon-move-hold-up" aria-hidden="true"></i></a>';
                        buttons +=
                            '<a class="hold-arrow move-hold" title="Move hold to top" href="#" data-move-hold="top" data-priority="' +
                            row.priority +
                            '" reserve_id="' +
                            row.hold_id +
                            '"><i class="fa fa-lg icon-move-hold-top" aria-hidden="true"></i></a>';
                        buttons +=
                            '<a class="hold-arrow move-hold" title="Move hold to bottom" href="#" data-move-hold="bottom" data-priority="' +
                            row.priority +
                            '" reserve_id="' +
                            row.hold_id +
                            '"><i class="fa fa-lg icon-move-hold-bottom" aria-hidden="true"></i></a>';
                        buttons +=
                            '<a class="hold-arrow move-hold" title="Move hold down" href="#" data-move-hold="down" data-priority="' +
                            row.priority +
                            '" reserve_id="' +
                            row.hold_id +
                            '"><i class="fa fa-lg icon-move-hold-down" aria-hidden="true"></i></a>';
                        return buttons;
                    },
                },
                {
                    data: "patron.cardnumber",
                    orderable: false,
                    searchable: true,
                    render: function (data, type, row, meta) {
                        if (data == null) {
                            let library = libraries.find(
                                library => library._id == row.pickup_library_id
                            );
                            return __("A patron from library %s").format(
                                library.name
                            );
                        } else {
                            return (
                                '<a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=' +
                                row.patron.patron_id +
                                '">' +
                                data +
                                "</a>"
                            );
                        }
                    },
                },
                {
                    data: "notes",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        return data;
                    },
                },
                {
                    data: "hold_date",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        if (AllowHoldDateInFuture) {
                            return (
                                '<input type="text" class="holddate" value="' +
                                $date(data, { dateformat: "rfc3339" }) +
                                '" size="10" name="hold_date" data-id="' +
                                row.hold_id +
                                '" data-current-date="' +
                                data +
                                '"/>'
                            );
                        } else {
                            return $date(data);
                        }
                    },
                },
                {
                    data: "expiration_date",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        return (
                            '<input type="text" class="expirationdate" value="' +
                            $date(data, { dateformat: "rfc3339" }) +
                            '" size="10" name="expiration_date" data-id="' +
                            row.hold_id +
                            '" data-current-date="' +
                            data +
                            '"/>'
                        );
                    },
                },
                {
                    data: "pickup_library_id",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        var branchSelect =
                            "<select priority=" +
                            row.priority +
                            ' class="hold_location_select" data-id="' +
                            row.hold_id +
                            '" reserve_id="' +
                            row.hold_id +
                            '" name="pick-location" data-pickup-location-source="hold">';
                        var libraryname;
                        for (var i = 0; i < libraries.length; i++) {
                            var selectedbranch;
                            var setbranch;
                            if (libraries[i]._id == data) {
                                selectedbranch = " selected='selected' ";
                                setbranch = __(" (current) ");
                                libraryname = libraries[i]._str;
                            } else if (libraries[i].pickup_location == false) {
                                continue;
                            } else {
                                selectedbranch = "";
                                setbranch = "";
                            }
                            branchSelect +=
                                '<option value="' +
                                libraries[i]._id.escapeHtml() +
                                '"' +
                                selectedbranch +
                                ">" +
                                libraries[i]._str.escapeHtml() +
                                setbranch +
                                "</option>";
                        }
                        branchSelect += "</select>";
                        if (row.status == "T") {
                            return __(
                                "Item being transferred to <strong>%s</strong>"
                            ).format(libraryname);
                        } else if (row.status == "P") {
                            return __(
                                "Item being processed at <strong>%s</strong>"
                            ).format(libraryname);
                        } else if (row.status == "W") {
                            return __(
                                "Item waiting at <strong>%s</strong> since %s"
                            ).format(libraryname, $date(row.waiting_date));
                        } else {
                            return branchSelect;
                        }
                    },
                },
                {
                    data: "",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        if (row.item_id) {
                            return (
                                '<a href="/cgi-bin/koha/catalogue/moredetail.pl?biblionumber=' +
                                row.biblio_id +
                                "&itemnumber=" +
                                row.item_id +
                                '">' +
                                row.item.external_id +
                                "</a>"
                            );
                        } else if (row.item_group_id) {
                            return __(
                                "Next available item from group <strong>%s</strong>"
                            ).format(row.item_group.description);
                        } else {
                            if (row.non_priority) {
                                return (
                                    "<em>" +
                                    __("Next available") +
                                    "</em><br/><i>" +
                                    __("Non priority hold") +
                                    "</i>"
                                );
                            } else {
                                return "<em>" + __("Next available") + "</em>";
                            }
                        }
                    },
                },
                {
                    data: "",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        if (row.item_id) {
                            return null;
                        } else {
                            if (row.lowest_priority) {
                                return (
                                    '<a class="hold-arrow toggle-lowest-priority" title="Remove lowest priority" href="#" data-op="cud-setLowestPriority" data-borrowernumber="' +
                                    row.patron_id +
                                    '" data-biblionumber="' +
                                    biblio_id +
                                    '" data-reserve_id="' +
                                    row.hold_id +
                                    '" data-date="' +
                                    row.hold_date +
                                    '"><i class="fa fa-lg fa-rotate-90 icon-unset-lowest" aria-hidden="true"></i></a>'
                                );
                            } else {
                                return (
                                    '<a class="hold-arrow toggle-lowest-priority" title="Set lowest priority" href="#" data-op="cud-setLowestPriority" data-borrowernumber="' +
                                    row.patron_id +
                                    '" data-biblionumber="' +
                                    biblio_id +
                                    '" data-reserve_id="' +
                                    row.hold_id +
                                    '" data-date="' +
                                    row.hold_date +
                                    '"><i class="fa fa-lg fa-rotate-90 icon-set-lowest" aria-hidden="true"></i></a>'
                                );
                            }
                        }
                    },
                },
                {
                    data: "hold_id",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        return (
                            '<a class="cancel-hold" title="Cancel hold" reserve_id="' +
                            data +
                            '" href="#"><i class="fa fa-trash" aria-label="Cancel hold"></i></a>'
                        );
                    },
                },
                {
                    data: "hold_id",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        if (row.status) {
                            var link_value =
                                row.status == "T"
                                    ? __("Revert transit status")
                                    : __("Revert waiting status");
                            return (
                                '<a class="btn btn-default submit-form-link" href="#" id="revert_hold_' +
                                data +
                                '" data-op="cud-move" data-where="down" data-first_priority="1" data-last_priority="' +
                                totalHolds +
                                '" data-prev_priority="0" data-next_priority="1" data-borrowernumber="' +
                                row.patron_id +
                                '" data-biblionumber="' +
                                biblio_id +
                                '" data-itemnumber="' +
                                row.item_id +
                                '" data-reserve_id="' +
                                row.hold_id +
                                '" data-date="' +
                                row.hold_date +
                                '" data-action="request.pl" data-method="post">' +
                                link_value +
                                "</a>"
                            );
                        } else {
                            let td = "";
                            if (SuspendHoldsIntranet) {
                                td +=
                                    '<button class="btn btn-default btn-xs toggle-suspend" data-id="' +
                                    data +
                                    '" data-biblionumber="' +
                                    biblio_id +
                                    '" data-suspended="' +
                                    row.suspended +
                                    '">';
                                if (row.suspended) {
                                    td +=
                                        '<i class="fa fa-play" aria-hidden="true"></i> ' +
                                        __("Resume") +
                                        "</button>";
                                } else {
                                    td +=
                                        '<i class="fa fa-pause" aria-hidden="true"></i> ' +
                                        __("Suspend") +
                                        "</button>";
                                }
                                if (AutoResumeSuspendedHolds) {
                                    if (row.suspended) {
                                        td +=
                                            '<label for="suspend_until_' +
                                            data +
                                            '">' +
                                            __("Suspend on") +
                                            " </label>";
                                    } else {
                                        td +=
                                            '<label for="suspend_until_' +
                                            data +
                                            '">' +
                                            __("Suspend until") +
                                            " </label>";
                                    }
                                    td +=
                                        '<input type="text" name="suspend_until_' +
                                        data +
                                        '" data-id="' +
                                        data +
                                        '" size="10" value="' +
                                        $date(row.suspended_until, {
                                            dateformat: "rfc3339",
                                        }) +
                                        '" class="suspenddate" data-flatpickr-futuredate="true" data-suspend-date="' +
                                        row.suspended_until +
                                        '" />';
                                }
                                return td;
                            } else {
                                return null;
                            }
                        }
                    },
                },
                {
                    data: "hold_id",
                    orderable: false,
                    searchable: false,
                    render: function (data, type, row, meta) {
                        if (row.status == "W" || row.status == "T") {
                            return (
                                '<a class="btn btn-default btn-xs printholdslip" data-reserve_id="' +
                                data +
                                '">' +
                                __("Print slip") +
                                "</a>"
                            );
                        } else {
                            return "";
                        }
                    },
                },
            ],
        },
        hold_table_settings
    );
    $(table_id).on("draw.dt", function () {
        // Remove the search box. Don't know why it isn't working in the table settings
        $(this).parent().find(".pager .table_controls .dt-search").remove();
        $(this)
            .parent()
            .find(".pager .table_controls .dt-buttons .dt_button_clear_filter")
            .remove();
        var MSG_CANCEL_SELECTED = _("Cancel selected (%s)");
        $(".cancel_selected_holds").html(
            MSG_CANCEL_SELECTED.format(
                $(".holds_table .select_hold:checked").length
            )
        );
        $(".holds_table .select_hold").each(function () {
            if (
                localStorage.selectedHolds &&
                localStorage.selectedHolds.includes($(this).data("id"))
            ) {
                $(this).prop("checked", true);
            }
        });
        $(".holds_table .select_hold_all").on("click", function () {
            var table = $(this).parents(".holds_table");
            var count = $(".select_hold:checked", table).length;
            $(".select_hold", table).prop("checked", !count);
            $(this).prop("checked", !count);
            $(this).parent().parent().toggleClass("selected");
            $(".cancel_selected_holds").html(
                MSG_CANCEL_SELECTED.format(
                    $(".holds_table .select_hold:checked").length
                )
            );
            localStorage.selectedHolds = $(".holds_table .select_hold:checked")
                .toArray()
                .map(el => $(el).data("id"));
        });
        $(".holds_table .select_hold").on("click", function () {
            var table = $(this).parents(".holds_table");
            var count = $(".select_hold:not(:checked)", table).length;
            $(".select_hold_all", table).prop("checked", !count);
            $(this).parent().parent().toggleClass("selected");
            $(".cancel_selected_holds").html(
                MSG_CANCEL_SELECTED.format(
                    $(".holds_table .select_hold:checked").length
                )
            );
            localStorage.selectedHolds = $(".holds_table .select_hold:checked")
                .toArray()
                .map(el => $(el).data("id"));
        });
        $(".cancel-hold").on("click", function (e) {
            e.preventDefault;
            var res_id = $(this).attr("reserve_id");
            $(".select_hold").prop("checked", false);
            $(".select_hold_all").prop("checked", false);
            $(".cancel_selected_holds").html(MSG_CANCEL_SELECTED.format(0));
            $("#cancelModal")
                .modal("show")
                .find("#cancelModalConfirmBtn")
                .attr("data-id", res_id);
            delete localStorage.selectedHolds;
        });
        $(".cancel_selected_holds").on("click", function (e) {
            e.preventDefault();
            if ($(".holds_table .select_hold:checked").length) {
                delete localStorage.selectedHolds;
                $("#cancelModal").modal("show");
            }
            return false;
        });
        // Remove any previously attached handlers
        $("#cancelModalConfirmBtn").off("click");
        // Attach the handler to the button
        $("#cancelModalConfirmBtn").one("click", function (e) {
            e.preventDefault();
            let hold_ids;
            const hold_id = $("#cancelModal")
                .modal("show")
                .find("#cancelModalConfirmBtn")
                .attr("data-id");
            let reason = $("#modal-cancellation-reason").val();
            if (hold_id) {
                hold_ids = [hold_id];
            } else {
                hold_ids = $(".holds_table .select_hold:checked")
                    .toArray()
                    .map(el => $(el).data("id"));
            }
            $("#cancelModal")
                .find(".modal-footer #cancelModalConfirmBtn")
                .before(
                    '<img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" style="padding-right: 10px;"/>'
                );
            deleteHolds(hold_ids, reason);
            $("#cancelModal")
                .modal("show")
                .find("#cancelModalConfirmBtn")
                .attr("data-id", "");
        });
        async function deleteHolds(hold_ids, reason) {
            for (const hold_id of hold_ids) {
                await deleteHold(hold_id, reason);
                $("#cancelModal")
                    .find(".modal-body")
                    .append(
                        '<p class="hold-cancelled">' +
                            __("Hold") +
                            " " +
                            hold_id +
                            " " +
                            __("cancelled") +
                            "</p>"
                    );
                await new Promise(resolve => setTimeout(resolve, 1000));
            }

            holdsQueueTable.api().ajax.reload(null, false);
            setTimeout(() => {
                $("#cancelModal").modal("hide");
                $("#cancelModal")
                    .find(".modal-footer #cancelModalConfirmBtn")
                    .prev("img")
                    .remove();
                $("#cancelModal")
                    .find(".modal-body")
                    .find(".hold-cancelled")
                    .remove();
            });
        }
        async function deleteHold(hold_id, reason) {
            try {
                await $.ajax({
                    method: "DELETE",
                    url: "/api/v1/holds/" + encodeURIComponent(hold_id),
                    data: JSON.stringify(reason),
                });
            } catch (error) {
                console.error("Error when deleting hold: " + hold_id);
            }
        }
        $(".holddate, .expirationdate").flatpickr({
            onReady: function (selectedDates, dateStr, instance) {
                $(instance.altInput)
                    .wrap("<span class='flatpickr_wrapper'></span>")
                    .after(
                        $("<a/>")
                            .attr("href", "#")
                            .addClass("clear_date")
                            .addClass("fa fa-times")
                            .addClass("ps-2")
                            .on("click", function (e) {
                                e.preventDefault();
                                instance.clear();
                            })
                            .attr("aria-hidden", true)
                    );
            },
            onChange: function (selectedDates, dateStr, instance) {
                let hold_id = $(instance.input).attr("data-id");
                let fieldname = $(instance.input).attr("name");
                let current_date = $(instance.input).attr("data-current-date");
                dateStr = dateStr ? dateStr : null;
                let req =
                    fieldname == "hold_date"
                        ? { hold_date: dateStr }
                        : { expiration_date: dateStr };
                if (current_date != dateStr) {
                    $.ajax({
                        method: "PATCH",
                        url: "/api/v1/holds/" + encodeURIComponent(hold_id),
                        contentType: "application/json",
                        data: JSON.stringify(req),
                        success: function (data) {
                            holdsQueueTable.api().ajax.reload(null, false);
                        },
                        error: function (jqXHR, textStatus, errorThrown) {
                            holdsQueueTable.api().ajax.reload(null, false);
                        },
                    });
                }
            },
        });
        $(".suspenddate").flatpickr({
            onReady: function (selectedDates, dateStr, instance) {
                $(instance.altInput)
                    .wrap("<span class='flatpickr_wrapper'></span>")
                    .after(
                        $("<a/>")
                            .attr("href", "#")
                            .addClass("clear_date")
                            .addClass("fa fa-times")
                            .addClass("ps-2")
                            .on("click", function (e) {
                                e.preventDefault();
                                instance.clear();
                            })
                            .attr("aria-hidden", true)
                    );
            },
        });
        $(".toggle-suspend").one("click", function (e) {
            e.preventDefault();
            const hold_id = $(this).data("id");
            const suspended = $(this).attr("data-suspended");
            const input = $(`.suspenddate[data-id="${hold_id}"]`);
            const method = suspended == "true" ? "DELETE" : "POST";
            let end_date = input.val() && method == "POST" ? input.val() : null;
            let params =
                end_date !== null && end_date !== ""
                    ? JSON.stringify({ end_date: end_date })
                    : null;
            $.ajax({
                method: method,
                url:
                    "/api/v1/holds/" +
                    encodeURIComponent(hold_id) +
                    "/suspension",
                contentType: "application/json",
                data: params,
                success: function (data) {
                    holdsQueueTable.api().ajax.reload(null, false);
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    holdsQueueTable.api().ajax.reload(null, false);
                    alert(
                        "There was an error:" + textStatus + " " + errorThrown
                    );
                },
            });
        });
        $(".rank-request").on("change", function (e) {
            e.preventDefault();
            const hold_id = $(this).data("id");
            let priority = e.target.value;
            $.ajax({
                method: "PUT",
                url:
                    "/api/v1/holds/" +
                    encodeURIComponent(hold_id) +
                    "/priority",
                data: JSON.stringify(priority),
                success: function (data) {
                    holdsQueueTable.api().ajax.reload(null, false);
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert(
                        "There was an error:" + textStatus + " " + errorThrown
                    );
                },
            });
        });
        $(".move-hold").one("click", function (e) {
            e.preventDefault();
            let toPosition = $(this).attr("data-move-hold");
            let priority = $(this).attr("data-priority");
            var res_id = $(this).attr("reserve_id");
            var moveTo;
            if (toPosition == "up") {
                moveTo = parseInt(priority) - 1;
            }
            if (toPosition == "down") {
                moveTo = parseInt(priority) + 1;
            }
            if (toPosition == "top") {
                moveTo = 1;
            }
            if (toPosition == "bottom") {
                moveTo = totalHolds;
            }
            $.ajax({
                method: "PUT",
                url:
                    "/api/v1/holds/" + encodeURIComponent(res_id) + "/priority",
                data: JSON.stringify(moveTo),
                success: function (data) {
                    holdsQueueTable.api().ajax.reload(null, false);
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert(
                        "There was an error:" + textStatus + " " + errorThrown
                    );
                },
            });
        });
        $(".toggle-lowest-priority").one("click", function (e) {
            e.preventDefault();
            var res_id = $(this).attr("data-reserve_id");
            $.ajax({
                method: "PUT",
                url:
                    "/api/v1/holds/" +
                    encodeURIComponent(res_id) +
                    "/lowest_priority",
                success: function (data) {
                    holdsQueueTable.api().ajax.reload(null, false);
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert(
                        "There was an error:" + textStatus + " " + errorThrown
                    );
                },
            });
        });
        $(".hold_location_select").on("change", function () {
            $(this).prop("disabled", true);
            var cur_select = $(this);
            var res_id = $(this).attr("reserve_id");
            $(this).after(
                '<div id="updating_reserveno' +
                    res_id +
                    '" class="waiting"><img src="/intranet-tmpl/prog/img/spinner-small.gif" alt="" /><span class="waiting_msg"></span></div>'
            );
            let api_url =
                "/api/v1/holds/" +
                encodeURIComponent(res_id) +
                "/pickup_location";
            $.ajax({
                method: "PUT",
                url: api_url,
                data: JSON.stringify({ pickup_library_id: $(this).val() }),
                headers: { "x-koha-override": "any" },
                success: function (data) {
                    holdsQueueTable.api().ajax.reload(null, false);
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert(
                        "There was an error:" + textStatus + " " + errorThrown
                    );
                    cur_select.prop("disabled", false);
                    $("#updating_reserveno" + res_id).remove();
                    cur_select.val(
                        cur_select.children('option[selected="selected"]').val()
                    );
                },
            });
        });
        $(".printholdslip").one("click", function () {
            var reserve_id = $(this).attr("data-reserve_id");
            window.open(
                "/cgi-bin/koha/circ/hold-transfer-slip.pl?reserve_id=" +
                    reserve_id
            );
            return false;
        });
    });
}
