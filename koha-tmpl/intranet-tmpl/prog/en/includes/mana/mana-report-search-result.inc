[% USE Asset %]
[% USE KohaDates %]
[% USE Koha %]
[% USE AuthorisedValues %]
[% USE Branches %]
[% USE raw %]
[% PROCESS 'i18n.inc' %]
[% INCLUDE 'doc-head-open.inc' %]
<title
    >[% FILTER collapse %]
        [% t("Mana Knowledge Base reports search") | html %]
        &rsaquo; [% t("Reports") | html %] &rsaquo; [% t("Koha") | html %]
    [% END %]</title
>
[% INCLUDE 'doc-head-close.inc' %]
[% Asset.css("css/reports.css") | $raw %]
</head>

<body id="rep_mana_search" class="rep">
[% WRAPPER 'header.inc' %]
    [% INCLUDE 'circ-search.inc' %]
[% END %]

<div id="breadcrumbs">
    <a href="/cgi-bin/koha/mainpage.pl">Home</a>
    &rsaquo; <a href="/cgi-bin/koha/reports/reports-home.pl">Reports</a> &rsaquo; <a href="/cgi-bin/koha/reports/guided_reports.pl">Guided reports wizard</a>
    &rsaquo; Mana Knowledge Base report search results
</div>

<div class="main container-fluid">
    <div class="row">
        <div class="col-md-10 order-md-2 order-sm-1">
            <main>
                <h2>Mana Knowledge Base report search results</h2>

                <div id="mana_results">
                    [% IF statuscode == "200" AND reports %]
                        <table id="mana_results_datatable">
                            <thead>
                                <tr>
                                    <th>Report name</th>
                                    <th class="anti-the">Notes</th>
                                    <th>Type</th>
                                    <th title="Number of libraries using this pattern"># of users</th>
                                    <th title="Last time a library used this pattern">Last import</th>
                                    <th> Comments </th>
                                    [% UNLESS search_only %]
                                        <th class="no-sort no-export">Actions</th>
                                    [% END %]
                                </tr>
                            </thead>
                            <tbody>
                                [% FOREACH report IN reports %]
                                    [% UNLESS report.cannotdisplay %]
                                        [% IF report.nbofcomment > highWarned %]
                                            [% SET tr_class = 'high-warned-row' %]
                                        [% ELSIF report.nbofcomment > warned %]
                                            [% SET tr_class = 'warned-row' %]
                                        [% ELSIF report.nbofcomment > lowWarned %]
                                            [% SET tr_class = 'highlighted-row' %]
                                        [% ELSE %]
                                            [% SET tr_class = '' %]
                                        [% END %]
                                        <tr id="[% report.id | html %]" class="[% tr_class | html %]">
                                            <td>
                                                <input type="hidden" class="rowid" value="[% report.id | $raw %]" />
                                                [% IF ( report.report_name ) %]
                                                    [% report.report_name | html %]
                                                [% END %]
                                            </td>
                                            <td title="[% report.savedsql | html %]">
                                                [% IF report.notes.length > 200 %]
                                                    <div>
                                                        [% report.notes.substr(0,200) | html %]... <a href="#" class="btn btn-link btn-sm showbutton"><i class="fa-solid fa-square-plus"></i> Show more</a>
                                                    </div>
                                                    <div style="display:none">
                                                        [% report.notes | html %]
                                                        <a href="#" class="btn btn-link btn-sm hidebutton"><i class="fa-solid fa-square-minus"></i> Show less</a>
                                                    </div>
                                                [% ELSE %]
                                                    [% report.notes | html %]
                                                [% END %]
                                            </td>
                                            <td> [% report.type | html %] </td>
                                            <td>
                                                [% IF ( report.nbofusers ) %]
                                                    [% report.nbofusers | html %]
                                                [% END %]
                                            </td>
                                            <td data-order="[% report.lastimport | html %]"> [% report.lastimport | $KohaDates %] </td>
                                            <td>
                                                [% FOREACH comment IN report.comments %]
                                                    [% comment.message | html %]
                                                    ([% comment.nb | html %])<br />
                                                [% END %]
                                            </td>

                                            [% UNLESS search_only %]
                                                <td>
                                                    <button type="button" class="btn btn-default btn-xs mana-use" id="mana-use-[% report.id | html %]" data-report_id="[% report.id | html %]"><i class="fa fa-download"></i> Import</button>
                                                </td>
                                            [% END %]
                                        </tr>
                                    [% END %]
                                [% END %]
                            </tbody>
                        </table>
                    [% ELSE %]
                        <h4>
                            [% IF ( msg ) %]
                                [% msg | html %] <span>(Status code: [% statuscode | html %])</span>
                            [% ELSE %]
                                <span>No results found</span>
                            [% END %]
                        </h4>
                    [% END %]
                </div>
            </main>
        </div>
        <!-- /.col-md-10.order-md-2 -->

        <div class="col-md-2 order-sm-2 order-md-1">
            <aside> [% INCLUDE 'guided-reports-view.inc' %] </aside>
        </div>
        <!-- /.col-md-2.order-md-1 -->
    </div>
    <!-- /.row -->

    [% INCLUDE 'intranet-bottom.inc' %]
</div>
