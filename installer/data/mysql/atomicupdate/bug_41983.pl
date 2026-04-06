use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41983",
    description => "Add hold_group_id to tmp_holdsqueue",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'tmp_holdsqueue', 'hold_group_id' ) ) {
            $dbh->do(
                q{
                    ALTER TABLE tmp_holdsqueue
                    ADD COLUMN hold_group_id int(11) DEFAULT NULL AFTER notes
                }
            );
            say_success( $out, "Added hold_group_id to tmp_holdsqueue" );
        }
    },
};
