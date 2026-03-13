#!/usr/bin/perl

# This file is part of Koha
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

use Test::NoWarnings;
use Test::More tests => 3;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';

sub authorized_patron {
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $builder->build(
        {
            source => 'UserPermission',
            value  => {
                borrowernumber => $patron->borrowernumber,
                module_bit     => 3,
                code           => 'manage_identity_providers',
            },
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    return $patron;
}

subtest 'generate_certificate() authorization tests' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 0 }
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    $t->post_ok( "//$userid:$password@/api/v1/auth/identity_providers/saml2/certificate" => json =>
            { common_name => 'sp.example.com' } )->status_is( 403, 'Requires manage_identity_providers' );

    $schema->storage->txn_rollback;
};

subtest 'generate_certificate() validation and generation tests' => sub {

    plan tests => 20;

    $schema->storage->txn_begin;

    my $patron = authorized_patron();
    my $userid = $patron->userid;
    my $url    = "//$userid:$password@/api/v1/auth/identity_providers/saml2/certificate";

    # Missing common_name is rejected by the OpenAPI schema layer before the
    # controller runs, so only the status is stable
    $t->post_ok( $url => json => {} )->status_is(400);

    # Invalid characters in common_name
    $t->post_ok( $url => json => { common_name => 'sp.example.com; rm -rf' } )
        ->status_is(400)
        ->json_is( '/error_code', 'invalid_parameter_value' );

    # Unsupported key size
    $t->post_ok( $url => json => { common_name => 'sp.example.com', key_size => 3072 } )
        ->status_is(400)
        ->json_is( '/error_code', 'invalid_parameter_value' );

    # validity_days out of range (low and high)
    $t->post_ok( $url => json => { common_name => 'sp.example.com', validity_days => 0 } )
        ->status_is(400)
        ->json_is( '/error_code', 'invalid_parameter_value' );
    $t->post_ok( $url => json => { common_name => 'sp.example.com', validity_days => 3651 } )
        ->status_is(400)
        ->json_is( '/error_code', 'invalid_parameter_value' );

    # Valid request returns a PEM certificate and key
    $t->post_ok( $url => json => { common_name => 'sp.example.com', key_size => 2048, validity_days => 30 } )
        ->status_is(201);
    like( $t->tx->res->json->{certificate}, qr/-----BEGIN CERTIFICATE-----/,        'PEM certificate returned' );
    like( $t->tx->res->json->{private_key}, qr/-----BEGIN (RSA )?PRIVATE KEY-----/, 'PEM private key returned' );

    # Slashes in the CN (entity IDs) must not break subject parsing
    $t->post_ok( $url => json => { common_name => 'https://sp.example.com/saml/metadata' } )->status_is(201);

    $schema->storage->txn_rollback;
};
