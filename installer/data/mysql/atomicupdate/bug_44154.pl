use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "44154",
    description => "Add illrequests.source",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'illrequests', 'source' ) ) {
            $dbh->do(
                q{
                ALTER TABLE illrequests
                    ADD COLUMN `source` varchar(20) DEFAULT NULL COMMENT 'The interface the request was created from (opac, intranet, api, cron, commandline)'
                    AFTER `backend`
                }
            );

            say $out "Added column 'illrequests.source'";
        }
    },
};
