# FuelSwitch AI 1.1.1 — Working automatic updates

Fixes the updater reporting version 1.0.5 as current after a newer GitHub release was published.

## Fixes

- In-app update status and Sparkle now read the same installable-release feed. A GitHub tag without a signed update is no longer a separate source of truth.
- Failed network requests, HTTP errors, and malformed feeds show a retry message instead of “up to date”. The message is translated into all 12 languages.
- Both manual check buttons offer installation through Sparkle. Update banners open the installer instead of a browser download.
- Saved automatic-check/download preferences are applied before starting Sparkle. Automatic checks and downloads remain opt-in in Settings; Sparkle handles installation/relaunch.
- ZIP packaging preserves Sparkle framework symlinks. The previous ZIP packaging expanded those links and failed strict code-signature verification after extraction.
- Every release must have an EdDSA signature matching the existing bundled public key. CI verifies the extracted app, verifies the archive signature, and publishes the feed only after the exact ZIP is publicly downloadable.
- Feed publication is automatic, retry-safe, and refuses to replace a newer build with an older release.

## Updating

In FuelSwitch AI Settings, check for updates. Version 1.0.5 can use its existing Sparkle updater and trusted key to install this release once the signed feed has been published. Enable both automatic-check and automatic-download switches for background updates. Installation/relaunch follows Sparkle's normal prompts and quit-time behavior; running work is not forcibly terminated.

Requires macOS 13 or newer; includes Apple Silicon and Intel binaries. Build number: 8.

## Verification

- 244 offline Swift tests across 19 suites passed locally; an additional opt-in test checks the live production feed from version 1.0.5.
- 10 release-feed regression tests passed, covering lost symlinks, missing signatures, incompatible keys, tag mismatch, duplicate build numbers, retries, and out-of-order publication.
- The release workflow additionally verifies the packaged app and the exact published archive before updating the live feed.

The app remains ad-hoc code-signed, not Apple-notarized. Sparkle archive verification uses the existing EdDSA update key. Automated tests do not simulate a complete GUI installation on the user's running copy.
