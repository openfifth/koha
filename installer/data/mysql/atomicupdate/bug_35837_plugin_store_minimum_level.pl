use Modern::Perl;
use Koha::Installer::Output qw(say_success);

return {
    bug_number  => "35837",
    description => "Add PluginStoreMinimumLevel system preference",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable, value, options, explanation, type)
                VALUES ('PluginStoreMinimumLevel', '', 'INCOMPLETE|STRUCTURAL|CERTIFIED',
                    'Minimum plugin-store certification tier required to install a plugin known to originate from the plugin store. Leave empty to disable this check.',
                    'Choice')
            }
        );

        say $out "Added new system preference 'PluginStoreMinimumLevel'";
    },
};
