package Koha::Overdues::ActionExecutor;

# Copyright Open Fifth 2025
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
use Koha::Logger;
use Koha::Items;
use Koha::Patron::Debarments qw( AddUniqueDebarment );
use C4::Accounts             qw( chargelostitem );
use C4::Circulation          qw( MarkIssueReturned );
use C4::Context;
use Koha::Patrons;
use Koha::Checkouts;
use Koha::Checkout;
use Koha::DateUtils qw( dt_from_string output_pref );

=head1 NAME

Koha::Overdues::ActionExecutor - Koha Overdue ActionExecutor object set class.

=head2 Class Methods

=cut

=head3 new

Instantiate the class.
=cut

sub new {
    my ($class) = @_;
    my $self = {
        action_batch_queue => [],
        notice_queue       => {},
    };
    return bless $self, $class;
}

=head3 route_item_actions_to_queue

Separate action sets into notice and standard action sets, and calls the relevant enqueing subroutine.

=cut

sub route_item_actions_to_queue {
    my ( $self, $effective_rule_sets, $overdue_item ) = @_;

    my $branchcode     = $self->_resolve_rule_context_branchcode($overdue_item);
    my $categorycode   = $overdue_item->{categorycode};
    my $itemtype       = $overdue_item->{itemtype};
    my $days_overdue   = $overdue_item->{days_overdue};
    my $borrowernumber = $overdue_item->{borrowernumber};

    my $actions_hashes = $effective_rule_sets->{"$branchcode|$categorycode|$itemtype|$days_overdue"}->{actions};

    if ( !$actions_hashes || !@$actions_hashes ) {
        return;
    }

    my %actions = map { $_->{type} => $_ } @$actions_hashes;

    # handle notice
    if ( $actions{notice} && defined $actions{notice}->{notice_code} && $actions{notice}->{notice_code} ne '' ) {
        my $notice_key =
            join( "|", $borrowernumber, $actions{notice}->{notice_code}, $actions{notice}->{mtt} // '', $days_overdue );
        $self->add_to_notice_queue(
            $notice_key,
            [ { item => $overdue_item, action => $actions{notice}, delay => $days_overdue } ]
        );
    }

    # handle action batch
    my %action_batch;
    for my $type (qw( restrict lost charge mark_returned forgive_fine )) {
        if ( !$actions{$type} ) {
            next;
        }

        if ( !defined $actions{$type}->{value} || $actions{$type}->{value} eq '' ) {
            next;
        }

        $action_batch{$type} = $actions{$type}{value};
    }

    if (%action_batch) {
        $self->add_to_action_batch_queue(
            {
                item    => $overdue_item,
                delay   => $days_overdue,
                actions => \%action_batch,
            }
        );
    }
}

=head3 process_action_queue

Process the standard queue.

=cut

sub process_action_queue {
    my ($self) = @_;

    foreach my $batch ( @{ $self->{action_batch_queue} } ) {
        my $overdue_item = $batch->{item};
        my $actions      = $batch->{actions};

        if ( $actions->{restrict} ) {
            $self->enact_restrict($overdue_item);
        }

        if ( $actions->{lost} ) {
            $self->enact_lost( $overdue_item, $actions->{lost} );
        }

        if ( $actions->{forgive_fine} ) {
            $self->enact_forgive_fine($overdue_item);
        }

        if ( $actions->{charge} ) {
            $self->enact_charge($overdue_item);
        }

        if ( $actions->{mark_returned} ) {
            $self->enact_mark_returned($overdue_item);
        }
    }
}

=head3 format_action_item

Takes in an item, an action, and a delay, and returns a formatted action_item to be processed.

=cut

sub format_action_item {
    my ( $self, $overdue_item, $action_hashref ) = @_;

    return { item => {%$overdue_item}, action => {%$action_hashref}, delay => $overdue_item->{days_overdue} };

    # FIXME: return { item =>  $overdue_item, action => $action_hashref, delay => $overdue_item->{days_overdue} };
}

=head3 format_notice_context

Takes in an item, an action, and a delay, and returns a formatted notice_context to be processed.

=cut

sub format_notice_context {
    my ( $self, $item, $action_hashref, $delay ) = @_;
    return { item => $item, action => $action_hashref, delay => $delay };
}

=head3 add_to_notice_queue

Adds an action item to the notice queue, or, if the key exists, updates it.
Takes in a notice_context, that is borrowernumber|notice_code|delay.
Takes in the action items to assign to this notice
=cut

sub add_to_notice_queue {
    my ( $self, $key, $action_item_array ) = @_;
    push @{ $self->{notice_queue}->{$key} }, @$action_item_array;
}

=head3 add_to_action_batch_queue

Adds an action item to the standard queue.

=cut

sub add_to_action_batch_queue {
    my ( $self, $action_item_batch ) = @_;
    push @{ $self->{action_batch_queue} }, $action_item_batch;
}

=head3 enact_restrict

Add an OVERDUES debarment for the patron associated with the overdue item.

=cut

sub enact_restrict {
    my ( $self, $overdue_item ) = @_;
    AddUniqueDebarment(
        {
            borrowernumber => $overdue_item->{borrowernumber},
            type           => 'OVERDUES',
            comment        => "OVERDUES_PROCESS " . output_pref( dt_from_string() ),
        }
    );
}

=head3 enact_lost

Set the item's lost status (and cancel outstanding transfers) via
L<Koha::Item/mark_lost>.

=cut

sub enact_lost {
    my ( $self, $overdue_item, $lost_value ) = @_;
    my $item = Koha::Items->find( $overdue_item->{itemnumber} );
    if ( !$item ) {
        Koha::Logger->get->warn("enact_lost: itemnumber $overdue_item->{itemnumber} not found — skipping");
        return;
    }
    $item->mark_lost($lost_value);
}

=head3 enact_forgive_fine

Forgive any outstanding UNRETURNED OVERDUE accountline(s) for this checkout via
L<Koha::Account/forgive_debit>. Gated by the trigger row's C<forgive_fine> rule
value in L</process_action_queue>; legacy C<WhenLostForgiveFine> is deprecated
and not consulted.

The audit-trail side effects (UNRETURNED → LOST status flip and zero-amount
accountline cleanup) are not part of this action — they fire from
L<Koha::Item/mark_lost>.

=cut

sub enact_forgive_fine {
    my ( $self, $overdue_item ) = @_;

    my $accountlines = Koha::Account::Lines->search(
        {
            borrowernumber  => $overdue_item->{borrowernumber},
            itemnumber      => $overdue_item->{itemnumber},
            issue_id        => $overdue_item->{issue_id},
            debit_type_code => 'OVERDUE',
            status          => 'UNRETURNED',
        }
    );

    my $account        = Koha::Account->new( { patron_id => $overdue_item->{borrowernumber} } );
    my $forgiven_count = 0;
    while ( my $accountline = $accountlines->next ) {
        my $credit = $account->forgive_debit( $accountline, { interface => 'cron' } );
        if ($credit) {
            $forgiven_count++;
        }
    }

    if ( $forgiven_count && C4::Context->preference('FinesLog') ) {
        Koha::Logger->get->info(
            "Overdue forgiven: borrower $overdue_item->{borrowernumber}, item $overdue_item->{itemnumber} ($forgiven_count line(s))"
        );
    }
}

=head3 enact_charge

Charge the patron the item's replacement fee.

Resolves the fee-context branch via LKoha::Checkout/branch_for_fee_context so the LOST accountline's library_id honours
LostChargesControl / HomeOrHoldingBranch. Records the accountline with interface 'cron'.

=cut

sub enact_charge {
    my ( $self, $overdue_item ) = @_;

    if ( !$overdue_item->{replacementfee} || $overdue_item->{replacementfee} == 0 ) {
        Koha::Logger->get->warn("No replacement fee set for itemnumber $overdue_item->{itemnumber} — skipping charge");
        return;
    }

    my $item   = Koha::Items->find( $overdue_item->{itemnumber} );
    my $patron = Koha::Patrons->find( $overdue_item->{borrowernumber} );
    my $issue  = Koha::Checkouts->search(
        {
            issue_id => $overdue_item->{issue_id},
        }
    )->next;

    my $rule_branch = Koha::Checkout->branch_for_fee_context(
        fee_type => 'LOST',
        patron   => $patron,
        item     => $item,
        issue    => $issue,
    );

    my $description = sprintf(
        "%s %s %s",
        $item->biblio ? ( $item->biblio->title // q{} ) : q{},
        $item->barcode        // q{},
        $item->itemcallnumber // q{},
    );

    Koha::Account->new( { patron_id => $overdue_item->{borrowernumber} } )->add_lost_replacement_fee(
        {
            item              => $item,
            issue             => $issue,
            library_id        => $rule_branch,
            interface         => 'cron',
            description       => $description,
            replacement_price => $overdue_item->{replacementfee},
        }
    );
}

=head3 enact_mark_returned

Mark the patron's checkout of this item as returned, honouring the patron's
privacy setting.

Important: MarkIssueReturned archives the issue to old_issues (reassigning
related accountlines to old_issue_id), clears items.onloan, records
last_returned_by, and may remove an OVERDUES debarment per
AutoRemoveOverduesRestrictions. Patron privacy=2 anonymises the archived
checkout.

=cut

sub enact_mark_returned {
    my ( $self, $overdue_item ) = @_;
    my $patron = Koha::Patrons->find( $overdue_item->{borrowernumber} );
    if ( !$patron ) {
        Koha::Logger->get->warn("enact_mark_returned: borrower $overdue_item->{borrowernumber} not found — skipping");
        return;
    }
    MarkIssueReturned(
        $overdue_item->{borrowernumber},
        $overdue_item->{itemnumber},
        undef,
        $patron->privacy,
    );
}

=head3 _resolve_rule_context_branchcode

  my $branchcode = $self->_resolve_rule_context_branchcode($overdue_item);

Resolves the branchcode used to key the effective rule-set lookup for an
overdue item, honoring the C<CircControl> and C<HomeOrHoldingBranch> sysprefs
(cf. the informative blurb in smart-rules.tt). In cron context (no userenv)
C<PickupLibrary> falls through to the item-side path, matching
C<C4::Circulation::_GetCircControlBranch>.

TODO: find this a better home. This is general circ-rule context resolution,
not overdue-specific. Candidate target: a public method on
C<Koha::CirculationRules> (or wherever C<_GetCircControlBranch> ends up
promoted to), taking scalars rather than objects so batch callers like the
overdues processor don't load Item + Patron per row.

=cut

sub _resolve_rule_context_branchcode {
    my ( $self, $overdue_item ) = @_;

    my $circ_control = C4::Context->preference('CircControl');
    if ( $circ_control eq 'PatronLibrary' ) {
        return $overdue_item->{patronhomebranch};
    }

    return ( C4::Context->preference('HomeOrHoldingBranch') eq 'homebranch' )
        ? $overdue_item->{itemhomebranch}
        : $overdue_item->{itemholdingbranch};
}

1;
