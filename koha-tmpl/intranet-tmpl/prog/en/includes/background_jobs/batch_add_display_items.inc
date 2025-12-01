[% USE Koha %]

[% BLOCK report %]
    [% SET report = job.report %]
    [% IF report %]
        [% IF job.status == 'finished' %]
            [% IF report.total_errors > 0 %]
                <div class="alert alert-alert"> Processed [% report.total_success | html %] of [% report.total_records | html %] with [% report.total_errors | html %] errors</div>
            [% ELSE %]
                <div class="alert alert-success"> Processed [% report.total_success | html %] of [% report.total_records | html %]</div>
            [% END %]
        [% ELSIF job.status == 'cancelled' %]
            <span> The job has been cancelled before it finished.</span>
        [% END %]
    [% END %]
[% END %]

[% BLOCK detail %]
    [% SET messages = job.messages %]
    [% IF messages && (messages.size > 0) %]
        <h4>Messages</h4>
        <table>
            <tr>
                <th>Type</th>
                <th>Code</th>
                <th>Error</th>
            </tr>
            [% FOR message IN messages %]
                <tr>
                    <td>[% message.type | html %]</td>
                    <td>[% message.code | html %]</td>
                    <td>[% message.error | html %]</td>
                </tr>
            [% END %]
        </table>
    [% END %]
    [% SET report = job.report %]
    [% IF report %]
        [% IF (report.added_items.size > 0) %]
            <h4>Added items</h4>
            <table>
                <tr>
                    <th>Item barcode</th>
                    <th>Display number</th>
                </tr>
                [% FOR added_item IN report.added_items %]
                    <tr>
                        <td><a href="/cgi-bin/koha/catalogue/moredetail.pl?itemnumber=[% added_item.itemnumber | url %]">[% added_item.barcode | html %]</a></td>
                        <td><a href="/cgi-bin/koha/display/displays/[% report.display_id | url %]">[% report.display_name | html %]</a></td>
                    </tr>
                [% END %]
            </table>
        [% END %]
        [% IF (report.failed_items.size > 0) %]
            <h4>Failed items</h4>
            <table>
                <tr>
                    <th>Item barcode</th>
                    <th>Error message</th>
                </tr>
                [% FOR failed_item IN report.failed_items %]
                    <tr>
                        <td><a href="/cgi-bin/koha/catalogue/moredetail.pl?itemnumber=[% failed_item.itemnumber | url %]">[% failed_item.barcode | html %]</a></td>
                        <td>[% failed_item.error | html %]</td>
                    </tr>
                [% END %]
            </table>
        [% END %]
    [% END %]
    [% IF job.status == 'cancelled' %]
        <span> The job has been cancelled before it finished.</span>
    [% END %]
[% END %]

[% BLOCK js %]
[% END %]
