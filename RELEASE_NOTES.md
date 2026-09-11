# ⛽ FuelSwitch AI 1.2.0 — Choose your interface

Build 11 · macOS 13+ · Apple Silicon and Intel

## New

- Settings → Appearance → Interface template offers **Classic (default)** and **Native macOS**. Selection persists and applies immediately, independently of light/dark mode and widget size. Existing installations keep Classic.
- Native macOS adds a resizable account workspace, provider navigation, account search, active-account filtering, remaining-limit table and account details/actions. Open it from the menu bar; closing the window keeps monitoring running.
- Native expanded widgets and horizontal compact bars share the existing account and quota model. Numeric remaining limits stay visible. Low-fuel indicators turn orange below 20%.
- The approved orange fuel-tank artwork is the shared app icon and in-app brand mark in both templates. OAuth callback pages use a matching embedded favicon.
- All new labels are translated into the 12 supported languages. Settings, account switching, Codex desktop synchronization and update preferences remain shared.

## Fixes

- The Classic compact widget no longer presents the first saved account as active when no active account can be matched.
- Native views distinguish missing/error data from an empty tank and show cached-data status.
- Template-aware widget geometry keeps Native compact mode a horizontal bar with room for numbers.

## Verification and limits

- 247 offline Swift tests passed (248 declared, one opt-in live test skipped), covering default/fallback selection, persistence, setting independence, localization completeness and compact geometry.
- 13 release-feed and brand-asset tests passed; the universal arm64/x86_64 app built successfully and passed strict signature verification.
- Documentation previews render production views with synthetic .example accounts, without loading credentials or starting polling.
- This is a layout release, not a replacement of provider quota APIs. Provider integrations are unchanged; the render checks do not verify live account quotas.
- Distribution remains ad-hoc code-signed, not Apple-notarized. Sparkle archives are separately signed. Automated checks are not a full interactive OAuth/install or accessibility audit.

## Update

Use Settings → Check for Updates → Download, or enable automatic checking and downloading in Settings. Classic remains selected until you explicitly choose Native macOS.
