[% USE Asset %]
[% USE Koha %]
[% USE raw %]
<!-- calendar.inc -->
[% FILTER collapse %]
<script>
    var debug    = "[% debug | html %]";
    var dateformat_pref = "[% Koha.Preference('dateformat') | html %]";
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
    var sentmsg = 0;
    var dateInputStyle = "[% Koha.Preference('DateInputStyle') | html %]";
    var bidi = [% IF(bidi) %] true[% ELSE %] false[% END %];
    var calendarFirstDayOfWeek = '[% Koha.Preference('CalendarFirstDayOfWeek') | html %]';
    var flatpickr_timeformat_string = [% IF Koha.Preference('TimeFormat') == '12hr' %]"G:i K"[% ELSE %]"H:i"[% END %];
    var flatpickr_timeformat = [% IF Koha.Preference('TimeFormat') == '12hr' %]false[% ELSE %]true[% END %];
</script>
<!-- / calendar.inc -->
[% Asset.js("js/calendar.js") | $raw %]
[% Asset.js("lib/flatpickr/flatpickr.min.js") | $raw %]
[% Asset.js("lib/flatpickr/shortcut-buttons-flatpickr.min.js") | $raw %]
<script>
    flatpickr.l10ns.default.weekdays = flatpickr_weekdays;
    flatpickr.l10ns.default.months   = flatpickr_months;
    let flatpickr_defaults = {
        allowInput: true,
        dateFormat: "Y-m-d",
        altInput: true,
        altFormat: flatpickr_dateformat_string,
        altInputClass: 'flatpickr-input',
        nextArrow: '<i class="fa fa-fw fa-arrow-right"></i>',
        prevArrow: '<i class="fa fa-fw fa-arrow-left"></i>',
        time_24hr: flatpickr_timeformat,
        defaultHour: 23,
        defaultMinute: 59,
        locale: {
            "firstDayOfWeek": calendarFirstDayOfWeek
        },
        onReady: function( selectedDates, dateStr, instance ){

            /* When onReady is triggered, remove any existing "clear date" link */
            $(instance.input).parent().find('.flatpickr_wrapper_' + instance.input.id).remove();

            /* When flatpickr instance is created, automatically append a "clear date" link */
            $(instance.input).find('~input.flatpickr:first')
                /* Add a wrapper element so that we can prevent the clear button from wrapping */
                .wrap("<span class='flatpickr_wrapper flatpickr_wrapper_"+instance.input.id+"'></span>")
                .attr("autocomplete", "off")
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
        onChange: function( selectedDates, dateText, instance) {
            if (selectedDates.length === 0) {
                return;
            }

            var thisInput = instance.input;
            let = accepts_time = $(thisInput).data('flatpickr-enable-time');
            if ( accepts_time ) {
                let parsedDate = flatpickr.parseDate(dateText, instance.config.dateFormat);
                if ( !parsedDate.getHours() ) {
                    instance.setDate(selectedDates[0].setHours(23, 59, 0, 0));
                }
            }
        },
        onClose: function( selectedDates, dateText, instance) {
            validate_date( dateText, instance );
            var thisInput = instance.input;
            if ( thisInput.hasAttribute('data-date_to') ) {
                var endPicker = document.querySelector("#"+thisInput.dataset.date_to)._flatpickr;
                endPicker.set('minDate', selectedDates[0]);
            }

            let = on_close_focus = $(thisInput).data('flatpickr-on-close-focus');
            if ( on_close_focus ) {
                $(on_close_focus).focus();
            }
        },
        plugins: [
          ShortcutButtonsPlugin({
            button: [
              {
                label: _("Yesterday")
              },
              {
                label: _("Today")
              },
              {
                label: _("Tomorrow")
              }
            ],
            label: _("or"),
            onClick: (index, fp) => {
              let date;
              let hh = 23, mm = 59;
              switch (index) {
                case 0:
                  date = new Date().fp_incr(-1);
                  break;
                case 1:
                  date = new Date();
                  if ( $(fp.input).data("flatpickr-pastinclusive") === true ) {
                    hh = date.getHours();
                    mm = date.getMinutes();
                  }
                  break;
                case 2:
                  date = new Date().fp_incr(1);
                  break;
              }
              date.setHours(hh, mm, 0, 0);
              fp.setDate(date);
            }
          })
        ]
    };

    flatpickr.setDefaults(flatpickr_defaults);

    function apply_flatpickr(input){
        let options = {};
        let refresh_max_date = 0;
        let disable_buttons = [];
        let is_time      = $(input).data('flatpickr-enable-time') === true;
        let is_time_only = $(input).data('flatpickr-time-only') === true;
        let is_period    = $(input).data('flatpickr-period');

        if( $(input).data("flatpickr-futureinclusive") === true
         || $(input).data("flatpickr-futuredate") === true ) {
            let original_date = $(input).val();
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
                if( $(input).data("flatpickr-futureinclusive") === true ) {
                    options['minDate'] = new Date().setHours(00, 00, 00, 00);
                } else {
                    options['minDate'] = new Date().fp_incr(1);
                }
            }

            disable_buttons.push(0); /* Yesterday */

            if ( $(input).data("flatpickr-futuredate") === true ) {
                disable_buttons.push(1); /* Today */
            }
        }
        if( $(input).data("flatpickr-pastinclusive") === true ) {
            options['maxDate'] = new Date(); /* Not today or hh:mm will be 00:00 */
            refresh_max_date = 1;
            disable_buttons.push(2); /* Tomorrow */
        }
        if( $(input).data("flatpickr-pastdate") === true ) {
            options['maxDate'] = new Date().fp_incr(-1).setHours(23, 59, 00, 00);
            disable_buttons.push(1); /* Today */
            disable_buttons.push(2); /* Tomorrow */
        }
        if ( $(input).data('flatpickr-enable-time') === true ) {
            options['enableTime'] = true;
            options['dateFormat'] = "Y-m-d H:i";
            options['altFormat'] = flatpickr_dateformat_string + " " + flatpickr_timeformat_string;
        }
        if ( $(input).data('flatpickr-disable-shortcuts') === true ) {
            options['plugins'] = [];
        }
        let maxDate = $(input).data("flatpickr-maxdate");
        if( typeof maxDate !== 'undefined' ) {
            options['maxDate'] = new Date(maxDate);
        }

        let fp;
        if ( dateInputStyle === 'split' && !is_time && !is_time_only && !is_period ) {
            fp = apply_split_date_widget(input, options);
        } else {
            fp = $(input).flatpickr(options);
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
    }

    function apply_split_date_widget(input, fpOptions) {
        let parts_order, sep;
        switch (dateformat_pref) {
            case 'us':    parts_order = ['month', 'day', 'year']; sep = '/'; break;
            case 'iso':
            case 'sql':   parts_order = ['year', 'month', 'day']; sep = '-'; break;
            case 'dmydot': parts_order = ['day', 'month', 'year']; sep = '.'; break;
            default:      parts_order = ['day', 'month', 'year']; sep = '/'; /* metric */
        }
        let labels       = { day: __("Day"),   month: __("Month"), year: __("Year") };
        let placeholders = { day: 'DD',        month: 'MM',        year: 'YYYY'     };
        let autocompletes = { day: 'bday-day', month: 'bday-month', year: 'bday-year' };
        let inputId = input.id || ('fp_split_' + Math.random().toString(36).substr(2, 8));

        let options = Object.assign({}, fpOptions, {
            clickOpens: false,
            onReady: function(selectedDates, dateStr, instance) {
                /* Hide the altInput; our split inputs replace it visually */
                $(instance.altInput)
                    .addClass('sr-only')
                    .attr('tabindex', '-1')
                    .attr('aria-hidden', 'true');

                let $wrapper = $('<div class="date-split-wrapper"></div>')
                    .attr('data-split-for', inputId);

                for (let i = 0; i < parts_order.length; i++) {
                    let part   = parts_order[i];
                    let partId = inputId + '_' + part;
                    let $group = $('<span class="split-part-group"></span>');
                    $group.append(
                        $('<label></label>').attr('for', partId).text(labels[part])
                    );
                    $group.append(
                        $('<input type="text" inputmode="numeric" pattern="[0-9]*">')
                            .attr('id', partId)
                            .attr('maxlength', part === 'year' ? 4 : 2)
                            .attr('placeholder', placeholders[part])
                            .attr('autocomplete', autocompletes[part])
                            .addClass('split-part split-' + part)
                    );
                    $wrapper.append($group);
                    if (i < parts_order.length - 1) {
                        $wrapper.append(
                            $('<span class="split-sep" aria-hidden="true"></span>').text(sep)
                        );
                    }
                }

                let $calBtn = $('<a href="#" class="split-calendar-btn"></a>')
                    .attr('title', __("Open calendar"))
                    .attr('aria-label', __("Open calendar"))
                    .attr('aria-hidden', 'true');
                let $clearBtn = $('<a href="#" class="clear_date split-clear-btn fa fa-fw fa-times"></a>')
                    .attr('aria-label', __("Clear date"))
                    .attr('aria-hidden', 'true');
                $wrapper.append($calBtn).append($clearBtn);

                $(instance.altInput).after($wrapper);

                /* Populate split inputs from the current ISO value (edit mode) */
                let val = $(input).val();
                if (val && /^\d{4}-\d{2}-\d{2}$/.test(val)) {
                    let p = val.split('-');
                    $wrapper.find('.split-year').val(p[0]);
                    $wrapper.find('.split-month').val(p[1]);
                    $wrapper.find('.split-day').val(p[2]);
                }

                let syncing = false;

                /* Split inputs -> flatpickr ISO */
                $wrapper.on('input', '.split-part', function() {
                    let d = $wrapper.find('.split-day').val().trim();
                    let m = $wrapper.find('.split-month').val().trim();
                    let y = $wrapper.find('.split-year').val().trim();
                    syncing = true;
                    if (d && m && y && y.length === 4) {
                        instance.setDate(y + '-' + m.padStart(2, '0') + '-' + d.padStart(2, '0'), false);
                    } else {
                        instance.clear(false);
                        $(input).val('');
                    }
                    $(input).trigger('change');
                    syncing = false;
                });

                /* Auto-advance from day/month after 2 digits (skip on delete/backspace) */
                $wrapper.on('input', '.split-day, .split-month', function(e) {
                    let inputType = e.originalEvent && e.originalEvent.inputType;
                    if ($(this).val().length >= 2 && inputType && !inputType.startsWith('delete')) {
                        let $parts = $wrapper.find('.split-part');
                        let idx = $parts.index(this);
                        if (idx < $parts.length - 1) {
                            $parts.eq(idx + 1).focus().select();
                        }
                    }
                });

                /* Calendar date selected -> populate split inputs */
                $(input).on('change', function() {
                    if (syncing) return;
                    let v = $(input).val();
                    if (v && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
                        let p = v.split('-');
                        $wrapper.find('.split-year').val(p[0]);
                        $wrapper.find('.split-month').val(p[1]);
                        $wrapper.find('.split-day').val(p[2]);
                    } else {
                        $wrapper.find('.split-year, .split-month, .split-day').val('');
                    }
                });

                /* Calendar button opens the flatpickr calendar */
                $calBtn.on('click', function(e) {
                    e.preventDefault();
                    instance.open();
                });

                /* Clear button clears all split inputs and the flatpickr value */
                $clearBtn.on('click', function(e) {
                    e.preventDefault();
                    syncing = true;
                    instance.clear();
                    $(input).val('');
                    $wrapper.find('.split-year, .split-month, .split-day').val('');
                    syncing = false;
                });
            }
        });

        return $(input).flatpickr(options);
    }

    function validateSplitDateInputs() {
        let valid = true;
        $('.date-split-wrapper').each(function() {
            let $wrapper  = $(this);
            let origId    = $wrapper.data('split-for');
            let $orig     = origId ? $('#' + origId) : null;
            let isRequired = $orig && $orig.is('[required]');
            let d = $wrapper.find('.split-day').val().trim();
            let m = $wrapper.find('.split-month').val().trim();
            let y = $wrapper.find('.split-year').val().trim();
            let anyFilled = d || m || y;
            let allFilled = d && m && y && y.length === 4;

            if (isRequired && !allFilled) {
                alert(__("Please enter a complete date."));
                $wrapper.find('.split-part').first().focus();
                valid = false;
                return false;
            }
            if (anyFilled && !allFilled) {
                alert(__("Please complete all parts of the date field."));
                $wrapper.find('.split-part').first().focus();
                valid = false;
                return false;
            }
            if (allFilled) {
                let dt = new Date(parseInt(y, 10), parseInt(m, 10) - 1, parseInt(d, 10));
                if ( dt.getFullYear() !== parseInt(y, 10)
                    || dt.getMonth()    !== parseInt(m, 10) - 1
                    || dt.getDate()     !== parseInt(d, 10) ) {
                    alert(__("Please enter a valid date."));
                    $wrapper.find('.split-part').first().focus();
                    valid = false;
                    return false;
                }
            }
        });
        return valid;
    }

    $(document).ready(function(){
        $(".flatpickr").each(function(){
            apply_flatpickr(this);
        });
    });
</script>
[% END %]
