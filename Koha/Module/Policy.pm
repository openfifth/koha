package Koha::Module::Policy;

# Copyright 2026 Koha Development Team
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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use C4::Context;
use Koha::Exceptions;
use Koha::Token;

=head1 NAME

Koha::Module::Policy - Base class for module-scoped policy contracts

=head1 SYNOPSIS

    # Subclass implementation
    package Koha::Module::Policy::Checkin;
    use parent 'Koha::Module::Policy';

    sub _build_hashref { ... }

    # Usage in a controller
    my $policy = Koha::Module::Policy::Checkin->new(
        {
            user    => $c->stash('koha.user'),
            library => $library,
        }
    );

    $c->res->headers->header('X-Koha-Module-Policy' => $policy->as_jwt);

    # Client reads the JWT payload to know what the UI should offer.

=head1 DESCRIPTION

A module policy represents the current capabilities available to a specific
user, at a specific library, for a given functional module (checkin, checkout,
ERM, etc.).

It is the intersection of:

=over 4

=item * System preferences (feature toggles)

=item * User permissions (what this staff member can do)

=item * Library context (branch-specific configuration)

=back

The policy is serialized as a signed JWT and attached to API responses via a
header. The client decodes the payload to render the appropriate UI controls.
The server remains authoritative - the JWT is informational, not an access
token. Every action is still validated server-side.

=head1 API

=head2 Class methods

=head3 new

    my $policy = Koha::Module::Policy::Checkin->new(
        {
            user    => $patron_object,
            library => $library_id,
        }
    );

Constructor. Requires:

=over 4

=item * user - A Koha::Patron object representing the logged-in staff member

=back

Optional:

=over 4

=item * library - The branchcode (string) where the action takes place

=back

Subclasses may accept and use additional parameters.

=cut

sub new {
    my ( $class, $params ) = @_;

    Koha::Exceptions::MissingParameter->throw("'user' is required")
        unless $params->{user};

    my $self = { %$params, _cache => undef };
    bless $self, $class;

    # Compute global policy keys once at construction — these are shared
    # across all modules and cannot be overridden by subclasses.
    $self->{_global} = {
        audio_alerts     => C4::Context->preference('AudioAlerts')     ? 1 : 0,
        catalog_concerns => C4::Context->preference('CatalogConcerns') ? 1 : 0,
    };

    return $self;
}

=head2 Instance methods

=head3 user

    my $user = $policy->user;

Returns the Koha::Patron object.

=cut

sub user { return $_[0]->{user} }

=head3 library

    my $library_id = $policy->library;

Returns the library branchcode.

=cut

sub library { return $_[0]->{library} }

=head3 to_hashref

    my $hashref = $policy->to_hashref;

Returns the policy as a plain hashref. Result is cached for the lifetime
of the object.

The returned hashref has two layers:

=over 4

=item * B<global> - A nested hashref of keys common to all modules, computed
by the base class constructor. Subclasses cannot override these.

=item * B<module-specific keys> - Flat keys returned by the subclass's
C<_build_hashref> method.

=back

Example structure:

    {
        global => {
            audio_alerts     => 1,
            catalog_concerns => 0,
        },
        exempt_fine         => 1,
        specify_return_date => 1,
        ...
    }

=head2 Global policy keys

The following keys are provided under the C<global> namespace for all
module policies. They are computed once at construction time from system
preferences and cannot be overridden by subclasses.

=over 4

=item B<audio_alerts> - Audio alerts are enabled (C<AudioAlerts> syspref)

=item B<catalog_concerns> - "Report a concern" feature is available (C<CatalogConcerns> syspref)

=back

=cut

sub to_hashref {
    my ($self) = @_;
    $self->{_cache} //= {
        global => $self->{_global},
        %{ $self->_build_hashref },
    };
    return $self->{_cache};
}

=head3 as_jwt

    my $token = $policy->as_jwt;

Returns the policy serialized as a signed JWT string. The payload is
the hashref from C<to_hashref>.

=cut

sub as_jwt {
    my ($self) = @_;
    return Koha::Token->new->encode_claims( $self->to_hashref );
}

=head3 scope

    my $scope = $policy->scope;

Returns the policy scope name (e.g., 'checkin', 'checkout', 'erm').
Derived from the class name by default.

Subclasses may override this.

=cut

sub scope {
    my ($self)  = @_;
    my $class   = ref($self) || $self;
    my ($scope) = $class =~ /::([^:]+)$/;
    return lc($scope);
}

=head2 Abstract methods

=head3 _build_hashref

    my $hashref = $self->_build_hashref;

Subclasses B<must> implement this method. It should return a hashref
representing the current policy state for the user/library combination.

Keys should be stable identifiers (the client's contract). Values are
booleans, integers, or simple strings. Never expose raw syspref names.

=cut

sub _build_hashref {
    Koha::Exception->throw("Subclass must implement _build_hashref");
}

=head1 TODO

Add an B<env> namespace to carry session/environment context that every
module needs but that is not a feature flag. This would replace the
template params currently injected by C<C4::Auth::get_template_and_user>
for all pages — Vue-based and TT-based alike.

While this framework was designed for Vue module policies, it is equally
a refactoring of the monolithic and unmaintainable code in
C<get_template_and_user>, which today scatters 50+ individually-set
template params with no structure, no contract, and no testability.
The policy pattern provides all three: structured data, a stable client
contract, and a unit-testable class per module.

Candidate keys for the C<env> namespace:

    env => {
        dateformat    => 'metric',        # C4::Context->preference('dateformat')
        time_zone     => 'America/...',   # Library timezone
        language      => 'en',            # Interface language
        library_id    => 'CPL',           # Logged-in branch
        library_name  => 'Centerville',   # For display
        user_id       => 51,              # Borrowernumber
        single_branch => 0,              # Koha::Libraries->count == 1
    }

This separates concerns: C<global> = feature flags (sysprefs), C<env> =
session context, top-level = module-specific capabilities. Together they
provide the full UI contract, making C<get_template_and_user>'s param
injection redundant for pages that adopt this pattern.

=head1 AUTHOR

Koha Development Team <https://koha-community.org/>

=cut

1;
