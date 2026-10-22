#!/usr/bin/perl

# Copyright Open Fifth 2025
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
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Test::NoWarnings;
use Test::More tests => 11;

use Koha::CirculationRules;
use Koha::Database;
use Koha::Overdues::RuleResolver;

use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

subtest 'new' => sub {
    plan tests => 3;

    my $resolver = Koha::Overdues::RuleResolver->new;
    isa_ok( $resolver, 'Koha::Overdues::RuleResolver' );
    is_deeply( $resolver->{raw_overdue_rule_sets},       {}, 'raw_overdue_rule_sets initialised empty' );
    is_deeply( $resolver->{effective_overdue_rule_sets}, {}, 'effective_overdue_rule_sets initialised empty' );
};

subtest '_get_fallback_contexts' => sub {
    plan tests => 1;

    my $resolver = Koha::Overdues::RuleResolver->new;
    my $keys     = $resolver->_get_fallback_contexts( 'BR', 'PC', 'IT', 1 );

    is_deeply(
        $keys,
        [
            'BR|PC|IT|1',
            'BR|PC|*|1',
            'BR|*|IT|1',
            'BR|*|*|1',
            '*|PC|IT|1',
            '*|PC|*|1',
            '*|*|IT|1',
            '*|*|*|1',
        ],
        'fallback context list ordered from most-specific to default'
    );
};

subtest 'set_raw_overdue_rule_sets' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $branchcode   = $builder->build( { source => 'Branch' } )->{branchcode};
    my $categorycode = $builder->build( { source => 'Category' } )->{categorycode};
    my $itemtype     = $builder->build( { source => 'Itemtype' } )->{itemtype};

    Koha::CirculationRules->set_rule(
        {
            branchcode   => $branchcode,
            categorycode => $categorycode,
            itemtype     => $itemtype,
            rule_name    => 'overdue_1_delay',
            rule_value   => 7,
        }
    );
    Koha::CirculationRules->set_rule(
        {
            branchcode   => $branchcode,
            categorycode => $categorycode,
            itemtype     => $itemtype,
            rule_name    => 'overdue_1_lost',
            rule_value   => 1,
        }
    );

    # A trigger with no delay rule of its own is kept, to inherit one later.
    Koha::CirculationRules->set_rule(
        {
            branchcode   => $branchcode,
            categorycode => $categorycode,
            itemtype     => $itemtype,
            rule_name    => 'overdue_9_charge',
            rule_value   => 1,
        }
    );

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->set_raw_overdue_rule_sets( [$branchcode], [$categorycode], [$itemtype] );

    my $cache_key = join( "|", $branchcode, $categorycode, $itemtype, 1 );
    my $rule_set  = $resolver->{raw_overdue_rule_sets}->{$cache_key};
    ok( $rule_set, "raw set cached under $cache_key (branchcode|cat|itype|trigger_number)" );
    is( $rule_set->{delay},           7, 'cached delay matches the delay rule_value' );
    is( $rule_set->{actions}->{lost}, 1, 'cached actions include the lost rule_value' );

    my $no_delay_key = join( "|", $branchcode, $categorycode, $itemtype, 9 );
    is_deeply(
        $resolver->{raw_overdue_rule_sets}->{$no_delay_key},
        { actions => { charge => 1 } },
        'trigger with action rules but no delay rule is cached without a delay'
    );

    $schema->storage->txn_rollback;
};

subtest '_find_effective_rule_value walks fallback contexts' => sub {
    plan tests => 3;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        'BR|*|*|1' => { delay => 7, actions => { lost   => 2 } },
        '*|PC|*|1' => { delay => 7, actions => { notice => 'OD1' } },
    };

    is(
        $resolver->_find_effective_rule_value( 'BR', 'PC', 'IT', 1, 'lost' ),
        2, 'lost resolves via library-only fallback'
    );
    is(
        $resolver->_find_effective_rule_value( 'BR', 'PC', 'IT', 1, 'notice' ),
        'OD1', 'notice resolves via category-only fallback'
    );
    is(
        $resolver->_find_effective_rule_value( 'BR', 'PC', 'IT', 1, 'charge' ),
        undef, 'unset action returns undef'
    );
};

subtest 'set_effective_overdue_rule_sets' => sub {
    plan tests => 3;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        'BR|PC|IT|1' => {
            delay   => 7,
            actions => {
                notice => 'OD1',
                mtt    => 'email',
                lost   => 1,
            },
        },
    };

    $resolver->set_effective_overdue_rule_sets( ['BR|BR|PC|IT'], { BR => { 7 => 7 } } );

    my $key = 'BR|BR|PC|IT|7';
    my $eff = $resolver->{effective_overdue_rule_sets}->{$key};
    ok( $eff, "effective rule set cached under $key" );

    my %by_type = map { $_->{type} => $_ } @{ $eff->{actions} };
    is_deeply(
        $by_type{notice},
        { type => 'notice', notice_code => 'OD1', mtts => ['email'] },
        'notice action shape: type/notice_code/mtts'
    );
    is_deeply(
        $by_type{lost},
        { type => 'lost', value => 1 },
        'non-notice action shape: type/value'
    );
};

subtest 'notice action splits comma-separated mtt rule value' => sub {
    plan tests => 4;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        'BR|PC|IT|1' => { delay => 7,  actions => { notice => 'OD1', mtt => 'email, print' } },
        'BR|PC|IT|2' => { delay => 14, actions => { notice => 'OD2', mtt => '' } },
        'BR|PC|IT|3' => { delay => 21, actions => { notice => 'OD3', mtt => 'sms' } },
    };

    $resolver->set_effective_overdue_rule_sets(
        ['BR|BR|PC|IT'],
        { BR => { 7 => 7, 14 => 14, 21 => 21 } }
    );

    my %by_type_7 =
        map { $_->{type} => $_ } @{ $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|7'}->{actions} };
    is_deeply(
        $by_type_7{notice}->{mtts},
        [ 'email', 'print' ],
        'comma-scalar splits and trims whitespace into mtts array'
    );

    ok(
        !exists $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|14'},
        'empty mtt scalar skips the notice action entirely (no rule cached)'
    );

    my %by_type_21 =
        map { $_->{type} => $_ } @{ $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|21'}->{actions} };
    is_deeply(
        $by_type_21{notice}->{mtts},
        ['sms'],
        'single mtt wraps in a one-element mtts array'
    );

    ok( !exists $by_type_7{notice}->{mtt}, 'no scalar mtt key leaks alongside mtts' );
};

subtest 'empty mtt resolves to the broader context mtt' => sub {
    plan tests => 1;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        'BR|PC|IT|1' => { delay => 7, actions => { notice => 'OD1', mtt => '' } },
        '*|*|*|1'    => { delay => 7, actions => { mtt    => 'email' } },
    };

    $resolver->set_effective_overdue_rule_sets( ['BR|BR|PC|IT'], { BR => { 7 => 7 } } );

    my %by_type = map { $_->{type} => $_ } @{ $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|7'}->{actions} };
    is_deeply( $by_type{notice}->{mtts}, ['email'], 'empty mtt resolves to the default context mtt' );
};

subtest 'an override that sets no delay inherits the delay of the same trigger' => sub {
    plan tests => 2;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        '*|*|*|1'  => { delay   => 7, actions => { notice => 'OD1', mtt => 'print' } },
        'BR|*|*|1' => { actions => { notice => 'OD2' } },
    };

    $resolver->set_effective_overdue_rule_sets(
        [ 'BR|BR|PC|IT', 'XX|XX|PC|IT' ],
        { BR => { 7 => 7 }, XX => { 7 => 7 } }
    );

    my %overridden =
        map { $_->{type} => $_ } @{ $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|7'}->{actions} };
    is( $overridden{notice}->{notice_code}, 'OD2', 'the library override applies at the inherited delay' );

    my %inherited =
        map { $_->{type} => $_ } @{ $resolver->{effective_overdue_rule_sets}->{'XX|XX|PC|IT|7'}->{actions} };
    is( $inherited{notice}->{notice_code}, 'OD1', 'another library still gets the default' );
};

subtest 'an override that moves a trigger\'s delay does not also fire at the default delay' => sub {
    plan tests => 2;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        '*|*|*|1'  => { delay => 7,  actions => { lost => 1 } },
        'BR|*|*|1' => { delay => 10, actions => {} },
    };

    $resolver->set_effective_overdue_rule_sets( ['BR|BR|PC|IT'], { BR => { 7 => 7, 10 => 10 } } );

    ok( !exists $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|7'}, 'nothing fires at the default delay' );
    ok(
        exists $resolver->{effective_overdue_rule_sets}->{'BR|BR|PC|IT|10'},
        'the trigger fires at the overridden delay'
    );
};

subtest 'lost, charge, mark_returned and forgive_fine resolve against the LostChargesControl branch' => sub {
    plan tests => 4;

    my $resolver = Koha::Overdues::RuleResolver->new;
    $resolver->{raw_overdue_rule_sets} = {
        'CPL|*|*|1' => { delay => 7, actions => { notice => 'OD1', mtt => 'print', lost => 2, forgive_fine => 0 } },
        'FPL|*|*|1' => { delay => 7, actions => { notice => 'OD2', mtt => 'print', lost => 1, forgive_fine => 1 } },
    };

    $resolver->set_effective_overdue_rule_sets( ['CPL|FPL|PC|IT'], { CPL => { 7 => 7 }, FPL => { 7 => 7 } } );

    my %by_type =
        map { $_->{type} => $_ } @{ $resolver->{effective_overdue_rule_sets}->{'CPL|FPL|PC|IT|7'}->{actions} };
    is( $by_type{notice}->{notice_code}, 'OD1', 'the notice comes from the CircControl branch' );
    is( $by_type{lost}->{value},         1,     'lost comes from the LostChargesControl branch' );
    is( $by_type{forgive_fine}->{value}, 1,     'forgive_fine comes from the LostChargesControl branch' );
    is(
        scalar grep( { $_->{type} eq 'lost' }
            @{ $resolver->{effective_overdue_rule_sets}->{'CPL|FPL|PC|IT|7'}->{actions} } ),
        1,
        'each action is resolved once'
    );
};
