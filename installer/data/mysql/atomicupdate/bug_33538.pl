use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "33538",
    description => "Add sync_on_creation and sync_on_update to identity_provider_mappings",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        unless ( column_exists( 'identity_provider_mappings', 'sync_on_creation' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_mappings
                   ADD COLUMN sync_on_creation tinyint(1) NOT NULL DEFAULT 1 AFTER default_content
                }
            );
            say_success( $out, "Added sync_on_creation to identity_provider_mappings table" );
        }

        unless ( column_exists( 'identity_provider_mappings', 'sync_on_update' ) ) {
            $dbh->do(
                q{
                ALTER TABLE identity_provider_mappings
                    ADD COLUMN sync_on_update tinyint(1) NOT NULL DEFAULT 1 AFTER sync_on_creation
                }
            );
            say_success( $out, "Added sync_on_update columns to identity_provider_mappings table" );
        }

    },
};
