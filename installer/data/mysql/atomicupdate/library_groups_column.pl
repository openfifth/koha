use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_failure say_success say_info);

return {
    bug_number  => "TBC",
    description => "Add an acquisitions option to library groups",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( !column_exists( 'library_groups', 'ft_acquisitions' ) ) {
            $dbh->do(
                "ALTER TABLE `library_groups` ADD COLUMN `ft_acquisitions` tinyint(1) NOT NULL DEFAULT 0 AFTER `ft_local_float_group`"
            );
        }
    },
};

