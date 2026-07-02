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

use Test::NoWarnings;
use Test::More tests => 4;
use Test::Exception;

use Mojo::JWT;

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Database;

BEGIN {
    use_ok('Koha::Module::Policy');
    use_ok('Koha::Module::Policy::Checkin');
}

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'Koha::Module::Policy base class tests' => sub {

    plan tests => 3;

    subtest 'new() tests' => sub {

        plan tests => 5;

        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
        my $library = $builder->build_object( { class => 'Koha::Libraries' } );

        throws_ok {
            Koha::Module::Policy->new( { library => $library->branchcode } );
        }
        'Koha::Exceptions::MissingParameter', 'Throws without user';

        my $policy;
        lives_ok {
            $policy = Koha::Module::Policy->new( { user => $patron } );
        }
        'Constructor succeeds with user only (library optional)';

        lives_ok {
            $policy = Koha::Module::Policy->new(
                {
                    user    => $patron,
                    library => $library->branchcode,
                }
            );
        }
        'Constructor succeeds with user and library';

        is( $policy->user->id, $patron->id,          'user accessor returns the patron' );
        is( $policy->library,  $library->branchcode, 'library accessor returns the branchcode' );

        $schema->storage->txn_rollback;
    };

    subtest '_build_hashref() tests' => sub {

        plan tests => 1;

        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
        my $library = $builder->build_object( { class => 'Koha::Libraries' } );

        my $policy = Koha::Module::Policy->new(
            {
                user    => $patron,
                library => $library->branchcode,
            }
        );

        throws_ok {
            $policy->to_hashref;
        }
        'Koha::Exception', 'Base class _build_hashref throws (abstract)';

        $schema->storage->txn_rollback;
    };

    subtest 'scope() tests' => sub {

        plan tests => 1;

        $schema->storage->txn_begin;

        my $patron  = $builder->build_object( { class => 'Koha::Patrons' } );
        my $library = $builder->build_object( { class => 'Koha::Libraries' } );

        my $policy = Koha::Module::Policy::Checkin->new(
            {
                user    => $patron,
                library => $library->branchcode,
            }
        );

        is( $policy->scope, 'checkin', 'scope() derives from class name' );

        $schema->storage->txn_rollback;
    };
};
