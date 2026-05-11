[% USE raw %]
[% USE Asset %]
[% Asset.css("css/humanmsg.css") | $raw %]
[% Asset.js("lib/jquery/plugins/humanmsg.js") | $raw %]
[% Asset.js("js/ajax.js") | $raw %]
[% Asset.js("js/form-completer.js") | $raw %]
<script type="text/javascript">
    //<![CDATA[
    var MSG_FETCHING_BORROWER_DATA = _("Fetching borrower data ...");
    var MSG_BAD_REQUEST = _("Bad request");
    var MSG_UNAUTHORIZED = _("Authentication required, log in and try again");
    var MSG_FORBIDDEN = _("You lack permissions for this operation");
    var MSG_NOT_FOUND = _("The resource was not found");
    var MSG_SERVICE_UNAVAILABLE = _("The service is currently unavailable, try again later");
    var MSG_INTERNAL_SERVER_ERROR = _("Internal server error");
    //]]>
    $(document).ready(function () {
        new FormCompleter({
            modal: "#fetch-borrower-data-modal",
            form_id: ["entryform", "quick_add_form"],
            url: "/api/v1/borrower_completion",
            fetch_msg: MSG_FETCHING_BORROWER_DATA,
            id_field: {
                name: "patron_attr_",
                attrname: "PERSNUMMER",
            },
        });
    });
</script>
<form>
    <div id="fetch-borrower-data-modal" class="modal fade" tabindex="-1" role="dialog">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h4 class="modal-title">Fetch borrower data</h4>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                </div>
                <div class="modal-body">
                    <div>
                        <label for="recipient-name" class="control-label">Personal number:</label>
                        <input
                            type="text"
                            class="form-control"
                            id="personal-number"
                            required
                            pattern="(\d{10})|(\d{12})|(\d{6}-\d{4})|(\d{8}-\d{4})"
                            title="A valid personal number (yymmdd-xxxx, yyyymmdd-xxxx, yymmddxxxx, or yyyymmddxxxx)."
                        />
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-default" data-bs-dismiss="modal">Close</button>
                    <button type="button" class="btn btn-primary">Fetch borrower data</button>
                </div> </div
            ><!-- /.modal-content --> </div
        ><!-- /.modal-dialog --> </div
    ><!-- /.modal -->
</form>
