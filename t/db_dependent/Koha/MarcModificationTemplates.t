#!/usr/bin/perl

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
use Test::More tests => 3;

use Koha::Database;
use Koha::MarcModificationTemplates;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'search() returns Koha::MarcModificationTemplate objects' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    my $template = $builder->build_object(
        { class => 'Koha::MarcModificationTemplates', value => { name => 'MMT search test' } } );

    my $found = Koha::MarcModificationTemplates->search( { name => 'MMT search test' } )->next;
    isa_ok( $found, 'Koha::MarcModificationTemplate' );
    is( $found->template_id, $template->template_id, 'Same template found' );
    is(
        Koha::MarcModificationTemplates->search( { name => 'no such template' } )->count, 0,
        'Nothing found for unknown name'
    );

    $schema->storage->txn_rollback;
};

subtest 'to_api() uses marc_modification_template_id' => sub {
    plan tests => 3;
    $schema->storage->txn_begin;

    my $template =
        $builder->build_object( { class => 'Koha::MarcModificationTemplates', value => { name => 'MMT api test' } } );

    my $api = $template->to_api;
    is( $api->{marc_modification_template_id}, $template->template_id, 'id mapped from template_id' );
    ok( !exists $api->{template_id}, 'template_id not exposed' );
    is( $api->{name}, 'MMT api test', 'name exposed' );

    $schema->storage->txn_rollback;
};
