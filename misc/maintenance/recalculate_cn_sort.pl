#!/usr/bin/perl

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

use Getopt::Long qw( GetOptions );
use Pod::Usage   qw( pod2usage );

use Koha::Script;
use C4::ClassSource qw( GetClassSort );
use Koha::Items;
use Koha::SearchEngine::Indexer;

my ( $help, $confirm, $dry_run, $verbose, $skip_index, $where );
my @cn_sources;

GetOptions(
    'c|confirm'     => \$confirm,
    'n|dry-run'     => \$dry_run,
    'v|verbose'     => \$verbose,
    'cn_source=s'   => \@cn_sources,
    'where=s'       => \$where,
    'skip-indexing' => \$skip_index,
    'h|help'        => \$help,
) or pod2usage(2);

pod2usage( -verbose => 2 ) if $help;
pod2usage(1) unless $confirm || $dry_run;
pod2usage( -message => "--confirm and --dry-run are mutually exclusive\n", -exitval => 2 ) if $confirm && $dry_run;

my @conditions;

if (@cn_sources) {
    my @codes = grep { $_ ne 'NULL' } @cn_sources;
    my @or;
    push @or,         { cn_source => { -in => \@codes } } if @codes;
    push @or,         { cn_source => undef }, { cn_source => '' } if @codes != @cn_sources;
    push @conditions, { -or       => \@or };
}

push @conditions, \[$where] if $where;

my $items = Koha::Items->search( @conditions ? { -and => \@conditions } : {}, { order_by => 'itemnumber' } );

my %counts = ( examined => 0, skipped => 0, unchanged => 0, changed => 0, empty_key => 0 );
my %biblionumbers;

while ( my $item = $items->next ) {
    $counts{examined}++;

    # Same condition as Koha::Item->store uses when adding an item
    unless ( $item->itemcallnumber or $item->cn_source ) {
        $counts{skipped}++;
        next;
    }

    my $old = $item->cn_sort                                              // '';
    my $new = GetClassSort( $item->cn_source, $item->itemcallnumber, "" ) // '';

    if ( $new eq $old ) {
        $counts{unchanged}++;
        next;
    }

    $counts{changed}++;

    if ( $new eq '' and length( $item->itemcallnumber // '' ) ) {
        $counts{empty_key}++;
        printf STDERR (
            "Item %s: call number '%s' produced an empty cn_sort with the '%s' filing rule\n",
            $item->itemnumber, $item->itemcallnumber, $item->cn_source // 'default'
        );
    }

    printf "Item %s (%s): '%s' => '%s'\n", $item->itemnumber, $item->itemcallnumber // '', $old, $new if $verbose;

    next if $dry_run;

    # Nothing but cn_sort changes: skip logging, holds queue and per-item
    # indexing, the biblios are indexed together at the end.
    $item->cn_sort($new)->store(
        {
            log_action        => 0,
            skip_record_index => 1,
            skip_holds_queue  => 1,
        }
    );
    $biblionumbers{ $item->biblionumber } = 1;
}

if ( !$dry_run && !$skip_index && %biblionumbers ) {
    my @biblionumbers = sort { $a <=> $b } keys %biblionumbers;
    my $indexer       = Koha::SearchEngine::Indexer->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );
    $indexer->index_records( \@biblionumbers, 'specialUpdate', 'biblioserver' );
    print scalar(@biblionumbers) . " biblio(s) queued for reindexing\n";
}

print "### Dry run, database not modified ###\n" if $dry_run;
printf "Examined: %d, changed: %d, unchanged: %d, skipped (no call number or source): %d\n",
    @counts{qw( examined changed unchanged skipped )};
print "Warning: $counts{empty_key} call number(s) produced an empty cn_sort\n" if $counts{empty_key};

=head1 NAME

recalculate_cn_sort.pl - recalculate items.cn_sort from the current filing rules

=head1 SYNOPSIS

recalculate_cn_sort.pl --dry-run [options]

recalculate_cn_sort.pl --confirm [options]

 Options:
   -h --help           this message
   -c --confirm        recalculate and save
   -n --dry-run        report what would change, modify nothing
   -v --verbose        list every item that changes
   --cn_source CODE    only items with this classification source (repeatable);
                       use NULL for items with no source
   --where CLAUSE      additional raw SQL condition on the items table
   --skip-indexing     do not queue the search index update

=head1 DESCRIPTION

Koha only calculates C<items.cn_sort> when an item is created, or when its
call number or classification source changes. Editing a classification
source or filing rule, or a wrong configuration at migration time, therefore
leaves existing items with the old sort key. This script recalculates the key
for existing items using the current configuration.

Items with no classification source use the I<DefaultClassificationSource>
preference, exactly as at save time.

Only items whose key changes are written. Writes skip the cataloguing log, the
holds queue update and per-item indexing. The biblios of changed items are
queued for reindexing once at the end, unless C<--skip-indexing> is given. In
that case reindex later, for instance with C<rebuild_elasticsearch.pl>.

Items whose call number produces an empty key are reported, as can happen
when a filing rule such as LCC cannot parse a call number.

Run with C<--dry-run> first.

=cut
