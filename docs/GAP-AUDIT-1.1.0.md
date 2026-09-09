# Account switching audit — 2026-09-09

Scope: provider credential switching, OAuth refresh, active-account detection, desktop lifecycle, settings/localization and release plumbing. This is not a complete security or visual audit of every application screen.

| Gap | Resolution in 1.1.0 |
| --- | --- |
| Desktop caches authentication after auth.json changes | Opt-in graceful quit, credential write, relaunch; no force termination |
| Codex token dictionary inherited previous identity/API keys | Fresh payload, matching ID-token validation, complete required fields |
| Hardcoded Codex directory and file backend | CODEX_HOME plus file/direct-Keychain/auto routing; unsupported modes fail closed |
| UI switch could use tokens rotated since the UI snapshot | Reload latest stored account and coalesce credential refreshes |
| Poller discarded refreshed id_token | Preserve new ID token; retain the existing one only when refresh omits it |
| Codex and FuelSwitch could keep different generations of credentials | Adopt newer matching Codex credentials and synchronize refreshes only while the original account/token remains active |
| Repeated clicks or auto-switch could interleave | Per-provider switch guard and cooldown after automatic failures |
| Claude metadata changed even if Keychain failed | Roll back metadata and remove previous-account quota cache on success |
| Gemini active pointer changed before credentials | Credentials first, rollback on pointer failure; remove active email from old-account list |
| Credential temporary files survived errors | Cleanup on every exit; restrictive permissions at creation |
| New setting could silently restart Codex after upgrade | Preference defaults off and describes restart implications in all 12 languages |

Remaining constraints: local-file login cannot change an externally managed ChatGPT login; arbitrary Codex config overrides and encrypted/ephemeral storage are not supported. A graceful restart is not a supported live auth RPC to an already-running desktop session. The real user's desktop account was not switched during automated verification. Sparkle requires a distribution-specific EdDSA signature; the existing feed is intentionally not pointed at an unsigned or differently packaged artifact.

Reference: upstream `openai/codex`, `codex-rs/login/src/auth/storage.rs`, `codex-rs/login/src/token_data.rs` and `codex-rs/login/src/auth/manager.rs` (inspected 2026-09-09).
