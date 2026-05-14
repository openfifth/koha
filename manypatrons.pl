use Modern::Perl;

use C4::Context;
use Koha::Libraries;
use Koha::Patron::Categories;

my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;

my @branchcodes = Koha::Libraries->search->get_column('branchcode');
my @categories  = Koha::Patron::Categories->search->get_column('categorycode');

die "No branches found\n"   unless @branchcodes;
die "No categories found\n" unless @categories;

my @surnames = qw(
    Smith Jones Williams Brown Taylor Davies Evans Wilson Thomas Roberts
    Johnson White Martin Anderson Thompson Garcia Martinez Robinson Clark
);

my $target     = $ARGV[0] // 250_000;
my $batch_size = 1000;

my ($max_card) = $dbh->selectrow_array(q{SELECT COALESCE(MAX(CAST(cardnumber AS UNSIGNED)), 0) FROM borrowers});

my $card    = $max_card;
my $created = 0;

print "Creating $target patrons in batches of $batch_size...\n";

while ( $created < $target ) {
    my $batch = $batch_size < ( $target - $created ) ? $batch_size : ( $target - $created );
    my @rows;
    for my $i ( 1 .. $batch ) {
        $card++;
        my $surname      = $surnames[ $card % scalar @surnames ];
        my $firstname    = "Test$card";
        my $branchcode   = $branchcodes[ $card % scalar @branchcodes ];
        my $categorycode = $categories[ $card % scalar @categories ];
        push @rows,
            $dbh->quote($card) . ','
            . $dbh->quote($surname) . ','
            . $dbh->quote($firstname) . ','
            . $dbh->quote($branchcode) . ','
            . $dbh->quote($categorycode)
            . ",CURDATE(),DATE_ADD(CURDATE(), INTERVAL 1 YEAR),1";
    }

    $dbh->do(
        "INSERT INTO borrowers (cardnumber, surname, firstname, branchcode, categorycode, dateenrolled, dateexpiry, privacy) VALUES "
            . join( ',', map { "($_)" } @rows ) );

    $created += $batch;
    printf "\r%d / %d", $created, $target;
}

$dbh->commit;
print "\nDone.\n";
