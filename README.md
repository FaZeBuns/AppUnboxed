# App Unboxed

A CS:GO-style case opener for the iPhone Duo. Open the app on the cover screen,
unfold the phone, and a 3D crate drops in, rattles, bursts open and rolls a
fullscreen reel of the apps on your phone. Whatever it lands on gets opened.

Native SwiftUI + Core Animation. MIT licensed.

## Install

1. Download the latest `.ipa` from [Releases](../../releases).
2. Sideload it with [Sideloadly](https://sideloadly.io) or AltStore using your
   Apple ID.
3. Open it on the cover screen, wait for "OPEN YOUR IPHONE DUO", then unfold.

Tapping the box opens a case without unfolding, so it also works on a regular
iPhone (iOS 16 or newer).

## What it does

- **Cover screen**: an idle 3D loot box that spins, floats, rattles and leaks
  gold light while your apps are scanned.
- **Unfold to open**: tells an unfold apart from a rotation.
- **Crate cinematic**: a real six-sided crate with synced sound and haptics.
- **Fullscreen reel**: one tick per card, weighted drop odds (2% gold up to
  46% mil-spec), lands on an app and opens it.
- **Add Apps**: search the App Store and add anything the scan missed.

## Which apps it can find

iOS does not let a normally installed app ask for the list of installed apps,
so App Unboxed dynamically discovers what is on **your** phone at launch using
every route iOS answers:

| Method | What it finds on stock iOS / iPhone Duo (iOS 27.1) |
| --- | --- |
| LaunchServices plugin discovery | Every user app with widgets, notifications, share sheet, Siri intents, etc. (zero hardcoding, runs dynamically on device) |
| LaunchServices scheme check (`isApplicationAvailableToOpenURL`) | 160+ curated third-party apps and games (bypasses the 50-scheme `canOpenURL` limit) |
| Icon lookup (`_applicationIconImage...`) | Apple's own system apps |
| LaunchServices full list (`allInstalledApplications`) | Complete user app inventory (when running on a jailbroken phone) |
| Add Apps (manual search) | Any app on the App Store |

On a stock phone, the scan runs completely dynamically on-device and discovers
installed apps automatically without hardcoding personal lists. Detected apps
automatically fetch high-resolution App Store icons in fast batch lookups and
cache locally. **Add Apps** covers any remaining niche apps.

## Privacy

- The scan runs on your phone and its result is stored only on your phone.
- There is no server, account, analytics or tracking.
- Two things contact Apple's public App Store API, and nothing else is ever
  contacted: **Add Apps** search (sends what you type), and **icon download**
  (sends the bundle ids of detected apps that iOS gave no icon for, to fetch
  their artwork). Icon download can be switched off in the Add Apps screen.

## Build it yourself

Sources are plain files compiled with `swiftc` and `clang`; there is no Xcode
project. Two ways to build:

**On a Mac** (Xcode command-line tools):

```bash
bash scripts/build_macos.sh
```

This path mirrors the on-device build but has not been run on a real Mac yet.
The same script runs in GitHub Actions (`Build IPA`, started by hand).

**On a jailbroken iPhone** (no Mac needed; this is how releases are made):

1. Install `swift`, `clang`, `ldid`, `zip` and `python3` from Procursus.
2. `cp build.env.example build.env` and set `PHONE` and `SSH_KEY`.
3. Run:

```bash
bash scripts/build_on_iphone.sh
```

Either way the `.ipa` lands in `dist/`. Both scripts stamp the binary's
`LC_BUILD_VERSION` SDK as 27.1 (`scripts/stamp_sdk.py`), which the Duo needs
for its full dual-screen canvas, and sign after stamping.

### Changing things

- **Apps it recognises**: `src/AppCatalog.swift` (bundle id, name, URL scheme,
  rarity). After adding schemes run `python scripts/build_scheme_catalog.py`
  to rewrite the scheme list in `Info.plist`. Only the first 50 count, so the
  script puts the most popular first.
- **Your own phone's apps**: `python scripts/compare_with_device.py dump.json`
  reads the app list from a USB-connected iPhone, and
  `python scripts/build_scheme_catalog.py dump.json` turns it into catalog
  entries. That output describes your phone, so do not commit it publicly.
- **Chart catalog**: `python scripts/build_catalog.py` refreshes
  `Resources/catalog.json` from Apple's top charts.
- **Drop odds, timings, look**: `InstalledAppsModel.swift`,
  `CrateStageView.swift`, `ReelStripView.swift`, `CoverCrateView.swift`.

### Tools for contributors

- `scripts/test_on_iphone.sh` installs a build on the jailbroken phone and
  saves snapshots and the scan log.
- `DetectionLab` runs once per version and writes
  `Documents/detection_report.json`: which detection methods the device
  answered. `scripts/read_device_report.py` reads it back over USB. If you find
  a method that reveals third-party apps on iOS 27, please open an issue.

## Layout

```
src/         Swift + Objective-C sources
Resources/   Info.plist, entitlements, icons, sounds, catalog.json
scripts/     build, test and catalog tools
```
