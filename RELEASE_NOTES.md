# ⛽ FuelSwitch AI 1.2.11 — Keep Antigravity signed in when switching

Build 22 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Saved Antigravity sessions are written as the ASCII password expected by go-keyring. The previous hex write doubled the command size and exceeded the 4096-byte interactive input limit for full sessions, leaving truncated credentials and forcing another sign-in.
- Keychain writes are checked by reading back the exact stored value. Commands that exceed the input limit are rejected before they can damage the existing login. Credentials are still passed through stdin, without appearing in process arguments.

## Verification and limits

- The truncation was reproduced with a full-size synthetic session in a temporary Keychain item. The corrected write round-tripped the full value through the same security command used by go-keyring.
- Regression tests cover full session size, argument quoting and rejection before oversized writes. Live switching between two real accounts was not exercised.
- Distribution remains ad-hoc code-signed; Sparkle update archives are separately signed by the release workflow.

---

# ⛽ FuelSwitch AI 1.2.10 — Switch the actual Antigravity account

Build 21 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Gemini switching now restores the standalone Antigravity app's actual Keychain sign-in instead of changing an obsolete token file. Older saved JSON sessions are converted to the format Antigravity expects; snapshots for a different account are rejected.
- Antigravity's application path is captured before quitting, with an installed-app fallback, so it is reopened after switching or a failed credential update.
- FuelSwitch reports success and updates the Gemini CLI account only after the restarted Antigravity language server confirms the selected email. If the account has no saved Antigravity session, FuelSwitch asks for a one-time sign-in inside Antigravity.
- With Antigravity synchronization enabled, the active Gemini account displayed in FuelSwitch comes from the running Antigravity app, rather than an outdated Gemini CLI marker. Antigravity IDE retains its separate sign-in.
- Application packaging resolves SwiftPM's current output directory, preventing local Xcode builds from copying an older executable.

## Verification and limits

- Regression tests cover Keychain session swapping, legacy session encoding, snapshot identity, relaunch paths and account verification after startup.
- The running Antigravity identity API and a synthetic Keychain write/read were checked locally. Switching between two real user accounts was not exercised.
- Distribution remains ad-hoc code-signed; Sparkle update archives are separately signed by the release workflow.

---

# ⛽ FuelSwitch AI 1.2.9 — Follow Claude Code token rotation

Build 20 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Claude limit polling now adopts the tokens renewed by Claude Code even when its Keychain record has no email address. Claude Code stores the account identity in `.claude.json` and removes FuelSwitch's extra email field when renewing tokens. FuelSwitch previously ignored that record and could keep using an invalidated refresh token.
- FuelSwitch no longer replaces a newer stored session with an older Keychain session. It rejects empty credentials and credentials belonging to another active Claude account.
- A token renewed by FuelSwitch is copied back to Claude Code when the previous tokens match exactly, including records without email metadata. A session switched or renewed elsewhere is preserved.

## Verification and limits

- Regression tests cover the current Claude Code credential shape, account identity, older sessions and synchronization after token rotation.
- Live signed-in Claude quota requests were not exercised. Distribution remains ad-hoc code-signed; Sparkle update archives are separately signed by the release workflow.

---

# ⛽ FuelSwitch AI 1.2.8 — Show Gemini usage for every Antigravity account

Build 19 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Gemini usage is read from the Antigravity language server that is signed in with that account. Each Antigravity window and the standalone app run their own server, so FuelSwitch now asks each one which account it uses before reading its quota. Before, 1.2.7 picked the account from a stale token file, and the IDE's account showed no usage.
- A Gemini account no longer drops back to "sign in again" after a successful sign-in. Google's quota endpoint answers 403 to Gemini CLI tokens even when they are valid. FuelSwitch now shows that usage is available only while Antigravity is open with that account, and clears the stale re-auth flag.
- The Gemini switch now restarts only the standalone Antigravity app. Antigravity IDE keeps its own login, so restarting it did not change its account. Change the IDE account inside the IDE.

## Verification and limits

- The language server lookup was checked against running Antigravity and Antigravity IDE servers on a real machine. Automated tests cover the response parsing and the re-auth handling.
- Release artifacts are built and signed by the release workflow after tag `v1.2.8` is pushed.

---

# ⛽ FuelSwitch AI 1.2.7 — Switch Antigravity together with Gemini

Build 18 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Switching a Gemini account now quits Antigravity, swaps its sign-in and reopens it, the same way the Codex app is restarted. Antigravity keeps its login in memory, so before this fix it stayed on the previous account after a switch.
- Each account's Antigravity sign-in is saved under its email in FuelSwitch's Application Support folder and restored on later switches. Antigravity issues its tokens for its own OAuth client, so FuelSwitch does not write its Gemini CLI tokens into Antigravity. When an account has no saved sign-in yet, Antigravity asks you to sign in once.
- Gemini accounts no longer all show the same usage. Quota from the local Antigravity language server is now used only for the account Antigravity is signed in with; other accounts are read from the Gemini API.
- A new setting, "Sync account with Antigravity", controls the restart. It is on by default.

## Verification and limits

- Automated tests cover the sign-in swap, the restart order and the setting. They do not drive a real Antigravity install.
- Release artifacts are built and signed by the release workflow after tag `v1.2.7` is pushed.

---

# ⛽ FuelSwitch AI 1.2.6 — Stop repeated Keychain and quota prompts

Build 17 · macOS 13+ · Apple Silicon and Intel

## Fixes

- FuelSwitch now reads and writes the `Claude Code-credentials` Keychain item through `/usr/bin/security`, the same tool Claude Code uses. macOS no longer asks every few hours for permission to use that item after Claude Code refreshes its token.
- Usage threshold notifications are sent only for the account the CLI currently uses. An inactive account at its weekly cap no longer repeats the weekly quota alert on every refresh.

## Verification and limits

- The full automated test suite passes. The Keychain change was not checked against a live macOS prompt in CI.
- Release artifacts are built and signed by the release workflow after tag `v1.2.6` is pushed.

---

# ⛽ FuelSwitch AI 1.2.5 — Keep Claude usage requests current

Build 16 · macOS 13+ · Apple Silicon and Intel

## Fixes

- Claude usage requests now identify the locally installed Claude Code version instead of sending a version frozen in FuelSwitch. This avoids using an outdated CLI identity after Claude Code updates; systems without the CLI use the current verified fallback.

## Verification and limits

- Automated tests cover CLI version discovery, fallback behavior, and the Anthropic request headers. They do not verify live quota values for a signed-in account.
- Release artifacts are built and signed by the release workflow after tag `v1.2.5` is pushed.

---

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
