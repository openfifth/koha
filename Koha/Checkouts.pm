package Koha::Checkouts;

# Copyright ByWater Solutions 2015
#
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

use C4::Context;
use C4::Circulation qw( AddReturn );
use Koha::Checkout;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string );

use base qw(Koha::Objects);

=head1 NAME

Koha::Checkouts - Koha Checkout object set class

=head1 API

=head2 Class Methods

=cut

=head3 calculate_dropbox_date

my $dt = Koha::Checkouts::calculate_dropbox_date();

=cut

sub calculate_dropbox_date {
    my $userenv    = C4::Context->userenv;
    my $branchcode = $userenv->{branch} // q{};

    my $daysmode = Koha::CirculationRules->get_effective_daysmode(
        {
            categorycode => undef,
            itemtype     => undef,
            branchcode   => $branchcode,
        }
    );
    my $calendar     = Koha::Calendar->new( branchcode => $branchcode, days_mode => $daysmode );
    my $today        = dt_from_string;
    my $dropbox_date = $calendar->addDuration( $today, -1 );

    return $dropbox_date;
}

=head3 automatic_checkin

my $automatic_checkins = Koha::Checkouts->automatic_checkin()

Checks in every due issue which itemtype has automatic_checkin enabled. Also if the AutoCheckinAutoFill system preference is enabled, the item is trapped for the next patron.

=cut

sub automatic_checkin {
    my ( $self, $params ) = @_;

    my $current_date = dt_from_string;

    my $dtf           = Koha::Database->new->schema->storage->datetime_parser;
    my $due_checkouts = $self->search(
        { date_due => { '<=' => $dtf->format_datetime($current_date) } },
        { prefetch => 'item' }
    );

    my $autofill_next = C4::Context->preference('AutomaticCheckinAutoFill');

    while ( my $checkout = $due_checkouts->next ) {
        if ( $checkout->item->itemtype->automatic_checkin ) {
            my ( undef, $messages ) = C4::Circulation::AddReturn(
                $checkout->item->barcode, $checkout->branchcode, undef,
                dt_from_string( $checkout->date_due )
            );
            if ($autofill_next) {
                if ( $messages->{ResFound} ) {
                    my $is_transfer = $checkout->branchcode ne $messages->{ResFound}->{branchcode};
                    C4::Reserves::ModReserveAffect(
                        $checkout->item->itemnumber, $checkout->borrowernumber,
                        $is_transfer, $messages->{ResFound}->{reserve_id}, $checkout->{desk_id}, 0
                    );
                    if ($is_transfer) {
                        C4::Items::ModItemTransfer(
                            $checkout->item->itemnumber,         $checkout->branchcode,
                            $messages->{ResFound}->{branchcode}, "Reserve"
                        );
                    }
                }
            }
        }
    }
}

=head3 type

=cut

sub _type {
    return 'Issue';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Checkout';
}

=head3 GetOverduesBy

my $overdues = Koha::Checkouts::GetOverdues( $parameters )

Fetches all overdues, and optionally filters by
- patron OR patron category  AND/OR  
- item home OR issue branch

=cut

sub GetOverduesBy {
    my ($parameters) = shift;

    my %attributes;

    if ( $parameters->{get_summary} != 1 ) {
        $attributes{prefetch} = {
            'patron' => 'category',
            'item'   => [ 'homebranch', { 'biblio' => 'biblioitem' } ]
        };
    } else {
        $attributes{join} = {
            'patron' => 'category',
            'item'   => [ 'homebranch', { 'biblio' => 'biblioitem' } ]
        };
        $attributes{'+select'} = [
            'borrowernumber',
            'patron.firstname',
            'patron.surname',
            'patron.address',
            'patron.address2',
            'patron.city',
            'patron.zipcode',
            'patron.country',
            'patron.email',
            'patron.emailpro',
            'patron.B_email',
            'patron.smsalertnumber',
            'patron.phone',
            'patron.cardnumber',
            'biblioitem.itemtype',
            'homebranch.branchname',
            'category.overduenoticerequired',
            'item.homebranch',
        ];
        $attributes{'+as'} = [
            'borrowernumber',
            'patron_firstname',
            'patron_surname',
            'patron_address',
            'patron_address2',
            'patron_city',
            'patron_zipcode',
            'patron_country',
            'patron_email',
            'patron_emailpro',
            'patron_B_email',
            'patron_smsalertnumber',
            'patron_phone',
            'patron_cardnumber',
            'biblioitem_itemtype',
            'homebranch_branchname',
            'category_overduenoticerequired',
            'item_homebranch',
        ];
    }

    # FILTERS:

    my %conditions;

    # patron (borrowernumber) or patron categorycode
    if ( defined $parameters->{'borrowernumber'} ) {
        $conditions{'me.borrowernumber'} = $parameters->{'borrowernumber'};
    } elsif ( defined $parameters->{'patron_categorycode'} ) {
        $conditions{'patron.categorycode'} = $parameters->{'patron_categorycode'};
    }

    # owning or issue branch
    if ( defined $parameters->{'item_homebranch'} ) {
        $conditions{'item.homebranch'} = $parameters->{'item_homebranch'};
    } elsif ( defined $parameters->{'item_issuebranch'} ) {
        $conditions{'issue.branchcode'} = $parameters->{'item_issuebranch'};
    }

    # item type, either at bib or item level
    my $itemtypes = join( ", ", Koha::ItemTypes->search()->get_column('itemtype') );
    if ( C4::Context->preference('item-level_itypes') ) {
        $conditions{'item.itype'} = { '-in', $itemtypes };
    } else {
        $conditions{'biblioitem.itemtype'} = { '-in', $itemtypes };
    }

    my $checkouts_set = Koha::Checkouts->new();

    try {
        my $search_rs = $checkouts_set->search( \%conditions, \%attributes );
        my @results;

        # may want to leave this iteration in the script so we don't iterate twice
        while ( my $row = $search_rs->next() ) {
            push( @results, $row );
        }
        return @results;

    } catch {
        $checkouts_set->unhandled_exception($_);
    };
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

=head3 filter_by_overdue

my $overdue_checkouts = Koha::Checkouts->filter_by_overdue({
    date => $date,                     # optional, defaults to today
    item_homebranch => $branchcode,    # optional
    item_issuebranch => $branchcode,   # optional alternative to homebranch
    patron_categorycode => $categorycode, # optional
    borrowernumber => $borrowernumber,    # optional
    include_lost => 0,                 # optional, defaults to 0 (exclude lost items)
    require_notice => 1,               # optional, defaults to 1 (require overduenoticerequired)
});

Returns a Koha::Checkouts object containing overdue checkouts matching the specified criteria.
This method uses modern SQL::Abstract syntax and DBIx::Class relationships.

=cut

sub filter_by_overdue {
    my ( $self, $params ) = @_;
    $params //= {};

    my $reference_date = $params->{date} || dt_from_string();
    my $dtf            = Koha::Database->new->schema->storage->datetime_parser;

    # Base overdue condition
    my $conditions = { date_due => { '<' => $dtf->format_datetime($reference_date) } };

    # Optional: exclude lost items (default behavior)
    unless ( $params->{include_lost} ) {
        $conditions->{'item.itemlost'} = 0;
    }

    # Optional: require overduenoticerequired (default behavior)
    if ( $params->{require_notice} // 1 ) {
        $conditions->{'borrower.category.overduenoticerequired'} = 1;
    }

    # Optional: filter by patron
    if ( $params->{borrowernumber} ) {
        $conditions->{borrowernumber} = $params->{borrowernumber};
    }

    # Optional: filter by patron category
    if ( $params->{patron_categorycode} ) {
        $conditions->{'borrower.categorycode'} = $params->{patron_categorycode};
    }

    # Optional: filter by item homebranch or issuebranch
    if ( $params->{item_homebranch} ) {
        $conditions->{'item.homebranch'} = $params->{item_homebranch};
    } elsif ( $params->{item_issuebranch} ) {
        $conditions->{branchcode} = $params->{item_issuebranch};
    }

    # Join with related tables for filtering and data access
    my $join_conditions = {
        join => {
            item => {
                biblio       => 'biblioitems',
                home_library => undef
            },
            borrower => 'category'
        },
        prefetch => {
            item => {
                biblio       => 'biblioitems',
                home_library => undef
            },
            borrower => 'category'
        }
    };

    return $self->search( $conditions, $join_conditions );
}

1;
