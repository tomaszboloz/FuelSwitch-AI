# ⛽ FuelSwitch AI 1.2.2 — Keep sessions alive and sign back in

Build 13 · macOS 13+ · Apple Silicon and Intel

## New and improved

- OAuth sessions now renew before expiry, and an early unauthorized response gets one refresh-and-retry before the account is marked as signed out. This reduces avoidable session interruptions while preserving a clear re-authentication state when a provider truly rejects the session.
- FuelSwitch adopts newer Claude Code credentials from Keychain when that app has already rotated the shared refresh token, and copies successful FuelSwitch token rotations back to Claude Code when it is still using the same account.
- Expired accounts now show a **Sign in again** action on their account card, in both widget styles, and in Native account details and widget views. The compact widget keeps the saved account visible after the CLI logs out, so re-authentication remains one click away.

- Claude accounts now include a reset action in the main panel, Classic and Native widgets, and the Native account details view. It opens Claude's official Settings → Usage page, where eligible plans can use the one-time limit reset described in [Anthropic's instructions](https://support.claude.com/en/articles/17007452-what-is-a-limit-reset).
- Codex reset credits now call the provider's consume endpoint, send the selected credit and a unique redemption request ID, refresh the account immediately, and report success or failure in the panel. The action is hidden when no reset credit is available.
- Reset labels and status messages are translated across all 12 supported languages.

## Interface carried forward

- Settings → Appearance → Interface template offers **Classic (default)** and **Native macOS**. Selection persists and applies immediately, independently of light/dark mode and widget size. Existing installations keep Classic.
- Native macOS adds a resizable account workspace, provider navigation, account search, active-account filtering, remaining-limit table and account details/actions. Open it from the menu bar; closing the window keeps monitoring running.
- Native expanded widgets and horizontal compact bars share the existing account and quota model. Numeric remaining limits stay visible. Low-fuel indicators turn orange below 20%.
- The approved orange fuel-tank artwork is the shared app icon and in-app brand mark in both templates. OAuth callback pages use a matching embedded favicon.
- All new labels are translated into the 12 supported languages. Settings, account switching, Codex desktop synchronization and update preferences remain shared.

## Fixes

- Keychain access remains best-effort, but account-store write failures are no longer swallowed while adopting Claude Code credentials.
- The Classic compact widget no longer presents the first saved account as active when no active account can be matched.
- Native views distinguish missing/error data from an empty tank and show cached-data status.
- Template-aware widget geometry keeps Native compact mode a horizontal bar with room for numbers.

## Verification and limits

- 253 offline Swift tests passed, covering session refresh/retry, account persistence, reset requests, localization completeness and widget behavior; opt-in live checks were skipped.
- 13 Python release-feed and brand-asset tests passed; the universal arm64/x86_64 app built successfully and passed strict signature verification.
- Documentation previews render production views with synthetic .example accounts, without loading credentials or starting polling.
- Core provider quota reads remain unchanged; reset actions use the documented Claude web flow or the Codex reset-credit endpoint. The render checks do not verify live account quotas.
- Distribution remains ad-hoc code-signed, not Apple-notarized. Sparkle archives are separately signed. Automated checks are not a full interactive OAuth/install or accessibility audit.

## Update

Use Settings → Check for Updates → Download, or enable automatic checking and downloading in Settings. Classic remains selected until you explicitly choose Native macOS.
