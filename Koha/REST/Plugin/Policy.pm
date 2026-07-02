package Koha::REST::Plugin::Policy;

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

use Mojo::Base 'Mojolicious::Plugin';

=head1 NAME

Koha::REST::Plugin::Policy - Mojolicious plugin for module policy headers

=head1 SYNOPSIS

    # In the Koha REST app startup
    $self->plugin('Koha::REST::Plugin::Policy');

    # In any controller
    $c->attach_module_policy('Checkin');
    $c->attach_module_policy('Checkin', { library => $library_id });

=head1 DESCRIPTION

Provides helpers for attaching module policy JWTs to API responses via the
C<X-Koha-Module-Policy> header. The policy represents the current capabilities
available to the authenticated user at the given library for a specific module.

=head1 API

=head2 Helper methods

=cut

=head2 register

=cut

sub register {
    my ( $self, $app ) = @_;

=head3 attach_module_policy

    $c->attach_module_policy('Checkin');
    $c->attach_module_policy('Checkin', { library => 'CPL' });

Attaches the C<X-Koha-Module-Policy> response header with a signed JWT
representing the current policy for the given module scope.

Parameters:

=over 4

=item * C<$scope> (required) - Module name, e.g., 'Checkin', 'Checkout', 'ERM'.
    Maps to C<Koha::Module::Policy::$scope>.

=item * C<$params> (optional hashref):

=over 4

=item * C<library> - Branch code. Defaults to the authenticated user's branch.

=back

=back

=cut

    $app->helper(
        'attach_module_policy' => sub {
            my ( $c, $scope, $params ) = @_;

            $params //= {};

            my $user       = $c->stash('koha.user');
            my $library_id = $params->{library} // $user->branchcode;

            my $class = "Koha::Module::Policy::$scope";
            eval "require $class";    ## no critic (BuiltinFunctions::ProhibitStringyEval)
            return if $@;

            my $policy = $class->new(
                {
                    user    => $user,
                    library => $library_id,
                }
            );

            $c->res->headers->header( 'X-Koha-Module-Policy' => $policy->as_jwt );

            return;
        }
    );
}

1;
