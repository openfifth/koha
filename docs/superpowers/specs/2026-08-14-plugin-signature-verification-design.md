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

**Considered and rejected: the OS certificate/key store.** Two reasons it
doesn't fit: (1) this is a *public* verification key, not a secret — OS
keyrings/keystores exist to protect confidentiality, which buys nothing
here; (2) the closest server-side analogue, the system CA trust store, is
built for X.509/TLS chain validation (multiple CAs, expiry, revocation) —
a different trust model than one fixed, non-expiring Ed25519 anchor with no
chain of trust at all. Wrapping the key in an X.509 cert just to live there
would add complexity for no real benefit, and risks mixing plugin-store
trust into the same store other services on the box use for HTTPS
validation.

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

### New config: `plugins_allow_unsigned`

An **absent** signature (no store match at all, or a legacy pre-signing
published version) is not automatically a free pass — it's gated by a new
`koha-conf.xml` entry, matching the `plugins_restricted`/`plugin_repos`
precedent:

```xml
<plugins_allow_unsigned>1</plugins_allow_unsigned>
```

Defaults to **enabled** (`1`) so existing behavior — arbitrary/private
plugins install with no store-signature involvement at all — doesn't break
for sites that don't opt into stricter policy. When disabled (`0`), an
unsigned plugin is a hard block, full stop, no way to override it: new error
code `UNSIGNED`.

When enabled (the default), an absent signature is **never** a silent pass —
it always requires an explicit human decision, surfaced as a two-step
confirm-and-retry:

1. First call to `install()` (via either `add()` or `upload()`) with no
   `confirm_unsigned` param and an absent signature returns a new,
   *non-terminal* code: `UNSIGNEDCONFIRMREQUIRED`. Nothing is installed.
2. The caller (REST controller → Vue) shows a confirmation dialog — *"This
   plugin isn't signed by the plugin store. It may be a private/in-house
   plugin the store has never seen, or one published before this store
   supported signing. Install anyway?"* with Cancel/Continue.
3. On Continue, the exact same request is re-issued with
   `confirm_unsigned: true` (JSON field for `add()`, form field for
   `upload()`). This time `install()` proceeds.

This is distinct from `plugins_allow_unsigned=0`'s `UNSIGNED`, which never
offers a confirmation option at all — the config flag controls whether
unsigned installs are *possible*; the confirm step exists so the fact of
"this went unverified" is never silent when they are.

A genuinely **invalid** signature (present but fails verification) is a
different situation and is unaffected by any of the above — always
`SIGNATUREMISMATCH`, always a hard block, never offered a confirmation
dialog. Tampering/corruption is not something a "continue anyway" prompt is
appropriate for.

### Store-install path

`Koha::Plugins::Store::lookup_by_kpz_url()` is extended to also return
`signed_manifest`/`signature` from the store's discovery API response
(alongside the existing `repo_url`/`certification_tier`). `install()`'s
logic, in order:

1. Both `signed_manifest`/`signature` present → `_verify_signature`. Valid →
   proceed (subject to the existing, independent `certification_tier` gate).
   Invalid → `SIGNATUREMISMATCH`, hard fail — the `kpz_url` came from the
   store's own discovery listing, so a mismatch here is a genuine
   tamper/corruption/MITM signal.
2. Either field absent (legacy pre-signing published version, or the store
   simply didn't return one) → the `plugins_allow_unsigned`/confirm-and-retry
   logic above.

`SearchModal.vue` already has each release's `signature` field from the
discovery listing it fetched for display — it can show the confirmation
dialog *before* even calling the install API for a plainly-unsigned release,
saving a round trip. The server-side check stays authoritative regardless
(the client-side check is a UX shortcut, never a substitute) — the actual
`add()` call still needs `confirm_unsigned: true` to succeed.

### Upload path

`Koha::REST::V1::Plugins::upload()` currently never consults the store at
all (no `repo_url`/`certification_tier` lookup) — a `.kpz` dragged in
directly could be a private, in-house plugin never submitted to any store,
and that must keep working. After computing the digest (already happens),
call `GET /api/plugins/verify?digest=<digest>` against the configured store
URL:

- **404** (nothing in the store matches this digest) → absent signature,
  same `plugins_allow_unsigned`/confirm-and-retry logic as the store-install
  path. Unlike `SearchModal.vue`, `upload()` cannot know signed-status ahead
  of time — the confirm dialog can only appear after the first API round
  trip returns `UNSIGNEDCONFIRMREQUIRED`.
- **200** (a published version matches) → run the same
  `_verify_signature` + `_meets_minimum_level` checks the store-install path
  uses, with the `certification_tier` from this response. A mismatch here
  is `SIGNATUREMISMATCH`, same as the store-install path.

Existing `_repo_allowed`/`plugins_restricted` checks are unrelated to any of
the above and still apply independently on both paths.

**Implementation note for `UploadModal.vue`'s retry:** unlike `add()`'s
trivial `{kpz_url}` retry, the confirm-and-retry step here means re-sending
the multipart upload, so the component must hold onto the selected `File`
object across the rejected first attempt and the confirmed retry, not just a
boolean flag — worth flagging explicitly since it's the one path where the
retry isn't just "the same tiny JSON body again."

## 4. Error codes and surfacing

Three new error codes, matching the existing all-caps, no-underscore
convention (`NOTKPZ`, `NOWRITEPLUGINS`, `RESTRICTED`, `BELOWMINIMUMLEVEL`,
`UNZIPFAIL`):

- `SIGNATUREMISMATCH` — a signature is present but fails verification.
  Always a terminal, hard-block error.
- `UNSIGNED` — no signature, and `plugins_allow_unsigned=0`. Always a
  terminal, hard-block error.
- `UNSIGNEDCONFIRMREQUIRED` — no signature, `plugins_allow_unsigned=1`
  (default), and no `confirm_unsigned` param was sent. **Not** a terminal
  error — a signal to the frontend to show a confirmation dialog and retry.

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
`UNSIGNED`/`UNSIGNEDCONFIRMREQUIRED` → `BELOWMINIMUMLEVEL` (a tampered or
unverified file is a more fundamental problem than a tier that's merely too
low; a confirmed-bad signature is worse than an absent one).

Both `add()` and `upload()` gain the new `confirm_unsigned` param (JSON
field / form field respectively), threaded straight through to
`install()`.

`SearchModal.vue`'s `install()`, `Home.vue`'s `doUpdatePlugin()`, and
`UploadModal.vue`'s existing submit handler all gain (or, for `UploadModal`,
extend) a `.catch()` that special-cases `UNSIGNEDCONFIRMREQUIRED` *before*
falling through to the generic message map — that one code means "show a
confirm dialog and retry with `confirm_unsigned: true` on acceptance," not
"display this as a failure":

```javascript
.catch(error => {
    if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
        // show confirm dialog; on accept, re-issue the same call with
        // { confirm_unsigned: true } added
        return;
    }
    this.error = this.$__(ERROR_MESSAGES[error.message] || "An unknown error has occurred.");
});
```

`ERROR_MESSAGES` currently exists only as a local `const` inside
`UploadModal.vue` (checked — not a shared module; the only other hits are
bundled `dist/*.js` build artifacts from unrelated Vue entry points). Since
`SearchModal.vue` and `Home.vue` need the same map, extract it into a small
shared module (e.g.
`koha-tmpl/intranet-tmpl/prog/js/vue/components/Plugin-store/errorMessages.js`)
and import it from all three, rather than duplicating the object. It gains
`SIGNATUREMISMATCH` and `UNSIGNED` entries with copy that reads as a
security/integrity concern, visibly distinct from the tier-rejection
message — e.g. *"This file's signature doesn't match what the store
signed — it may have been altered or corrupted."* for the former, vs.
`BELOWMINIMUMLEVEL`'s existing tier-rejection copy. `UNSIGNEDCONFIRMREQUIRED`
is deliberately **not** in this map — it's handled entirely by the special
case above, never falls through to a generic message.

## 5. Testing

- **`t/Koha/Plugins/Install.t`** (extend existing subtest style): new
  subtests for `_verify_signature` — valid signature passes; tampered
  manifest JSON fails; tampered signature bytes fail; a valid signature over
  a manifest whose `digest` doesn't match the file's actual digest fails.
  Plus `install()`-level subtests: `SIGNATUREMISMATCH` lands in `%errors`
  for a present-but-invalid signature; absent signature with
  `plugins_allow_unsigned=0` yields `UNSIGNED`; absent signature with
  `plugins_allow_unsigned=1` (default) and no `confirm_unsigned` yields
  `UNSIGNEDCONFIRMREQUIRED` without installing anything; the same case
  *with* `confirm_unsigned=1` proceeds to install. All alongside the
  existing `BELOWMINIMUMLEVEL` subtest.
- **`t/Koha/Plugins/Store.t`** (extend): `lookup_by_kpz_url` returns
  `signed_manifest`/`signature` from a mocked store response.
- **`t/db_dependent/api/v1/plugins.t`** (extend): both `add()` and
  `upload()` — the harmonized single-code error shape; `upload()`'s new call
  to `/api/plugins/verify` (mocked) for both the 404 (no-gate) and 200
  (gate-applies) branches; both endpoints correctly thread `confirm_unsigned`
  through to `install()`.
- **Vue side**: no existing test infrastructure for these components in this
  codebase (no `.test.js`/`__tests__` for any plugin-store Vue file) — the
  `.catch()` additions, the `UNSIGNEDCONFIRMREQUIRED` special case, the
  confirm-dialog-and-retry flow, and the new `ERROR_MESSAGES` entries get
  manual verification only, matching how the rest of this Vue work has been
  tested so far.

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
