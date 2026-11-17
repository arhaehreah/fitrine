# Pixie binary profiles

`targets/spotify-*.json` owns target fingerprints, instruction expectations and
cave allocations and primary/compatibility artifact policy. `targets/runtime-1.2.json`
retains the shared ABI/layout facts used by the migrated 1.4 companion.
`tools/pixie_target.py` loads immutable targets explicitly;
there is no process-global/environment-selected target. Selection requires
the exact short version, bundle build, main UUID and SpotifyShared UUID.

| Spotify | Build | Packaging | Runtime layout |
| --- | --- | --- | --- |
| 9.1.90 | 919002269 | Enabled | Verified old target |
| 9.2.0 | 920002054 | Primary IPA enabled | Reservation counters, wrapper, queue, provider and trace-owner fields unverified; runtime remains inactive |

IPA packaging may patch a 9.2.0 executable. Jailbreak remains 9.1.90-only.
Changing the profile's enabled flag is not runtime-layout verification.

Pixie is opt-in: default builds never include it, on any Spotify version.
Use `PIXIE=1` with Make, or `--pixie` (`--require-pixie` alias) with the pipeline,
to require an enabled exact profile. The primary 9.2.0 artifact is
`out/vitrine-<version>-pixie.ipa`; the compatibility artifact is
`out/vitrine-<version>-pixie-spotify-9.1.90.ipa`. Make's Pixie default input follows
the JSON primary target unless `IPA` was explicitly supplied.
An unsupported version, build or UUID is fatal when Pixie is requested;
9.2.0 packaging warns that its native runtime gates are still closed.
`PIXIE=0` / `--no-pixie` explicitly excludes it. WireGuard admission is independent
and unchanged. Every lane, including default and explicit exclusion, rejects
existing companion payloads, native dependencies and partial overlays.
Malformed or encrypted inputs always fail.

Packaging generates all compiler headers into its private temporary include
directory. Angle-bracket includes select those files ahead of `src/`; source
header snapshots are only the 9.1.90 defaults for standalone fixtures. Builds
never rewrite source headers. Cross-profile header sets are rejected before
compilation. Runtime admission also checks both loaded image UUIDs and bundle
metadata before allowing native mutation.
The constructor, jailbreak writer/import installer, hook installers and public
mutation APIs share `SAPRuntimeProfileAdmitted`; an unsupported host does not
rewrite configuration caches, issue offline/library commands or persist settings.
Jailbreak packaging also uses a private temporary workspace per invocation.

## Focused checks

Run under the repository build lock, for example:

```sh
/usr/bin/lockf -k /tmp/vitrine-build.lock env -u MAKELEVEL THEOS=$HOME/theos \
  python3 -B NativeDownloads/tests/patch_goldens.py
```

Other focused scripts: `tests/profiles.py`,
`tests/profile_runtime.py`, `tests/native_admission.py`,
`tests/runtime_effects.py`, `tests/packaging_admission.py`, `tests/golden_mutation.py`,
`tests/key_mode_runtime.py`, `tests/native_trace_patch.py`, and
`tests/build_guard.py ipa/Spotify-9.1.90.ipa`. `tests/jailbreak_support.py` checks
that the DEB bootstrap reports readiness only after both patches and imports succeed.
They are also included in the
native suite where applicable. If a supplied IPA exists, failures to extract,
assemble or validate it are failures, not skips.

The 1.4 host runner is `tools/test14.py`: 57 compiled fixtures plus eight script
fixtures, selected individually with `--fixture`. Its default runs all 65, not
just the compiled fixtures. The script fixtures cover artwork caching, encrypted
export, Apple M4A encoding, library ZIP packaging, native restrictions/trace ABI,
entitlement preservation and sideload dependency resolution. Pass `--build-dir`
with a fresh temporary directory and remove its generated artifacts afterwards.

The frozen 9.1.90 goldens cover the entire patched executable (fixed-zero trace
and selectable-key variants) and the four existing generated headers, before
signing. They do not promise identical signatures or a byte-identical companion
dylib after runtime fixes. Never regenerate the expected hashes from a changed
patcher.

9.2.0 static proofs are not evidence of account authorization, callback/manager
ownership or offline playback. Real-device capture and separate review are
required before enabling its runtime; no device/library mutation is part of these tests.
The separate host-side nebula account-attributes wiring is also necessary:
Eevee commit `5f7b82e4de89121d1cd1dd6e224b67ad2c9cce52` records download
`NOT_ALLOWED (23)` before that integration. Do not infer offline usability from
an archive containing the companion and valid static patches.

## Target foundation interface

Target data is adapted from Glongq/Vitrine-Pixie
`2632bdf9081665b9fd78e71cea2878edc6aae73c` and EeveeSpotifyReincarnated
`0d9feaa9008e53b06382c61fffcb5cfcfceb2981`, GPL-3.0. The JSON files retain the
upstream native/trace schema and add exact admission metadata. The 9.1.90 export
sites come from that baseline's `patch_export14.py`/`patch_export15.py`; the 9.2.0
export sites and ABI-2 emitter come from Eevee's target/`patch_export.py`.
The source-built companion is now 1.4; no upstream prebuilt library is used.
The host-test drivers and `signing_metadata.py` / `fix_sideload_dependencies.py`
also derive from the pinned Vitrine-Pixie source. The packager uses these helpers
instead of duplicate inline signing/dependency rewrites: embedded XML entitlements
are retained even when `codesign -d` cannot read an ldid signature, and an optional
replacement Vitrine dylib resolves Substrate relative to its own loader.

`companion_build.build_companion` consumes `pixie_target.PROFILES` / `load_target(path)` and passes a
target explicitly to `generate_target.generate_headers(folder, target)` and
`validate_headers(folder, target)`. The CLI requires both `--target` and
`--output`; it refuses the source tree. Compiler include order must put this
invocation-owned folder before `src`. `Generated/TargetProfile.h` contains the
exact identities, the native address macros and `SAP_TARGET_MANAGER_FIELD_SHIFT`;
the retained runtime reads the resulting `SAPProfileQuotaBlockOffset`.
Native patch headers plus `ExportObservationV2Patch.h` and
`ExportMediaUnsealPatch.h` are emitted together. Export window facts are
available as `target.export_windows` for the later companion layout headers.

`build_vitrine_9190.prepare_foundation(native, target)` produces an in-memory
static 1.4 image and report, including export observations. It is **not** a
packaging bypass: callers must first admit the IPA's complete identity tuple.
The packager installs the native overlay and export observations together with
their source-built 1.4 consumer.
All declared allocations, including the 9.2.0 text-tail caves, are checked at
their complete emitted lengths after import injection. Export-only partial
overlays are rejected even when version/build metadata is changed.

Run `python3 -B NativeDownloads/tests/target_foundation.py` under the build lock,
alongside the focused admission checks above. It checks both supplied images,
export replay and branch/resolver targets, complete write boundaries, dyld import
binding, malformed export inputs and simultaneous independent header generation.
Its compiled manager fixture distinguishes the 9.1.90 offset from the 9.2.0 +8
offset; it does not enable or exercise a real Spotify manager on 9.2.0.
