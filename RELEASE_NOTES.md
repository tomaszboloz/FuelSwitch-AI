# FuelSwitch AI 1.1.0 — Codex desktop account sync

Account switching can now update the login used by the macOS Codex app. Enable **Settings → Sync account with the Codex app**. This is opt-in and off by default. When enabled, manual, launcher and automatic Codex switches gracefully quit and reopen Codex to reload the selected local OAuth login. Running tasks may be interrupted. Refused or timed-out quits are reported without force-killing the app.

## Fixed gaps

- Codex credential replacement now requires a complete matching identity and removes credentials left by the previous account, including API keys and account IDs.
- Respect `CODEX_HOME` and file/direct-Keychain credential storage. Refuse unsupported storage instead of claiming a successful write to an ignored file.
- Use the latest saved tokens for switching, preserve refreshed ID tokens and coalesce simultaneous polling/switch refresh requests.
- Adopt newer tokens rotated by Codex itself and avoid undoing an external account switch when persisting refreshed credentials.
- Serialize account switches per provider and update the active account/statusline after a successful write.
- Restore Claude metadata on a Keychain write failure; clear previous-account cached limits and metadata.
- Write Gemini credentials before its active-account pointer and restore credentials on pointer failure.
- Create switcher temporary credential files with owner-only permissions and clean them up on failure.
- Translate the new settings and desktop restart error into all 12 supported languages.

## Compatibility

Requires macOS 13 or newer. The release bundle includes Apple Silicon and Intel binaries. Desktop synchronization requires Codex to use the same local OAuth store and `CODEX_HOME`; it does not change a separate ChatGPT-hosted login. Open terminal sessions may need a restart. Multi-file rollback handles reported errors, not a process crash between writes.

The Sparkle feed remains on the last signed update until a matching EdDSA-signed distribution is published. This tag does not claim to publish a new signed Sparkle update.

Build number: 7.

## Verification

- 240 tests passed across 19 suites, including the opt-in desktop lifecycle, refusal/rollback paths, credential rotation and localization completeness.
- Codex CLI 0.153.0 accepted the generated login in an isolated temporary CODEX_HOME (synthetic credentials; no real account switch).
- Universal macOS release build passed for arm64 and x86_64.
- A live desktop account switch was not performed; visual inspection was unavailable because macOS UI-access permissions were pending.
