package Koha::Holds;

# Copyright ByWater Solutions 2014
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

use Koha::Database;

use Koha::Hold;

use base qw(Koha::Objects);

=head1 NAME

Koha::Holds - Koha Hold object set class

=head1 API

=head2 Class methods

=head3 filter_by_found

    my $found_holds = $holds->filter_by_found;

Returns a filtered resultset without holds that are considered I<found>.
i.e. 'P', 'T' and 'W'.

=cut

sub filter_by_found {
    my ($self) = @_;

    return $self->search( { found => [ 'P', 'T', 'W' ] } );
}

=head3 waiting

returns a set of holds that are waiting from an existing set

=cut

sub waiting {
    my ($self) = @_;

    return $self->search( { found => 'W' } );
}

=head3 processing

returns a set of holds that are processing from an existing set

=cut

sub processing {
    my ($self) = @_;

    return $self->search( { found => 'P' } );
}

=head3 unfilled

returns a set of holds that are unfilled from an existing set

=cut

sub unfilled {
    my ($self) = @_;

    return $self->search( { found => undef } );
}

=head3 forced_hold_level

If a patron has multiple holds for a single record,
those holds must be either all record level holds,
or they must all be item level holds.

This method should be used with Hold sets where all
Hold objects share the same patron and record.

This method will return 'item' if the patron has
at least one item level hold. It will return 'record'
if the patron has holds but none are item level,
Finally, if the patron has no holds, it will return
undef which indicates the patron may select either
record or item level holds, barring any other rules
that would prevent one or the other.

=cut

sub forced_hold_level {
    my ($self) = @_;

    my $item_level_count = $self->search( { itemnumber => { '!=' => undef } } )->count();
    return 'item' if $item_level_count > 0;

    my $item_group_level_count = $self->search( { item_group_id => { '!=' => undef } } )->count();
    return 'item_group' if $item_group_level_count > 0;

    my $record_level_count = $self->search( { itemnumber => undef } )->count();
    return 'record' if $record_level_count > 0;

    return;
}

=head3 get_items_that_can_fill

    my $items = $holds->get_items_that_can_fill();

Return the list of items that can fill the hold set.

Items that are not:

  in transit
  waiting
  lost
  widthdrawn
  not for loan
  not on loan
  in closed stack

=cut

sub get_items_that_can_fill {
    my ($self) = @_;

    return Koha::Items->new->empty()
        unless $self->count() > 0;

    my @itemnumbers   = $self->search( { 'me.itemnumber' => { '!=' => undef } } )->get_column('itemnumber');
    my @biblionumbers = $self->search( { 'me.itemnumber' => undef } )->get_column('biblionumber');
    my @bibs_or_items;
    push @bibs_or_items, 'me.itemnumber'   => { in => \@itemnumbers }   if @itemnumbers;
    push @bibs_or_items, 'me.biblionumber' => { in => \@biblionumbers } if @biblionumbers;

    my @branchtransfers = Koha::Item::Transfers->filter_by_current->search(
        {},
        {
            columns  => ['itemnumber'],
            collapse => 1,
        }
    )->get_column('itemnumber');
    my @waiting_holds = Koha::Holds->search(
        { 'found' => 'W' },
        {
            columns  => ['itemnumber'],
            collapse => 1,
        }
    )->get_column('itemnumber');

    return Koha::Items->search(
        {
            -or             => \@bibs_or_items,
            itemnumber      => { -not_in => [ @branchtransfers, @waiting_holds ] },
            onloan          => undef,
            notforloan      => 0,
            is_closed_stack => 0,
        }
    )->filter_by_for_hold();
}

=head3 filter_by_has_cancellation_requests

    my $with_cancellation_reqs = $holds->filter_by_has_cancellation_requests;

Returns a filtered resultset only containing holds that have cancellation requests.

=cut

sub filter_by_has_cancellation_requests {
    my ($self) = @_;

    return $self->search(
        { 'hold_cancellation_request_id' => { '!=' => undef } },
        { join                           => 'cancellation_requests' }
    );
}

=head3 filter_out_has_cancellation_requests

    my $holds_without_cancellation_requests = $holds->filter_out_has_cancellation_requests;

Returns a filtered resultset without holds with cancellation requests.

=cut

sub filter_out_has_cancellation_requests {
    my ($self) = @_;

    return $self->search(
        { 'hold_cancellation_request_id' => { '=' => undef } },
        { join                           => 'cancellation_requests' }
    );
}

=head3 filter_by_closed_stack_requests

Apply filter to keep only closed stack requests

    $holds = Koha::Holds->search($filter)->filter_by_closed_stack_requests();

Returns a C<Koha::Holds> object

=cut

sub filter_by_closed_stack_requests {
    my ($self) = @_;

    return $self->search( $self->_closed_stack_request_filter, { join => 'item' } );
}

=head3 filter_out_closed_stack_requests

Apply filter to exclude closed stack requests

    $holds = Koha::Holds->search($filter)->filter_out_closed_stack_requests();

Returns a C<Koha::Holds> object

=cut

sub filter_out_closed_stack_requests {
    my ($self) = @_;

    return $self->search( { -not_bool => $self->_closed_stack_request_filter }, { join => 'item' } );
}

sub _closed_stack_request_filter {

    # This query returns the top priority reserve's id for each item
    my $reserve_id_subselect = q{
        select reserve_id from (
            select reserve_id, itemnumber, row_number() over (partition by itemnumber order by priority) rank
            from reserves where itemnumber is not null
        ) r
        where rank = 1
    };

    my %where = (
        'me.reserve_id'        => { -in => \$reserve_id_subselect },
        'me.suspend'           => 0,
        'me.found'             => undef,
        'me.priority'          => { '!=' => 0 },
        'item.itemlost'        => 0,
        'item.withdrawn'       => 0,
        'item.onloan'          => undef,
        'item.is_closed_stack' => 1,
        'item.itemnumber'      => {
            -not_in => \'SELECT itemnumber FROM branchtransfers WHERE datearrived IS NULL AND datecancelled IS NULL'
        },
    );

    if ( !C4::Context->preference('AllowHoldsOnDamagedItems') ) {
        $where{'item.damaged'} = 0;
    }

    if ( C4::Context->only_my_library() ) {
        $where{'me.branchcode'} = C4::Context->userenv->{'branch'};
    }

    return \%where;
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'Reserve';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::Hold';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
