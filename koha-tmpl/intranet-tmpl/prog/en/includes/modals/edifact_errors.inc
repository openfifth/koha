[%# EDIFACT errors modal %]
[%# This modal provides EDIFACT interchange parsing error display %]
[%# Usage: INCLUDE 'modals/edifact_errors.inc' modal_id='custom_errors_modal' modal_size='lg' %]
[%# Requires: Asset.js("js/modals/edifact_errors.js") %]

[%# Set defaults if not provided %]
[% UNLESS modal_id %][% modal_id = 'EDI_errors_modal' %][% END %]
[% UNLESS modal_size %][% modal_size = 'lg' %][% END %]
[% UNLESS modal_title %][% modal_title = 'EDIFACT processing errors for' %][% END %]

<!-- Modal to display EDIFACT errors -->
<div class="modal fade" id="[% modal_id | html %]" tabindex="-1" role="dialog" aria-labelledby="[% modal_id | html %]_label" aria-hidden="true">
    <div class="modal-dialog modal-[% modal_size | html %]">
        <div class="modal-content">
            <div class="modal-header">
                <h1 class="modal-title" id="[% modal_id | html %]_label"> [% modal_title | html %] <span class="filename"></span> </h1>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="edi-loading">
                    <img src="[% interface | html %]/[% theme | html %]/img/spinner-small.gif" alt="" />
                    [% t("Loading errors...") | html %]
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-primary" data-bs-dismiss="modal">[% t("Close") | html %]</button>
            </div>
        </div>
    </div>
</div>
