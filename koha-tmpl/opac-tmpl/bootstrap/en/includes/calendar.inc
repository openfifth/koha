[% USE Asset %]
[% USE Koha %]
[% USE raw %]
<script>
    var flatpickr_weekdays = {
        shorthand: [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
        longhand: [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ]
    };

    var flatpickr_months = {
        shorthand: [ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
        longhand: [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    };
    var debug    = "[% debug | html %]";
    var dateformat_pref = "[% Koha.Preference('dateformat') | html %]";
    var sentmsg = 0;
    if (debug > 1) {alert("dateformat: " + dateformat_pref + "\ndebug is on (level " + debug + ")");}
    var calendarFirstDayOfWeek = '[% Koha.Preference('CalendarFirstDayOfWeek') | html %]';
    var flatpickr_timeformat_string = [% IF Koha.Preference('TimeFormat') == '12hr' %]"G:i K"[% ELSE %]"H:i"[% END %];
    var flatpickr_timeformat = [% IF Koha.Preference('TimeFormat') == '12hr' %]false[% ELSE %]true[% END %];
    var flatpickr_dateformat_string = "";
    switch ( dateformat_pref ){
        case "us":
            flatpickr_dateformat_string = "m/d/Y";
            break;
        case "metric":
            flatpickr_dateformat_string = "d/m/Y";
            break;
        case "dmydot":
            flatpickr_dateformat_string = "d.m.Y";
            break;
        default:
            flatpickr_dateformat_string = "Y-m-d";
    }

    function get_dateformat_str(dateformat) {
        var dateformat_str;
        if (dateformat == 'us') {
            dateformat_str = 'mm/dd/yyyy';
        } else if (dateformat == 'metric') {
            dateformat_str = 'dd/mm/yyyy';
        } else if (dateformat == 'iso') {
            dateformat_str = 'yyyy-mm-dd';
        } else if (dateformat == 'dmydot') {
            dateformat_str = 'dd.mm.yyyy';
        }
        return dateformat_str;
    }
</script>
[% Asset.js("lib/flatpickr/flatpickr.min.js") | $raw %]
<script>
    flatpickr.l10ns.default.weekdays = flatpickr_weekdays;
    flatpickr.l10ns.default.months   = flatpickr_months;
    flatpickr.setDefaults({
        dateFormat: "Y-m-d",
        altInput: true,
        allowInput: true,
        altFormat: flatpickr_dateformat_string,
        altInputClass: 'flatpickr-input',
        nextArrow: '<i class="fa fa-fw fa-arrow-right" aria-hidden="true"></i>',
        prevArrow: '<i class="fa fa-fw fa-arrow-left" aria-hidden="true"></i>',
        time_24hr: flatpickr_timeformat,
        locale: {
            "firstDayOfWeek": calendarFirstDayOfWeek
        },
        onReady: function( selectedDates, dateStr, instance ){
            /* When flatpickr instance is created, automatically append a "clear date" link */
            if( $(instance.input).hasClass("futuredate") ){
                instance.set("minDate", new Date().fp_incr(1));
            }
            if( $(instance.input).hasClass("pastdate") ){
                instance.set("maxDate", new Date().fp_incr(-1));
            }
            $(instance.input).find('~input.flatpickr:first')
                /* Add a wrapper element so that we can prevent the clear button from wrapping */
                .wrap("<span class='flatpickr_wrapper'></span>")
                .after( $("<a/>")
                    .attr("href","#")
                    .addClass("clear_date")
                    .on("click", function(e){
                        e.preventDefault();
                        instance.clear();
                    })
                    .addClass("fa fa-fw fa-times")
                    .attr("aria-hidden", true)
                    .attr("aria-label", _("Clear date") )
                ).keydown(function(e) {
                    var key = (event.keyCode ? event.keyCode : event.which);
                    if ( key == 40 ) {
                        instance.set('allowInput',false);
                    }
                });
        },
        onClose: function( selectedDates, dateText, instance) {
            validate_date( dateText, instance );
            var thisInput = instance.input;
            if ( thisInput.hasAttribute('data-start_for') ) {
                var endPicker = document.querySelector("#"+thisInput.dataset.start_for)._flatpickr;
                endPicker.set('minDate', selectedDates[0]);
            }
        },
    });

    var MSG_PLEASE_ENTER_A_VALID_DATE = ( _("Please enter a valid date (should match %s).") );

    function is_valid_date(date) {
        // An empty string is considered as a valid date for convenient reasons.
        if (date === '') return 1;
        var dateformat = flatpickr_dateformat_string;
        switch ( dateformat_pref ){
            case "us":
                flatpickr_dateformat_string = "m/d/Y";
                break;
            case "metric":
                flatpickr_dateformat_string = "d/m/Y";
                break;
            case "dmydot":
                flatpickr_dateformat_string = "d.m.Y";
                break;
            default:
                flatpickr_dateformat_string = "Y-m-d";
        }
        try {
            flatpickr.parseDate(date, dateformat);
        } catch (e) {
            return 0;
        }
        return 1;
    }

    function validate_date(dateText, inst) {
        if (!is_valid_date(dateText)) {
            var dateformat_str = get_dateformat_str( dateformat_pref );
            alert(MSG_PLEASE_ENTER_A_VALID_DATE.format(dateformat_str));
            inst.clear();
        }
    }

    function apply_split_date_widget(input, fpOptions) {
        let parts_order, sep;
        switch (dateformat_pref) {
            case "us":
                parts_order = ["month", "day", "year"];
                sep = "/";
                break;
            case "iso":
            case "sql":
                parts_order = ["year", "month", "day"];
                sep = "-";
                break;
            case "dmydot":
                parts_order = ["day", "month", "year"];
                sep = ".";
                break;
            default:
                parts_order = ["day", "month", "year"];
                sep = "/"; // metric
        }
        let labels = { day: _("Day"), month: _("Month"), year: _("Year") };
        let placeholders = { day: "DD", month: "MM", year: "YYYY" };
        let autocompletes = { day: "bday-day", month: "bday-month", year: "bday-year" };
        let inputId = input.id || "fp_split_" + Math.random().toString(36).substr(2, 8);

        let options = Object.assign({}, fpOptions, {
            clickOpens: false,
            onReady: function (selectedDates, dateStr, instance) {
                // Handle pastdate / futuredate CSS classes (normally in default onReady)
                if ($(instance.input).hasClass("pastdate")) {
                    instance.set("maxDate", new Date().fp_incr(-1));
                }
                if ($(instance.input).hasClass("futuredate")) {
                    instance.set("minDate", new Date().fp_incr(1));
                }

                // Hide the altInput; our split inputs replace it visually
                $(instance.altInput).addClass("sr-only").attr("tabindex", "-1").attr("aria-hidden", "true");

                let $wrapper = $('<div class="date-split-wrapper"></div>').attr("data-split-for", inputId);

                for (let i = 0; i < parts_order.length; i++) {
                    let part = parts_order[i];
                    let partId = inputId + "_" + part;
                    let $group = $('<span class="split-part-group"></span>');
                    $group.append($("<label></label>").attr("for", partId).text(labels[part]));
                    $group.append(
                        $('<input type="text" inputmode="numeric" pattern="[0-9]*">')
                            .attr("id", partId)
                            .attr("maxlength", part === "year" ? 4 : 2)
                            .attr("placeholder", placeholders[part])
                            .attr("autocomplete", autocompletes[part])
                            .addClass("split-part split-" + part)
                    );
                    $wrapper.append($group);
                    if (i < parts_order.length - 1) {
                        $wrapper.append($('<span class="split-sep" aria-hidden="true"></span>').text(sep));
                    }
                }

                let $calBtn = $('<a href="#" class="split-calendar-btn"></a>').attr("title", _("Open calendar")).attr("aria-label", _("Open calendar")).attr("aria-hidden", "true");
                let $clearBtn = $('<a href="#" class="clear_date split-clear-btn fa fa-fw fa-times"></a>').attr("aria-label", _("Clear date")).attr("aria-hidden", "true");
                $wrapper.append($calBtn).append($clearBtn);

                $(instance.altInput).after($wrapper);

                // Populate split inputs from the current ISO value (edit mode)
                let val = $(input).val();
                if (val && /^\d{4}-\d{2}-\d{2}$/.test(val)) {
                    let p = val.split("-");
                    $wrapper.find(".split-year").val(p[0]);
                    $wrapper.find(".split-month").val(p[1]);
                    $wrapper.find(".split-day").val(p[2]);
                }

                let syncing = false;

                // Split inputs → flatpickr ISO
                $wrapper.on("input", ".split-part", function () {
                    let d = $wrapper.find(".split-day").val().trim();
                    let m = $wrapper.find(".split-month").val().trim();
                    let y = $wrapper.find(".split-year").val().trim();
                    syncing = true;
                    if (d && m && y && y.length === 4) {
                        instance.setDate(y + "-" + m.padStart(2, "0") + "-" + d.padStart(2, "0"), false);
                    } else {
                        instance.clear(false);
                        $(input).val("");
                    }
                    $(input).trigger("change");
                    syncing = false;
                });

                // Auto-advance from day/month after 2 digits (skip on delete/backspace)
                $wrapper.on("input", ".split-day, .split-month", function (e) {
                    let inputType = e.originalEvent && e.originalEvent.inputType;
                    if ($(this).val().length >= 2 && inputType && !inputType.startsWith("delete")) {
                        let $parts = $wrapper.find(".split-part");
                        let idx = $parts.index(this);
                        if (idx < $parts.length - 1) {
                            $parts
                                .eq(idx + 1)
                                .focus()
                                .select();
                        }
                    }
                });

                // Calendar date selected → populate split inputs
                $(input).on("change", function () {
                    if (syncing) return;
                    let v = $(input).val();
                    if (v && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
                        let p = v.split("-");
                        $wrapper.find(".split-year").val(p[0]);
                        $wrapper.find(".split-month").val(p[1]);
                        $wrapper.find(".split-day").val(p[2]);
                    } else {
                        $wrapper.find(".split-year, .split-month, .split-day").val("");
                    }
                });

                // Calendar button opens the flatpickr calendar
                $calBtn.on("click", function (e) {
                    e.preventDefault();
                    instance.open();
                });

                // Clear button clears all split inputs and the flatpickr value
                $clearBtn.on("click", function (e) {
                    e.preventDefault();
                    syncing = true;
                    instance.clear();
                    $(input).val("");
                    $wrapper.find(".split-year, .split-month, .split-day").val("");
                    syncing = false;
                });
            },
        });

        return $(input).flatpickr(options);
    }

    function validateSplitDateInputs() {
        let valid = true;
        $(".date-split-wrapper").each(function () {
            let $wrapper = $(this);
            let origId = $wrapper.data("split-for");
            let $orig = origId ? $("#" + origId) : null;
            let isRequired = $orig && $orig.is("[required]");
            let d = $wrapper.find(".split-day").val().trim();
            let m = $wrapper.find(".split-month").val().trim();
            let y = $wrapper.find(".split-year").val().trim();
            let anyFilled = d || m || y;
            let allFilled = d && m && y && y.length === 4;

            if (isRequired && !allFilled) {
                alert(_("Please enter a complete date."));
                $wrapper.find(".split-part").first().focus();
                valid = false;
                return false;
            }
            if (anyFilled && !allFilled) {
                alert(_("Please complete all parts of the date field."));
                $wrapper.find(".split-part").first().focus();
                valid = false;
                return false;
            }
            if (allFilled) {
                let dt = new Date(parseInt(y, 10), parseInt(m, 10) - 1, parseInt(d, 10));
                if (dt.getFullYear() !== parseInt(y, 10) || dt.getMonth() !== parseInt(m, 10) - 1 || dt.getDate() !== parseInt(d, 10)) {
                    alert(_("Please enter a valid date."));
                    $wrapper.find(".split-part").first().focus();
                    valid = false;
                    return false;
                }
            }
        });
        return valid;
    }

        $(document).ready(function(){
            $(".flatpickr").each(function(){
                let options = {};
                let refresh_max_date = 0;
                let disable_buttons = [];
                let is_time = $(this).data("flatpickr-enable-time") === true;
                let is_period = $(this).data("flatpickr-period");

                if( $(this).data("flatpickr-futureinclusive") === true
                 || $(this).data("flatpickr-futuredate") === true ) {
                    let original_date = $(this).val();
                    if ( original_date ) {
                        original_date = flatpickr.parseDate(original_date, 'Y-m-d').getTime();
                        let tomorrow = new Date().fp_incr(1).getTime();

                        options['enable'] = [function(date){
                            date = date.getTime();
                            if ( date == original_date ) return true;
                            if ( date >= tomorrow)       return true;
                        }];
                    }
                    else {
                        if( $(this).data("flatpickr-futureinclusive") === true ) {
                            options['minDate'] = new Date().setHours(00, 00, 00, 00);
                        } else {
                            options['minDate'] = new Date().fp_incr(1);
                        }
                    }

                    disable_buttons.push(0); /* Yesterday */

                    if ( $(this).data("flatpickr-futuredate") === true ) {
                        disable_buttons.push(1); /* Today */
                    }
                }
                if( $(this).data("flatpickr-pastinclusive") === true ) {
                    options['maxDate'] = new Date(); /* Not today or hh:mm will be 00:00 */
                    refresh_max_date = 1;
                    disable_buttons.push(2); /* Tomorrow */
                }
                if( $(this).data("flatpickr-pastdate") === true ) {
                    options['maxDate'] = new Date().fp_incr(-1).setHours(23, 59, 00, 00);
                    disable_buttons.push(1); /* Today */
                    disable_buttons.push(2); /* Tomorrow */
                }
                if ( $(this).data('flatpickr-enable-time') === true ) {
                    options['enableTime'] = true;
                    options['dateFormat'] = flatpickr_dateformat_string + " " + flatpickr_timeformat_string;
                }

                let fp;
                if ($(this).data("flatpickr-split") && !is_time && !is_period) {
                    fp = apply_split_date_widget(this, options);
                } else {
                    fp = $(this).flatpickr(options);
                }

                $(disable_buttons).each(function(index, value){
                    $(fp.calendarContainer).find(".shortcut-buttons-flatpickr-button[data-index='"+value+"']").prop("disabled", "disabled");
                });

                if ( refresh_max_date ) {
                    /* Refresh the maxDate every 30 secondes to make sure the user will not
                       be stuck with the minute passed.
                       Adding 1 minute to not introduce a gap.
                       Example: last update at 40s, a new minute passed at 00.
                       Between 00 and 10s the user won't be able click 'Today'.
                    */
                    setInterval(() => {
                        let now = new Date();
                        fp.set("maxDate", now.setMinutes(now.getMinutes() + 1));
                    }, 30000);
                }
            });
        });

</script>
