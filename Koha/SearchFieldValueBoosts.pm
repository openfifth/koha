package Koha::SearchFieldValueBoosts;

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

use Koha::Database;
use Koha::SearchFields;
use Koha::SearchFieldValueBoost;

use base qw(Koha::Objects);

=head1 NAME

Koha::SearchFieldValueBoosts - Koha SearchFieldValueBoost Object set class

=head1 API

=head2 Class Methods

=cut

=head3 existing_boosts_by_search_field_name

    my $existing_boosts = Koha::SearchFieldValueBoosts->existing_boosts_by_search_field_name;

Returns a hashref of all existing value boosts, keyed by search field name (stable across a
delete-and-recreate of the search_field table) and then by boosted value, mapping to the
configured weight.

=cut

sub existing_boosts_by_search_field_name {
    my ($class) = @_;

    my %existing_boosts;
    for my $boost ( $class->search( {}, { prefetch => 'search_field' } )->as_list ) {
        $existing_boosts{ $boost->search_field->name }{ $boost->value } = $boost->weight;
    }
    return \%existing_boosts;
}

=head3 restore_from_existing_boosts

    Koha::SearchFieldValueBoosts->restore_from_existing_boosts($existing_boosts);

Recreates value boosts from the hashref returned by C<existing_boosts_by_search_field_name>,
resolving each field name to its current Koha::SearchField id. Field names no longer present
are skipped.

=cut

sub restore_from_existing_boosts {
    my ( $class, $existing_boosts ) = @_;

    for my $field_name ( keys %$existing_boosts ) {
        my $search_field = Koha::SearchFields->find( { name => $field_name }, { key => 'name' } );
        next unless $search_field;
        while ( my ( $value, $weight ) = each %{ $existing_boosts->{$field_name} } ) {
            Koha::SearchFieldValueBoost->new(
                { search_field_id => $search_field->id, value => $value, weight => $weight } )->store;
        }
    }
}

=head3 _type

=cut

sub _type {
    return 'SearchFieldValueBoost';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::SearchFieldValueBoost';
}

1;
