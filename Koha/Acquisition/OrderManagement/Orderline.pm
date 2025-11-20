package Koha::Acquisition::OrderManagement::Orderline;

# Copyright 2024 PTFS Europe

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

use Koha::Acquisition::OrderManagement::OrderlineUser;
use Koha::Acquisition::OrderManagement::OrderlineManager;
use Koha::Acquisition::OrderManagement::OrderlineFundDistributions;
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

=cut

sub add_patron_relationships {
    my ( $self, $args ) = @_;

    my $patrons_to_notify = $args->{patrons_to_notify};
    my $managed_by        = $args->{managed_by};

    if ($patrons_to_notify) {
        foreach my $patron (@$patrons_to_notify) {
            Koha::Acquisition::OrderManagement::OrderlineUser->new(
                {
                    orderline_id   => $self->orderline_id,
                    borrowernumber => $patron
                }
            )->store;
        }
    }
    if ($managed_by) {
        foreach my $patron (@$managed_by) {
            Koha::Acquisition::OrderManagement::OrderlineManager->new(
                {
                    orderline_id   => $self->orderline_id,
                    borrowernumber => $patron
                }
            )->store;
        }
    }
}

=head3 fund_distributions

=cut

sub fund_distributions {
    my ( $self, $fund_distributions ) = @_;

    if ($fund_distributions) {
        my $schema = $self->_result->result_source->schema;
        $schema->txn_do(
            sub {
                $self->fund_distributions->delete;

                for my $distribution (@$fund_distributions) {
                    delete $distribution->{fund};
                    delete $distribution->{currency};
                    delete $distribution->{taxIncluded};
                    $self->_result->add_to_acq_orderline_fund_distributions($distribution);
                }
            }
        );
    }
    my $fund_distributions_rs = $self->_result->acq_orderline_fund_distributions;
    return Koha::Acquisition::OrderManagement::OrderlineFundDistributions->_new_from_dbic($fund_distributions_rs);
}

=head3 biblio

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
                "biblioitems.itemtype"         => $biblio_data->{itemtype}          || '',
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

    my $rs = $self->_result->biblionumber;
    return unless $rs;
    return Koha::Biblio->_new_from_dbic($rs);
}

=head3 vendor

Return the vendor for this orderline

=cut

sub vendor {
    my ($self) = @_;
    my $vendor_rs = $self->_result->vendor;
    return unless $vendor_rs;
    return Koha::Acquisition::Bookseller->_new_from_dbic($vendor_rs);
}

=head3 managing_library

=cut

sub managing_library {
    my ($self) = @_;
    my $managing_library_rs = $self->_result->managing_branch;
    return unless $managing_library_rs;
    return Koha::Library->_new_from_dbic($managing_library_rs);
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'AcqOrderline';
}

1;
