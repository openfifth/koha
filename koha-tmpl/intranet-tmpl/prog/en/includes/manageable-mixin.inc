[% BLOCK select_manager_show %]
    [% borrowerlink = "/cgi-bin/koha/members/moremember.pl" _ "?borrowernumber=" _ manager.borrowernumber %]
    [% IF display == 'fieldset' %]
        <li class="managedby">
            <span class="label managedby">Managed by:</span>
            [% IF manager %]
                <a href="[% borrowerlink | url %]" title="View manager details"> [% manager.firstname _ " " _ manager.surname _ " [" _ manager.cardnumber _ "]" | html %] </a>
            [% ELSE %]
                Nobody
            [% END %]
        </li>
    [% ELSIF display == 'table' %]
        <tr>
            <th>Managed by:</th>
            <td>[% manageddate | $KohaDates %]</td>
            <td>
                [% IF ( manager.borrowernumber ) %]
                    <a href="[% borrowerlink | url %]">[% manager.surname | html %], [% manager.firstname | html %] ([% manager.cardnumber | html %])</a>
                    [% Branches.GetName( manager.branchcode ) | html %] ([% manager.category.description | html %])
                [% END %]
            </td>
        </tr>
    [% ELSE %]
        <!-- Fallback for unknown display -->
        <p>Error: Unknown display "[% display | html %]".</p>
    [% END %]
[% END %]

[% BLOCK select_manager_form %]
    <li>
        <label for="managedby_name">Managed by:</label>
        <div>
            <span id="managedby_name" name="managedby_name">
                [% IF required_permission %]
                    <a href="/cgi-bin/koha/members/moremember.pl?borrowernumber=[% logged_in_user.borrowernumber | uri %]">You</a>
                [% ELSE %]
                    Nobody
                [% END %]
            </span>
            [% IF manager.borrowernumber && logged_in_user.borrowernumber != manager.borrowernumber %]
                | Previously was [% INCLUDE 'patron-title.inc' patron=manager hide_patron_infos_if_needed=1 %] [% Branches.GetName( manager.branchcode ) | html %] ([% manager.category.description | html %])
            [% END %]
            <br />
            <label>&nbsp;</label>
            [% PROCESS select_manager_button %]
            [% IF manager.borrowernumber && logged_in_user.borrowernumber != manager.borrowernumber %]
                <a class="btn btn-default btn-xs" id="restore_previous_manager" href="#"><i class="fa fa-trash-can"></i> Keep existing manager</a>
            [% END %]
            [% IF required_permission %]
                <input type="hidden" name="managedby" id="managedby" value="[% logged_in_user.borrowernumber | html %]" />
            [% END %]

            <br />
            [% IF notify_option %]
                <label for="notify">Notify manager:</label>
                <input
                    type="checkbox"
                    id="notify"
                    name="notify"
                    value="notify"
                    disabled="disabled"
                    title="A NOTIFY_MANAGER notice will be generated and send to the manager if a valid email address is defined. This can be checked if a new manager has been selected."
                />
            [% END %]
        </div>
    </li>
[% END %]

[% BLOCK select_manager_button %]
    [% IF href %]
        [% hash_href_val = href %]
    [% ELSE %]
        [% hash_href_val = 'patron_search_modal_manager' %]
    [% END %]
    [% IF id %]
        [% id_val = id %]
    [% ELSE %]
        [% id_val = 'edit_manager' %]
    [% END %]
    [% IF data_tab %]
        [% id_val = id %]
    [% ELSE %]
        [% id_val = 'edit_manager' %]
    [% END %]
    <a
        href="#[% hash_href_val | uri %]"
        id="[% id_val | uri %]"
        data-bs-toggle="modal"
        class="btn btn-default btn-xs"
        [% IF data_tab %]
            data-tab="[% data_tab | uri %]"
        [% END %]
    >
        <i class="fa fa-search"></i> Select manager
    </a>
[% END %]
