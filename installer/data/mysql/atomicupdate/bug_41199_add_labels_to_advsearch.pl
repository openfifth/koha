use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "41199",
    description => "Add a way to enable/disable search input field labels",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable,value,options,explanation,type) VALUES ('OPACShowLabelsForSearchInputs','0',NULL,'If enabled, show labels beside each input field related to search inputs','YesNo')}
        );

        say_success( $out, "Added new system preference 'OPACShowLabelsForSearchInputs'" );
    },
};
