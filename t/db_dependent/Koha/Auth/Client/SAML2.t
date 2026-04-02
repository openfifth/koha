#!/usr/bin/perl

# Copyright 2026 Koha Development Team
#
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

use Test::More tests => 10;
use Test::MockModule;
use Test::NoWarnings;
use Test::Warn;

use Encode;
use CGI        qw(-utf8);
use File::Temp qw(tempdir);
use JSON       qw( encode_json );
use URI::Escape;

use Koha::Auth::Client::SAML2;
use Koha::Database;
use Koha::Patron::Attribute;
use Koha::Patron::Attributes;

use t::lib::Mocks;
use t::lib::Mocks::Logger;
use t::lib::TestBuilder;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------

# Build a minimal enabled SAML2 provider with a linked hostname and one or
# more field mappings.  Returns ($provider, $hostname_obj).
#
# Options (hashref):
#   hostname   - hostname string (default: 'saml-test.library.com')
#   matchpoint - matchpoint field (default: 'userid')
#   config     - provider config hashref (default: {})
#   mappings   - arrayref of { koha_field, provider_field }
#                (default: [ { koha_field => 'userid', provider_field => 'uid' } ])
sub _build_provider {
    my ($opts) = @_;
    $opts //= {};

    my $hostname   = $opts->{hostname}   // 'saml-test.library.com';
    my $matchpoint = $opts->{matchpoint} // 'userid';
    my $config     = $opts->{config}     // {};
    my $mappings   = $opts->{mappings}   // [ { koha_field => 'userid', provider_field => 'uid' } ];

    my $provider = $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Providers',
            value => { protocol => 'SAML2', enabled => 1, config => encode_json($config) },
        }
    );

    my $hostname_obj =
        $builder->build_object( { class => 'Koha::Auth::Hostnames', value => { hostname => $hostname } } );

    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Hostnames',
            value => {
                identity_provider_id => $provider->id,
                hostname_id          => $hostname_obj->id,
                is_enabled           => 1,
                matchpoint           => $matchpoint,
            },
        }
    );

    for my $m ( @{$mappings} ) {
        $builder->build_object(
            {
                class => 'Koha::Auth::Identity::Provider::Mappings',
                value => {
                    identity_provider_id => $provider->id,
                    koha_field           => $m->{koha_field},
                    provider_field       => $m->{provider_field},
                    default_content      => undef,
                },
            }
        );
    }

    return ( $provider, $hostname_obj );
}

# -----------------------------------------------------------------------
# checkpw() - failure cases
# -----------------------------------------------------------------------

subtest 'checkpw() - failure cases' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    # No provider found for hostname
    my $result = $client->checkpw( 'anyone', {}, 'no-provider.example.com' );
    is( $result, 0, 'returns 0 when no SAML2 provider found for hostname' );

    # Matchpoint not mapped (provider has matchpoint='userid' but no mapping for userid)
    my ( $provider_no_map, $hostname_no_map ) = _build_provider(
        {
            hostname   => 'saml-nomap.library.com',
            matchpoint => 'userid',
            mappings   => [ { koha_field => 'email', provider_field => 'mail' } ],    # userid NOT mapped
        }
    );
    my $r2;
    {
        local $SIG{__WARN__} = sub { };    # suppress expected carp from checkpw
        $r2 = $client->checkpw( 'anyone', {}, 'saml-nomap.library.com' );
    }
    is( $r2, 0, 'returns 0 when matchpoint field is not in mappings' );

    # Multiple patrons with same matchpoint value
    my ( $provider_dup, $hostname_dup ) = _build_provider(
        {
            hostname   => 'saml-dup.library.com',
            matchpoint => 'email',
            mappings   => [ { koha_field => 'email', provider_field => 'mail' } ],
        }
    );
    $builder->build_object( { class => 'Koha::Patrons', value => { email => 'dup@example.com' } } );
    $builder->build_object( { class => 'Koha::Patrons', value => { email => 'dup@example.com' } } );
    my $r3 = $client->checkpw( 'dup@example.com', { mail => 'dup@example.com' }, 'saml-dup.library.com' );
    is( $r3, 0, 'returns 0 when multiple patrons match' );

    # Patron not found, autocreate disabled
    my ( $provider_noac, $hostname_noac ) = _build_provider(
        {
            hostname   => 'saml-noac.library.com',
            matchpoint => 'userid',
            config     => { autocreate => 0 },
            mappings   => [ { koha_field => 'userid', provider_field => 'uid' } ],
        }
    );
    my $r4 = $client->checkpw( 'ghost_user', { uid => 'ghost_user' }, 'saml-noac.library.com' );
    is( $r4, 0, 'returns 0 when patron not found and autocreate disabled' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - patron found
# -----------------------------------------------------------------------

subtest 'checkpw() - patron found returns correct values' => sub {
    plan tests => 4;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $patron = $builder->build_object( { class => 'Koha::Patrons', value => { userid => 'saml_found_user' } } );

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'saml-found.library.com',
            matchpoint => 'userid',
            mappings   => [ { koha_field => 'userid', provider_field => 'uid' } ],
        }
    );

    my ( $ok, $cardnumber, $userid, $returned_patron ) =
        $client->checkpw( 'saml_found_user', { uid => 'saml_found_user' }, 'saml-found.library.com' );

    is( $ok,                  1,                   'returns 1 on success' );
    is( $cardnumber,          $patron->cardnumber, 'returns correct cardnumber' );
    is( $userid,              $patron->userid,     'returns correct userid' );
    is( $returned_patron->id, $patron->id,         'returns correct patron object' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - autocreate
# -----------------------------------------------------------------------

subtest 'checkpw() - autocreate' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    # Autocreate via provider config flag
    my ( $provider_ac, $hostname_ac ) = _build_provider(
        {
            hostname   => 'saml-ac.library.com',
            matchpoint => 'userid',
            config     => { autocreate => 1 },
            mappings   => [
                { koha_field => 'userid',    provider_field => 'uid' },
                { koha_field => 'firstname', provider_field => 'givenName' },
                { koha_field => 'surname',   provider_field => 'sn' },
            ],
        }
    );

    # Ensure patron doesn't pre-exist
    Koha::Patrons->search( { userid => 'new_saml_patron' } )->delete;

    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { category_type => 'A' } } );

    # Add domain with defaults so patron can be stored (needs categorycode + branchcode)
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => {
                identity_provider_id => $provider_ac->id,
                domain               => undef,
                allow_opac           => 1,
                allow_staff          => 0,
                auto_register_opac   => 0,
                auto_register_staff  => 0,
                default_library_id   => $library->branchcode,
                default_category_id  => $category->categorycode,
            },
        }
    );

    my ( $ok, $cardnumber, $userid, $new_patron ) = $client->checkpw(
        'new_saml_patron',
        { uid => 'new_saml_patron', givenName => 'Auto', sn => 'Created' },
        'saml-ac.library.com'
    );

    is( $ok,     1,                 'autocreate returns 1' );
    is( $userid, 'new_saml_patron', 'autocreated patron has correct userid' );

    my $stored = Koha::Patrons->search( { userid => 'new_saml_patron' } )->next;
    ok( defined $stored, 'patron was created in DB' );
    is( $stored->firstname, 'Auto',    'firstname populated from SAML attributes' );
    is( $stored->surname,   'Created', 'surname populated from SAML attributes' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - data sync on login
# -----------------------------------------------------------------------

subtest 'checkpw() - syncs patron data when sync config is enabled' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    my $client = Koha::Auth::Client::SAML2->new;

    my $patron = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { userid => 'sync_user_saml', firstname => 'OldFirst', surname => 'OldSurname' }
        }
    );

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'saml-sync.library.com',
            matchpoint => 'userid',
            config     => { sync => 1 },
            mappings   => [
                { koha_field => 'userid',    provider_field => 'uid' },
                { koha_field => 'firstname', provider_field => 'givenName' },
                { koha_field => 'surname',   provider_field => 'sn' },
            ],
        }
    );

    # Domain with update_on_auth => 1 is required for sync to trigger in checkpw()
    my $library  = $builder->build_object( { class => 'Koha::Libraries' } );
    my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { category_type => 'A' } } );
    $builder->build_object(
        {
            class => 'Koha::Auth::Identity::Provider::Domains',
            value => {
                identity_provider_id => $provider->id,
                domain               => undef,
                allow_opac           => 1,
                allow_staff          => 0,
                auto_register_opac   => 0,
                auto_register_staff  => 0,
                update_on_auth       => 1,
                default_library_id   => $library->branchcode,
                default_category_id  => $category->categorycode,
            },
        }
    );

    $client->checkpw(
        'sync_user_saml',
        { uid => 'sync_user_saml', givenName => 'NewFirst', sn => 'NewSurname' },
        'saml-sync.library.com'
    );

    $patron->discard_changes;
    is( $patron->firstname, 'NewFirst',   'firstname synced on login' );
    is( $patron->surname,   'NewSurname', 'surname synced on login' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# is_enabled() - replaces C4::Auth_with_shibboleth::shib_ok
# -----------------------------------------------------------------------

subtest 'is_enabled() - returns 1 when a valid SAML2 provider exists' => sub {
    plan tests => 6;

    $schema->storage->txn_begin;

    my $logger = t::lib::Mocks::Logger->new();

    local $ENV{HTTP_HOST} = 'samltest.library.com';

    # No provider yet
    Koha::Auth::Identity::Providers->search( { protocol => 'SAML2' } )->delete;
    is( Koha::Auth::Client::SAML2->is_enabled(), 0, 'returns 0 when no SAML2 provider exists' );

    # Good provider
    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'samltest.library.com',
            matchpoint => 'userid',
            mappings   => [ { koha_field => 'userid', provider_field => 'uid' } ],
        }
    );
    $logger->clear;
    is( Koha::Auth::Client::SAML2->is_enabled(), 1, 'returns 1 with valid provider' );

    # No matchpoint set
    $schema->resultset('IdentityProviderHostname')
        ->search( { identity_provider_id => $provider->id } )
        ->update( { matchpoint           => undef } );
    $logger->clear;
    my $result;
    warnings_are { $result = Koha::Auth::Client::SAML2->is_enabled() }
    [ { carped => 'shibboleth matchpoint not defined' } ],
        'carps when matchpoint not set';
    is( $result, 0, 'returns 0 when matchpoint not defined' );

    # Matchpoint not in mappings
    $schema->resultset('IdentityProviderHostname')
        ->search( { identity_provider_id => $provider->id } )
        ->update( { matchpoint           => 'email' } );
    $logger->clear;
    warnings_are { $result = Koha::Auth::Client::SAML2->is_enabled() }
    [ { carped => 'shibboleth matchpoint not mapped' } ],
        'carps when matchpoint not mapped';
    is( $result, 0, 'returns 0 when matchpoint not mapped' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# get_matchpoint_value() - replaces C4::Auth_with_shibboleth::get_login_shib
# -----------------------------------------------------------------------

subtest 'get_matchpoint_value() - reads ENV var for matchpoint attribute' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    local $ENV{HTTP_HOST} = 'mp-test.library.com';
    local $ENV{uid}       = 'mpuser42';

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'mp-test.library.com',
            matchpoint => 'userid',
            mappings   => [ { koha_field => 'userid', provider_field => 'uid' } ],
        }
    );

    my $logger = t::lib::Mocks::Logger->new();
    my $value  = Koha::Auth::Client::SAML2->get_matchpoint_value();
    is( $value, 'mpuser42', 'returns ENV value for mapped matchpoint attribute' );
    $logger->debug_is( 'koha borrower field to match: userid', 'matchpoint debug logged' )
        ->debug_is( 'shibboleth attribute to match: uid', 'attribute debug logged' );

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# login_url() and _get_uri()
# -----------------------------------------------------------------------

subtest 'login_url() - returns native SAML2 login URL' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    t::lib::Mocks::mock_preference( 'OPACBaseURL', 'testopac.com' );

    my $context = Test::MockModule->new('C4::Context');
    $context->mock( 'interface', sub { return 'opac' } );

    my $string                   = 'language=en-GB&param="heh❤"';
    my $query_string             = Encode::encode( 'UTF-8', $string );
    my $query_string_uri_escaped = URI::Escape::uri_escape_utf8( '?' . $string );

    local $ENV{REQUEST_METHOD} = 'GET';
    local $ENV{QUERY_STRING}   = $query_string;
    local $ENV{SCRIPT_NAME}    = '/cgi-bin/koha/opac-user.pl';
    my $query  = CGI->new($query_string);
    my $client = Koha::Auth::Client::SAML2->new;

    is(
        $client->login_url($query),
        'https://testopac.com/cgi-bin/koha/saml2/login?target='
            . 'https://testopac.com/cgi-bin/koha/opac-user.pl'
            . $query_string_uri_escaped,
        'login_url returns native SAML2 login endpoint with correct target'
    );

    # POST request — no query params in target
    my $post_params = 'user=bob&password=wideopen';
    local $ENV{REQUEST_METHOD} = 'POST';
    local $ENV{CONTENT_LENGTH} = length($post_params);

    my $dir    = tempdir( CLEANUP => 1 );
    my $infile = "$dir/in.txt";
    open my $fh_write, '>', $infile or die "Could not open '$infile' $!";
    print $fh_write $post_params;
    close $fh_write;
    open my $fh_read, '<', $infile or die "Could not open '$infile' $!";
    $query = CGI->new($fh_read);
    close $fh_read;

    is(
        $client->login_url($query),
        'https://testopac.com/cgi-bin/koha/saml2/login?target=https://testopac.com/cgi-bin/koha/opac-user.pl',
        'login_url with POST request omits query params from target'
    );

    $schema->storage->txn_rollback;
};

subtest '_get_uri() - builds base URI from sysprefs' => sub {
    plan tests => 13;

    $schema->storage->txn_begin;

    my $logger    = t::lib::Mocks::Logger->new();
    my $context   = Test::MockModule->new('C4::Context');
    my $interface = 'opac';
    $context->mock( 'interface', sub { return $interface } );

    t::lib::Mocks::mock_preference( 'OPACBaseURL', 'testopac.com' );
    is( Koha::Auth::Client::SAML2::_get_uri(), 'https://testopac.com', 'plain opac URL gets https' );
    $logger->clear;

    my $unencrypted_opac_url = 'http' . '://testopac.com';
    t::lib::Mocks::mock_preference( 'OPACBaseURL', $unencrypted_opac_url );
    my $result = Koha::Auth::Client::SAML2::_get_uri();
    is( $result, 'https://testopac.com', 'unencrypted opac URL upgraded to https' );
    $logger->warn_is(
        'Shibboleth requires OPACBaseURL/staffClientBaseURL to use the https protocol!',
        'warns when unencrypted protocol used'
    )->clear;

    t::lib::Mocks::mock_preference( 'OPACBaseURL', 'https://testopac.com' );
    is( Koha::Auth::Client::SAML2::_get_uri(), 'https://testopac.com', 'https opac URL returned unchanged' );
    $logger->clear;

    t::lib::Mocks::mock_preference( 'OPACBaseURL', undef );
    $result = Koha::Auth::Client::SAML2::_get_uri();
    is( $result, 'https://', 'undef OPACBaseURL returns bare https://' );
    $logger->warn_is(
        'Syspref staffClientBaseURL or OPACBaseURL not set!',
        'warns when OPACBaseURL not set'
    )->clear;

    $interface = 'intranet';
    t::lib::Mocks::mock_preference( 'StaffClientBaseURL', 'teststaff.com' );
    is( Koha::Auth::Client::SAML2::_get_uri(), 'https://teststaff.com', 'plain staff URL gets https' );
    $logger->clear;

    my $unencrypted_staff_url = 'http' . '://teststaff.com';
    t::lib::Mocks::mock_preference( 'StaffClientBaseURL', $unencrypted_staff_url );
    $result = Koha::Auth::Client::SAML2::_get_uri();
    is( $result, 'https://teststaff.com', 'unencrypted staff URL upgraded to https' );
    $logger->warn_is(
        'Shibboleth requires OPACBaseURL/staffClientBaseURL to use the https protocol!',
        'warns for unencrypted staff URL'
    )->clear;

    t::lib::Mocks::mock_preference( 'StaffClientBaseURL', 'https://teststaff.com' );
    is( Koha::Auth::Client::SAML2::_get_uri(), 'https://teststaff.com', 'https staff URL returned unchanged' );
    is( $logger->count(),                      0,                       'no warnings for valid https staff URL' );

    t::lib::Mocks::mock_preference( 'StaffClientBaseURL', undef );
    $result = Koha::Auth::Client::SAML2::_get_uri();
    is( $result, 'https://', 'undef StaffClientBaseURL returns bare https://' );
    $logger->warn_is(
        'Syspref staffClientBaseURL or OPACBaseURL not set!',
        'warns when StaffClientBaseURL not set'
    )->clear;

    $schema->storage->txn_rollback;
};

# -----------------------------------------------------------------------
# checkpw() - IPC mode: attributes loaded from ENV when undef
# -----------------------------------------------------------------------

subtest 'checkpw() - IPC mode loads attributes from ENV when saml_attributes is undef' => sub {
    plan tests => 5;

    $schema->storage->txn_begin;

    local $ENV{HTTP_HOST} = 'ipc-test.library.com';
    local $ENV{uid}       = 'ipc_user';
    local $ENV{sn}        = 'IpcSurname';

    my $category = $builder->build_object( { class => 'Koha::Patron::Categories', value => { category_type => 'A' } } );
    my $patron   = $builder->build_object(
        {
            class => 'Koha::Patrons',
            value => { userid => 'ipc_user', categorycode => $category->categorycode }
        }
    );

    my ( $provider, $hostname_obj ) = _build_provider(
        {
            hostname   => 'ipc-test.library.com',
            matchpoint => 'userid',
            config     => {},
            mappings   => [
                { koha_field => 'userid',  provider_field => 'uid' },
                { koha_field => 'surname', provider_field => 'sn' },
            ],
        }
    );

    my $client = Koha::Auth::Client::SAML2->new;

    # Pass undef for saml_attributes — should auto-load from ENV
    my ( $ok, $cardnumber, $userid, $ret_patron ) = $client->checkpw( 'ipc_user', undef, 'ipc-test.library.com' );

    is( $ok,              1,                   'patron authenticated in IPC mode' );
    is( $cardnumber,      $patron->cardnumber, 'correct cardnumber returned' );
    is( $userid,          'ipc_user',          'correct userid returned' );
    is( ref($ret_patron), 'Koha::Patron',      'Koha::Patron object returned' );

    # Unknown patron, autocreate disabled → should fail
    my $r2 = $client->checkpw( 'unknown_ipc_user', undef, 'ipc-test.library.com' );
    is( $r2, 0, 'returns 0 for unknown patron with autocreate disabled' );

    $schema->storage->txn_rollback;
};
