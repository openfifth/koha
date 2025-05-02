
#!/usr/bin/perl

use Modern::Perl;

use Koha::Suggestion;
use String::Random qw( random_string );

my @status_list = ( 'ASKED', 'ACCEPTED', 'REJECTED', 'CHECKED', 'ORDERED', 'AVAILABLE' );
my @branches    = ( "CPL",   "FFL", "FPL", "FRL", "IPT", "LPL", "MPL", "PVL", "RPL", "SPL", "TPL", "UPL" );

foreach my $i ( 1 .. 10 ) {
    warn $i . " created\n" if $i % 100 == 0;
    my $title = random_string("cccccccccc");

    # my $status_index = rand(6);
    my $status_index = 0;
    my $branch_index = rand(11);
    my $patron_id    = rand(50) + 1;
    my $suggestion   = Koha::Suggestion->new(
        {
            suggestedby => $patron_id,               STATUS    => $status_list[$status_index],
            branchcode  => $branches[$branch_index], managedby => 51, itemtype => 'BK', suggesteddate => '2025-05-02',
            archived    => 0,                        title     => $title
        }
    )->store;
}

warn "Complete";
