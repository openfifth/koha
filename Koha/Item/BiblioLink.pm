package Koha::Item::BiblioLink;

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

use base qw(Koha::Object);

use C4::Context;

use Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue;
use Koha::Biblios;
use Koha::Exceptions::Item::BiblioLink;
use Koha::Holds;
use Koha::Items;
use Koha::SearchEngine;
use Koha::SearchEngine::Indexer;

=head1 NAME

Koha::Item::BiblioLink - Koha Item to bibliographic record link object class

A link row associates one item with a bibliographic record other than the one
its item record lives on (items.biblionumber). All linked records are peers -
the link carries no hierarchy. The link_type column (authorised value category
ITEM_BIBLIO_LINK_TYPE, e.g. 'binding', 'analytic') is for handling UI display.

=head1 API

=head2 Class methods

=head3 item

    my $item = $link->item;

Returns the linked Koha::Item.

=cut

sub item {
    my ($self) = @_;
    my $rs = $self->_result->itemnumber;
    return Koha::Item->_new_from_dbic($rs);
}

=head3 biblio

    my $biblio = $link->biblio;

Returns the linked Koha::Biblio.

=cut

sub biblio {
    my ($self) = @_;
    my $rs = $self->_result->biblionumber;
    return Koha::Biblio->_new_from_dbic($rs);
}

=head3 store

    $link->store;

Overloaded I<store> method that refuses to link an item to the bibliographic
record its item record already lives on (throws
I<Koha::Exceptions::Item::BiblioLink::SameBiblio>) and triggers a reindex and
holds queue update of the linked record.

$params can take the same optional 'skip_record_index' and 'skip_holds_queue'
parameters as Koha::Item->store.

=cut

sub store {
    my ( $self, $params ) = @_;

    my $item = Koha::Items->find( $self->itemnumber );
    Koha::Exceptions::Item::BiblioLink::SameBiblio->throw
        if $item && $item->biblionumber == $self->biblionumber;

    my $result = $self->SUPER::store;

    $self->_trigger_biblio_update($params);

    return $result;
}

=head3 delete

    $link->delete;
    $link->delete( { force => 1 } );

Overloaded I<delete> method that refuses to remove the link while holds exist
for the item on the linked bibliographic record (throws
I<Koha::Exceptions::Item::BiblioLink::HoldsExist>) unless I<force> is passed,
and triggers a reindex and holds queue update of the linked record.

$params can take the same optional 'skip_record_index' and 'skip_holds_queue'
parameters as Koha::Item->delete.

=cut

sub delete {
    my ( $self, $params ) = @_;

    unless ( $params->{force} ) {
        my $holds_count = Koha::Holds->search(
            {
                biblionumber => $self->biblionumber,
                itemnumber   => $self->itemnumber,
            }
        )->count;
        Koha::Exceptions::Item::BiblioLink::HoldsExist->throw if $holds_count;
    }

    my $result = $self->SUPER::delete;

    $self->_trigger_biblio_update($params);

    return $result;
}

=head3 to_api_mapping

This method returns the mapping for representing a Koha::Item::BiblioLink
object on the API.

=cut

sub to_api_mapping {
    return {
        id           => 'item_biblio_link_id',
        itemnumber   => 'item_id',
        biblionumber => 'biblio_id',
    };
}

=head2 Internal methods

=head3 _trigger_biblio_update

Reindex the linked bibliographic record and enqueue a holds queue update for
it, so availability and hold targeting reflect the link change.

=cut

sub _trigger_biblio_update {
    my ( $self, $params ) = @_;

    unless ( $params->{skip_record_index} ) {
        my $indexer = Koha::SearchEngine::Indexer->new( { index => $Koha::SearchEngine::BIBLIOS_INDEX } );
        $indexer->index_records( $self->biblionumber, "specialUpdate", "biblioserver" );
    }

    Koha::BackgroundJob::BatchUpdateBiblioHoldsQueue->new->enqueue( { biblio_ids => [ $self->biblionumber ] } )
        unless $params->{skip_holds_queue}
        or !C4::Context->preference('RealTimeHoldsQueue');

    return $self;
}

=head3 _type

=cut

sub _type {
    return 'ItemBiblioLink';
}

1;
