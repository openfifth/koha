[% IF whole.error %]
    <p>Unhandled error</p>
[% END %]

[% IF whole.stage == "complete" %]
    <h2>Complete request</h2>
    <p>Proceeding with this action will set this request to 'Completed'.</p>
    <p>You can select a status alias from the available options:</p>
    <p>
        [% base_url = "/cgi-bin/koha/ill/ill-requests.pl" %]
        [% proceed_url = base_url _ "?method=mark_completed&stage=complete" _ "&illrequest_id=" _ request.illrequest_id %]
        <form action="[% proceed_url | url %]" method="get">
            <select name="status_alias">
                <option value="" selected></option>
                [% FOREACH alias IN AuthorisedValues.Get('ILL_STATUS_ALIAS') %]
                    <option value="[% alias.authorised_value | html %]" > [% alias.lib | html %] </option>
                [% END %]
            </select>
            <input type="hidden" name="method" value="mark_completed">
            <input type="hidden" name="stage" value="complete">
            <input type="hidden" name="illrequest_id" value="[% request.illrequest_id %]">
            <fieldset class="action">
                <button type="submit" class="btn btn-sm btn-primary">Complete request</button>
                <a class="btn btn-sm btn-default cancel" href="[% base_url | url %]">Cancel</a>
            </fieldset>
        </form>
    </p>
[% ELSE %]
    <p>Unknown stage. This should not have happened. </p>
[% END %]

