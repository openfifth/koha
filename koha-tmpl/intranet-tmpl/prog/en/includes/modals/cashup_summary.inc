[% USE raw %]
[% USE To %]
[% PROCESS 'accounts.inc' %]
[%# Build a code -> translated label lookup by reusing accounts.inc's own
    debit_type_description / credit_type_description blocks. Known system
    types (OVERDUE, RESERVE, RENT...) render their hardcoded, translated
    label, the same one shown everywhere else in Koha; anything else falls
    through to that type's own (untranslated) stored description, exactly
    as accounts.inc already does. This is used client-side as a fallback
    when the API's own description for a type is missing (e.g. a system
    type predating Bug 26403, whose description was never backfilled). #%]
[% SET type_descriptions = {} %]
[% FOREACH dt IN all_debit_types %]
    [% SET code = dt.code %]
    [% label = BLOCK %][% PROCESS debit_type_description debit_type = dt %][% END %]
    [% SET type_descriptions.$code = label.remove('<[^>]+>').trim %]
[% END %]
[% FOREACH ct IN all_credit_types %]
    [% SET code = ct.code %]
    [% label = BLOCK %][% PROCESS credit_type_description credit_type = ct %][% END %]
    [% SET type_descriptions.$code = label.remove('<[^>]+>').trim %]
[% END %]
<!-- Cashup summary modal -->
<div class="modal printable" id="cashupSummaryModal" tabindex="-1" role="dialog" aria-labelledby="cashupSummaryLabel" data-type-descriptions="[% To.json(type_descriptions) | html %]">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h1 class="modal-title" id="cashupSummaryLabel">Cashup summary</h1>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <ul>
                    <li>Cash register: <span id="register_description"></span></li>
                    <li>Period: <span id="from_date"></span> to <span id="to_date"></span></li>
                </ul>

                <table class="table table-striped">
                    <thead>
                        <tr>
                            <th>Type</th>
                            <th>Total</th>
                        </tr>
                    </thead>
                    <tbody> </tbody>
                    <tfoot> </tfoot>
                </table>

                <style nonce="[% Koha.CSPNonce | $raw %]">
                    #cashupSummaryModal .reconciliation-separator hr {
                        margin: 0.5rem 0;
                        border-color: #dee2e6;
                    }

                    #cashupSummaryModal .reconciliation-info {
                        background-color: #f8f9fa;
                    }

                    #cashupSummaryModal .reconciliation-result.text-warning {
                        background-color: #fff3cd;
                        color: #856404;
                    }

                    #cashupSummaryModal .reconciliation-result.text-danger {
                        background-color: #f8d7da;
                        color: #721c24;
                    }

                    #cashupSummaryModal .total-row {
                        border-top: 2px solid #dee2e6;
                    }
                </style>
            </div>
            <!-- /.modal-body -->
            <div class="modal-footer">
                <button type="button" class="printModal btn btn-primary"><i class="fa fa-print"></i> Print</button>
                <button type="button" class="btn btn-default" data-bs-dismiss="modal">Close</button>
            </div>
            <!-- /.modal-footer -->
        </div>
        <!-- /.modal-content -->
    </div>
    <!-- /.modal-dialog -->
</div>
<!-- /#cashupSummaryModal -->
