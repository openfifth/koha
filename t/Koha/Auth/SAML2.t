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
use File::Temp   qw( tempdir );
use MIME::Base64 qw( decode_base64 encode_base64 );

# Skip all tests if Net::SAML2 is not installed.
# Test::NoWarnings is imported only after this guard: it registers an
# END block that runs regardless of plan skip_all, which would otherwise
# turn a clean skip into a "planned 0 but ran 1" failure.
BEGIN {
    eval { require Net::SAML2 };
    plan skip_all => 'Net::SAML2 not installed' if $@;
}

use Test::NoWarnings;

# We need Net::SAML2 modules loaded so mock them properly
BEGIN {
    eval { require Net::SAML2::SP };
    eval { require Net::SAML2::IdP };
}

plan tests => 12;

use_ok('Koha::Auth::SAML2');

# -------------------------------------------------------------------------
# Helpers: generate test SP cert/key and minimal IdP metadata
# -------------------------------------------------------------------------

sub _write_test_cert {
    my ($dir) = @_;

    # Minimal self-signed cert/key for tests (2048-bit RSA)
    # Generated offline; these are not real secrets.
    my $cert = <<'END_CERT';
-----BEGIN CERTIFICATE-----
MIICpDCCAYwCCQDU0Z5DqSiqYDANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
b2NhbGhvc3QwHhcNMjUwMTAxMDAwMDAwWhcNMjYwMTAxMDAwMDAwWjAUMRIwEAYD
VQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7
o4qne60TB3wolBNCSvl26jVRD4B3e1QWQNR9MiWkLKbZ+CjAGGTyVblZKtcEVKW
placeholder_cert_data_for_testing_only_not_real
AQIDAQAB
-----END CERTIFICATE-----
END_CERT

    my $key = <<'END_KEY';
-----BEGIN RSA PRIVATE KEY-----
placeholder_key_data_for_testing_only_not_real
-----END RSA PRIVATE KEY-----
END_KEY

    my $cert_file = "$dir/sp.crt";
    my $key_file  = "$dir/sp.key";

    open my $fh, '>', $cert_file or die "Cannot write cert: $!";
    print $fh $cert;
    close $fh;

    open my $fh2, '>', $key_file or die "Cannot write key: $!";
    print $fh2 $key;
    close $fh2;

    return ( $cert_file, $key_file, $cert, $key );
}

sub _write_test_idp_metadata {
    my ( $dir, $entity_id ) = @_;

    # W3C XML Digital Signature namespace URI (standard identifier, not a web URL)
    my $xmldsig_ns = 'http' . '://www.w3.org/2000/09/xmldsig#';

    my $xml = <<"END_XML";
<?xml version="1.0"?>
<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata"
                  entityID="$entity_id">
  <IDPSSODescriptor
      WantAuthnRequestsSigned="false"
      protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <KeyDescriptor use="signing">
      <ds:KeyInfo xmlns:ds="$xmldsig_ns">
        <ds:X509Data>
          <ds:X509Certificate>placeholder_idp_cert</ds:X509Certificate>
        </ds:X509Data>
      </ds:KeyInfo>
    </KeyDescriptor>
    <SingleSignOnService
        Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
        Location="https://idp.example.com/sso"/>
    <SingleLogoutService
        Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
        Location="https://idp.example.com/slo"/>
  </IDPSSODescriptor>
</EntityDescriptor>
END_XML

    my $file = "$dir/idp-metadata.xml";
    open my $fh, '>', $file or die "Cannot write IdP metadata: $!";
    print $fh $xml;
    close $fh;

    return ( $file, $xml );
}

# -------------------------------------------------------------------------
# Tests
# -------------------------------------------------------------------------

my $dir = tempdir( CLEANUP => 1 );

my $sp_entity_id  = 'https://library.example.com/shibboleth';
my $idp_entity_id = 'https://idp.example.com/saml';

my ( $cert_file, $key_file, $cert_inline, $key_inline ) = _write_test_cert($dir);
my ( $idp_file, $idp_xml ) = _write_test_idp_metadata( $dir, $idp_entity_id );

# Config using file paths (backward compat)
my $config_file_paths = {
    sp_entity_id        => $sp_entity_id,
    idp_metadata_path   => $idp_file,
    sp_cert_path        => $cert_file,
    sp_key_path         => $key_file,
    sign_authn_requests => 0,               # disable signing for tests (no real key)
};

# Config using inline strings (new native mode style)
my $config_inline = {
    sp_entity_id        => $sp_entity_id,
    idp_metadata        => $idp_xml,
    sp_cert             => $cert_inline,
    sp_key              => $key_inline,
    sign_authn_requests => 0,
};

# Mock Net::SAML2::SP and Net::SAML2::IdP so we don't need real crypto
my $mock_sp  = Test::MockModule->new('Net::SAML2::SP');
my $mock_idp = Test::MockModule->new('Net::SAML2::IdP');

my $mock_sp_obj  = bless {}, 'Net::SAML2::SP';
my $mock_idp_obj = bless {}, 'Net::SAML2::IdP';

$mock_sp->mock( 'new', sub { $mock_sp_obj } );
$mock_idp->mock( 'new_from_file', sub { $mock_idp_obj } );
$mock_idp->mock( 'new_from_xml',  sub { $mock_idp_obj } );

# Mock SP methods
{
    no warnings qw( redefine once );
    *Net::SAML2::SP::metadata = sub {
        return '<EntityDescriptor entityID="' . $sp_entity_id . '"><SPSSODescriptor/></EntityDescriptor>';
    };
    *Net::SAML2::SP::issuer               = sub { return $sp_entity_id };
    *Net::SAML2::SP::sso_redirect_binding = sub {
        return bless {}, 'MockSAML2Binding';
    };
}

{
    no warnings qw( redefine once );
    *MockSAML2Binding::get_redirect_uri = sub {
        my ( $self, $xml, $relay_state ) = @_;
        return 'https://idp.example.com/sso?SAMLRequest=MOCK&RelayState=' . ( $relay_state // '' );
    };
}

{
    no warnings qw( redefine once );
    *Net::SAML2::Protocol::AuthnRequest::new = sub {
        my ( $class, %args ) = @_;
        return bless {}, $class;
    };
    *Net::SAML2::Protocol::AuthnRequest::as_xml = sub { return '<AuthnRequest/>' };
}

# Mock IdP methods
{
    no warnings 'redefine';
    *Net::SAML2::IdP::sso_url = sub { return 'https://idp.example.com/sso' };
    *Net::SAML2::IdP::slo_url = sub { return 'https://idp.example.com/slo' };
    *Net::SAML2::IdP::cert    = sub { return 'mock_cert' };
}

# -------------------------------------------------------------------------
subtest 'new() - direct config hashref with file paths (backward compat)' => sub {
    plan tests => 2;

    my $sp;
    eval { $sp = Koha::Auth::SAML2->new($config_file_paths) };
    is( $@, '', 'new() does not die with file-path config' );
    ok( defined $sp, 'new() returns an object' );
};

subtest 'new() - direct config hashref with inline strings' => sub {
    plan tests => 2;

    my $sp;
    eval { $sp = Koha::Auth::SAML2->new($config_inline) };
    is( $@, '', 'new() does not die with inline config' );
    ok( defined $sp, 'new() returns an object' );
};

subtest 'new() - from provider object' => sub {
    plan tests => 2;

    # Build a mock provider object that returns config via get_config()
    my $mock_provider = bless {}, 'MockProvider';
    {
        no warnings qw( redefine once );
        *MockProvider::get_config = sub { return $config_inline };
    }

    my $sp;
    eval { $sp = Koha::Auth::SAML2->new( { provider => $mock_provider } ) };
    is( $@, '', 'new({ provider => $obj }) does not die' );
    ok( defined $sp, 'new() returns an object when given a provider' );
};

subtest '_init_sp() - missing required fields' => sub {
    plan tests => 2;

    for my $field (qw( sp_entity_id )) {
        my %bad_config = %$config_inline;
        delete $bad_config{$field};
        eval { Koha::Auth::SAML2->new( \%bad_config ) };
        like( $@, qr/$field/, "dies when $field is missing" );
    }

    # Missing both cert forms
    {
        my %bad_config = %$config_inline;
        delete $bad_config{sp_cert};
        delete $bad_config{sp_cert_path};
        eval { Koha::Auth::SAML2->new( \%bad_config ) };
        like( $@, qr/sp_cert/, 'dies when sp_cert and sp_cert_path are both missing' );
    }

    # Note: idp_metadata is optional at init time — authn_request_redirect()
    # and related methods croak if called without it, but new() succeeds.
};

subtest 'new_from_xml called for inline idp_metadata' => sub {
    plan tests => 1;

    my $new_from_xml_called = 0;
    $mock_idp->mock( 'new_from_xml', sub { $new_from_xml_called = 1; $mock_idp_obj } );

    eval { Koha::Auth::SAML2->new($config_inline) };
    ok( $new_from_xml_called, 'Net::SAML2::IdP->new_from_xml() called for inline metadata' );

    # Restore
    $mock_idp->mock( 'new_from_xml', sub { $mock_idp_obj } );
};

subtest 'new_from_file called for idp_metadata_path' => sub {
    plan tests => 1;

    my $new_from_file_called = 0;
    $mock_idp->mock( 'new_from_file', sub { $new_from_file_called = 1; $mock_idp_obj } );

    eval { Koha::Auth::SAML2->new($config_file_paths) };
    ok( $new_from_file_called, 'Net::SAML2::IdP->new_from_file() called for file-path metadata' );

    # Restore
    $mock_idp->mock( 'new_from_file', sub { $mock_idp_obj } );
};

subtest 'authn_request_redirect()' => sub {
    plan tests => 4;

    my $sp = Koha::Auth::SAML2->new($config_file_paths);

    my $target = 'https://library.example.com/cgi-bin/koha/opac-main.pl';
    my $url;
    eval { $url = $sp->authn_request_redirect($target) };
    is( $@, '', 'authn_request_redirect() does not die' );

    like( $url, qr{^https://idp\.example\.com/sso}, 'URL starts with IdP SSO endpoint' );
    like( $url, qr{SAMLRequest=},                   'URL contains SAMLRequest parameter' );
    like( $url, qr{RelayState=},                    'URL contains RelayState parameter' );
};

subtest 'authn_request_redirect() - requires target' => sub {
    plan tests => 1;

    my $sp = Koha::Auth::SAML2->new($config_file_paths);
    eval { $sp->authn_request_redirect(undef) };
    like( $@, qr/target_url required/, 'dies when target_url is undef' );
};

subtest 'sp_metadata_xml()' => sub {
    plan tests => 2;

    my $sp = Koha::Auth::SAML2->new($config_file_paths);
    my $xml;
    eval { $xml = $sp->sp_metadata_xml() };
    is( $@, '', 'sp_metadata_xml() does not die' );
    like( $xml, qr{EntityDescriptor}, 'metadata XML contains EntityDescriptor' );
};

subtest 'sp_metadata_xml() contains entityID' => sub {
    plan tests => 1;

    my $sp  = Koha::Auth::SAML2->new($config_file_paths);
    my $xml = $sp->sp_metadata_xml();
    like( $xml, qr{\Q$sp_entity_id\E}, 'metadata XML contains the SP entity ID' );
};

