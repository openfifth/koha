use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "22707",
    description => "Add autoMemberNumFormat system preference for patron cardnumber generation strategy",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        if ( $dbh->selectrow_array(q{SELECT 1 FROM systempreferences WHERE variable = 'autoMemberNumFormat'}) ) {
            say_warning( $out, "System preference 'autoMemberNumFormat' already exists, skipping" );
            return;
        }

        $dbh->do(
            q{INSERT IGNORE INTO systempreferences (variable, value) VALUES ('autoMemberNumFormat', 'sequential')});
        say_success( $out, "Added system preference 'autoMemberNumFormat' (default: 'sequential')" );
    },
};
