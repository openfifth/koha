use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "43089",
    description => "Adds ILL group feature",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'library_groups', 'ft_ill_group' ) ) {
            $dbh->do(
                q{
                ALTER TABLE `library_groups` ADD `ft_ill_group` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Use this group to scope searches for ILL requests' AFTER `ft_local_float_group`
            }
            );
            say_success( $out, 'Added ft_ill_group column' );
        }
    },
};
