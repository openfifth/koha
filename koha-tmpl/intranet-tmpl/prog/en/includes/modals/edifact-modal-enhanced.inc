[%# Enhanced EDIFACT message modal include %]
[%# This modal provides configurable EDIFACT message display %]
[%# Usage: INCLUDE 'modals/edifact-modal-enhanced.inc' modal_id='custom_modal' modal_size='xl' %]

[%# Set defaults if not provided %]
[% UNLESS modal_id %][% modal_id = 'EDI_modal' %][% END %]
[% UNLESS modal_size %][% modal_size = 'lg' %][% END %]
[% UNLESS modal_title %][% modal_title = 'EDIFACT message' %][% END %]
[% UNLESS show_actions.defined %][% show_actions = 1 %][% END %]

<!-- Modal to display EDIFACT messages -->
<div class="modal fade" id="[% modal_id | html %]" tabindex="-1" role="dialog" aria-labelledby="[% modal_id | html %]_label" aria-hidden="true">
    <div class="modal-dialog modal-[% modal_size | html %]">
        <div class="modal-content">
            <div class="modal-header">
                <h1 class="modal-title" id="[% modal_id | html %]_label">[% modal_title | html %]</h1>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="edi-loading">
                    <img src="[% interface | html %]/[% theme | html %]/img/spinner-small.gif" alt="" />
                    [% t("Loading EDIFACT message...") | html %]
                </div>
            </div>
            [% IF show_actions %]
                <div class="modal-footer">
                    <button type="button" class="btn btn-primary" data-bs-dismiss="modal">[% t("Close") | html %]</button>
                </div>
            [% END %]
        </div>
    </div>
</div>

[%# Optional: Include errors modal if needed %]
[% IF include_errors_modal %]
    <!-- Modal to display EDIFACT errors -->
    <div class="modal fade" id="[% modal_id | html %]_errors" tabindex="-1" role="dialog" aria-labelledby="[% modal_id | html %]_errors_label" aria-hidden="true">
        <div class="modal-dialog modal-[% modal_size | html %]">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" id="[% modal_id | html %]_errors_label"> [% t("EDIFACT processing errors for") | html %] <span class="filename"></span> </h1>
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
[% END %]
<script>
    // Initialize modal-specific functionality with plain JavaScript
    (function() {
        function initializeModal() {
            var modalId = '[% modal_id | html %]';
            var modal = document.getElementById(modalId.replace('#', ''));

            if (!modal) return;

            // Download functionality removed

            // Store message ID when modal is shown
            modal.addEventListener('show.bs.modal', function(event) {
                var button = event.relatedTarget;
                var messageId = button ? button.getAttribute('data-message-id') : null;
                if (messageId) {
                    modal.setAttribute('data-current-message-id', messageId);
                }
            });
        }

        // Initialize when DOM is ready or jQuery is available
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', initializeModal);
        } else {
            initializeModal();
        }

        // Also initialize when jQuery becomes available (fallback)
        if (typeof $ !== 'undefined') {
            $(document).ready(initializeModal);
        }
    })();
</script>
