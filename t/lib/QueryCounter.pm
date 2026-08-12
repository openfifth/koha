package t::lib::QueryCounter;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use DBIx::Class::Storage::Statistics;
use Time::HiRes qw( time );

use Koha::Database;

=head1 NAME

t::lib::QueryCounter - Count the SQL queries and measure the run time of a code block

=head1 SYNOPSIS

    use t::lib::QueryCounter;

    my ( $result, $stats ) = t::lib::QueryCounter->measure(
        sub {
            return Koha::Biblio::Availability::Hold->check( { biblio => $biblio, patron => $patron } );
        }
    );

    is( $stats->{queries}, 14, 'The check issues 14 queries' );
    diag( sprintf( 'The check took %.1f ms', $stats->{elapsed_ms} ) );

=head1 DESCRIPTION

This helper turns on the DBIx::Class statement trace, runs a code block, and
then turns the trace off again. It reports the number of SQL statements that the
block issued and the time that the block took.

Use it to show that a query count stays flat as the data set grows, and to
measure a performance budget.

The DBIx::Class trace only sees SQL that DBIx::Class itself issues. Some Koha
code talks to the database directly through C<< C4::Context->dbh >>, bypassing
DBIx::Class entirely - C<C4::Reserves::CalculatePriority> is one example. That
SQL would otherwise be invisible to this helper, silently under-counting any
block that calls into code like that. C<measure> also hooks DBI's own
C<do>/C<select*> convenience methods on the shared database handle, so a call
made through one of those is counted too, on the same terms as a DBIx::Class
query (its trace, its elapsed time).

This still does not catch a raw, explicit C<< $dbh->prepare(...)->execute(...) >>
call. DBI's per-statement-handle hooks only apply to a handle prepared while
they are set - a handle DBI already had cached from before this call (a
common case, since Koha's test fixtures often run the same query the code
under test does) keeps using whatever it had, unaffected by this call. Only
the plain C<do>/C<select*> methods are exempt from that gap, because DBI
dispatches those at the database-handle level, not through a cached
statement handle.

=head1 API

=head2 Class methods

=head3 measure

    my ( $result, $stats ) = t::lib::QueryCounter->measure( $code );
    my ( $result, $stats ) = t::lib::QueryCounter->measure( $code, { schema => $schema } );

Runs the I<$code> coderef with the statement trace on.

Returns two values. The first value is the first return value of I<$code>. The
second value is a hashref with these keys:

=over 4

=item queries - the number of SELECT, INSERT, UPDATE and DELETE statements

=item elapsed_ms - the run time of I<$code> in milliseconds

=item trace - the raw trace text, for a caller that needs to count a specific
statement rather than every statement

=back

Accepts an optional parameters hashref. The only parameter is C<schema>, which
defaults to C<< Koha::Database->new->schema >>.

The method restores the initial trace settings before it returns. It also
restores them if I<$code> throws an exception, and then rethrows that exception.
A test can therefore call this method inside another call to it.

=cut

# The DBI database-handle methods that issue a statement without going
# through DBIx::Class. Each one's first argument (after the handle itself)
# is the SQL text, matching DBI's own method signatures.
my @RAW_SQL_METHODS = qw(
    do
    selectrow_array
    selectrow_arrayref
    selectrow_hashref
    selectall_arrayref
    selectall_hashref
    selectcol_arrayref
);

sub measure {
    my ( $class, $code, $params ) = @_;
    $params //= {};

    my $schema  = $params->{schema} // Koha::Database->new->schema;
    my $storage = $schema->storage;
    my $dbh     = $storage->dbh;

    my $trace = q{};
    open my $fh, '>', \$trace or die "Cannot open an in-memory filehandle: $!";

    # Save the trace settings. Never set the filehandle on the statistics
    # object that the storage already holds: a read of that object's debugfh
    # value lazily opens a handle on STDERR, and a write of the value back
    # clears its _defaulted_to_stderr flag. The whole test suite shares that
    # object, so both actions affect other tests.
    my $old_debug    = $storage->debug;
    my $old_debugobj = $storage->debugobj;

    # This statistics object is private to this call. It holds no state to
    # protect, so set its filehandle and then swap it in.
    my $statistics = DBIx::Class::Storage::Statistics->new;
    $statistics->debugfh($fh);

    $storage->debugobj($statistics);
    $storage->debug(1);

    # Log a raw DBI call (see @RAW_SQL_METHODS above) into the same trace
    # DBIx::Class is already writing to, so the single query count below
    # covers both. DBIx::Class's own SQL is always a single line with no
    # leading whitespace; a raw call's SQL is whatever the caller wrote,
    # often an indented multi-line literal, so it needs the same shape
    # before the query count below can find it.
    my $old_dbh_callbacks = $dbh->{Callbacks};
    my $record_raw_sql    = sub {
        my $sql = $_[1] // q{};
        $sql =~ s/^\s+//;
        $sql =~ s/\s+/ /g;
        print $fh "$sql\n";
        return;
    };
    $dbh->{Callbacks} = { map { $_ => $record_raw_sql } @RAW_SQL_METHODS };

    my @result;
    my $error;
    my $start = time();

    unless ( eval { @result = $code->(); 1 } ) {
        $error = $@;
    }

    my $elapsed_ms = ( time() - $start ) * 1000;

    $storage->debug($old_debug);
    $storage->debugobj($old_debugobj);
    $dbh->{Callbacks} = $old_dbh_callbacks;
    close $fh;

    die $error if $error;

    return (
        $result[0],
        {
            queries    => scalar( () = $trace =~ /^(?:SELECT|INSERT|UPDATE|DELETE)\b/mg ),
            elapsed_ms => $elapsed_ms,
            trace      => $trace,
        }
    );
}

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
