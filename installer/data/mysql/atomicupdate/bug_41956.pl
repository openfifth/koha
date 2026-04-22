use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "d41956",
    description => "Remove visual_hold_group_id column from hold_groups",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( column_exists( 'hold_groups', 'visual_hold_group_id' ) ) {
            $dbh->do(q{ALTER TABLE hold_groups DROP COLUMN visual_hold_group_id});
            say_success( $out, "Removed column 'visual_hold_group_id' from hold_groups" );
        }
    },
};
