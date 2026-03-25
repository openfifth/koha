use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "39756",
    description => "Rename `OverdueNoticeCalendar` syspref to `OverdueTriggersCalendar`",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q| 
            UPDATE systempreferences SET variable='OverdueTriggersCalendar', explanation='Take calendar into consideration when processing overdue triggers' where variable='OverdueNoticeCalendar' 
        |
        );

        say_success( $out, "Renamed `OverdueNoticeCalendar` syspref to `OverdueTriggersCalendar`" );
    }
};

1;
