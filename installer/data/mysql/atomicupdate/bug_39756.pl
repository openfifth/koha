use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "39756",
    description => "Rename `OverdueNoticeCalendar` syspref to `OverdueTriggersCalendar` and index issues.date_due",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q| 
            UPDATE systempreferences SET variable='OverdueTriggersCalendar', explanation='Take calendar into consideration when processing overdue triggers' where variable='OverdueNoticeCalendar' 
        |
        );

        say_success( $out, "Renamed `OverdueNoticeCalendar` syspref to `OverdueTriggersCalendar`" );

        # process_circulation_triggers.pl selects checkouts by date_due range and
        # orders by (date_due, borrowernumber). Without a key on those columns the
        # range has no candidate index at all and every run is a full scan of
        # issues plus a filesort — once per branch on the calendar-adjusted path's
        # per-branch fallback.
        if ( !index_exists( 'issues', 'date_due_idx' ) ) {
            $dbh->do(
                q|
                ALTER TABLE issues ADD KEY `date_due_idx` (`date_due`, `borrowernumber`)
            |
            );

            say_success( $out, "Added `date_due_idx` on issues(date_due, borrowernumber)" );
        } else {
            say_info( $out, "Index `date_due_idx` already exists on issues, skipping" );
        }
    }
};

1;
