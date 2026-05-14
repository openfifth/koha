package Koha::Acquisition::OrderManagement::Orderline;

# Copyright 2026 Open Fifth

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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use base qw(Koha::Object::Mixin::AdditionalFields Koha::Object);

use Koha::Acquisition::OrderManagement::OrderlineItem;
use Koha::Acquisition::OrderManagement::OrderlineUser;
use Koha::Acquisition::OrderManagement::OrderlineUsers;
use Koha::Acquisition::OrderManagement::OrderlineManager;
use Koha::Acquisition::OrderManagement::OrderlineManagers;
use Koha::Acquisition::OrderManagement::OrderlineFundDistributions;
use Koha::Item;
use Koha::Items;
use Koha::Util::MARC;
use Koha::Acquisition::Bookseller;
use Koha::Library;

use C4::Biblio qw( AddBiblio TransformKohaToMarc );
use C4::Search qw( FindDuplicate );

=head1 NAME

Koha::Acquisition::OrderManagement::Orderline Object class

=head1 API

=head2 Class methods

=head3 add_patron_relationships

    $orderline->add_patron_relationships({
        patrons_to_notify => \@patron_hashrefs,
        managed_by        => \@patron_hashrefs,
    });

Replaces the patron notification list and/or the manager list for this orderline.
Each argument is an arrayref of hashrefs containing a C<borrowernumber> key. If a
key is omitted, that relationship type is left unchanged. Each replacement is
performed atomically in its own database transaction (delete-then-insert).

=cut

sub add_patron_relationships {
    my ( $self, $args ) = @_;

    my $patrons_to_notify = $args->{patrons_to_notify};
    my $managed_by        = $args->{managed_by};

    if ($patrons_to_notify) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->patrons_to_notify->delete;
                foreach my $patron (@$patrons_to_notify) {
                    Koha::Acquisition::OrderManagement::OrderlineUser->new(
                        {
                            orderline_id   => $self->orderline_id,
                            borrowernumber => $patron->{borrowernumber}
                        }
                    )->store;
                }
            }
        );
    }
    if ($managed_by) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->managed_by->delete;
                foreach my $patron (@$managed_by) {
                    Koha::Acquisition::OrderManagement::OrderlineManager->new(
                        {
                            orderline_id   => $self->orderline_id,
                            borrowernumber => $patron->{borrowernumber}
                        }
                    )->store;
                }
            }
        );
    }
}

=head3 fund_distributions

    my $distributions = $orderline->fund_distributions;
    $orderline->fund_distributions(\@distribution_hashrefs);

Getter/setter for the fund distributions associated with this orderline.

When called with an arrayref, replaces all existing distributions in a single
database transaction. Each hashref is passed directly to
C<add_to_acq_orderline_fund_distributions>.

Always returns a C<Koha::Acquisition::OrderManagement::OrderlineFundDistributions>
result set.

=cut

sub fund_distributions {
    my ( $self, $fund_distributions ) = @_;

    if ($fund_distributions) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->fund_distributions->delete;

                for my $distribution (@$fund_distributions) {
                    $self->_result->add_to_acq_orderline_fund_distributions($distribution);
                }
            }
        );
    }
    my $fund_distributions_rs = $self->_result->acq_orderline_fund_distributions;
    return Koha::Acquisition::OrderManagement::OrderlineFundDistributions->_new_from_dbic($fund_distributions_rs);
}

=head3 biblio

    my $biblio = $orderline->biblio;
    my $biblio = $orderline->biblio({
        biblio_data           => { title => ..., author => ..., ... },
        confirm_not_duplicate => 1,
    });

Getter/setter for the bibliographic record linked to this orderline.

When C<biblio_data> is supplied, builds a MARC record from the provided fields
(C<title>, C<author>, C<series_title>, C<isbn>, C<ean>, C<publisher>,
C<publication_year>, C<item_type>, C<edition_statement>) and creates a new biblio
via C<C4::Biblio::AddBiblio>. Unless C<confirm_not_duplicate> is true, a duplicate
check is performed first; if a match is found,
C<Koha::Exceptions::DuplicateObject> is thrown with the existing biblionumber.

Always returns the associated C<Koha::Biblio>, or C<undef> if none is linked.

=cut

sub biblio {
    my ( $self, $args ) = @_;

    my $biblio_data           = $args->{biblio_data};
    my $confirm_not_duplicate = $args->{confirm_not_duplicate};

    if ($biblio_data) {
        my $record = TransformKohaToMarc(
            {
                "biblio.title"                 => $biblio_data->{title}             || '',
                "biblio.author"                => $biblio_data->{author}            || '',
                "biblio.seriestitle"           => $biblio_data->{series_title}      || '',
                "biblioitems.isbn"             => $biblio_data->{isbn}              || '',
                "biblioitems.ean"              => $biblio_data->{ean}               || '',
                "biblioitems.publishercode"    => $biblio_data->{publisher}         || '',
                "biblioitems.publicationyear"  => $biblio_data->{publication_year}  || '',
                "biblio.copyrightdate"         => $biblio_data->{publication_year}  || '',
                "biblioitems.itemtype"         => $biblio_data->{item_type}         || '',
                "biblioitems.editionstatement" => $biblio_data->{edition_statement} || '',
            }
        );
        Koha::Util::MARC::FillWithDefaultValues($record);

        if ( !$confirm_not_duplicate ) {
            my ( $duplicate_biblionumber, $duplicate_title ) = FindDuplicate($record);

            if ($duplicate_biblionumber) {
                Koha::Exceptions::DuplicateObject->throw($duplicate_biblionumber);
            }
        }

        my ( $biblionumber, $bibitemnum ) = AddBiblio( $record, '' );
        $self->biblionumber($biblionumber)->store;

        #ACQTODO: Suggestion modification?
    }

    my $rs = $self->_result->biblio;
    return unless $rs;
    return Koha::Biblio->_new_from_dbic($rs);
}

=head3 items

    my $items = $orderline->items;
    $orderline->items(\@item_data_hashrefs);

Getter/setter for the items associated with this orderline.

When called with an arrayref, removes all existing item links and creates new
C<Koha::Item> records from the supplied data (via C<new_from_api>), linking each
to this orderline via C<OrderlineItem>. The C<biblio_id> field is populated
automatically from the orderline's C<biblionumber>.

Always returns a C<Koha::Items> collection.

=cut

sub items {
    my ( $self, $items_data ) = @_;

    #ACQTODO: How do we handle items on a PUT request?
    #ACQTODO: Does the barcode handling from the Biblio add_item endpoint need processing here?

    if ($items_data) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->items->delete;
                for my $item_data (@$items_data) {
                    $item_data->{biblio_id} = $self->biblionumber;
                    my $item = Koha::Item->new_from_api($item_data)->store->discard_changes;
                    Koha::Acquisition::OrderManagement::OrderlineItem->new(
                        {
                            orderline_id => $self->orderline_id,
                            itemnumber   => $item->itemnumber,
                        }
                    )->store;
                }
            }
        );
    }

    my $rs = $self->_result->acq_orderline_items;
    return Koha::Items->_new_from_dbic( $rs->related_resultset('itemnumber') );
}

=head3 vendor

Returns the C<Koha::Acquisition::Bookseller> for this orderline, or C<undef> if
none is set.

=cut

sub vendor {
    my ($self) = @_;
    my $vendor_rs = $self->_result->vendor;
    return unless $vendor_rs;
    return Koha::Acquisition::Bookseller->_new_from_dbic($vendor_rs);
}

=head3 managing_library

Returns the C<Koha::Library> that manages this orderline, or C<undef> if none is set.

=cut

sub managing_library {
    my ($self) = @_;
    my $managing_library_rs = $self->_result->managing_branch;
    return unless $managing_library_rs;
    return Koha::Library->_new_from_dbic($managing_library_rs);
}

=head3 managed_by

Returns a C<Koha::Acquisition::OrderManagement::OrderlineManagers> collection of
managers assigned to this orderline, or C<undef> if none are assigned.

=cut

sub managed_by {
    my ($self) = @_;
    my $managers = $self->_result->acq_orderline_managers;
    return unless $managers;
    return Koha::Acquisition::OrderManagement::OrderlineManagers->_new_from_dbic($managers);
}

=head3 patrons_to_notify

Returns a C<Koha::Acquisition::OrderManagement::OrderlineUsers> collection of
patrons to be notified about this orderline, or C<undef> if none are assigned.

=cut

sub patrons_to_notify {
    my ($self) = @_;
    my $users = $self->_result->acq_orderline_users;
    return unless $users;
    return Koha::Acquisition::OrderManagement::OrderlineUsers->_new_from_dbic($users);
}

=head2 Internal methods

=head3 _type

Returns the DBIx::Class result class name for orderlines (C<AcqOrderline>).

=cut

sub _type {
    return 'AcqOrderline';
}

1;
