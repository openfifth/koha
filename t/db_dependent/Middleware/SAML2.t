#!/usr/bin/perl

# Copyright 2025 Koha Development Team
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
use Test::More;
use Test::MockModule;
use Test::NoWarnings;
use Plack::Test;
use HTTP::Request;
use HTTP::Request::Common qw( GET POST );
use MIME::Base64          qw( encode_base64 );

# Skip if Net::SAML2 is not installed
BEGIN {
    eval { require Net::SAML2 };
    plan skip_all => 'Net::SAML2 not installed' if $@;
}

use t::lib::TestBuilder;
use t::lib::Mocks;

use Koha::Middleware::SAML2;
use Koha::Session;

my $schema  = Koha::Database->new->schema;
my $builder = t::lib::TestBuilder->new;

# Set up system preferences used by the middleware
t::lib::Mocks::mock_preference( 'OPACBaseURL',        'https://opac.example.com' );
t::lib::Mocks::mock_preference( 'staffClientBaseURL', 'https://staff.example.com' );

# -------------------------------------------------------------------------
# Mock provider helpers
# -------------------------------------------------------------------------

# Build a mock provider object for the given mode
sub _mock_provider {
    my ($mode) = @_;
    $mode //= 'native';

    my $config = {
        mode         => $mode,
        sp_entity_id => 'https://library.example.com/shibboleth',
        sp_cert      => "-----BEGIN CERTIFICATE-----\nfake\n-----END CERTIFICATE-----\n",
        sp_key       => "-----BEGIN RSA PRIVATE KEY-----\nfake\n-----END RSA PRIVATE KEY-----\n",
        idp_metadata => '<EntityDescriptor/>',
    };

    my $provider = bless { _config => $config }, 'MockSAML2Provider';
    return $provider;
}

{

    package MockSAML2Provider;

    sub get_config { return $_[0]->{_config} }

    sub is_native {
        my ($self) = @_;
        return ( ( $self->get_config->{mode} // '' ) eq 'native' ) ? 1 : 0;
    }

    sub build_sp {
        my ($self) = @_;
        return bless { _provider => $self }, 'MockSP';
    }
}

# Build a simple pass-through Plack app for "next" middleware
my $passthrough_app = sub {
    return [ 200, [ 'Content-Type' => 'text/plain' ], ['passed through'] ];
};

# Wrap with our middleware
my $app = Koha::Middleware::SAML2->wrap($passthrough_app);

# -------------------------------------------------------------------------
# Helper: mock the _get_provider method to return a specific provider
# -------------------------------------------------------------------------
sub _with_provider {
    my ( $provider, $test_sub ) = @_;

    my $mock_middleware = Test::MockModule->new('Koha::Middleware::SAML2');
    $mock_middleware->mock( '_get_provider', sub { $provider } );
    $test_sub->();
    $mock_middleware->unmock('_get_provider');
}

# -------------------------------------------------------------------------
subtest 'Non-SAML2 paths pass through regardless of provider' => sub {
    plan tests => 2;

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET '/cgi-bin/koha/opac-main.pl' );
                is( $res->code,    200,              'Non-SAML2 path returns 200' );
                is( $res->content, 'passed through', 'Non-SAML2 path reaches next app' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'SAML2 paths pass through when no provider found' => sub {
    plan tests => 2;

    _with_provider(
        undef,
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET '/cgi-bin/koha/saml2/login?target=/cgi-bin/koha/opac-main.pl' );
                is( $res->code,    200,              'Passes through when no provider' );
                is( $res->content, 'passed through', 'Reaches next app when no provider' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'SAML2 paths pass through when provider is IPC mode' => sub {
    plan tests => 2;

    _with_provider(
        _mock_provider('ipc'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET '/cgi-bin/koha/saml2/login?target=/cgi-bin/koha/opac-main.pl' );
                is( $res->code,    200,              'Passes through for IPC provider' );
                is( $res->content, 'passed through', 'Reaches next app for IPC provider' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'GET /cgi-bin/koha/saml2/metadata returns XML for native provider' => sub {
    plan tests => 3;

    {
        no warnings 'redefine';
        *MockSP::sp_metadata_xml = sub {
            return '<EntityDescriptor entityID="https://library.example.com/shibboleth"/>';
        };
    }

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET '/cgi-bin/koha/saml2/metadata' );
                is( $res->code, 200, '/cgi-bin/koha/saml2/metadata returns 200' );
                like(
                    $res->header('Content-Type'),
                    qr{application/samlmetadata\+xml},
                    'Content-Type is application/samlmetadata+xml'
                );
                like( $res->content, qr{EntityDescriptor}, 'Response body contains EntityDescriptor' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'GET /cgi-bin/koha/saml2/login redirects to IdP' => sub {
    plan tests => 3;

    my $idp_url    = 'https://idp.example.com/sso?SAMLRequest=xxx&RelayState=yyy';
    my $target_url = 'https://opac.example.com/cgi-bin/koha/opac-main.pl';

    {
        no warnings 'redefine';
        *MockSP::authn_request_redirect = sub { $idp_url };
    }

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET "/cgi-bin/koha/saml2/login?target=$target_url" );
                is( $res->code,               302,      'Login returns 302' );
                is( $res->header('Location'), $idp_url, 'Redirects to IdP URL' );
                ok( defined $res->header('Location'), 'Location header is set' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'GET /cgi-bin/koha/saml2/login rejects open redirect' => sub {
    plan tests => 1;

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET '/cgi-bin/koha/saml2/login?target=https://evil.example.com/steal' );
                is( $res->code, 400, 'Rejects external target URL (open redirect prevention)' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'POST /cgi-bin/koha/saml2/acs (ACS) stores SAML attributes in session' => sub {
    plan tests => 3;

    $schema->storage->txn_begin;

    my $relay_state = 'https://opac.example.com/cgi-bin/koha/opac-main.pl';

    {
        no warnings 'redefine';
        *MockSP::process_response = sub {
            return {
                all_attributes => { eppn => 'testuser@example.com' },
                relay_state    => $relay_state,
                nameid         => 'testuser@example.com',
                session_index  => 'idx_001',
            };
        };
    }

    my $saml_response = encode_base64('<saml_response_xml/>');

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->(
                    POST '/cgi-bin/koha/saml2/acs',
                    Content => [
                        SAMLResponse => $saml_response,
                        RelayState   => $relay_state,
                    ]
                );

                is( $res->code,               302,          'ACS returns 302 redirect' );
                is( $res->header('Location'), $relay_state, 'Redirects to RelayState' );

                # Verify the session cookie was set
                my $cookie_header = $res->header('Set-Cookie') // '';
                like( $cookie_header, qr{CGISESSID=}, 'CGISESSID cookie is set' );
            };
        }
    );

    $schema->storage->txn_rollback;
};

# -------------------------------------------------------------------------
subtest 'POST /cgi-bin/koha/saml2/acs rejects bad RelayState' => sub {
    plan tests => 2;

    $schema->storage->txn_begin;

    {
        no warnings 'redefine';
        *MockSP::process_response = sub {
            return {
                all_attributes => {},
                relay_state    => 'https://evil.example.com/steal',
                nameid         => 'user@example.com',
            };
        };
    }

    my $saml_response = encode_base64('<saml_response_xml/>');

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->(
                    POST '/cgi-bin/koha/saml2/acs',
                    Content => [
                        SAMLResponse => $saml_response,
                        RelayState   => 'https://evil.example.com/steal',
                    ]
                );

                is( $res->code, 302, 'ACS still returns 302 (falls back to safe URL)' );
                unlike(
                    $res->header('Location') // '',
                    qr{evil\.example\.com},
                    'Location does not redirect to evil domain'
                );
            };
        }
    );

    $schema->storage->txn_rollback;
};

# -------------------------------------------------------------------------
subtest 'POST /cgi-bin/koha/saml2/acs returns 400 without SAMLResponse' => sub {
    plan tests => 1;

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( POST '/cgi-bin/koha/saml2/acs', Content => [] );
                is( $res->code, 400, 'Returns 400 when SAMLResponse is missing' );
            };
        }
    );
};

# -------------------------------------------------------------------------
subtest 'GET /cgi-bin/koha/saml2/logout redirects without SLO if no NameID' => sub {
    plan tests => 2;

    my $return_url = 'https://opac.example.com/cgi-bin/koha/opac-main.pl';

    _with_provider(
        _mock_provider('native'),
        sub {
            test_psgi $app, sub {
                my $cb  = shift;
                my $res = $cb->( GET "/cgi-bin/koha/saml2/logout?return=$return_url" );
                is( $res->code,               302,         'Logout returns 302' );
                is( $res->header('Location'), $return_url, 'Redirects to return URL' );
            };
        }
    );
};

done_testing();
