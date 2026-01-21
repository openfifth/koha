package Koha::Patron::AccountLink;

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
use Koha::Patron::AccountLinks;
use Koha::Patrons;

use base qw(Koha::Object);

=head1 NAME

Koha::Patron::AccountLink - Represents a link between patron accounts

=head1 DESCRIPTION

Patrons in Koha may have multiple accounts at different libraries within a
consortium. This class models those links and provides access to linked accounts.

=head1 API

=head2 Class methods

=head3 patron

Returns the Koha::Patron object for this link

=cut

sub patron {
    my ($self) = @_;
    return Koha::Patrons->find( $self->borrowernumber );
}

=head3 linked_patrons

Returns Koha::Patrons of all OTHER patrons in this link group (excluding self)

=cut

sub linked_patrons {
    my ($self) = @_;

    my @borrowernumbers = Koha::Patron::AccountLinks->search(
        {
            link_group_id  => $self->link_group_id,
            borrowernumber => { '!=' => $self->borrowernumber }
        }
    )->get_column('borrowernumber');

    return Koha::Patrons->search( { borrowernumber => \@borrowernumbers } );
}

=head3 all_linked_borrowernumbers

Returns arrayref of all borrowernumbers in link group (including self)

=cut

sub all_linked_borrowernumbers {
    my ($self) = @_;

    my @borrowernumbers =
        Koha::Patron::AccountLinks->search( { link_group_id => $self->link_group_id } )->get_column('borrowernumber');

    return \@borrowernumbers;
}

=head3 delete

Override delete to clean up orphaned links.

When a patron leaves a linked group, if only one patron remains,
that patron's link is also deleted (they would be an orphan).

=cut

sub delete {
    my ($self) = @_;

    my $link_group_id = $self->link_group_id;

    # Delete this link
    $self->SUPER::delete;

    # Check for orphans in the group
    my @remaining = Koha::Patron::AccountLinks->search( { link_group_id => $link_group_id } )->as_list;

    # If only one patron remains, delete their orphan link too
    if ( @remaining == 1 ) {
        $remaining[0]->SUPER::delete;
    }

    return $self;
}

=head3 to_api_mapping

=cut

sub to_api_mapping {
    return {
        id             => 'account_link_id',
        link_group_id  => 'link_group_id',
        borrowernumber => 'patron_id',
        created_on     => 'created_on',
    };
}

=head2 Internal methods

=head3 _type

=cut

sub _type {
    return 'PatronAccountLink';
}

1;
