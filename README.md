<h1 align="center">Vitrine</h1>

<p align="center">Spotify, in glass.</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white" alt="iOS">
  <img src="https://img.shields.io/badge/Spotify-9.1.78-1ED760?style=for-the-badge&logo=spotify&logoColor=white" alt="Spotify 9.1.78">
  <img src="https://img.shields.io/badge/9.1.88-supported-555555?style=for-the-badge&logo=spotify&logoColor=white" alt="Spotify 9.1.88 supported">
  <img src="https://img.shields.io/badge/Objective--C-3A95E3?style=for-the-badge&logo=apple&logoColor=white" alt="Objective-C">
  <img src="https://img.shields.io/badge/GitHub_Actions-2671E5?style=for-the-badge&logo=githubactions&logoColor=white" alt="GitHub Actions">
  <img src="https://img.shields.io/badge/License-GPL_v3-blue?style=for-the-badge" alt="GPL-3.0">
</p>

<p align="center">
  <a href="#build-it">Build it</a> ·
  <a href="docs/tweaks.md">Hack on it</a>
</p>

<p align="center">
  <img src="docs/screenshots/now-playing.webp" width="16%" alt="Full screen player with lyrics">
  <img src="docs/screenshots/album.webp" width="16%" alt="Album">
  <img src="docs/screenshots/playlist.webp" width="16%" alt="Playlist">
  <img src="docs/screenshots/queue.webp" width="16%" alt="Queue">
  <img src="docs/screenshots/live-activity.webp" width="16%" alt="Live Activity on the lock screen">
  <img src="docs/screenshots/home.webp" width="16%" alt="Home">
</p>

A no-jailbreak Theos tweak that rebuilds Spotify for iOS in Liquid Glass, injected into your own
decrypted IPA and signed with your own certificate.

Vitrine is a fork of [spoti.pw](https://github.com/skopevoj/spoti.pw) by Vojtěch Škopek, taken from
0.21.1 (commit `c790445`, 2026-09-23), the last version released under GPL-3.0, and modified since.

Supports **Spotify 9.1.78**, **Spotify 9.1.88**, **Spotify 9.1.90** and **Spotify 9.2.0**.
The mod hooks Spotify's own classes, which change between releases, so any other version may build and then break.

| | |
|---|---|
| The redesign | **iOS 26+** |
| Legacy look | iOS 16.1+ |
| Live Activity | iOS 17+ |

The redesign is `UIGlassEffect`, which only exists from iOS 26. Below that the Redesigned UI switch
turns it on only after a warning that it is untested there, and a launch with it that hangs goes back
to Spotify's own screens with everything else the mod adds on top. Both live in Settings → Mod Settings.

## Build it

No IPA is distributed. Bring a decrypted **Spotify 9.1.78**, **9.1.88**, **9.1.90** or **9.2.0** IPA; you get an unsigned
`vitrine-<mod version>.ipa` to sign with SideStore, Feather or any certificate signer. Releases have no `.deb`:
injected by hand, the tweak alone misses the app changes the redesign needs (its glass tab bar), the Live
Activity, Music Haptics in the background and Connect's local discovery, so build the IPA instead.

App-local **WireGuard / proxy is included by default**, but stays off until you import a `.conf`
or save a proxy, enable it and restart. It is **not a leak-proof or device-wide VPN**:
background sessions, web sign-in, AVURLAsset, pre-initializer traffic and local-network exemptions
are outside coverage. See [coverage and limitations](docs/wireguard.md).
The inspected WireGuard targets currently include 9.1.90 and 9.2.0, not 9.1.78 or 9.1.88;
those versions require `WIREGUARD=0` (uncheck **Include app-local WireGuard / proxy** in Actions).
A build without WireGuard drops enforcement even if it was previously enabled.

### Build with GitHub Actions

Fork the repo, enable Actions, run **Build IPA from your own Spotify IPA**. It takes a direct link to
your decrypted `.ipa` and hands the built IPA back as a workflow artifact. No Mac needed; the link is
masked in the log and the result stays in your fork.

### Build on a Mac

Theos in `~/theos` and Xcode with an iPhoneOS 26+ SDK (`xcode-select` it). An SDK in `~/theos/sdks`
alone builds too, but without the Live Activity. Then:

Default IPA builds also require the exact Go release pinned in `WireGuard/go.mod`.
`make release WIREGUARD=0` excludes WireGuard and needs no Go; direct tweak development
builds remain Go-free by default.

    brew install make ldid dpkg zsign libimobiledevice
    uv tool install "cyan @ git+https://github.com/asdfzxcvbn/pyzule-rw"

Put the decrypted `.ipa` in `ipa/`, then:

    make release    # out/vitrine-<version>.ipa, ready to sign
    make install    # the same, signed with your certificate and installed over USB or Wi-Fi

`scripts/pipeline.sh <ipa> --no-flex --keep-watch` keeps Spotify's Apple Watch app (**untested**). Only its
arm64 build survives decryption on an iPhone, so it can run only on an Apple Watch Series 9, Ultra 2 or newer, and
it needs a signer that renames the Watch app to your App ID and signs it with a profile of its own that includes the
Watch. `make install` does not do that yet.

`make install` reads `SIGN_P12`, `SIGN_PROFILE` and `SIGN_P12_PASSWORD` from `.signing.env`; copy
`.signing.env.example` and fill it in.

The first build spends a minute reading Spotify's flags out of your IPA. `make flags` regenerates it.

### Optional Pixie native downloads

    make release PIXIE=1                              # primary Spotify 9.2.0
    make release PIXIE=1 IPA=ipa/Spotify-9.1.90.ipa     # compatibility lane

These produce `out/vitrine-<version>-pixie.ipa` and
`out/vitrine-<version>-pixie-spotify-9.1.90.ipa`, separately from the input and ordinary
Vitrine output. An explicit `IPA=` overrides the Pixie primary target.
`make build PIXIE=1` and `make install PIXIE=1` use the same overlay
(the latter also signs and installs). Direct pipeline usage accepts `--pixie`
(`--require-pixie` is an alias). Default builds never include Pixie on any version;
`make quick` does not build the overlay.

Packaging accepts the exact decrypted Spotify **9.2.0** (`920002054`) and
**9.1.90** (`919002269`) profiles. Main and SpotifyShared UUIDs are recorded in
`NativeDownloads/targets/spotify-9.2.0.json` and `spotify-9.1.90.json`.
Version, build, both UUIDs, instruction windows, import bindings and unused executable
padding are checked before the base build; requested Pixie mismatches fail closed.
**9.2.0 packages are not yet functional-download releases.** Packaging admission
does not override the companion's unverified native-layout/counter gates:
its runtime remains inactive on 9.2.0. Separately, the host must feed the nebula
account-attributes response through `SAPRewriteOfflineAccountAttributes`; without
that integration, Eevee's 9.2 port observed `NOT_ALLOWED (23)` for downloads.
Neither condition is established by a successful build. Jailbreak packaging is
9.1.90-only; 9.2.0 DEBs are refused before output mutation.
Default builds still work without Pixie. All builds reject existing Pixie
payloads, partial overlays, malformed inputs and encrypted executables.
The finished Vitrine IPA is checked again and overlaid after App Intents merging, before
any installation. The companion build needs Xcode's iPhoneOS SDK and `ldid`; application
entitlements are preserved and the complete ZIP is verified before atomic publication.

Settings → Vitrine reuses Pixie's existing runtime attachment for **Pixie Download Manager**
and **Send log**. Downloads stay in Spotify's offline storage; Pixie 1.4 also offers
separate, explicit audio-export actions.
Music-track context menus gain **Download**, bound to the selected track rather than
the currently playing one. The manager's **Add single-track downloads to Liked Songs**
switch defaults off and applies to subsequent individual downloads, including the
current-track action. When enabled, an accepted or already-present download also
requests an add to Liked Songs; album downloads do not. Canceling or removing a
download never removes a like. Library-add errors are reported separately from
download status. Menu routing and library changes still need real-device acceptance;
the host regressions check captured track identity and the verified 9.1.90 API.
Release builds enforce `SAP_ENABLE_WAV_CAPTURE=0`. Diagnostics default off; enabling them
persists across launches. Action recording also respects this switch. Reports can contain
track URIs, device identifiers and listening/download history: inspect before sharing.
Unstructured Eevee debug logs are excluded because their credential safety is unknown.
Existing About diagnostics remain available and are included through `SGWriteDiagnosticsFile`.
Pixie's `SAPL` uses Vitrine's localization keys and Korean/English resources, following the
app's language with the same checked English fallback. `scripts/check-strings.py` also checks
Pixie's keys and placeholders. Long-term offline licence renewal remains unverified.

`NativeDownloads/` imports the sources, tests, patch tools and assets from
[Glongq/Vitrine-Pixie](https://github.com/Glongq/Vitrine-Pixie) at exact commit
[`2632bdf9081665b9fd78e71cea2878edc6aae73c`](https://github.com/Glongq/Vitrine-Pixie/tree/2632bdf9081665b9fd78e71cea2878edc6aae73c/NativeDownloads),
under GPL-3.0 with existing notices retained. Upstream credits Pixie development/integration
to OpenAI Codex under Glongq's direction, and device testing/feedback to Glongq; earlier
work comes from Glongq/EeveeSpotifyReincarnated. Selected companion fixes are pinned to
Eevee [`0d9feaa9008e53b06382c61fffcb5cfcfceb2981`](https://github.com/Glongq/EeveeSpotifyReincarnated/tree/0d9feaa9008e53b06382c61fffcb5cfcfceb2981).
Its Vitrine host overlay patch was **not** applied.
Local adaptations add preflight/atomic build integration, entitlement preservation,
init-family ownership safety, nonblocking diagnostic notifications and diagnostics privacy guards.
Jailbreak packaging supports only the exact 9.1.90 profile (rootful and rootless);
9.2.0 DEBs are rejected. Both Pixie package formats include the root GPL license
and `NativeDownloads/vendor/M4A-NOTICES.md`. Jailbroken-device execution remains unverified.

Focused checks on an Apple Silicon Mac (no installation):

    python3 -B NativeDownloads/tests/build_guard.py ipa/Spotify-9.1.90.ipa
    python3 -B NativeDownloads/tools/test.py
    SPOTIFY_TEST_IPA="$PWD/ipa/Spotify-9.1.90.ipa" python3 -B NativeDownloads/tools/test_native_restrictions.py

`tools/test.py` and `tools/test14.py` share one current runner, including the
exact-target admission and frozen-golden checks. These use the clean target IPAs.
`python3 NativeDownloads/tools/test_trace_platform.py` exercises the production notification
observers for nonblocking background posts and disabled/stale-generation delivery.
After simulator checks, run `xcrun simctl shutdown all` and `osascript -e 'tell application "Simulator" to quit'`.

### Signing

Sign with a bundle id matching your certificate's App ID. If it doesn't match, the app still works
but tapping the player on the lock screen won't open it — and it tells you on first launch which id
to use. In Feather, copy the App ID into **Identifier** and leave **PPQ protection** off; AltStore,
SideStore and Sideloadly get this right on their own.

The app keeps Spotify's bundle id, so it installs over the real Spotify.

## Credits

[cyan](https://github.com/asdfzxcvbn/pyzule-rw) injects, [Theos](https://theos.dev) builds, and
[FLEX](https://github.com/FLEXTool/FLEX), as hopeless's AutoFLEX build in `vendor/`, is the inspector
the view trees are read through. The ad blocking and the Premium state are ported from
[EeveeSpotify Reincarnated](https://github.com/SideloadLabs/EeveeSpotifyReincarnated).

GPL-3.0. Not affiliated with Spotify.
