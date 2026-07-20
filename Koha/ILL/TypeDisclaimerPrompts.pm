package Koha::ILL::TypeDisclaimerPrompts;

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
use Koha::ILL::TypeDisclaimerPrompt;
use base qw(Koha::Objects);

=head1 TypeDisclaimerPrompts

Koha::ILL::Request - Koha ILL type disclaimer prompt Objects class

=head2 Internal methods

=head3 _type

The corresponding Result class.

=cut

sub _type {
    return 'IllTypeDisclaimerPrompt';
}

=head3 object_class

The corresponding singular Object class.

=cut

sub object_class {
    return 'Koha::ILL::TypeDisclaimerPrompt';
}

1;
