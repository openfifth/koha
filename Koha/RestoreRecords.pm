package Koha::RestoreRecords;

use Modern::Perl;
use base qw(Koha::Object);

use C4::Context;
use Koha::DateUtils qw( dt_from_string );
use Koha::SearchEngine;
use Koha::SearchEngine::Elasticsearch::Indexer;
use Koha::SearchEngine::Zebra::Indexer;
use Koha::Biblios;
use Koha::Biblio;
use Koha::Items;
use Koha::Database;
use C4::Biblio qw( ModBiblioMarc );
use MARC::Record;
use MARC::File::XML;

=head1 NAME

Koha::RestoreRecords

=head1 SYNOPSIS

  use Koha::RestoreRecords;
  my $restorer = Koha::RestoreRecords->new();
  $restorer->restore_biblio($biblionumber);
  $restorer->restore_item($itemnumber);

=head1 DESCRIPTION

This module provides functionality to restore deleted bibliographic records and items
from Koha's deletion tables.

=head1 METHODS

=head2 Class methods

=head3 new

  my $restorer = Koha::RestoreRecords->new();

Creates a new RestoreRecords object.

=cut

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

=head3 restore_biblio

  $restorer->restore_biblio($biblionumber);

Restores a deleted bibliographic record and its associated items.

=cut

sub restore_biblio {
    my ($self, $biblionumber) = @_;
    my $schema = Koha::Database->new->schema;

    # Check if deleted biblio exists
    my $deleted_biblio = $schema->resultset('Deletedbiblio')
        ->search({ biblionumber => $biblionumber }, { order_by => { -desc => 'timestamp' } })
        ->next;
    return { success => 0, error => 'Deleted record not found' } unless $deleted_biblio;

    # Begin transaction
    my $guard = $schema->txn_scope_guard;

    eval {
        # Get deleted biblioitems
        my @deleted_biblioitems = $schema->resultset('Deletedbiblioitem')->search({ biblionumber => $biblionumber })->all;

        # Convert to storage hash for restoration
        my $biblio_data = { $deleted_biblio->get_columns };

        # Get the MARC record from deletedbiblio_metadata
        my $deleted_metadata = $schema->resultset('DeletedbiblioMetadata')
            ->search({ biblionumber => $biblionumber })
            ->next;
        unless ($deleted_metadata) {
            die "No MARC record found in deletedbiblio_metadata for biblio $biblionumber";
        }

        # Parse the MARC record
        my $marc_record;
        eval {
            if ($deleted_metadata->format eq 'marcxml') {
                $marc_record = MARC::Record::new_from_xml($deleted_metadata->metadata, 'UTF-8');
            } else {
                $marc_record = MARC::Record::new_from_usmarc($deleted_metadata->metadata);
            }
            unless ($marc_record) {
                die "Failed to parse MARC record";
            }
        } or do {
            die "Failed to parse MARC record: $@";
        };

        # Restore biblio
        $schema->resultset('Biblio')->create($biblio_data);

        # Restore biblioitems
        foreach my $biblioitem (@deleted_biblioitems) {
            my $biblioitem_data = { $biblioitem->get_columns };
            $schema->resultset('Biblioitem')->create($biblioitem_data);
        }

        # Restore MARC record
        ModBiblioMarc($marc_record, $biblionumber, { skip_record_index => 1 });

        # Delete from deleted tables
        $deleted_biblio->delete;
        $_->delete for @deleted_biblioitems;
        $deleted_metadata->delete;

        # Commit the transaction
        $guard->commit;
    };

    if ($@) {
        return { success => 0, error => $@ };
    }

    # Verify the biblio was actually restored
    my $biblio = Koha::Biblios->find($biblionumber);
    unless ($biblio) {
        return { success => 0, error => "Failed to restore biblio - record not found after restoration" };
    }

    # Reindex the record after transaction is committed
    if ($biblio) {
        # Use the correct search engine initialization
        if (C4::Context->preference('SearchEngine') eq 'Elasticsearch') {
            my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });
            eval {
                $indexer->index_records($biblionumber, "specialUpdate", "biblioserver");
            };
            if ($@) {
                return { success => 0, error => "Failed to index biblio with Elasticsearch: $@" };
            }
        } else {
            # Properly initialize the Zebra indexer
            my $indexer = Koha::SearchEngine::Zebra::Indexer->new();
            eval {
                $indexer->index_records($biblionumber, "specialUpdate", "biblioserver");
            };
            if ($@) {
                return { success => 0, error => "Failed to index biblio with Zebra: $@" };
            }
        }
    }

    return { success => 1 };
}

=head3 restore_item

  $restorer->restore_item($itemnumber);

Restores a deleted item.

=cut

sub restore_item {
    my ($self, $itemnumber) = @_;
    my $schema = Koha::Database->new->schema;

    # Check if deleted item exists
    my $deleted_item = $schema->resultset('Deleteditem')
        ->search({ itemnumber => $itemnumber }, { order_by => { -desc => 'timestamp' } })
        ->next;
    return { success => 0, error => 'Deleted item not found' } unless $deleted_item;

    # Get item data and check if biblio exists
    my $item_data = { $deleted_item->get_columns };
    my $biblionumber = $item_data->{biblionumber};
    
    # Check if biblio exists
    my $biblio = Koha::Biblios->find($biblionumber);
    unless ($biblio) {
        return { success => 0, error => 'Cannot restore item: associated bibliographic record does not exist' };
    }

    # Begin transaction
    my $guard = $schema->txn_scope_guard;

    eval {
        # Restore the item
        $schema->resultset('Item')->create($item_data);

        # Delete from deleted table
        $deleted_item->delete;

        # Reindex the record
        if ($biblio) {
            # Use the correct search engine initialization
            if (C4::Context->preference('SearchEngine') eq 'Elasticsearch') {
                my $indexer = Koha::SearchEngine::Elasticsearch::Indexer->new({ index => $Koha::SearchEngine::BIBLIOS_INDEX });
                $indexer->index_records($biblionumber, "specialUpdate", "biblioserver");
            } else {
                # Properly initialize the Zebra indexer
                my $indexer = Koha::SearchEngine::Zebra::Indexer->new();
                $indexer->index_records($biblionumber, "specialUpdate", "biblioserver");
            }
        }

        # Commit the transaction
        $guard->commit;
    };

    if ($@) {
        return { success => 0, error => $@ };
    }

    # Verify the item was actually restored
    my $item = Koha::Items->find($itemnumber);
    unless ($item) {
        return { success => 0, error => "Failed to restore item" };
    }

    return { success => 1 };
}

=head3 search_deleted_records

  my $records = $restorer->search_deleted_records($type, $from_date, $to_date);

Searches for deleted records or items within a date range.

=cut

sub search_deleted_records {
    my ($self, $type, $from_date, $to_date) = @_;
    my $schema = Koha::Database->new->schema;

    $from_date = dt_from_string($from_date) if $from_date;
    $to_date = dt_from_string($to_date) if $to_date;

    my @results;

    if ($type eq "records") {
        my $search_params = {};
        my $search_attrs = {
            join => 'deletedbiblioitems',
            '+select' => [
                'deletedbiblioitems.isbn',
                'deletedbiblioitems.issn'
            ],
            '+as' => [
                'isbn',
                'issn'
            ]
        };

        # Add date conditions if provided
        if ($from_date) {
            $search_params->{'timestamp'} = { '>=' => $from_date };
        }
        if ($to_date) {
            my $next_day = $to_date->clone->add(days => 1);
            $search_params->{'timestamp'} = { '<=' => $next_day } if $to_date;
        }

        my $rs = $schema->resultset('Deletedbiblio')->search($search_params, $search_attrs);

        while (my $row = $rs->next) {
            my $data = {
                biblionumber => $row->biblionumber,
                author => $row->author,
                title => $row->title,
                isbn => $row->get_column('isbn'),
                issn => $row->get_column('issn'),
                timestamp => $row->timestamp,
                datecreated => $row->datecreated
            };
            push @results, $data;
        }
    } else {
        my $search_params = {};
        my $search_attrs = {
            join => ['deletedbiblio', 'deletedbiblioitems'],
            '+select' => [
                'deletedbiblio.title',
                'deletedbiblio.author',
                'deletedbiblioitems.isbn',
                'deletedbiblioitems.issn'
            ],
            '+as' => [
                'title',
                'author',
                'isbn',
                'issn'
            ]
        };

        # Add date conditions if provided
        if ($from_date) {
            $search_params->{'timestamp'} = { '>=' => $from_date };
        }
        if ($to_date) {
            my $next_day = $to_date->clone->add(days => 1);
            $search_params->{'timestamp'} = { '<=' => $next_day } if $to_date;
        }

        my $rs = $schema->resultset('Deleteditem')->search($search_params, $search_attrs);

        while (my $row = $rs->next) {
            my $data = {
                itemnumber => $row->itemnumber,
                barcode => $row->barcode,
                biblionumber => $row->biblionumber,
                title => $row->get_column('title'),
                author => $row->get_column('author'),
                isbn => $row->get_column('isbn'),
                issn => $row->get_column('issn'),
                timestamp => $row->timestamp
            };
            push @results, $data;
        }
    }

    return \@results;
}

=head3 _type

=cut

sub _type {
    return 'RestoreRecord';
}

1;