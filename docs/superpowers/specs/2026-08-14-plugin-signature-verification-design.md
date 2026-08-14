# Plugin Signature Verification (bug 35837) — Design

> Companion to the koha-plugin-store project's signing feature (PR #22 there):
> every published `plugin_versions` row gets an Ed25519 signature over a canonical
> JSON manifest `{slug, version, kpz_url, digest, published_at}`, exposed via
> `GET /api/plugins` (discovery listing) and a new
> `GET /api/plugins/verify?digest=<sha256hex>` (digest-based lookup for files
> with no known `kpz_url`).

## 1. Goal

Wire real signature verification into Koha's plugin install flow, replacing the
deliberate no-op left in `Koha::Plugins::Install::install()`. A verification
failure and a below-minimum-certification-tier rejection must surface as two
visibly different errors — the koha-plugin-store spec (§4.3, §8) is explicit
that conflating "tampered/corrupted" with "hasn't cleared this site's review
bar yet" is actively harmful: it either hides a tampering event behind a
message admins read as "just lower the syspref," or makes a legitimate
low-tier plugin sound like a security incident.

## 2. Public key configuration

Koha ships with the store's public key baked in, per the koha-plugin-store
spec's explicit "no per-admin key management" design (the approach explored
and abandoned in bug 24632). Matches the existing `plugin_repos`/
`plugins_restricted` precedent in `koha-conf.xml` (both are deploy-time,
sysadmin-controlled config, not syspref/UI-editable — appropriate for a
security trust anchor):

```xml
<plugin_store_public_key>
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEA...
-----END PUBLIC KEY-----
</plugin_store_public_key>
```

`Koha::Plugins::Install` ships a `DEFAULT_STORE_PUBLIC_KEY` constant (the real
community store's public key). Resolution order:
`C4::Context->config('plugin_store_public_key') // DEFAULT_STORE_PUBLIC_KEY`.
The config override exists for development/testing against an alternate store
(or a self-hosted mirror), not for routine admin use.

## 3. Verification logic

New method `Koha::Plugins::Install::_verify_signature($signed_manifest_json,
$signature_b64, $digest)`, using `Crypt::PK::Ed25519` (a **new Koha
dependency** — not currently in `cpanfile`/`debian/control.in`, needs adding).
Two checks, both required:

1. **Signature validity**: `Crypt::PK::Ed25519->new(\$public_key_pem)
   ->verify_message(decode_base64($signature_b64), $signed_manifest_json)`.
2. **Digest binding**: `decode_json($signed_manifest_json)->{digest} eq
   $digest` — the manifest being vouched for must be *this exact file*, not
   merely *some* file the store once signed. A valid signature over the wrong
   manifest is not a pass.

Returns true only if both hold.

### Store-install path

`Koha::Plugins::Store::lookup_by_kpz_url()` is extended to also return
`signed_manifest`/`signature` from the store's discovery API response
(alongside the existing `repo_url`/`certification_tier`). `install()` calls
`_verify_signature` only when **both** fields are present and non-null:

- Present and valid → proceed (subject to the existing `certification_tier`
  gate, unchanged and independent).
- Present and invalid → `SIGNATUREMISMATCH` error, hard fail. The `kpz_url`
  came from the store's own discovery listing, so a mismatch here is a
  genuine tamper/corruption/MITM signal, not an ambiguous case.
- **Absent** (null) → skip the check entirely, install proceeds as today.
  Plugin versions published before this feature shipped have no signature at
  all (nullable columns added via migration, no retroactive backfill) — this
  is the same "verify only when there's something to verify" principle
  applied to legacy data, so existing published plugins don't become
  uninstallable via the store-search flow until their developer cuts a new
  release through the now-signing pipeline.

### Upload path

`Koha::REST::V1::Plugins::upload()` currently never consults the store at
all (no `repo_url`/`certification_tier` lookup) — a `.kpz` dragged in
directly could be a private, in-house plugin never submitted to any store,
and that must keep working. After computing the digest (already happens),
call `GET /api/plugins/verify?digest=<digest>` against the configured store
URL:

- **404** (nothing in the store matches this digest) → not a store plugin.
  No store-specific gate at all — install proceeds exactly as today
  (existing `_repo_allowed`/`plugins_restricted` checks are unrelated and
  still apply independently).
- **200** (a published version matches) → run the same
  `_verify_signature` + `_meets_minimum_level` checks the store-install path
  uses, with the `certification_tier` from this response. A mismatch here
  is `SIGNATUREMISMATCH`, same as the store-install path — a digest match
  against a store-known file that fails signature verification is
  meaningful regardless of which path found it.

Verification is **opportunistic** for uploads: it only ever adds a
gate, never removes the ability to install a plugin the store doesn't know
about.

## 4. Error codes and surfacing

New error code: `SIGNATUREMISMATCH` (matches the existing all-caps,
no-underscore convention: `NOTKPZ`, `NOWRITEPLUGINS`, `RESTRICTED`,
`BELOWMINIMUMLEVEL`, `UNZIPFAIL`). Set only when a signature *is* present and
fails verification — never for absent/legacy data.

`Koha::REST::V1::Plugins::add()` currently returns
`{error: 'Install rejected', details: {BELOWMINIMUMLEVEL: 1, ...}}` — a
generic string plus a details hash `upload()`'s equivalent single-code shape
(`{error: 'BELOWMINIMUMLEVEL'}`) doesn't match, and which
`SearchModal.vue`/`Home.vue` never handle at all (`.then()` with no
`.catch()` — a rejection currently fails completely silently in both flows).

Fix, harmonizing `add()` onto `upload()`'s existing shape:

```perl
# add(), after harmonizing
return $c->render( status => 403, openapi => { error => (keys %errors)[0] // 'unknown_error' } )
    unless %errors ... ;
```

Since Perl hash key order isn't meaningful, `install()`'s internal error
checks are ordered so the *first* key inserted is deterministic and reflects
priority: `NOTKPZ` → `NOWRITEPLUGINS` → `RESTRICTED` → `SIGNATUREMISMATCH` →
`BELOWMINIMUMLEVEL` (matches the existing code's assignment order, with the
new check inserted before the existing tier check — a tampered file is a
more fundamental problem than a tier that's merely too low).

`SearchModal.vue`'s `install()` and `Home.vue`'s `doUpdatePlugin()` both gain
a `.catch()` matching `UploadModal.vue`'s existing, working pattern:

```javascript
.catch(error => {
    this.error = this.$__(ERROR_MESSAGES[error.message] || "An unknown error has occurred.");
});
```

`ERROR_MESSAGES` currently exists only as a local `const` inside
`UploadModal.vue` (checked — not a shared module; the only other hits are
bundled `dist/*.js` build artifacts from unrelated Vue entry points). Since
`SearchModal.vue` and `Home.vue` need the same map, extract it into a small
shared module (e.g.
`koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/errorMessages.js`)
and import it from all three, rather than duplicating the object. It gains a
`SIGNATUREMISMATCH` entry with copy that reads as a security/integrity
concern, visibly distinct from the tier-rejection message — e.g. *"This
file's signature doesn't match what the store signed — it may have been
altered or corrupted."* vs. `BELOWMINIMUMLEVEL`'s existing tier-rejection
copy.

## 5. Testing

- **`t/Koha/Plugins/Install.t`** (extend existing subtest style): new
  subtests for `_verify_signature` — valid signature passes; tampered
  manifest JSON fails; tampered signature bytes fail; a valid signature over
  a manifest whose `digest` doesn't match the file's actual digest fails;
  absent `signed_manifest`/`signature` skips the check (install proceeds).
  Plus an `install()`-level subtest confirming `SIGNATUREMISMATCH` lands in
  the returned `%errors` hash, alongside the existing
  `BELOWMINIMUMLEVEL` subtest.
- **`t/Koha/Plugins/Store.t`** (extend): `lookup_by_kpz_url` returns
  `signed_manifest`/`signature` from a mocked store response.
- **`t/db_dependent/api/v1/plugins.t`** (extend): both `add()` and
  `upload()` — the harmonized single-code error shape; `upload()`'s new call
  to `/api/plugins/verify` (mocked) for both the 404 (no-gate) and 200
  (gate-applies) branches.
- **Vue side**: no existing test infrastructure for these components in this
  codebase (no `.test.js`/`__tests__` for any plugin-store Vue file) — the
  `.catch()` additions and new `ERROR_MESSAGES` entry get manual
  verification only, matching how the rest of this Vue work has been tested
  so far.

## 6. Out of scope (this piece)

- `certification_tier` display in `SearchModal.vue`'s table (separate,
  smaller follow-up — noted, not forgotten).
- Install-count ping and Koha-instance identity (spec §4.2/§7) — still fully
  unbuilt on both sides, deferred until instance identity exists.
- The homegrown `compareVersions`/`date_released`-based "most recent
  release" logic — lower priority, only worth revisiting if release formats
  actually get weirder in practice.
- Moving koha-plugin-store's discovery/verify API under its OpenAPI spec —
  separate housekeeping on that side, doesn't block this work since the
  response shapes are already stable and documented informally.
