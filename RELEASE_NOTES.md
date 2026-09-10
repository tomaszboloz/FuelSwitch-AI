# FuelSwitch AI 1.1.3 — Update settings fix

Build number: 10. Requires macOS 13 or newer; Apple Silicon and Intel.

## Fixes

- Removed the duplicate "Check Now" button from the Sparkle Automatic Updates card in Settings. It called the exact same check as the "Check for Updates" button directly below it, so Settings showed two update-check controls stacked on top of each other for no reason.
- Added a real "Download" button next to the "Version X.X.X is available" message in Settings, matching the menu bar update banner. Previously, finding an available update in Settings only showed text with no action to take — installing required going to the menu bar banner instead, which was not obvious.
- Removed the now-unused `checkForSparkleUpdateNow()` model method and its `sparkleCheckNowButton` localization key (all 12 languages) along with the deleted button.

The Sparkle Automatic Updates card still holds the automatic-check and automatic-download toggles, plus the explanation text; it is no longer a second place to trigger a manual check. Manual checks and installs now live in one place.

## Updating

In FuelSwitch AI Settings, check for updates as before. When one is available, click "Download" to open Sparkle's installer — that is now the only button that starts an actual update.

## Verification

- 245 offline Swift tests across 19 suites passed locally.
- Release build (`swift build`, universal arm64/x86_64) compiles clean with no warnings from this change.

The app remains ad-hoc code-signed, not Apple-notarized. Automated tests do not simulate a complete GUI installation on the user's running copy.
