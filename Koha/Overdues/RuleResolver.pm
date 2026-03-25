package Koha::Overdues::RuleResolver;

use Modern::Perl;

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

use Koha::Exceptions;
use Koha::CirculationRules;
use Koha::Logger;

=head1 NAME

Koha::Overdues::RuleResolver - Koha Overdues RuleResolver object set class

=head1 API

=head2 Class Methods

=cut

my @action_names = ( 'notice', 'charge', 'lost', 'restrict', 'mark_returned', 'forgive_fine' );

=head3 new

Instantiate the class.
=cut

sub new {
    my ($class) = @_;
    my $self = {
        effective_overdue_rule_sets => {},
        raw_overdue_rule_sets       => {},
    };
    return bless $self, $class;
}

=head3 get_raw_overdue_rule_sets

Retrieves the effective overdue rule set values for a given context

=cut

sub get_raw_overdue_rule_sets {
    my ( $self, $branch_list, $category_list, $itemtype_list ) = @_;

    my $where = {
        'me.rule_name' => { -like => 'overdue\_%' },
        -and           => [
            -or => [
                { 'me.branchcode' => undef },
                { 'me.branchcode' => { -in => $branch_list } }
            ],
            -or => [
                { 'me.categorycode' => undef },
                { 'me.categorycode' => { -in => $category_list } }
            ],
            -or => [
                { 'me.itemtype' => undef },
                { 'me.itemtype' => { -in => $itemtype_list } }
            ],
        ]
    };

    try {
        my $rs = Koha::CirculationRules->search( $where, {} );
        return $rs;
    } catch {
        Koha::Logger->get->error("Failed to get overdue rule sets: $_");
        return;
    };
}

1;
