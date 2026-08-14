# Plugin Signature Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire real Ed25519 signature verification into Koha's plugin install flow (both
the store-search "Install"/"Update" path and the manual "Upload" path), replacing the
deliberate no-op in `Koha::Plugins::Install::install()`, and make a signature-verification
failure surface as a visibly different error from a below-minimum-certification-tier
rejection or an unsigned/unknown-provenance plugin.

**Architecture:** A new `_verify_signature` helper in `Koha::Plugins::Install` does the
actual Ed25519 + digest-binding check against a public key baked into Koha core (with a
`koha-conf.xml` override for dev/testing). `install()` gains three new error codes and a
`confirm_unsigned` bypass param. `Koha::Plugins::Store` grows a sibling lookup method for
the upload path's digest-based verification call. The two REST controller actions
(`add()`/`upload()`) get their error response shapes harmonized and gain the new param.
Three Vue components gain the missing error handling this whole feature depends on being
visible at all, using Koha's existing `setConfirmationDialog` UI primitive for the new
confirm-and-retry flow.

**Tech Stack:** Perl (`Modern::Perl`), `Crypt::PK::Ed25519` (from the `CryptX` distribution
— a new Koha dependency), `Mojolicious::Plugin::OpenAPI`, `Mojo::UserAgent`, Vue 3 Options
API, `Test::More`/`Test::Mojo`/`Test::MockModule`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-14-plugin-signature-verification-design.md` (this
  plan's source of truth).
- New error codes, matching the existing all-caps no-underscore convention (`NOTKPZ`,
  `NOWRITEPLUGINS`, `RESTRICTED`, `BELOWMINIMUMLEVEL`, `UNZIPFAIL`): `SIGNATUREMISMATCH`
  (present-but-invalid signature, always hard block), `UNSIGNED` (absent signature +
  `plugins_allow_unsigned=0`, always hard block), `UNSIGNEDCONFIRMREQUIRED` (absent
  signature + `plugins_allow_unsigned=1` [default] + no `confirm_unsigned` param — **not**
  terminal, signals the frontend to confirm-and-retry, nothing installed).
- **Correction to the spec's priority-ordering mechanism:** the spec describes picking the
  reported error via "the first key inserted into `%errors`" being deterministic. That's
  not actually true of Perl hashes — key order is randomized per hash instance and must
  never be relied on for priority. Task 2 below implements priority via an explicit
  ordered `if/elsif` chain instead, not hash insertion order. The *priority itself*
  (`NOTKPZ` → `NOWRITEPLUGINS` → `RESTRICTED` → `SIGNATUREMISMATCH` →
  `UNSIGNED`/`UNSIGNEDCONFIRMREQUIRED` → `BELOWMINIMUMLEVEL`) is unchanged from the spec.
- `plugins_allow_unsigned` (new `koha-conf.xml` entry) defaults to **enabled** (behaves as
  `1` when absent/unset) so existing private/in-house plugin uploads keep working
  unmodified.
- A present-but-**invalid** signature is always `SIGNATUREMISMATCH`, never offered a
  confirmation dialog, regardless of `plugins_allow_unsigned` — that flag only governs
  what happens for an **absent** signature.
- `Koha::Plugins::Search` (a separate, currently uncalled class — confirmed via
  `grep -rn "Koha::Plugins::Search"` finding no callers anywhere in the codebase) is **out
  of scope** for this plan. `SearchModal.vue`/`Home.vue` fetch the store's discovery API
  directly client-side (`plugin-store-api-client.js`'s `getStoreAll`, a CORS request
  straight to the configured `plugin_store_url`), so they already receive
  `signed_manifest`/`signature`/`certification_tier` per release with zero Koha-core Perl
  changes needed for that data to exist client-side — only the *verification-triggering
  call* (`add()`) and the *upload path* need Perl changes.
- Koha's shared `http-client.js` already calls a generic `setError()` (a red
  "Something went wrong: `<code>`" toast) unconditionally for **every** non-2xx API
  response, before the calling component's own success/error callback ever runs — this is
  pre-existing, unrelated infrastructure this plan does not modify. It means the new
  `UNSIGNEDCONFIRMREQUIRED` round-trip will show that generic toast briefly alongside the
  new confirmation dialog. This is a known, accepted, pre-existing rough edge (identical to
  how `UploadModal.vue`'s existing `BELOWMINIMUMLEVEL` handling already behaves today —
  both the generic toast and the friendly message currently show together), not something
  this plan fixes.
- Test layout: `t/Koha/Plugins/Install.t`, `t/Koha/Plugins/Store.t` (both non-DB-dependent,
  `Test::More tests => N` with a fixed count — **update the count** when adding subtests;
  `Test::NoWarnings` is the `+1`), `t/db_dependent/api/v1/plugins.t` (DB-dependent,
  `Test::Mojo` + `t::lib::TestBuilder`, same fixed-count convention).
- Follow existing code style exactly: 4-space indent, `Modern::Perl`, no unrelated
  reformatting.

---

### Task 1: `_verify_signature` and the public key

**Files:**
- Modify: `Koha/Plugins/Install.pm:1-30` (top of file — imports, new constant)
- Modify: `cpanfile:22-23` (new dependency)
- Modify: `debian/control:36-37` and `debian/control:288-289` (Build-Depends and Depends —
  both blocks list the same packages; `libcryptx-perl` sorts alphabetically immediately
  after `libcrypt-openssl-rsa-perl` and before `libdata-ical-perl` in both places)
- Modify: `etc/koha-conf.xml` and `debian/templates/koha-conf-site.xml.in` (new
  `plugin_store_public_key` entry, documented alongside the existing `plugin_repos` block)
- Test: `t/Koha/Plugins/Install.t`

**Interfaces:**
- Produces: `Koha::Plugins::Install::_verify_signature($class, $signed_manifest_json,
  $signature_b64, $digest)` → `1` (valid) or `0` (invalid, for any reason — bad signature,
  wrong digest, malformed JSON). Never dies on bad input; a verification failure is a
  normal `0`, not an exception.
- Produces: `Koha::Plugins::Install::DEFAULT_STORE_PUBLIC_KEY` (a constant — the fallback
  public key PEM string when no `plugin_store_public_key` config override is set).

- [ ] **Step 1: Add the CryptX dependency**

In `cpanfile`, immediately after the existing `Crypt::Eksblowfish::Bcrypt` line:

```perl
requires 'Crypt::CBC', '2.33';
requires 'Crypt::Eksblowfish::Bcrypt', '0.008';
requires 'CryptX', '0.078';
```

In `debian/control`, in **both** places `libcrypt-openssl-rsa-perl,` appears (the
Build-Depends block around line 37, and the Depends block around line 289 — search for
both, they're not adjacent), add `libcryptx-perl,` on the line immediately after:

```
 libcrypt-openssl-rsa-perl,
 libcryptx-perl,
 libdata-ical-perl,
```

- [ ] **Step 2: Generate a real Ed25519 test keypair for the failing test**

This step produces PEM strings you'll paste literally into the test file (Step 3) and the
implementation (Step 5). Run once, in the KTD container (or any environment with `CryptX`
installed):

```bash
perl -MCrypt::PK::Ed25519 -e '
my $pk = Crypt::PK::Ed25519->new;
$pk->generate_key;
print "PRIVATE:\n", $pk->export_key_pem("private");
print "PUBLIC:\n", $pk->export_key_pem("public");
'
```

Keep the two PEM blocks it prints — you will paste the **public** one into both the test
file (Step 3, as the "real" key the tests verify against) and use a *different*,
independently-generated keypair's public key as the `DEFAULT_STORE_PUBLIC_KEY` constant in
Step 5 (they must not be the same keypair — the constant is a placeholder for whatever the
real community store's key turns out to be once deployed; the test fixture's keypair is
purely local to the test file and never needs to match).

- [ ] **Step 3: Write the failing test**

In `t/Koha/Plugins/Install.t`, change `use Test::More tests => 7;` to
`use Test::More tests => 8;` (one new subtest), and add near the top, after the existing
`use Koha::Plugins::Install;` line:

```perl
use Crypt::PK::Ed25519;
use Mojo::JSON qw(encode_json);
```

Add this new subtest after the existing `'certification tier below PluginStoreMinimumLevel is rejected'` subtest (the last one in the file):

```perl
subtest '_verify_signature' => sub {
    plan tests => 5;

    my $keypair = Crypt::PK::Ed25519->new;
    $keypair->generate_key;
    my $public_key_pem  = $keypair->export_key_pem('public');
    my $private_key_pem = $keypair->export_key_pem('private');

    my $manifest = encode_json(
        {
            slug         => 'widget',
            version      => '1.0.0',
            kpz_url      => 'https://example.com/widget.kpz',
            digest       => 'abc123',
            published_at => '2026-01-01T00:00:00Z',
        }
    );
    my $signer    = Crypt::PK::Ed25519->new( \$private_key_pem );
    my $signature = MIME::Base64::encode_base64( $signer->sign_message($manifest), '' );

    my $install_module = Test::MockModule->new('Koha::Plugins::Install');
    $install_module->mock( _store_public_key => sub { return $public_key_pem } );

    ok(
        Koha::Plugins::Install->_verify_signature( $manifest, $signature, 'abc123' ),
        'a valid signature over the matching digest verifies'
    );

    ok(
        !Koha::Plugins::Install->_verify_signature( $manifest, $signature, 'wrongdigest' ),
        'a valid signature over a NON-matching digest fails -- the manifest is for a different file'
    );

    ( my $tampered_manifest = $manifest ) =~ s/widget/tampered/;
    ok(
        !Koha::Plugins::Install->_verify_signature( $tampered_manifest, $signature, 'abc123' ),
        'a tampered manifest fails signature verification'
    );

    my $other_keypair = Crypt::PK::Ed25519->new;
    $other_keypair->generate_key;
    my $wrong_signature = MIME::Base64::encode_base64( $other_keypair->sign_message($manifest), '' );
    ok(
        !Koha::Plugins::Install->_verify_signature( $manifest, $wrong_signature, 'abc123' ),
        'a signature from the wrong keypair fails'
    );

    ok(
        !Koha::Plugins::Install->_verify_signature( 'not valid json', $signature, 'abc123' ),
        'malformed manifest JSON fails cleanly rather than dying'
    );
};
```

- [ ] **Step 4: Run the test to verify it fails**

```bash
ktd --name "${KTD_INSTANCE:-kohadev}" --shell --run 'prove -v t/Koha/Plugins/Install.t'
```

Expected: FAIL — `_verify_signature` doesn't exist yet, and `_store_public_key` (the mocked
method) doesn't exist either. Also expect a `cpanm CryptX` install may be needed first if
this environment doesn't already have it (`ktd --name "${KTD_INSTANCE:-kohadev}" --shell --run 'cpanm CryptX'`).

- [ ] **Step 5: Implement `_verify_signature` and the public key resolution**

In `Koha/Plugins/Install.pm`, add to the top `use` block (after `use Digest::SHA
qw(sha256_hex);`):

```perl
use Crypt::PK::Ed25519;
use MIME::Base64 qw(decode_base64);
use Mojo::JSON   qw(decode_json);
```

Add this constant near the top of the file, after the `use` block and before `sub
register`/`sub install` (whichever comes first — in this file, before `sub install`):

```perl
# The real community plugin-store's Ed25519 public key. Deployments (or dev/testing
# environments pointed at a different store, e.g. a self-hosted mirror) can override
# via koha-conf.xml's plugin_store_public_key -- see _store_public_key below.
use constant DEFAULT_STORE_PUBLIC_KEY => <<'PEM';
-----BEGIN PUBLIC KEY-----
REPLACE_WITH_THE_REAL_COMMUNITY_STORE_KEY_ONCE_DEPLOYED
-----END PUBLIC KEY-----
PEM
```

Add these two new methods (anywhere among the other `_`-prefixed helper methods, e.g.
right after `_digest`):

```perl
sub _store_public_key {
    my ($class) = @_;
    return C4::Context->config('plugin_store_public_key') // DEFAULT_STORE_PUBLIC_KEY;
}

sub _verify_signature {
    my ( $class, $signed_manifest_json, $signature_b64, $digest ) = @_;

    my $manifest = eval { decode_json($signed_manifest_json) };
    return 0 unless $manifest;
    return 0 unless ( $manifest->{digest} // '' ) eq ( $digest // '' );

    my $public_key_pem = $class->_store_public_key;
    my $pk             = eval { Crypt::PK::Ed25519->new( \$public_key_pem ) };
    return 0 unless $pk;

    my $signature = eval { decode_base64($signature_b64) };
    return 0 unless $signature;

    return eval { $pk->verify_message( $signature, $signed_manifest_json ) } ? 1 : 0;
}
```

- [ ] **Step 6: Run the test to verify it passes**

Same command as Step 4. Expected: PASS — all 5 new assertions succeed, existing subtests
unaffected.

- [ ] **Step 7: Document `plugin_store_public_key` in the config templates**

In `etc/koha-conf.xml`, find the existing `<plugin_repos>` block (search for
`<plugin_repos>`) and add immediately after its closing `</plugin_repos>`:

```xml
 <!-- Override the Ed25519 public key used to verify the plugin store's signatures.
      Only needed for development/testing against an alternate or self-hosted store --
      production deployments should rely on the key baked into Koha core.
 <plugin_store_public_key>
-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----
 </plugin_store_public_key>
 -->
```

Make the identical addition in `debian/templates/koha-conf-site.xml.in` at the same
relative location (immediately after that file's own `</plugin_repos>`).

- [ ] **Step 8: Commit**

```bash
git add cpanfile debian/control etc/koha-conf.xml debian/templates/koha-conf-site.xml.in \
  Koha/Plugins/Install.pm t/Koha/Plugins/Install.t
git commit -m "Bug 35837: Add Ed25519 signature verification to Koha::Plugins::Install"
```

---

### Task 2: Unsigned-install gating and the `confirm_unsigned` bypass

**Files:**
- Modify: `Koha/Plugins/Install.pm` (`install()`, new config doc)
- Modify: `etc/koha-conf.xml` and `debian/templates/koha-conf-site.xml.in`
  (`plugins_allow_unsigned`)
- Test: `t/Koha/Plugins/Install.t`

**Interfaces:**
- Consumes: `Koha::Plugins::Install::_verify_signature` (Task 1).
- Produces: `install()` accepts three new optional params: `signed_manifest`,
  `signature`, `confirm_unsigned`. Returns the three new error keys
  (`SIGNATUREMISMATCH`, `UNSIGNED`, `UNSIGNEDCONFIRMREQUIRED`) in its `%errors`-derived
  return hash, per the priority rules in Global Constraints.

- [ ] **Step 1: Write the failing tests**

In `t/Koha/Plugins/Install.t`, change `use Test::More tests => 8;` to
`use Test::More tests => 12;` (four new subtests), and add these four subtests after the
`'_verify_signature'` subtest added in Task 1:

```perl
subtest 'a present, invalid signature is SIGNATUREMISMATCH regardless of plugins_allow_unsigned' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted',     0 );
    t::lib::Mocks::mock_config( 'plugins_allow_unsigned', 1 );
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path        => _fixture_kpz(),
            filename        => 'plugin.kpz',
            signed_manifest => '{"digest":"not-the-real-digest"}',
            signature       => 'ZmFrZQ==',    # base64 of 'fake' -- decodes fine, verifies against nothing real
        }
    );
    ok( !$ok, 'install is rejected when a signature is present but does not verify' );
    is( $result->{SIGNATUREMISMATCH}, 1, 'SIGNATUREMISMATCH error set' );
};

subtest 'an absent signature is UNSIGNED when plugins_allow_unsigned is off' => sub {
    plan tests => 2;
    t::lib::Mocks::mock_config( 'plugins_restricted',     0 );
    t::lib::Mocks::mock_config( 'plugins_allow_unsigned', 0 );
    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.kpz' } );
    ok( !$ok, 'install is rejected outright with no signature and unsigned installs disabled' );
    is( $result->{UNSIGNED}, 1, 'UNSIGNED error set' );
};

subtest 'an absent signature requires confirmation when plugins_allow_unsigned is on (the default)' => sub {
    plan tests => 3;
    t::lib::Mocks::mock_config( 'plugins_restricted',     0 );
    t::lib::Mocks::mock_config( 'plugins_allow_unsigned', 1 );

    my ( $ok, $result ) = Koha::Plugins::Install->install( { kpz_path => _fixture_kpz(), filename => 'plugin.kpz' } );
    ok( !$ok, 'install is not performed on the first, unconfirmed attempt' );
    is( $result->{UNSIGNEDCONFIRMREQUIRED}, 1, 'UNSIGNEDCONFIRMREQUIRED error set' );

    ( $ok, $result ) = Koha::Plugins::Install->install(
        { kpz_path => _fixture_kpz(), filename => 'plugin.kpz', confirm_unsigned => 1 }
    );
    ok( $ok, 'the same request with confirm_unsigned set proceeds to install' );
};

subtest 'plugins_allow_unsigned defaults to enabled when unset' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );

    # deliberately NOT calling mock_config('plugins_allow_unsigned', ...) -- confirms
    # the C4::Context->config('plugins_allow_unsigned') // 1 default takes effect
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        { kpz_path => _fixture_kpz(), filename => 'plugin.kpz', confirm_unsigned => 1 }
    );
    ok( $ok, 'an unconfigured plugins_allow_unsigned behaves as enabled (matches pre-existing behavior)' );
};
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
ktd --name "${KTD_INSTANCE:-kohadev}" --shell --run 'prove -v t/Koha/Plugins/Install.t'
```

Expected: the four new subtests FAIL — `install()` doesn't know about
`signed_manifest`/`signature`/`confirm_unsigned` yet, and `plugins_allow_unsigned` isn't
consulted.

- [ ] **Step 3: Rework `install()`'s error-collection logic**

In `Koha/Plugins/Install.pm`, replace the `sub install` body (from `my ( $class, $params )
= @_;` through the `return ( 1, { digest => $digest } );` line) with:

```perl
sub install {
    my ( $class, $params ) = @_;

    my $kpz_path         = $params->{kpz_path};
    my $filename         = $params->{filename} // '';
    my $repo_url         = $params->{repo_url};
    my $tier             = $params->{certification_tier};
    my $signed_manifest  = $params->{signed_manifest};
    my $signature        = $params->{signature};
    my $confirm_unsigned = $params->{confirm_unsigned};

    my %errors;
    $errors{NOTKPZ} = 1 if $filename !~ /\.kpz$/i;

    my $plugins_dir = C4::Context->config('pluginsdir');
    $plugins_dir = ref($plugins_dir) eq 'ARRAY' ? $plugins_dir->[0] : $plugins_dir;
    $errors{NOWRITEPLUGINS} = 1 unless -w $plugins_dir;

    $errors{RESTRICTED} = 1 unless $class->_repo_allowed($repo_url);

    # Computed here (rather than after the early-return below, as before) because the
    # signature check needs it -- the manifest's own digest must match this exact file,
    # not merely verify against something the store once signed.
    my $digest = $class->_digest($kpz_path);

    if ( $signed_manifest && $signature ) {
        $errors{SIGNATUREMISMATCH} = 1
            unless $class->_verify_signature( $signed_manifest, $signature, $digest );
    }
    else {
        my $allow_unsigned = C4::Context->config('plugins_allow_unsigned') // 1;
        if ( !$allow_unsigned ) {
            $errors{UNSIGNED} = 1;
        }
        elsif ( !$confirm_unsigned ) {
            $errors{UNSIGNEDCONFIRMREQUIRED} = 1;
        }
    }

    $errors{BELOWMINIMUMLEVEL} = 1 unless $class->_meets_minimum_level($tier);

    return ( 0, \%errors ) if %errors;

    my $ae = Archive::Extract->new( archive => $kpz_path, type => 'zip' );
    unless ( $ae->extract( to => $plugins_dir ) ) {
        return ( 0, { UNZIPFAIL => $ae->error } );
    }

    Koha::Plugins->new->InstallPlugins( { verbose => 0 } );

    return ( 1, { digest => $digest } );
}
```

Also update the POD block immediately above `sub install` (the `my ( $ok, $result ) =
Koha::Plugins::Install->install({...})` example and error-keys list) to add the three new
params and error keys:

```
    my ( $ok, $result ) = Koha::Plugins::Install->install({
        kpz_path            => $local_path_to_kpz,
        filename            => $original_filename,     # used for the .kpz extension check
        repo_url            => $repo_url,               # optional; the plugin's origin repo, if known
        certification_tier  => $tier,                   # optional; the plugin-store's tier for this version, if known
        signed_manifest     => $signed_manifest_json,   # optional; the plugin-store's signed manifest for this version, if known
        signature           => $signature_b64,          # optional; the plugin-store's signature over signed_manifest, if known
        confirm_unsigned    => $bool,                    # optional; bypasses UNSIGNEDCONFIRMREQUIRED once the caller has confirmed
    });

Validates, then extracts and installs, a plugin already downloaded to a local path. On success
returns C<(1, { digest => $sha256_hex })>. On failure returns C<(0, \%errors)> where C<%errors>
keys are any of C<NOTKPZ>, C<NOWRITEPLUGINS>, C<RESTRICTED>, C<SIGNATUREMISMATCH>, C<UNSIGNED>,
C<UNSIGNEDCONFIRMREQUIRED>, C<BELOWMINIMUMLEVEL>, C<UNZIPFAIL> -- never installs anything if any
check fails.
```

- [ ] **Step 4: Run the tests to verify they pass**

Same command as Step 2. Expected: all 12 subtests in the file PASS.

- [ ] **Step 5: Document `plugins_allow_unsigned` in the config templates**

In `etc/koha-conf.xml`, immediately after the `<plugins_restart>1</plugins_restart>`
line (right before the existing `<plugin_repos>` block):

```xml
 <plugins_restart>1</plugins_restart>
 <!-- Whether a plugin with no known signature from the configured plugin store may be
      installed at all (after an explicit confirmation prompt in the staff client). Set
      to 0 to require every install to have a valid store signature. Defaults to enabled
      (1) when this entry is absent, to preserve support for private/in-house plugins. -->
 <plugins_allow_unsigned>1</plugins_allow_unsigned>
```

Make the identical addition in `debian/templates/koha-conf-site.xml.in`, in the same
relative position (after that file's own `plugins_restart` entry).

- [ ] **Step 6: Commit**

```bash
git add Koha/Plugins/Install.pm t/Koha/Plugins/Install.t \
  etc/koha-conf.xml debian/templates/koha-conf-site.xml.in
git commit -m "Bug 35837: Gate unsigned plugin installs behind plugins_allow_unsigned"
```

---

### Task 3: `Koha::Plugins::Store` — signed manifest lookups

**Files:**
- Modify: `Koha/Plugins/Store.pm`
- Test: `t/Koha/Plugins/Store.t`

**Interfaces:**
- Produces: `Koha::Plugins::Store::lookup_by_kpz_url($kpz_url)` now also returns
  `signed_manifest`/`signature` in its result hash (alongside the existing
  `repo_url`/`certification_tier`).
- Produces: new `Koha::Plugins::Store::lookup_by_digest($digest)` →
  `{ signed_manifest, signature, certification_tier }` or `undef` (store not configured,
  unreachable, or no published version matches that digest — mirrors
  `lookup_by_kpz_url`'s existing undef-on-no-match behavior, calling the store's
  `GET /api/plugins/verify?digest=<digest>` endpoint instead of the discovery listing).

- [ ] **Step 1: Write the failing tests**

In `t/Koha/Plugins/Store.t`, replace the third subtest (`'resolves repo_url and
certification_tier for a matching kpz_url'`) entirely with:

```perl
subtest 'resolves repo_url, certification_tier, signed_manifest, and signature for a matching kpz_url' => sub {
    plan tests => 1;

    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );
    t::lib::Mocks::mock_preference( 'Version', '26.06.00.000' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx   = Mojo::Transaction::HTTP->new;
            my $body = '[{"repo_url":"https://github.com/openfifth/koha-plugin-coverflow","releases":'
                . '[{"kpz_url":"https://example.com/match.kpz","certification_tier":"CERTIFIED",'
                . '"signed_manifest":"{\"digest\":\"abc123\"}","signature":"fakesignaturebase64=="}]}]';
            $tx->res->code(200);
            $tx->res->body($body);
            return $tx;
        }
    );

    is_deeply(
        Koha::Plugins::Store->lookup_by_kpz_url('https://example.com/match.kpz'),
        {
            repo_url           => 'https://github.com/openfifth/koha-plugin-coverflow',
            certification_tier => 'CERTIFIED',
            signed_manifest    => '{"digest":"abc123"}',
            signature          => 'fakesignaturebase64==',
        },
        'repo_url, certification_tier, signed_manifest, and signature all resolved from the matching release'
    );
};
```

Then add two new subtests at the end of the file for `lookup_by_digest`, and update
`use Test::More tests => 4;` to `use Test::More tests => 6;` (two more subtests):

```perl
subtest 'lookup_by_digest returns undef when plugin_store_url is not configured' => sub {
    plan tests => 1;
    t::lib::Mocks::mock_config( 'plugin_store_url', undef );
    is( Koha::Plugins::Store->lookup_by_digest('abc123'), undef, 'undef when the store URL is not configured' );
};

subtest 'lookup_by_digest resolves signed_manifest, signature, and certification_tier for a known digest' => sub {
    plan tests => 2;

    t::lib::Mocks::mock_config( 'plugin_store_url', 'http://store.example.com' );

    my $ua_module = Test::MockModule->new('Mojo::UserAgent');
    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res->code(200);
            $tx->res->body(
                '{"signed_manifest":"{\"digest\":\"abc123\"}","signature":"fakesig==","certification_tier":"CERTIFIED"}'
            );
            return $tx;
        }
    );
    is_deeply(
        Koha::Plugins::Store->lookup_by_digest('abc123'),
        { signed_manifest => '{"digest":"abc123"}', signature => 'fakesig==', certification_tier => 'CERTIFIED' },
        'fields resolved from a 200 response'
    );

    $ua_module->mock(
        get => sub {
            my $tx = Mojo::Transaction::HTTP->new;
            $tx->res->code(404);
            return $tx;
        }
    );
    is( Koha::Plugins::Store->lookup_by_digest('unknown'), undef, 'undef on a 404 (no matching published version)' );
};
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
ktd --name "${KTD_INSTANCE:-kohadev}" --shell --run 'prove -v t/Koha/Plugins/Store.t'
```

Expected: FAIL — `lookup_by_kpz_url` doesn't return the two new fields yet, and
`lookup_by_digest` doesn't exist.

- [ ] **Step 3: Implement**

In `Koha/Plugins/Store.pm`, change the `return` inside `lookup_by_kpz_url`'s loop from:

```perl
            return {
                repo_url           => $plugin->{repo_url},
                certification_tier => $release->{certification_tier},
            };
```

to:

```perl
            return {
                repo_url           => $plugin->{repo_url},
                certification_tier => $release->{certification_tier},
                signed_manifest    => $release->{signed_manifest},
                signature          => $release->{signature},
            };
```

Add this new method after `lookup_by_kpz_url` (before the final `1;`):

```perl
=head3 lookup_by_digest

    my $info = Koha::Plugins::Store->lookup_by_digest($digest);
    # { signed_manifest => '...', signature => '...', certification_tier => '...' } or undef

Queries the configured plugin-store's digest-lookup endpoint
(C<GET /api/plugins/verify?digest=...>) for a published version matching the given SHA-256
digest -- used for manually-uploaded files, which have no C<kpz_url> to match against the
discovery listing C<lookup_by_kpz_url> consults. Returns C<undef> if C<plugin_store_url>
isn't configured, the store isn't reachable, or no published version has that digest.

=cut

sub lookup_by_digest {
    my ( $class, $digest ) = @_;

    my $store_url = C4::Context->config('plugin_store_url');
    return unless $store_url;

    my $ua = Mojo::UserAgent->new;
    my $tx = $ua->get("$store_url/api/plugins/verify?digest=$digest");

    return unless $tx->res->code && $tx->res->code == 200;

    my $result = eval { $tx->res->json };
    return unless $result;

    return {
        signed_manifest    => $result->{signed_manifest},
        signature          => $result->{signature},
        certification_tier => $result->{certification_tier},
    };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Same command as Step 2. Expected: all 6 subtests in the file PASS.

- [ ] **Step 5: Commit**

```bash
git add Koha/Plugins/Store.pm t/Koha/Plugins/Store.t
git commit -m "Bug 35837: Add Koha::Plugins::Store::lookup_by_digest, extend lookup_by_kpz_url"
```

---

### Task 4: Wire verification into the REST controllers

**Files:**
- Modify: `Koha/REST/V1/Plugins.pm` (`add()`, `upload()`)
- Modify: `api/v1/swagger/paths/plugins.yaml`
- Test: `t/db_dependent/api/v1/plugins.t`

**Interfaces:**
- Consumes: `Koha::Plugins::Store::lookup_by_kpz_url`/`lookup_by_digest` (Task 3),
  `Koha::Plugins::Install::install` with its new params (Task 2).
- Produces: `add()`'s error response is now `{error: <single code>}` (matching `upload()`),
  computed via explicit priority ordering (see Global Constraints — never hash key order).
  Both `add()` and `upload()` accept an optional `confirm_unsigned` boolean (JSON body
  field for `add()`, form field for `upload()`).

- [ ] **Step 1: Write the failing tests**

In `t/db_dependent/api/v1/plugins.t`, update the `add()` subtest's `plan tests => 8;` to
`plan tests => 17;` (9 new assertions — count them carefully: the new `is()` call is 1,
each `post_ok`/`status_is`/`json_is` in a chain is 1 apiece), and insert these assertions
immediately after the existing rejected-install
block (after the `$t->post_ok(...)->status_is( 403, 'A rejected install...` call around line
80-81), before the `Missing kpz_url` test:

```perl
    is(
        $t->tx->res->json->{error}, 'RESTRICTED',
        'the harmonized error shape reports a single code, matching upload()'
    );

    $install_module->mock( install => sub { return ( 0, { SIGNATUREMISMATCH => 1, BELOWMINIMUMLEVEL => 1 } ) } );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://example.com/plugin.kpz' } )
        ->status_is(403);
    is(
        $t->tx->res->json->{error}, 'SIGNATUREMISMATCH',
        'when multiple errors are present, SIGNATUREMISMATCH is reported ahead of BELOWMINIMUMLEVEL'
    );

    $install_module->mock( install => sub {
        my ( $class, $params ) = @_;
        return ( 1, { digest => 'abc123' } ) if $params->{confirm_unsigned};
        return ( 0, { UNSIGNEDCONFIRMREQUIRED => 1 } );
    } );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins" => json => { kpz_url => 'https://example.com/plugin.kpz' } )
        ->status_is(403)
        ->json_is( '/error' => 'UNSIGNEDCONFIRMREQUIRED' );
    $t->post_ok(
        "//$userid:$password\@/api/v1/plugins" =>
            json => { kpz_url => 'https://example.com/plugin.kpz', confirm_unsigned => \1 }
    )->status_is( 201, 'confirm_unsigned is threaded through to install()' );
```

In the same file's `upload()` subtest, update `plan tests => 6;` to `plan tests => 11;`
(5 new assertions), and
add after the existing `plugins_restricted` assertion (the last line before
`$schema->storage->txn_rollback;`):

```perl
    t::lib::Mocks::mock_config( 'plugins_restricted', 0 );
    $install_module->mock( 'install', sub {
        my ( $class, $params ) = @_;
        return ( 1, {} ) if $params->{confirm_unsigned};
        return ( 0, { UNSIGNEDCONFIRMREQUIRED => 1 } );
    } );
    $t->post_ok( "//$userid:$password\@/api/v1/plugins/upload" => form => { file => { file => $kpz_path } } )
        ->status_is(403)
        ->json_is( '/error' => 'UNSIGNEDCONFIRMREQUIRED' );
    $t->post_ok(
        "//$userid:$password\@/api/v1/plugins/upload" =>
            form => { file => { file => $kpz_path }, confirm_unsigned => 1 }
    )->status_is( 201, 'confirm_unsigned is threaded through upload() to install()' );
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
ktd --name "${KTD_INSTANCE:-kohadev}" --shell --run 'prove -v t/db_dependent/api/v1/plugins.t'
```

Expected: FAIL — `add()` still returns the old `{error: 'Install rejected', details:
{...}}` shape, and neither endpoint threads `confirm_unsigned` through yet.

- [ ] **Step 3: Harmonize `add()`'s error shape and thread `confirm_unsigned`**

In `Koha/REST/V1/Plugins.pm`, replace the `sub add` body from `my $lookup = ...` through
the `unless $ok;` line with:

```perl
sub add {
    my $c = shift->openapi->valid_input or return;

    my $body             = $c->req->json // {};
    my $kpz_url          = $body->{kpz_url};
    my $confirm_unsigned = $body->{confirm_unsigned};

    return $c->render( status => 400, openapi => { error => 'Missing kpz_url' } )
        unless $kpz_url;

    my $lookup = Koha::Plugins::Store->lookup_by_kpz_url($kpz_url);

    my $ff   = File::Fetch->new( uri => $kpz_url );
    my $file = eval { $ff->fetch };
    return $c->render( status => 500, openapi => { error => 'Could not download kpz_url' } )
        unless $file;

    my ($filename) = $kpz_url =~ m{([^/]+)$};

    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path           => $file,
            filename           => $filename,
            repo_url           => $lookup ? $lookup->{repo_url}           : undef,
            certification_tier => $lookup ? $lookup->{certification_tier} : undef,
            signed_manifest    => $lookup ? $lookup->{signed_manifest}    : undef,
            signature          => $lookup ? $lookup->{signature}         : undef,
            confirm_unsigned   => $confirm_unsigned,
        }
    );

    return $c->render( status => 403, openapi => { error => _priority_error($result) } )
        unless $ok;
```

Add this new helper function at the bottom of the file, just above the trailing `1;`:

```perl
=head3 _priority_error

    my $code = _priority_error($errors_hashref);

Picks a single error code to report from Koha::Plugins::Install::install()'s C<%errors>
hash, in a fixed priority order -- deliberately NOT C<(keys %$errors)[0]>, since Perl hash
key order is randomized per-instance and must never be relied on for anything meaningful.

=cut

sub _priority_error {
    my ($errors) = @_;

    for my $code (
        qw(NOTKPZ NOWRITEPLUGINS RESTRICTED SIGNATUREMISMATCH UNSIGNED UNSIGNEDCONFIRMREQUIRED BELOWMINIMUMLEVEL UNZIPFAIL)
        )
    {
        return $code if $errors->{$code};
    }

    return ( keys %$errors )[0] // 'unknown_error';
}
```

- [ ] **Step 4: Harmonize `upload()` onto the same helper and thread `confirm_unsigned`**

In `Koha/REST/V1/Plugins.pm`, replace the `sub upload` body's install call and error render:

```perl
    my $confirm_unsigned = $c->req->body_params->param('confirm_unsigned');

    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path         => $tempfile,
            filename         => $upload->filename,
            confirm_unsigned => $confirm_unsigned,
        }
    );

    return $c->render( status => 403, openapi => { error => _priority_error($result) } )
        unless $ok;
```

This replaces the existing `my ( $ok, $result ) = Koha::Plugins::Install->install({
kpz_path => $tempfile, filename => $upload->filename, });` and the `return $c->render(
status => 403, openapi => { error => ( keys %$result )[0] // 'unknown_error' } ) unless
$ok;` lines.

Now add the digest-verification call itself, right before the `install()` call (after
`$upload->move_to($tempfile);`):

```perl
    my $digest = Koha::Plugins::Install->_digest($tempfile);
    my $lookup = Koha::Plugins::Store->lookup_by_digest($digest);
```

and pass its results into the `install()` call:

```perl
    my ( $ok, $result ) = Koha::Plugins::Install->install(
        {
            kpz_path            => $tempfile,
            filename            => $upload->filename,
            certification_tier  => $lookup ? $lookup->{certification_tier} : undef,
            signed_manifest     => $lookup ? $lookup->{signed_manifest}    : undef,
            signature           => $lookup ? $lookup->{signature}         : undef,
            confirm_unsigned    => $confirm_unsigned,
        }
    );
```

(`_digest` is currently a private method computing the digest a second time here is
intentional and cheap — `install()` also computes it internally for its own verification
check; there's no clean way to pass a pre-computed digest into `install()` without
changing its contract, and re-hashing a just-uploaded small `.kpz` file twice is not worth
optimizing away.)

- [ ] **Step 5: Update the OpenAPI spec**

In `api/v1/swagger/paths/plugins.yaml`, in the `/plugins` `post` operation's `body`
parameter schema (around line 84-89), add the new property:

```yaml
      - name: body
        in: body
        schema:
          type: object
          properties:
            kpz_url:
              type: string
              description: URL to the plugin kpz file
            confirm_unsigned:
              type: boolean
              description: Set true to proceed with an unsigned/unverified plugin after the caller has confirmed with the user
```

And update its `"403"` response description (around line 112-115) to document the new
codes:

```yaml
      "403":
        description: |
          Access forbidden. Possible `error` attribute values:

          * `RESTRICTED`
          * `SIGNATUREMISMATCH`
          * `UNSIGNED`
          * `UNSIGNEDCONFIRMREQUIRED`
          * `BELOWMINIMUMLEVEL`
        schema:
          $ref: "../swagger.yaml#/definitions/error"
```

In the `/plugins/upload` `post` operation, add a new formData parameter after the existing
`file` parameter (around line 244-248):

```yaml
      - name: confirm_unsigned
        in: formData
        required: false
        type: boolean
        description: Set true to proceed with an unsigned/unverified plugin after the caller has confirmed with the user
```

And update its existing `"403"` description (around line 266-276) — it's currently missing
`BELOWMINIMUMLEVEL` too (a pre-existing gap, worth fixing while touching this block):

```yaml
      "403":
        description: |
          Access forbidden. Possible `error` attribute values:

          * `RESTRICTED`
          * `NOTKPZ`
          * `UZIPFAIL`
          * `NOWRITEPLUGINS`
          * `NOWRITETEMP`
          * `EMPTYUPLOAD`
          * `SIGNATUREMISMATCH`
          * `UNSIGNED`
          * `UNSIGNEDCONFIRMREQUIRED`
          * `BELOWMINIMUMLEVEL`
        schema:
          $ref: "../swagger.yaml#/definitions/error"
```

- [ ] **Step 6: Run the tests to verify they pass**

Same command as Step 2. Expected: all subtests in `add()` and `upload()` PASS.

- [ ] **Step 7: Commit**

```bash
git add Koha/REST/V1/Plugins.pm api/v1/swagger/paths/plugins.yaml t/db_dependent/api/v1/plugins.t
git commit -m "Bug 35837: Harmonize add()/upload() error shape, thread confirm_unsigned"
```

---

### Task 5: Vue — visible errors and the confirm-and-retry flow

**Files:**
- Create: `koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/errorMessages.js`
- Modify: `koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/UploadModal.vue`
- Modify: `koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/SearchModal.vue`
- Modify: `koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/Home.vue`

**Interfaces:**
- Consumes: the harmonized `{error: '<code>'}` shape and `confirm_unsigned` param
  (Task 4).
- Produces: a shared `ERROR_MESSAGES` export all three components import; a consistent
  confirm-and-retry pattern for `UNSIGNEDCONFIRMREQUIRED` using Koha's existing
  `setConfirmationDialog` UI primitive (already used by `Home.vue`'s `doUninstall`,
  `Home.vue:344-360`).

**Deliberate simplification vs. the spec:** the spec mentions `SearchModal.vue` *could*
check each release's already-fetched `signature` field client-side before even calling the
install API, to save a round trip for the plainly-unsigned case. This plan does not do
that — it always calls the API and handles `UNSIGNEDCONFIRMREQUIRED` via the same
round-trip pattern in all three components, for one consistent code path rather than a
special-cased shortcut in one of them. The spec explicitly framed this as an optional
optimization ("can"), not a requirement, so this is a deliberate scope choice, not a gap.

**No automated test coverage exists for these components in this codebase** (confirmed —
no `.test.js`/`__tests__` for any Plugin-store Vue file). Verify manually against a running
KTD instance after implementing: attempt an install/update/upload of an unsigned plugin,
confirm the dialog appears, confirm accepting it installs, confirm cancelling does not.

- [ ] **Step 1: Extract the shared error-messages module**

Create `koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/errorMessages.js`:

```javascript
// Deliberately does NOT include UNSIGNEDCONFIRMREQUIRED -- that code is not a terminal
// error to display, it's a signal to show a confirmation dialog and retry. Handling it
// as a generic message here would be wrong; each call site special-cases it before
// falling through to this map.
export const ERROR_MESSAGES = {
    NOTKPZ: "The upload file does not appear to be a kpz file.",
    UNZIPFAIL:
        "The file failed to unpack. Please verify the integrity of the zip file and retry.",
    NOWRITEPLUGINS:
        "Cannot unpack file to the plugins directory. Please verify that the web server user can write to the plugins directory.",
    RESTRICTED:
        "Cannot install plugin from unknown source whilst plugin restriction is enabled.",
    NOWRITETEMP:
        "This server is not able to create/write to the necessary temporary directory.",
    EMPTYUPLOAD: "The upload file appears to be empty.",
    BELOWMINIMUMLEVEL:
        "This plugin does not meet the site's minimum certification level.",
    SIGNATUREMISMATCH:
        "This file's signature doesn't match what the store signed -- it may have been altered or corrupted.",
    UNSIGNED:
        "This plugin is not signed by the plugin store, and this site requires a valid signature to install.",
};

export default ERROR_MESSAGES;
```

- [ ] **Step 2: Update `UploadModal.vue` to import the shared module and support confirm-and-retry**

In `UploadModal.vue`, remove the local `const ERROR_MESSAGES = {...}` block (lines 31-44)
entirely, and change the import line to:

```javascript
import { APIClient } from "../../fetch/api-client.js";
import { ERROR_MESSAGES } from "./errorMessages.js";
import { inject } from "vue";
```

Replace the `setup()`/`methods.submit` section — this component needs
`setConfirmationDialog` (for the confirm dialog) in addition to its existing
`setMessage`, and `submit()` needs to hold the selected `File` across a rejected first
attempt and a confirmed retry (per the spec's implementation note — the retry must resend
the actual file, not just a flag):

```javascript
    setup() {
        const { setMessage, setConfirmationDialog } = inject("mainStore");
        return { setMessage, setConfirmationDialog };
    },
    data() {
        return {
            selectedFile: null,
            error: null,
        };
    },
    methods: {
        onFileChange(event) {
            this.selectedFile = event.target.files[0] || null;
        },
        submit(confirmUnsigned = false) {
            this.error = null;
            const formData = new FormData();
            formData.append("file", this.selectedFile);
            if (confirmUnsigned) formData.append("confirm_unsigned", "1");

            const client = APIClient.plugin_store;
            client.plugins.upload(formData).then(
                () => {
                    this.setMessage(this.$__("Plugin has been installed."));
                    this.$emit("uploaded");
                },
                error => {
                    if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
                        this.setConfirmationDialog(
                            {
                                title: this.$__(
                                    "This plugin isn't signed by the plugin store. It may be a private/in-house plugin the store has never seen, or one published before this store supported signing. Install anyway?"
                                ),
                                accept_label: this.$__("Yes, install anyway"),
                                cancel_label: this.$__("No, cancel"),
                            },
                            () => this.submit(true)
                        );
                        return;
                    }
                    this.error = this.$__(
                        ERROR_MESSAGES[error.message] ||
                            "An unknown error has occurred."
                    );
                }
            );
        },
    },
```

Update the template's button click handler from `@click="submit"` to `@click="submit(false)"`.

- [ ] **Step 3: Wire `SearchModal.vue`'s `install()` and add the confirm dialog**

In `SearchModal.vue`, change the import to also pull in the shared messages:

```javascript
import { APIClient } from "../../fetch/api-client.js";
import { ERROR_MESSAGES } from "./errorMessages.js";
import { inject } from "vue";
```

In `setup()`, `setConfirmationDialog` needs adding to the existing destructure (currently
only `setError`/`setMessage` are pulled from `inject("mainStore")`):

```javascript
    setup() {
        const { setError, setMessage, setConfirmationDialog } =
            inject("mainStore");
        return { koha_version, setError, setMessage, setConfirmationDialog };
    },
```

Replace the `install(plugin)` method:

```javascript
        install(plugin, confirmUnsigned = false) {
            const release = this.mostRecentRelease(plugin);
            const client = APIClient.plugin_store;
            client.plugins
                .create({
                    kpz_url: release.kpz_url,
                    ...(confirmUnsigned ? { confirm_unsigned: true } : {}),
                })
                .then(
                    () => {
                        this.setMessage(
                            this.$__("%s has been installed.").format(
                                plugin.name
                            )
                        );
                        this.$emit("installed");
                    },
                    error => {
                        if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
                            this.setConfirmationDialog(
                                {
                                    title: this.$__(
                                        "This plugin isn't signed by the plugin store. It may be a private/in-house plugin the store has never seen, or one published before this store supported signing. Install anyway?"
                                    ),
                                    accept_label: this.$__(
                                        "Yes, install anyway"
                                    ),
                                    cancel_label: this.$__("No, cancel"),
                                },
                                () => this.install(plugin, true)
                            );
                            return;
                        }
                        this.setError(
                            this.$__(
                                ERROR_MESSAGES[error.message] ||
                                    "An unknown error has occurred."
                            )
                        );
                    }
                );
        },
```

- [ ] **Step 4: Wire `Home.vue`'s `doUpdatePlugin()`**

In `Home.vue`, add the import:

```javascript
import { ERROR_MESSAGES } from "./errorMessages.js";
```

`setError` isn't currently destructured from `inject("mainStore")` in this component
(only `setMessage`, `setConfirmationDialog`, `setComponentDialog` are) — add it:

```javascript
        const { setMessage, setError, setConfirmationDialog, setComponentDialog } =
            inject("mainStore");

        return {
            userPermissions: storeRefs.userPermissions,
            isUserPermitted,
            setMessage,
            setError,
            setConfirmationDialog,
            setComponentDialog,
        };
```

Replace `doUpdatePlugin`:

```javascript
        doUpdatePlugin(plugin, confirmUnsigned = false) {
            const release = this.mostRecentRelease(plugin);
            if (!release) {
                this.setMessage(this.$__("Update information not available."));
                return;
            }
            const client = APIClient.plugin_store;
            client.plugins
                .create({
                    kpz_url: release.kpz_url,
                    ...(confirmUnsigned ? { confirm_unsigned: true } : {}),
                })
                .then(
                    () => {
                        this.setMessage(this.$__("Plugin updated."));
                        this.refreshList();
                    },
                    error => {
                        if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
                            this.setConfirmationDialog(
                                {
                                    title: this.$__(
                                        "This plugin isn't signed by the plugin store. It may be a private/in-house plugin the store has never seen, or one published before this store supported signing. Update anyway?"
                                    ),
                                    accept_label: this.$__(
                                        "Yes, update anyway"
                                    ),
                                    cancel_label: this.$__("No, cancel"),
                                },
                                () => this.doUpdatePlugin(plugin, true)
                            );
                            return;
                        }
                        this.setError(
                            this.$__(
                                ERROR_MESSAGES[error.message] ||
                                    "An unknown error has occurred."
                            )
                        );
                    }
                );
        },
```

- [ ] **Step 5: Rebuild the Vue bundle**

```bash
ktd --name "${KTD_INSTANCE:-kohadev}" --shell --run 'yarn build'
```

- [ ] **Step 6: Manual verification**

Against a running KTD instance with `plugins_allow_unsigned` left at its default (unset):

1. Upload an unsigned/private `.kpz` via the Upload tab — confirm the confirmation dialog
   appears with the expected copy, Cancel leaves it uninstalled, Continue installs it.
2. Search-install a plugin from a configured store whose release has no
   `signed_manifest`/`signature` (or point `plugin_store_url` at this session's own
   koha-plugin-store dev instance with a pre-signing-feature plugin version) — confirm the
   same dialog appears from `SearchModal.vue`, and behaves the same way.
3. Set `plugins_allow_unsigned` to `0` in `koha-conf.xml` and restart — confirm the same
   unsigned plugin now fails outright with the `UNSIGNED` message, no confirmation dialog
   offered at all.
4. With a genuinely signed, valid plugin version, confirm normal install/update proceeds
   with no dialog and no errors.

- [ ] **Step 7: Commit**

```bash
git add koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/
git commit -m "Bug 35837: Show visible, actionable errors for plugin install rejections"
```
