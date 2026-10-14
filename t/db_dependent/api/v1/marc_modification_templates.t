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
use Test::More tests => 5;
use Test::Mojo;
use YAML::XS qw( LoadFile );

use t::lib::TestBuilder;
use t::lib::Mocks;

use C4::Context;
use Koha::Database;
use Koha::MarcModificationTemplates;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;
my $dbh     = C4::Context->dbh;

t::lib::Mocks::mock_preference( 'RESTBasicAuth', 1 );

my $t = Test::Mojo->new('Koha::REST::V1');

my $password = 'thePassword123';

sub patron_with_tools_permission {
    my ($code) = @_;
    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { flags => 4096 } } );
    if ($code) {
        $dbh->prepare(
            "INSERT INTO user_permissions (borrowernumber, module_bit, code) SELECT ?, bit, ? FROM userflags WHERE flag = ?"
        )->execute( $patron->borrowernumber, $code, 'tools' );
    }
    $patron->set_password( { password => $password, skip_validation => 1 } );
    return $patron;
}

subtest 'unauthorised access' => sub {
    plan tests => 4;
    $schema->storage->txn_begin;

    my $nopermission = patron_with_tools_permission();
    my $uid          = $nopermission->userid;

    $t->get_ok("//$uid:$password@/api/v1/marc_modification_templates")->status_is(403);

    my $template = $builder->build_object( { class => 'Koha::MarcModificationTemplates' } );
    $t->get_ok( "//$uid:$password@/api/v1/marc_modification_templates/" . $template->template_id )->status_is(403);

    $schema->storage->txn_rollback;
};

subtest 'list() tests' => sub {
    plan tests => 20;
    $schema->storage->txn_begin;

    Koha::MarcModificationTemplates->search->delete;
    my $t1 = $builder->build_object( { class => 'Koha::MarcModificationTemplates', value => { name => 'A_MMT' } } );
    my $t2 = $builder->build_object( { class => 'Koha::MarcModificationTemplates', value => { name => 'B_MMT' } } );

    # Any one of these permissions is enough
    for my $code (qw(stage_marc_import manage_staged_marc marc_modification_templates records_batchmod)) {
        my $patron = patron_with_tools_permission($code);
        my $uid    = $patron->userid;
        $t->get_ok("//$uid:$password@/api/v1/marc_modification_templates?_order_by=+name")
            ->status_is( 200, "list allowed with $code" )
            ->json_is( '/0/name' => 'A_MMT' )
            ->json_is( '/1/name' => 'B_MMT' );
    }

    my $patron = patron_with_tools_permission('stage_marc_import');
    my $uid    = $patron->userid;
    $t->get_ok("//$uid:$password@/api/v1/marc_modification_templates?name=B_MMT")
        ->status_is(200)
        ->json_is( '/0/marc_modification_template_id' => $t2->template_id )
        ->json_hasnt('/1');

    $schema->storage->txn_rollback;
};

subtest 'get() tests' => sub {
    plan tests => 8;
    $schema->storage->txn_begin;

    my $template = $builder->build_object( { class => 'Koha::MarcModificationTemplates' } );
    my $patron   = patron_with_tools_permission('stage_marc_import');
    my $uid      = $patron->userid;
    my $id       = $template->template_id;

    $t->get_ok("//$uid:$password@/api/v1/marc_modification_templates/$id")
        ->status_is(200)
        ->json_is( '' => $template->to_api, 'Template returned as API representation' );

    my $missing = $id + 100000;
    $t->get_ok("//$uid:$password@/api/v1/marc_modification_templates/$missing")
        ->status_is(404)
        ->json_is( '/error' => 'MARC modification template not found' );

    $t->get_ok("//$uid:$password@/api/v1/marc_modification_templates/notanumber")->status_is(400);

    $schema->storage->txn_rollback;
};

subtest 'definition' => sub {
    plan tests => 1;

    my $definition = LoadFile('api/v1/swagger/definitions/marc_modification_template.yaml');

    # Every column is NOT NULL, so every exposed field is always present
    is_deeply(
        [ sort @{ $definition->{required} } ],
        [ sort keys %{ $definition->{properties} } ],
        'All properties are listed as required'
    );
};
