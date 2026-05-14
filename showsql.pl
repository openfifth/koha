use Modern::Perl;
use Koha::Patrons;
use Time::HiRes qw( time );

my $attrs = {
    order_by => [ { -asc => 'me.surname' } ],
    rows     => 20,
    page     => 1,
};

sub bench {
    my ($extra_attrs) = @_;
    my %merged = ( %$attrs, %{ $extra_attrs // {} } );

    # warm-up
    my $rs = Koha::Patrons->search( {}, \%merged );
    $rs->count;
    $rs->_resultset->reset->next;

    my $total = 0;
    for ( 1 .. 3 ) {
        my $t0 = time();
        $rs = Koha::Patrons->search( {}, \%merged );
        $rs->count;
        $rs->_resultset->reset->next;
        $total += time() - $t0;
    }
    return $total / 3;
}

my $count = Koha::Patrons->search->count;
printf "Patron count: %d\n\n", $count;

my $before = bench( { prefetch => ['library'] } );
my $after  = bench();

printf "  %-35s %.3fs\n", "unpatched (JOIN on every request):", $before;
printf "  %-35s %.3fs\n", "patched   (no JOIN):",               $after;
printf "  %-35s %.1fx\n", "speedup:",                           $before / $after;
