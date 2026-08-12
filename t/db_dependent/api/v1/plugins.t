#!/usr/bin/env perl

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

use Test::More tests => 2;
use Test::NoWarnings;
use Test::Mojo;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

my $t = Test::Mojo->new('Koha::REST::V1');
t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

subtest 'add() respects plugins_restricted' => sub {

    plan tests => 2;

    $schema->storage->txn_begin;

    my $password = 'thePassword123';
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { flags => 2**19 }    # plugins flag
        }
    );
    $patron->set_password( { password => $password, skip_validation => 1 } );
    my $userid = $patron->userid;

    t::lib::Mocks::mock_config( 'plugins_restricted', 1 );
    t::lib::Mocks::mock_config( 'enable_plugins',     1 );

    $t->post_ok(
        "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://evil.example.com/plugin.kpz' } )
        ->status_is( 403, 'A kpz_url with an unresolvable plugin-store origin is rejected, not silently installed' );

    $schema->storage->txn_rollback;
};
