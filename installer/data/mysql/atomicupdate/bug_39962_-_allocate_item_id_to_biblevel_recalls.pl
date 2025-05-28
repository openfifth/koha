use Modern::Perl;
use Koha::Recalls;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "39962",
    description => "Recalled status does not show properly on staff interface record detail page",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        my @recalls = Koha::Recalls->search(
            { status => [ 'requested', 'overdue' ], item_id => undef, item_level => 0, completed => 0 } )->as_list;
        foreach my $r (@recalls) {
            if ( $r->checkout ) {
                my $item_id = $r->checkout->itemnumber;
                $r->update( { item_id => $item_id } );
            }
        }

        say_success( $out, "Allocated checkout itemnumber to biblio-level recalls" );
    },
};
