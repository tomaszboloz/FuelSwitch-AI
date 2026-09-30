# ⛽ FuelSwitch AI 1.2.4 — Move widgets from their passive surface

Build 15 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Floating widgets can now be dragged from passive background areas in Classic and Native templates, in compact and expanded layouts—not only from the fuel icon. The AppKit drag layer sits between the decorative background and interactive controls, so buttons and menus retain their normal actions.
- The native drag target accepts the first click in a non-activating panel, avoiding a dropped initial click when the widget is not focused.

## Verification and limits

- 253 Swift tests and 13 Python release-feed/brand tests passed. The universal arm64/x86_64 app built and passed strict signature verification.
- Automated tests do not replace a manual pointer-drag check on macOS 27. The app installed on this machine remains 1.2.3 until the new build is installed or the signed update is applied.

---

# ⛽ FuelSwitch AI 1.2.3 — Restore widget dragging on macOS 27

Build 14 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Floating widgets now have a native AppKit drag handle on the fuel icon in Classic and Native, compact and expanded layouts. This restores reliable moving on macOS 27 when the SwiftUI-hosted panel background no longer starts a window drag. The menu-bar popover does not expose this handle.
- Keychain access remains best-effort, but account-store write failures are no longer swallowed while adopting Claude Code credentials.
- The Classic compact widget no longer presents the first saved account as active when no active account can be matched.
- Native views distinguish missing/error data from an empty tank and show cached-data status.
- Template-aware widget geometry keeps Native compact mode a horizontal bar with room for numbers.

## Features carried forward

- OAuth sessions renew before expiry, and an early unauthorized response gets one refresh-and-retry before the account is marked as signed out.
- FuelSwitch adopts newer Claude Code credentials from Keychain when that app has already rotated the shared refresh token, and copies successful FuelSwitch token rotations back to Claude Code when it is still using the same account.
- Expired accounts show a **Sign in again** action on their account card, in both widget styles, and in Native account details and widget views. The compact widget keeps the saved account visible after the CLI logs out.

- Claude accounts now include a reset action in the main panel, Classic and Native widgets, and the Native account details view. It opens Claude's official Settings → Usage page, where eligible plans can use the one-time limit reset described in [Anthropic's instructions](https://support.claude.com/en/articles/17007452-what-is-a-limit-reset).
- Codex reset credits now call the provider's consume endpoint, send the selected credit and a unique redemption request ID, refresh the account immediately, and report success or failure in the panel. The action is hidden when no reset credit is available.
- Reset labels and status messages are translated across all 12 supported languages.

## Interface carried forward

- Settings → Appearance → Interface template offers **Classic (default)** and **Native macOS**. Selection persists and applies immediately, independently of light/dark mode and widget size. Existing installations keep Classic.
- Native macOS adds a resizable account workspace, provider navigation, account search, active-account filtering, remaining-limit table and account details/actions. Open it from the menu bar; closing the window keeps monitoring running.
- Native expanded widgets and horizontal compact bars share the existing account and quota model. Numeric remaining limits stay visible. Low-fuel indicators turn orange below 20%.
- The approved orange fuel-tank artwork is the shared app icon and in-app brand mark in both templates. OAuth callback pages use a matching embedded favicon.
- All new labels are translated into the 12 supported languages. Settings, account switching, Codex desktop synchronization and update preferences remain shared.

## Verification and limits

- 253 offline Swift tests passed, covering session refresh/retry, account persistence, reset requests, localization completeness and widget behavior; opt-in live checks were skipped.
- 13 Python release-feed and brand-asset tests passed; the universal arm64/x86_64 app built successfully and passed strict signature verification.
- Documentation previews render production views with synthetic .example accounts, without loading credentials or starting polling.
- Core provider quota reads remain unchanged; reset actions use the documented Claude web flow or the Codex reset-credit endpoint. The render checks do not verify live account quotas.
- Distribution remains ad-hoc code-signed, not Apple-notarized. Sparkle archives are separately signed. Automated checks are not a full interactive OAuth/install or accessibility audit.

## Update

Use Settings → Check for Updates → Download, or enable automatic checking and downloading in Settings. Classic remains selected until you explicitly choose Native macOS.
