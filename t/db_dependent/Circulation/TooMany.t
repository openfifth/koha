#!/usr/bin/perl

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;
use Test::NoWarnings;
use Test::More tests => 15;
use C4::Context;

use C4::Members;
use C4::Items;
use C4::Biblio;
use C4::Circulation qw( TooMany AddIssue );
use C4::Context;

use Koha::DateUtils qw( dt_from_string );
use Koha::Database;
use Koha::CirculationRules;

use t::lib::TestBuilder;
use t::lib::Mocks;

my $schema = Koha::Database->new->schema;
$schema->storage->txn_begin;

our $dbh = C4::Context->dbh;

$dbh->do(q|DELETE FROM issues|);
$dbh->do(q|DELETE FROM items|);
$dbh->do(q|DELETE FROM borrowers|);

#$dbh->do(q|DELETE FROM branches|);
$dbh->do(q|DELETE FROM categories|);
$dbh->do(q|DELETE FROM accountlines|);
$dbh->do(q|DELETE FROM itemtypes WHERE parent_type IS NOT NULL|);
$dbh->do(q|DELETE FROM itemtypes|);
Koha::CirculationRules->search()->delete();

my $builder = t::lib::TestBuilder->new();
t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );    # Assuming the item type is defined at item level

my $branch = $builder->build(
    {
        source => 'Branch',
    }
);

my $branch2 = $builder->build(
    {
        source => 'Branch',
    }
);

my $category = $builder->build(
    {
        source => 'Category',
    }
);

my $patron = $builder->build_object(
    {
        class => 'Koha::Patrons',
        value => {
            categorycode => $category->{categorycode},
            branchcode   => $branch->{branchcode},
        },
    }
);

my $biblio = $builder->build_sample_biblio( { branchcode => $branch->{branchcode} } );
my $item   = $builder->build_sample_item(
    {
        biblionumber  => $biblio->biblionumber,
        homebranch    => $branch->{branchcode},
        holdingbranch => $branch->{branchcode},
    }
);

t::lib::Mocks::mock_userenv( { patron => $patron } );

# TooMany return ($current_loan_count, $max_loans_allowed) or undef
# CO = Checkout
# OSCO: On-site checkout

subtest 'no rules exist' => sub {
    plan tests => 2;
    is_deeply(
        C4::Circulation::TooMany( $patron, $item ),
        { reason => 'NO_RULE_DEFINED', max_allowed => 0 },
        'CO should not be allowed, in any cases'
    );
    is_deeply(
        C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        { reason => 'NO_RULE_DEFINED', max_allowed => 0 },
        'OSCO should not be allowed, in any cases'
    );
};

subtest '1 Issuingrule exist 0 0: no issue allowed' => sub {
    plan tests => 8;
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 0,
                maxonsiteissueqty => 0,
            }
        },
    );
    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );

    my $data = C4::Circulation::TooMany( $patron, $item );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 0,
            max_allowed => 0,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_ONSITE_CHECKOUTS',
            count       => 0,
            max_allowed => 0,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 0,
            max_allowed => 0,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_ONSITE_CHECKOUTS',
            count       => 0,
            max_allowed => 0,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
};

subtest '1 Issuingrule exist with onsiteissueqty=unlimited' => sub {
    plan tests => 8;

    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => undef,
            }
        },
    );

    my $issue = C4::Circulation::AddIssue( $patron, $item->barcode, dt_from_string() );
    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );
    my $data = C4::Circulation::TooMany( $patron, $item );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, '', 'No circulation rule was returned' );
    is_deeply(
        $data,
        {},
        'OSCO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
};

subtest '1 Issuingrule exist 1 1: issue is allowed' => sub {
    plan tests => 4;
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );
    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );
    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef,
        'CO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    is(
        C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        undef,
        'OSCO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef,
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    is(
        C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        undef,
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
};

subtest '1 Issuingrule exist: 1 CO allowed, 1 OSCO allowed. Do a CO' => sub {
    plan tests => 9;
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    my $issue = C4::Circulation::AddIssue( $patron, $item->barcode, dt_from_string() );
    like( $issue->issue_id, qr|^\d+$|, 'The issue should have been inserted' );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );
    my $data = C4::Circulation::TooMany( $patron, $item );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, '', 'No circulation rule was returned' );
    is_deeply(
        $data,
        {},
        'OSCO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
};

subtest '1 Issuingrule exist: 1 CO allowed, 1 OSCO allowed, Do a OSCO' => sub {
    plan tests => 8;
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    my $issue = C4::Circulation::AddIssue(
        $patron, $item->barcode, dt_from_string(), undef, undef, undef,
        { onsite_checkout => 1 }
    );
    like( $issue->issue_id, qr|^\d+$|, 'The issue should have been inserted' );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );
    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef,
        'CO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    my $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_ONSITE_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_ONSITE_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
};

subtest '1 BranchBorrowerCircRule exist: 1 CO allowed, 1 OSCO allowed' => sub {

    # Note: the same test coul be done for
    # DefaultBorrowerCircRule, DefaultBranchCircRule, DefaultBranchItemRule ans DefaultCircRule.pm

    plan tests => 18;
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    my $issue = C4::Circulation::AddIssue( $patron, $item->barcode, dt_from_string(), undef, undef, undef );
    like( $issue->issue_id, qr|^\d+$|, 'The issue should have been inserted' );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );
    my $data = C4::Circulation::TooMany( $patron, $item );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        $rule = delete $data->{circulation_rule};
    is( ref $rule, '', 'No circulation rule was returned' );
    is_deeply(
        $data,
        {},
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => undef,
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    $issue = C4::Circulation::AddIssue(
        $patron, $item->barcode, dt_from_string(), undef, undef, undef,
        { onsite_checkout => 1 }
    );
    like( $issue->issue_id, qr|^\d+$|, 'The issue should have been inserted' );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 0 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, '', 'No circulation rule was returned' );
    is(
        keys %$data,
        0,
        'CO should be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_ONSITE_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 0'
    );

    t::lib::Mocks::mock_preference( 'ConsiderOnSiteCheckoutsAsNormalCheckouts', 1 );
    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'CO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );
    $data = C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_ONSITE_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'OSCO should not be allowed if ConsiderOnSiteCheckoutsAsNormalCheckouts == 1'
    );

    teardown();
};

subtest 'General vs specific rules limit quantity correctly' => sub {
    plan tests => 18;

    t::lib::Mocks::mock_preference( 'CircControl',                   'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'item' );
    my $branch   = $builder->build( { source => 'Branch', } );
    my $category = $builder->build( { source => 'Category', } );
    my $itemtype = $builder->build(
        {
            source => 'Itemtype',
            value  => {
                rentalcharge        => 0,
                rentalcharge_daily  => 0,
                rentalcharge_hourly => 0,
                notforloan          => 0,
            }
        }
    );
    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->{categorycode},
                branchcode   => $branch->{branchcode},
            }
        }
    );

    # Set up an issuing rule
    Koha::CirculationRules->set_rules(
        {
            categorycode => '*',
            itemtype     => $itemtype->{itemtype},
            branchcode   => '*',
            rules        => {
                issuelength => 1,
                firstremind => 1,        # 1 day of grace
                finedays    => 2,        # 2 days of fine per day of overdue
                lengthunit  => 'days',
            }
        }
    );

    # Set default maximum issue quantity limits for branch
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => '*',
            rules        => {
                patron_maxissueqty       => 1,
                patron_maxonsiteissueqty => 1,
            }
        }
    );

    # Set an All->All for an itemtype
    Koha::CirculationRules->set_rules(
        {
            branchcode   => '*',
            categorycode => '*',
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    # Create an item
    my $issue_item  = $builder->build_sample_item( { itype => $itemtype->{itemtype} } );
    my $branch_item = $builder->build_sample_item(
        {
            itype         => $itemtype->{itemtype},
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode}
        }
    );

    t::lib::Mocks::mock_userenv( { branchcode => $branch->{branchcode} } );
    my $issue = C4::Circulation::AddIssue( $patron, $issue_item->barcode, dt_from_string() );

    # We checkout one item
    my $data = C4::Circulation::TooMany( $patron, $branch_item );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'We are only allowed one, and we have one (itemtype on item)'
    );

    # Check itemtype on biblio level
    t::lib::Mocks::mock_preference( 'item-level_itypes', 0 );
    $issue_item->biblio->biblioitem->itemtype( $itemtype->{itemtype} )->store;
    $branch_item->biblio->biblioitem->itemtype( $itemtype->{itemtype} )->store;

    # We checkout one item
    $data = C4::Circulation::TooMany( $patron, $branch_item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'We are only allowed one, and we have one (itemtype on biblioitem)'
    );
    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );

    # Set a branch specific rule
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'homebranch' );

    is(
        C4::Circulation::TooMany( $patron, $branch_item ),
        undef,
        'We are allowed one from the branch specifically now'
    );

    # If circcontrol is PatronLibrary we count all the patron's loan, regardless of branch
    t::lib::Mocks::mock_preference( 'CircControl',                   'PatronLibrary' );
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'all' );
    $data = C4::Circulation::TooMany( $patron, $branch_item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'We are allowed one from the branch specifically, but have one'
    );
    t::lib::Mocks::mock_preference( 'CircControl',                   'ItemHomeLibrary' );
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'item' );

    $issue = C4::Circulation::AddIssue( $patron, $branch_item->barcode, dt_from_string() );

    # We issue that one
    # And make another
    my $branch_item_2 = $builder->build_sample_item(
        {
            itype         => $itemtype->{itemtype},
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode}
        }
    );
    $data = C4::Circulation::TooMany( $patron, $branch_item_2 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'We are only allowed one from that branch, and have one'
    );

    # Now we make another from a different branch
    # Switch to 'all' scope to test general rules counting all checkouts
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'all' );
    my $item_2 = $builder->build_sample_item(
        {
            itype => $itemtype->{itemtype},
        }
    );
    $data = C4::Circulation::TooMany( $patron, $item_2 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 2,
            max_allowed => 1,
        },
        'We are only allowed one for general rule, and have two'
    );
    t::lib::Mocks::mock_preference( 'CircControl', 'PatronLibrary' );
    $data = C4::Circulation::TooMany( $patron, $item_2 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 2,
            max_allowed => 1,
        },
        'We are only allowed one for general rule, and have two'
    );

    t::lib::Mocks::mock_preference( 'CircControl', 'PickupLibrary' );
    $data = C4::Circulation::TooMany( $patron, $item_2 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 2,
            max_allowed => 1,
        },
        'We are only allowed one for general rule, and have checked out two at this branch'
    );

    t::lib::Mocks::mock_userenv( { branchcode => $branch2->{branchcode} } );
    $data = C4::Circulation::TooMany( $patron, $item_2 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 2,
            max_allowed => 1,
        },
        'We are only allowed one for general rule, and have two total (no rule for specific branch)'
    );

    # Set a branch specific rule for new branch and use 'checkout' scope
    # With PickupLibrary CircControl, we want to count checkouts made at this branch
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'checkout' );
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch2->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty       => 1,
                maxonsiteissueqty => 1,
            }
        }
    );

    is(
        C4::Circulation::TooMany( $patron, $branch_item ),
        undef,
        'We are allowed one from the branch specifically now'
    );
};

subtest 'empty string means unlimited' => sub {
    plan tests => 2;

    Koha::CirculationRules->set_rules(
        {
            branchcode   => '*',
            categorycode => '*',
            itemtype     => '*',
            rules        => {
                maxissueqty       => '',
                maxonsiteissueqty => '',
            }
        },
    );
    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef,
        'maxissueqty="" should mean unlimited'
    );

    is(
        C4::Circulation::TooMany( $patron, $item, { onsite_checkout => 1 } ),
        undef,
        'maxonsiteissueqty="" should mean unlimited'
    );
};

subtest 'itemtype group tests' => sub {
    plan tests => 20;

    t::lib::Mocks::mock_preference( 'CircControl', 'ItemHomeLibrary' );
    Koha::CirculationRules->set_rules(
        {
            branchcode   => '*',
            categorycode => '*',
            itemtype     => '*',
            rules        => {
                maxissueqty       => '5',
                maxonsiteissueqty => '',
                issuelength       => 1,
                firstremind       => 1,        # 1 day of grace
                finedays          => 2,        # 2 days of fine per day of overdue
                lengthunit        => 'days',
            }
        },
    );

    my $parent_itype = $builder->build(
        {
            source => 'Itemtype',
            value  => {
                parent_type         => undef,
                rentalcharge        => undef,
                rentalcharge_daily  => undef,
                rentalcharge_hourly => undef,
                notforloan          => 0,
            }
        }
    );
    my $child_itype_1 = $builder->build(
        {
            source => 'Itemtype',
            value  => {
                parent_type         => $parent_itype->{itemtype},
                rentalcharge        => 0,
                rentalcharge_daily  => 0,
                rentalcharge_hourly => 0,
                notforloan          => 0,
            }
        }
    );
    my $child_itype_2 = $builder->build(
        {
            source => 'Itemtype',
            value  => {
                parent_type         => $parent_itype->{itemtype},
                rentalcharge        => 0,
                rentalcharge_daily  => 0,
                rentalcharge_hourly => 0,
                notforloan          => 0,
            }
        }
    );

    my $branch   = $builder->build( { source => 'Branch', } );
    my $category = $builder->build( { source => 'Category', } );
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->{categorycode},
                branchcode   => $branch->{branchcode},
            },
        }
    );
    my $item = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $child_itype_1->{itemtype}
        }
    );
    my $checkout_item = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $parent_itype->{itemtype}
        }
    );

    my $all_iq_rule = $builder->build_object(
        {
            class => 'Koha::CirculationRules',
            value => {
                branchcode   => $branch->{branchcode},
                categorycode => $category->{categorycode},
                itemtype     => undef,
                rule_name    => 'maxissueqty',
                rule_value   => 1
            }
        }
    );
    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef, 'Checkout allowed, using all rule of 1'
    );

    #Checkout an item
    my $issue = C4::Circulation::AddIssue( $patron, $checkout_item->barcode, dt_from_string() );
    like( $issue->issue_id, qr|^\d+$|, 'The issue should have been inserted' );

    #Patron has 1 checkout of parent itemtype

    my $parent_iq_rule = $builder->build_object(
        {
            class => 'Koha::CirculationRules',
            value => {
                branchcode   => $branch->{branchcode},
                categorycode => $category->{categorycode},
                itemtype     => $parent_itype->{itemtype},
                rule_name    => 'maxissueqty',
                rule_value   => 2
            }
        }
    );

    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef, 'Checkout allowed, using parent type rule of 2'
    );

    $all_iq_rule->rule_value(5)->store;
    $parent_iq_rule->rule_value(1)->store;

    my $data = C4::Circulation::TooMany( $patron, $item );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'Checkout not allowed, using parent type rule of 1'
    );

    $parent_iq_rule->rule_value(2)->store;

    is(
        C4::Circulation::TooMany( $patron, $item ),
        undef, 'Checkout allowed, using specific type of 1 and only parent type checked out'
    );

    $checkout_item->itype( $child_itype_1->{itemtype} )->store;

    my $child1_iq_rule = $builder->build_object(
        {
            class => 'Koha::CirculationRules',
            value => {
                branchcode   => $branch->{branchcode},
                categorycode => $category->{categorycode},
                itemtype     => $child_itype_1->{itemtype},
                rule_name    => 'maxissueqty',
                rule_value   => 1
            }
        }
    );

    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 1,
            max_allowed => 1,
        },
        'Checkout not allowed, using specific type rule of 1'
    );

    my $item_1 = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $child_itype_2->{itemtype}
        }
    );

    my $child2_iq_rule = $builder->build(
        {
            source => 'CirculationRule',
            value  => {
                branchcode   => $branch->{branchcode},
                categorycode => $category->{categorycode},
                itemtype     => $child_itype_2->{itemtype},
                rule_name    => 'maxissueqty',
                rule_value   => 3
            }
        }
    );

    is(
        C4::Circulation::TooMany( $patron, $item_1 ),
        undef, 'Checkout allowed'
    );

    #checkout an item
    $issue = C4::Circulation::AddIssue( $patron, $item_1->barcode, dt_from_string() );
    like( $issue->issue_id, qr|^\d+$|, 'the issue should have been inserted' );

    #patron has 1 checkout of childitype1 and 1 checkout of childitype2

    $data = C4::Circulation::TooMany( $patron, $item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 2,
            max_allowed => 2,
        },
        'Checkout not allowed, using parent type rule of 2, checkout of sibling itemtype counted'
    );

    my $parent_item = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $parent_itype->{itemtype}
        }
    );

    $data = C4::Circulation::TooMany( $patron, $parent_item );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            count       => 2,
            max_allowed => 2,
        },
        'Checkout not allowed, using parent type rule of 2, checkout of child itemtypes counted'
    );

    #increase parent type to greater than specific
    $parent_iq_rule->rule_value(4)->store();

    is(
        C4::Circulation::TooMany( $patron, $item_1 ),
        undef, 'Checkout allowed, using specific type rule of 3'
    );

    my $item_2 = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $child_itype_2->{itemtype}
        }
    );

    #checkout an item
    $issue = C4::Circulation::AddIssue(
        $patron, $item_2->barcode, dt_from_string(),
        undef,   undef,            undef
    );
    like( $issue->issue_id, qr|^\d+$|, 'the issue should have been inserted' );

    #patron has 1 checkout of childitype1 and 2 of childitype2

    is(
        C4::Circulation::TooMany( $patron, $item_2 ),
        undef,
        'Checkout allowed, using specific type rule of 3, checkout of sibling itemtype not counted'
    );

    $child1_iq_rule->rule_value(2)->store();    #Allow 2 checkouts for child type 1

    my $item_3 = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $child_itype_1->{itemtype}
        }
    );
    my $item_4 = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch->{branchcode},
            itype         => $child_itype_2->{itemtype}
        }
    );

    #checkout an item
    $issue = C4::Circulation::AddIssue(
        $patron, $item_4->barcode, dt_from_string(),
        undef,   undef,            undef
    );
    like( $issue->issue_id, qr|^\d+$|, 'the issue should have been inserted' );

    #patron has 1 checkout of childitype 1 and 3 of childitype2

    $data = C4::Circulation::TooMany( $patron, $item_3 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            max_allowed => 4,
            count       => 4,
        },
        'Checkout not allowed, using specific type rule of 2, checkout of sibling itemtype not counted, but parent rule (4) prevents another'
    );

    teardown();
};

subtest 'HomeOrHoldingBranch is used' => sub {
    plan tests => 4;

    t::lib::Mocks::mock_preference( 'CircControl', 'ItemHomeLibrary' );

    my $item_1 = $builder->build_sample_item(
        {
            homebranch    => $branch->{branchcode},
            holdingbranch => $branch2->{branchcode},
        }
    );

    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch->{branchcode},
            categorycode => undef,
            itemtype     => undef,
            rules        => {
                maxissueqty => 0,
            }
        }
    );

    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch2->{branchcode},
            categorycode => undef,
            itemtype     => undef,
            rules        => {
                maxissueqty => 1,
            }
        }
    );

    t::lib::Mocks::mock_userenv( { branchcode => $branch2->{branchcode} } );
    my $issue = C4::Circulation::AddIssue( $patron, $item_1->barcode, dt_from_string() );

    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'homebranch' );

    my $data = C4::Circulation::TooMany( $patron, $item_1 );
    my $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            max_allowed => 0,
            count       => 1,
        },
        'We are allowed zero issues from the homebranch specifically'
    );

    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'holdingbranch' );

    $data = C4::Circulation::TooMany( $patron, $item_1 );
    $rule = delete $data->{circulation_rule};
    is( ref $rule, 'Koha::CirculationRule', 'Circulation rule was returned' );
    is_deeply(
        $data,
        {
            reason      => 'TOO_MANY_CHECKOUTS',
            max_allowed => 1,
            count       => 1,
        },
        'We are allowed one issue from the holdingbranch specifically'
    );

    teardown();
};

subtest 'CircControlCheckoutLimitScope system preference controls checkout counting' => sub {
    plan tests => 12;

    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );

    my $branch1  = $builder->build( { source => 'Branch' } );
    my $branch2  = $builder->build( { source => 'Branch' } );
    my $category = $builder->build( { source => 'Category' } );
    my $itemtype = $builder->build( { source => 'Itemtype', value => { notforloan => 0 } } );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->{categorycode},
                branchcode   => $branch1->{branchcode},
            }
        }
    );

    # Create items from different branches
    my $item_branch1 = $builder->build_sample_item(
        {
            homebranch    => $branch1->{branchcode},
            holdingbranch => $branch1->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    my $item_branch2 = $builder->build_sample_item(
        {
            homebranch    => $branch2->{branchcode},
            holdingbranch => $branch2->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    # Set circulation rules for both branches
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch1->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty => 1,
            }
        }
    );

    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch2->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty => 1,
            }
        }
    );

    # Issue an item from branch1
    t::lib::Mocks::mock_userenv( { branchcode => $branch1->{branchcode} } );
    my $issue = C4::Circulation::AddIssue( $patron, $item_branch1->barcode, dt_from_string() );
    ok( $issue, 'Item from branch1 issued successfully' );

    # Test with CircControlCheckoutLimitScope = 'checkout'
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'checkout' );

    # From branch1 - should count checkout made at branch1
    my $data = C4::Circulation::TooMany( $patron, $item_branch1 );
    ok( $data, 'TooMany should return limit exceeded when checking from same pickup library' );
    is( $data->{count},  1,                    'Should count checkout made at this pickup library' );
    is( $data->{reason}, 'TOO_MANY_CHECKOUTS', 'Correct reason returned' );

    # From branch2 - should not count checkout made at branch1
    t::lib::Mocks::mock_userenv( { branchcode => $branch2->{branchcode} } );
    $data = C4::Circulation::TooMany( $patron, $item_branch2 );
    ok( !$data, 'TooMany should allow checkout when no checkouts from this pickup library' );

    # Test with CircControlCheckoutLimitScope = 'all'
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'all' );

    # Should count all patron checkouts regardless of pickup library
    $data = C4::Circulation::TooMany( $patron, $item_branch2 );
    ok( $data, 'TooMany should return limit exceeded when counting all checkouts' );
    is( $data->{count}, 1, 'Should count all patron checkouts regardless of branch' );

    # Test with CircControlCheckoutLimitScope = 'all' from branch1
    t::lib::Mocks::mock_userenv( { branchcode => $branch1->{branchcode} } );
    $data = C4::Circulation::TooMany( $patron, $item_branch2 );
    ok( $data, 'TooMany should return limit exceeded' );
    is( $data->{count}, 1, 'Should count all patron checkouts' );

    # Test with CircControlCheckoutLimitScope = 'item'
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'item' );

    # Item from branch2 - should not count checkout of item from branch1
    $data = C4::Circulation::TooMany( $patron, $item_branch2 );
    ok( !$data, 'TooMany should allow checkout when no items from this home library checked out' );

    # Item from branch1 - should count checkout of item from branch1
    my $item_branch1_2 = $builder->build_sample_item(
        {
            homebranch    => $branch1->{branchcode},
            holdingbranch => $branch1->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    $data = C4::Circulation::TooMany( $patron, $item_branch1_2 );
    ok( $data, 'TooMany should return limit exceeded when item from same home library already checked out' );
    is( $data->{count}, 1, 'Should count checkout of item from same home library' );

    teardown();
};

subtest 'CircControlCheckoutLimitScope with HomeOrHoldingBranch preference' => sub {
    plan tests => 8;

    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );
    t::lib::Mocks::mock_preference( 'CircControl',       'ItemHomeLibrary' );

    my $branch1  = $builder->build( { source => 'Branch' } );
    my $branch2  = $builder->build( { source => 'Branch' } );
    my $category = $builder->build( { source => 'Category' } );
    my $itemtype = $builder->build( { source => 'Itemtype', value => { notforloan => 0 } } );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->{categorycode},
                branchcode   => $branch1->{branchcode},
            }
        }
    );

    # Create an item with different home and holding branches
    my $item_home1_holding2 = $builder->build_sample_item(
        {
            homebranch    => $branch1->{branchcode},
            holdingbranch => $branch2->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    my $item_home2_holding1 = $builder->build_sample_item(
        {
            homebranch    => $branch2->{branchcode},
            holdingbranch => $branch1->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    # Set circulation rules for both branches
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch1->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty => 1,
            }
        }
    );

    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch2->{branchcode},
            categorycode => $category->{categorycode},
            itemtype     => $itemtype->{itemtype},
            rules        => {
                maxissueqty => 1,
            }
        }
    );

    # Test with scope='item' and HomeOrHoldingBranch='homebranch'
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'item' );
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch',           'homebranch' );
    t::lib::Mocks::mock_userenv( { branchcode => $branch1->{branchcode} } );

    # Check out item with homebranch=branch1
    my $issue = C4::Circulation::AddIssue( $patron, $item_home1_holding2->barcode, dt_from_string() );
    ok( $issue, 'Item with homebranch=branch1 issued successfully' );

    # Reload item to get updated holdingbranch (AddIssue may change it)
    $item_home1_holding2->discard_changes;

    # Try to check out another item with homebranch=branch1
    my $item_home1_2 = $builder->build_sample_item(
        {
            homebranch    => $branch1->{branchcode},
            holdingbranch => $branch1->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    my $data = C4::Circulation::TooMany( $patron, $item_home1_2 );
    ok( $data, 'TooMany should block checkout of another item from same homebranch' );
    is( $data->{count}, 1, 'Should count 1 checkout with same homebranch' );

    # Try to check out item with different homebranch (branch2)
    $data = C4::Circulation::TooMany( $patron, $item_home2_holding1 );
    ok( !$data, 'TooMany should allow checkout of item from different homebranch' );

    # Now test with HomeOrHoldingBranch='holdingbranch'
    t::lib::Mocks::mock_preference( 'HomeOrHoldingBranch', 'holdingbranch' );

    # After checkout, the item's holdingbranch may have been updated to the checkout library
    # Get the current holdingbranch from the checked-out item
    my $checked_out_holdingbranch = $item_home1_holding2->holdingbranch;

    # Try to check out another item with the same holdingbranch
    my $item_holding_same = $builder->build_sample_item(
        {
            homebranch    => $branch2->{branchcode},
            holdingbranch => $checked_out_holdingbranch,
            itype         => $itemtype->{itemtype}
        }
    );

    $data = C4::Circulation::TooMany( $patron, $item_holding_same );
    ok( $data, 'TooMany should block checkout of another item from same holdingbranch' );
    is( $data->{count}, 1, 'Should count 1 checkout with same holdingbranch' );

    # Try to check out item with different holdingbranch
    my $different_holdingbranch =
        $checked_out_holdingbranch eq $branch1->{branchcode} ? $branch2->{branchcode} : $branch1->{branchcode};
    my $item_holding_different = $builder->build_sample_item(
        {
            homebranch    => $branch1->{branchcode},
            holdingbranch => $different_holdingbranch,
            itype         => $itemtype->{itemtype}
        }
    );

    $data = C4::Circulation::TooMany( $patron, $item_holding_different );
    ok( !$data, 'TooMany should allow checkout of item from different holdingbranch' );

    # Verify that we're actually using holdingbranch not homebranch
    # item_home1_2 has homebranch=branch1, verify its holdingbranch determines the result
    $data = C4::Circulation::TooMany( $patron, $item_home1_2 );
    if ( $item_home1_2->holdingbranch eq $checked_out_holdingbranch ) {
        ok( $data, 'Item with same holdingbranch should be blocked' );
    } else {
        ok( !$data, 'Item with different holdingbranch should be allowed' );
    }

    teardown();
};

subtest 'CircControlCheckoutLimitScope with patron_maxissueqty' => sub {
    plan tests => 9;

    t::lib::Mocks::mock_preference( 'item-level_itypes', 1 );

    my $branch1  = $builder->build( { source => 'Branch' } );
    my $branch2  = $builder->build( { source => 'Branch' } );
    my $category = $builder->build( { source => 'Category' } );
    my $itemtype = $builder->build( { source => 'Itemtype', value => { notforloan => 0 } } );

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => {
                categorycode => $category->{categorycode},
                branchcode   => $branch1->{branchcode},
            }
        }
    );

    # Create items from different branches
    my $item_branch1 = $builder->build_sample_item(
        {
            homebranch    => $branch1->{branchcode},
            holdingbranch => $branch1->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    my $item_branch2 = $builder->build_sample_item(
        {
            homebranch    => $branch2->{branchcode},
            holdingbranch => $branch2->{branchcode},
            itype         => $itemtype->{itemtype}
        }
    );

    # Set patron_maxissueqty rules for both branches
    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch1->{branchcode},
            categorycode => $category->{categorycode},
            rules        => {
                patron_maxissueqty => 1,
            }
        }
    );

    Koha::CirculationRules->set_rules(
        {
            branchcode   => $branch2->{branchcode},
            categorycode => $category->{categorycode},
            rules        => {
                patron_maxissueqty => 1,
            }
        }
    );

    # Issue an item from branch1
    t::lib::Mocks::mock_userenv( { branchcode => $branch1->{branchcode} } );
    my $issue = C4::Circulation::AddIssue( $patron, $item_branch1->barcode, dt_from_string() );
    ok( $issue, 'Item from branch1 issued successfully' );

    # Test with scope='all' - should count all checkouts
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'all' );
    my $data = C4::Circulation::TooMany( $patron, $item_branch1 );
    ok( $data, 'patron_maxissueqty with scope=all should count all checkouts' );
    is( $data->{count}, 1, 'Should count 1 checkout total' );

    # Test with scope='item' - should count items from same branch
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'item' );
    $data = C4::Circulation::TooMany( $patron, $item_branch1 );
    ok( $data, 'patron_maxissueqty with scope=item should count items from same branch' );
    is( $data->{count}, 1, 'Should count 1 checkout from branch1' );

    # Item from different branch should be allowed with scope='item'
    $data = C4::Circulation::TooMany( $patron, $item_branch2 );
    ok( !$data, 'patron_maxissueqty with scope=item should allow item from different branch' );

    # Test with scope='checkout' - should count checkouts made at same location
    t::lib::Mocks::mock_preference( 'CircControlCheckoutLimitScope', 'checkout' );
    $data = C4::Circulation::TooMany( $patron, $item_branch1 );
    ok( $data, 'patron_maxissueqty with scope=checkout should count checkouts made here' );
    is( $data->{count}, 1, 'Should count 1 checkout made at branch1' );

    # From different branch should be allowed with scope='checkout'
    t::lib::Mocks::mock_userenv( { branchcode => $branch2->{branchcode} } );
    $data = C4::Circulation::TooMany( $patron, $item_branch2 );
    ok( !$data, 'patron_maxissueqty with scope=checkout should allow checkout from different branch' );

    teardown();
};

$schema->storage->txn_rollback;

sub teardown {
    $dbh->do(q|DELETE FROM issues|);
    $dbh->do(q|DELETE FROM circulation_rules|);
}

