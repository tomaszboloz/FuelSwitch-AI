# FuelSwitch AI — Claude Code, Codex & Gemini CLI Usage Widget + Account Switcher

**A native macOS menu bar app and floating HUD widget that monitors Claude Code, Codex CLI, and Gemini CLI usage limits in real time — with 1-click account switching between multiple accounts per provider.**

[![CI](https://img.shields.io/github/actions/workflow/status/tomaszboloz/FuelSwitch-AI/ci.yml?branch=main)](https://github.com/tomaszboloz/FuelSwitch-AI/actions)
[![Release](https://img.shields.io/github/v/release/tomaszboloz/FuelSwitch-AI)](https://github.com/tomaszboloz/FuelSwitch-AI/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://www.swift.org)
[![Tests: 229](https://img.shields.io/badge/tests-229%20passing-brightgreen.svg)](#testing)
[![Languages: 12](https://img.shields.io/badge/localized-12%20languages-informational.svg)](#localization)

[Why](#why) • [Features](#features) • [Account switching](#cli-account-switching) • [Floating widget](#floating-desktop-widget) • [Installation](#installation) • [Settings](#settings-reference) • [FAQ](#faq) • [Architecture](#architecture) • [Security](#security) • [Contributing](#contributing)

---

## Why

Most Claude Code / Codex / Gemini CLI usage trackers on GitHub are read-only: a CLI script, a Python dashboard, or a single-provider menu bar icon that tells you a percentage *after* you've already hit the wall mid-task. Very few combine three things at once:

1. **Multi-provider in one glance** — Claude Code, Codex, and Gemini CLI usage side by side, not three separate tools.
2. **A real always-on-top widget**, not just a menu bar number you have to click to read.
3. **Actual account switching** — not just monitoring, but swapping the active credentials for you, with an opt-in auto-switch when an account runs dry.

FuelSwitch AI is a native Swift/SwiftUI menu bar app built for engineers juggling multiple Claude Code, Codex, and Gemini CLI accounts across client work, personal projects, and testing. It polls all three providers in the background, on an adaptive interval, and surfaces the result two ways: a compact menu bar glyph and an optional floating desktop HUD.

## Features

### Usage monitoring
- **Multi-provider polling** — Claude Code (5-hour + 7-day windows, including separate Opus/Sonnet 7-day quotas), Codex, and Gemini CLI, polled in the background without blocking your terminal.
- **Menu bar glyph** — gauge, battery, percent-only, or monochrome icon style; toggle whether the numeric percentage renders next to it.
- **Pace estimation** — an ahead-of-pace / on-pace / burning-fast glyph so you know if your current session will outrun the reset window before you're 80% through it.
- **Adaptive refresh** — shortens the poll interval automatically when it detects recent CLI activity, layered on top of your manually chosen base interval, so idle time doesn't burn API calls.

### Account management & switching
- **1-click CLI account switching** — swap the active credentials for Claude Code (`~/.claude.json` + macOS Keychain), Codex (`~/.codex/auth.json`), and Gemini CLI (`~/.gemini/google_accounts.json` + `~/.gemini/oauth_creds.json`) without restarting the CLI, your terminal, or your editor session.
- **Account nicknames** — label accounts `work`, `personal`, `client-a` instead of reading raw email addresses off the panel.
- **Per-profile launcher scripts** — FuelSwitch generates shell snippets (e.g. `fs-work`, `fs-personal`) that switch the active CLI account straight from the terminal, or via a `fuelswitch://` URL scheme, with no need to open the app UI at all.
- **Auto-switch on quota hit** — when the active account runs dry, automatically fail over to the best available same-provider account, with a cooldown to prevent flapping between two nearly-exhausted accounts. Opt-in, off by default.

### Floating desktop widget
- **Always-on-top HUD** — a small, floating window that sits above other apps so usage is visible at all times, not hidden behind a menu bar click. Off by default, one toggle in Settings to enable.
- **Expanded and compact layouts** — expanded shows per-provider bars with labels; compact collapses to a minimal glyph strip for tight screen real estate.
- **Click-through positioning** — drag it to any corner or edge; it persists across app restarts and reboots.

### Alerts & integrations
- **Threshold notifications** — native macOS notifications at 75/90/95% usage (configurable), per account and per reset window, so you're warned before you hit the wall, not after.
- **Claude Code statusline integration** — installs a generated script into Claude Code's `statusLine` setting, showing Claude, Codex, and Gemini usage together in one line inside every Claude Code session, with local caching so it doesn't add latency to your prompt.
- **Update check** — a single, read-only request to GitHub Releases compares the installed version against the latest tag using real semver ordering (via Sparkle), so it never nags you about a "newer" version you already have installed.

### Everything else
- **Light, dark, and system themes.**
- **12 languages, RTL-aware** — see [Localization](#localization).
- **Universal binary** — one `lipo`-merged executable for both Apple Silicon and Intel, targeting macOS 13 Sonoma and newer, built on Combine/`ObservableObject` rather than the macOS 14-only Observation framework specifically so Intel Macs on macOS 13 aren't locked out.
- **Local-only storage** — all account data lives at `~/Library/Application Support/FuelSwitch/accounts.json` with `0600` permissions forced on. Nothing is sent to any FuelSwitch server, because there isn't one.

## Localization

UI available in 12 languages, switchable from Settings independent of your system locale:

English · Polski · Español · हिन्दी · 中文 · 日本語 · Deutsch · Français · Português · العربية · Русский · 한국어

Arabic renders right-to-left automatically. Every string in the app ships in all 12 languages — that's a hard test gate in CI ([`LocalizationTests.swift`](Tests/FuelSwitchCoreTests/LocalizationTests.swift)), not a best-effort translation pass.

## Installation

### Requirements

- macOS 13 (Ventura) or later, Apple Silicon or Intel.
- Xcode 16 / Swift 6 toolchain to build from source.

### Build from source

```bash
git clone https://github.com/tomaszboloz/FuelSwitch-AI.git
cd FuelSwitch-AI
swift test
make app # builds .build/FuelSwitch AI.app (ad-hoc signed, machine only)
make run
```

### Prebuilt release

Download `FuelSwitch-AI.dmg` from the [Releases](https://github.com/tomaszboloz/FuelSwitch-AI/releases) page and verify against its matching `.sha256` file.

The build is not notarized by Apple (no Apple Developer Program membership behind it), so first launch shows *"Apple could not verify FuelSwitch AI is free of malware"*. To open it anyway:

- Right-click (Control-click) the app → **Open** → **Open**, once, or
- In Terminal: `xattr -cr "/Applications/FuelSwitch AI.app"`

The `Makefile` has a full `make release` target (sign, notarize, staple, package) for anyone building with their own Developer ID certificate and notarytool credentials.

## CLI account switching

| CLI | Config file | Keychain |
| --- | --- | --- |
| Claude Code | `~/.claude.json` | `Claude Code-credentials` |
| Codex | `~/.codex/auth.json` | — (file-based) |
| Gemini CLI | `~/.gemini/google_accounts.json` | `~/.gemini/oauth_creds.json` (file-based) |

Switching an account swaps these files/Keychain entries atomically, so a running CLI session that re-reads its credentials picks up the new identity without a restart. Every switch is logged locally so you can see which account was active at any point in time.

## Floating desktop widget

The floating widget is the always-on-top HUD counterpart to the menu bar item. It's built with AppKit (not SwiftUI) for precise window-level control — it stays above other windows without stealing focus, and it's off at build-time and can be toggled off without touching any other setting.

- **Expanded mode** shows each provider's active account, percentage, and reset countdown as labeled bars.
- **Compact mode** collapses the same data to a minimal glyph strip for users who want the always-visible signal without the screen real estate.
- Position and layout persist across launches (`FloatingWidgetLayoutTests.swift` covers this).

## Settings reference

| Setting | Default | What it controls |
| --- | --- | --- |
| Menu bar metric | Active account | Which number the glyph reports per provider |
| Menu bar icon style | Gauge | Gauge / battery / percent-only / monochrome |
| Show percent in menu bar | On | Whether numeric text renders next to the glyph |
| Threshold notifications | Off | 75/90/95% usage alerts per account/window |
| Notification sound | On | Whether threshold alerts play a sound |
| Auto-switch on quota hit | Off | Automatic same-provider failover when an account runs dry |
| Pace estimation | On | Ahead/on-pace/burning-fast glyph |
| Adaptive refresh | Off | Shortens polling after detected CLI activity |
| Floating widget | Off | Always-on-top HUD, expanded or compact |
| Statusline integration | Off | Installs the Claude Code `statusLine` script |
| Theme | System | Light / dark / system appearance |
| Language | System | Any of the 12 supported UI languages |

## Screenshots

### Menu Bar Status Item
![Menu Bar Status Item](Screenshots/screen-pasek-menu.png)

### Main Application Panel
![Main Application Panel](Screenshots/screen-ustawienia.png)

### Floating Desktop HUD — Expanded
![Floating Desktop HUD Expanded](Screenshots/screen-wigdet.png)

### Floating Desktop HUD — Compact
![Floating Desktop HUD Compact](Screenshots/screen-kompakt.png)

## How FuelSwitch AI compares

There's a growing category of Claude/Codex/Gemini usage trackers on GitHub — CLI dashboards, Python scripts, single-provider menu bar apps, and account-switcher CLIs. FuelSwitch AI's position in that space:

| Capability | FuelSwitch AI | Typical CLI/Python usage monitor | Typical single-provider menu bar app | CLI-only account switcher |
| --- | --- | --- | --- | --- |
| Claude Code + Codex + Gemini CLI in one app | ✅ | ❌ (usually one provider) | ❌ (usually one provider) | Varies |
| Native macOS menu bar item | ✅ | ❌ | ✅ | ❌ |
| Always-on-top floating widget/HUD | ✅ | ❌ | Rarely | ❌ |
| 1-click account switching (not just monitoring) | ✅ | ❌ | ❌ | ✅ |
| Auto-switch on quota exhaustion | ✅ (opt-in) | ❌ | ❌ | Sometimes |
| Claude Code `statusLine` integration | ✅ | Sometimes | ❌ | ❌ |
| Per-account threshold notifications | ✅ | Rarely | Sometimes | ❌ |
| 12-language localized UI, RTL-aware | ✅ | ❌ | Rarely | ❌ |
| Local-only storage, no telemetry server | ✅ | Usually | Usually | Usually |
| Test coverage published in-repo | ✅ (229 tests) | Varies | Varies | Varies |

This table describes categories, not any single named competitor — the point is where FuelSwitch AI sits: it's the intersection of "native macOS widget" and "actual account switcher," which is a narrower list than either category alone.

## FAQ

### General

**1. What exactly is FuelSwitch AI?**
A free, open-source, native macOS menu bar app that (a) monitors your Claude Code, Codex CLI, and Gemini CLI usage limits in real time, and (b) lets you switch between multiple accounts for each of those CLIs with one click, from the menu bar, a floating widget, or the terminal.

**2. Is FuelSwitch AI free?**
Yes. It's MIT-licensed and free to build from source or download from Releases. There's no paid tier, no account required, and no telemetry.

**3. Which CLIs does it support?**
Claude Code, Codex CLI, and Gemini CLI. Each provider is polled independently, so you can use FuelSwitch AI even if you only use one of the three.

**4. What macOS versions and Mac models are supported?**
macOS 13 Ventura or later, on both Apple Silicon and Intel — it ships as a universal binary. Support for macOS 13 is deliberate: the app is built on Combine/`ObservableObject` rather than the macOS 14-only Observation framework specifically so Intel Macs stuck on Ventura aren't excluded.

**5. Is this built with Swift 6?**
Yes — the package targets Swift tools version 6.0 (`swift-tools-version: 6.0` in `Package.swift`), not Swift 5. It's built and tested with the Swift 6 toolchain end to end.

**6. Does it require an internet connection?**
Only to poll each provider's own usage API/endpoint and to check GitHub Releases for updates. There's no FuelSwitch backend — the app talks directly to Anthropic, OpenAI, and Google's own CLIs/APIs and nothing else.

### Account switching

**7. How does account switching actually work?**
FuelSwitch AI swaps the credential files/Keychain entries each CLI reads on startup or refresh: `~/.claude.json` plus the `Claude Code-credentials` Keychain item for Claude Code, `~/.codex/auth.json` for Codex, and `~/.gemini/google_accounts.json` + `~/.gemini/oauth_creds.json` for Gemini CLI. Switching is atomic, so a running session picks up the new identity without needing a terminal restart in most cases.

**8. Can I switch accounts without opening the app?**
Yes, two ways: a generated per-profile shell snippet (e.g. `fs-work`, `fs-personal`) you can alias or run directly, and a `fuelswitch://` URL scheme you can trigger from a script, a Raycast/Alfred workflow, or a keyboard-launcher of your choice.

**9. How many accounts can I add per provider?**
There's no hard cap in the app — you can add as many Claude Code, Codex, and Gemini CLI accounts as you have credentials for. Each gets its own nickname, usage bar, and threshold settings.

**10. What is "auto-switch on quota hit" and is it safe to enable?**
When your active account for a provider runs out of quota, FuelSwitch AI can automatically fail over to the best available same-provider account instead of leaving your CLI blocked. It's opt-in and off by default, and it includes a cooldown window specifically to stop it from flapping back and forth between two accounts that are both nearly exhausted.

**11. Does auto-switch work across providers (e.g. Claude → Codex)?**
No — auto-switch only fails over between accounts of the *same* provider (Claude → another Claude account, not Claude → Codex), since credentials, quotas, and CLI config formats aren't interchangeable across providers.

**12. What are account nicknames for?**
Readability. Instead of scanning raw email addresses in the panel, you label accounts `work`, `personal`, `client-a`, etc. Nicknames are local-only and never sent anywhere.

**13. Can I use FuelSwitch AI with only one account per provider?**
Yes — the usage monitoring, menu bar glyph, floating widget, and notifications all work the same whether you have one account or ten. Switching UI simply won't have anything to do if there's only one account.

**14. Does switching accounts log me out of the Claude Code / Codex / Gemini CLI web dashboards?**
No — FuelSwitch AI only touches local CLI credential files and Keychain entries used by the CLI tools themselves. It doesn't touch browser sessions or web-based dashboard logins.

### Floating widget / HUD

**15. What's the difference between the menu bar icon and the floating widget?**
The menu bar icon is a compact glyph in the system menu bar that you click to see detail. The floating widget is a separate always-on-top window that stays visible on your desktop without any click — for people who want usage numbers on screen at all times.

**16. Is the floating widget on by default?**
No, it's off by default. Enable it from Settings with a single toggle; it doesn't require changing any other setting.

**17. What's the difference between expanded and compact widget layouts?**
Expanded shows labeled bars per provider (account, percentage, reset countdown). Compact collapses that to a minimal glyph strip for users who want the signal but not the screen space.

**18. Does the floating widget block clicks to windows underneath it?**
It's designed to sit above other windows without stealing focus from them; you interact with it directly, and it doesn't intercept clicks meant for whatever's behind it.

**19. Does the widget's position persist after I restart the app or reboot my Mac?**
Yes — widget position and layout mode (expanded/compact) are persisted and covered by dedicated tests (`FloatingWidgetLayoutTests.swift`).

**20. Can I run the floating widget on a second/external monitor?**
Yes — like any macOS floating window, you can drag it to any connected display; it stays on the display you place it on.

### Usage monitoring & alerts

**21. How often does FuelSwitch AI poll usage data?**
On a base interval you choose in Settings, shortened automatically by the adaptive refresh feature when it detects recent CLI activity — so you're not polling constantly during idle time, but you get fresher data while you're actively working.

**22. What does "pace estimation" mean?**
A glyph (ahead-of-pace / on-pace / burning-fast) comparing how much of your usage window you've consumed against how much time is left in it, so you can tell if you're on track to run out before the reset.

**23. Can I get notified before I run out, not just after?**
Yes — threshold notifications fire at 75/90/95% usage (all configurable), per account and per reset window (e.g. separately for the 5-hour and 7-day Claude windows), specifically so the warning arrives before you hit the wall mid-task.

**24. Does it show Claude's separate Opus and Sonnet 7-day quotas?**
Yes — Claude Code's 5-hour window and its separate 7-day Opus/Sonnet quotas are polled and surfaced individually, not collapsed into one number.

### Statusline & terminal integration

**25. What does the Claude Code statusline integration do?**
It installs a generated script into Claude Code's `statusLine` setting so that Claude, Codex, and Gemini usage percentages appear together in one line inside every Claude Code session — no need to switch to the app or check the menu bar mid-conversation.

**26. Does the statusline integration slow down Claude Code?**
No — usage values are cached locally (`StatuslineCache`) so the statusline reads a cached number instead of making a network request on every prompt.

**27. Is the statusline integration on by default?**
No, off by default, one toggle to install it.

### Privacy & security

**28. Does FuelSwitch AI send my usage data or credentials anywhere?**
No. All account data lives locally at `~/Library/Application Support/FuelSwitch/accounts.json` with `0600` permissions, readable only by your user account. There is no FuelSwitch server — the app talks directly to each provider's own API/CLI.

**29. Are my OAuth tokens encrypted or protected?**
Token values are redacted from any debug/log output (`CustomStringConvertible` conformance strips them), OAuth exchanges use PKCE with a 32-byte verifier, and the `state` parameter is validated using `SecRandomCopyBytes` to prevent CSRF-style replay. Claude Code credentials additionally live in the macOS Keychain rather than a plain file.

**30. Why do I need to set up my own Gemini OAuth client?**
Because Google doesn't allow redistributing installed-app OAuth secrets. Set `FUELSWITCH_GEMINI_CLIENT_ID` / `FUELSWITCH_GEMINI_CLIENT_SECRET` at build time with your own Google Cloud OAuth client to enable Gemini sign-in — this is a Google policy constraint, not a FuelSwitch limitation.

**31. Is the app notarized by Apple?**
Not in the prebuilt Releases build, since that requires an active Apple Developer Program membership. Gatekeeper will warn on first launch; right-click → Open (once) or `xattr -cr` clears it. The `Makefile` includes a full `make release` target for anyone who wants to sign and notarize with their own Developer ID.

### Development & testing

**32. Is FuelSwitch AI actively tested?**
Yes — 229 tests across 30 test files in the `FuelSwitchCoreTests` target, covering account switching, OAuth/PKCE flows, usage polling, statusline generation, localization completeness across all 12 languages, and floating widget layout persistence. `FuelSwitchCore` has no UI dependencies, which is what makes it fully unit-testable.

**33. How do I run the tests myself?**
`swift test --parallel` from the repo root after cloning.

**34. Can I contribute?**
Yes — see [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

**35. What license is this under?**
MIT — see [LICENSE](LICENSE).

## Architecture

```
FuelSwitchCore   domain logic: Account/LimitWindow/AccountUsage models,
                 usage polling, OAuth/PKCE flows, CLISwitcher, AccountStore,
                 localization, notification logic, update checking
FuelSwitch       SwiftUI menu bar UI, settings, AppKit floating HUD
```

`FuelSwitchCore` has no UI dependencies and is covered by its own test target — 229 tests across 30 test files, including full localization-completeness checks across all 12 languages.

## Security

- Account data lives only on disk at `~/Library/Application Support/FuelSwitch/accounts.json`, with `0600` permissions.
- Token values are redacted from any `CustomStringConvertible` description.
- OAuth exchanges use PKCE (32-byte verifier) and validate the `state` parameter via `SecRandomCopyBytes`.
- No bundled Gemini OAuth client — Google doesn't allow redistributing installed-app secrets. Set `FUELSWITCH_GEMINI_CLIENT_ID` / `FUELSWITCH_GEMINI_CLIENT_SECRET` at build time with your own Google Cloud OAuth client to enable Gemini sign-in.

## Testing

```bash
swift test --parallel
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

MIT — see [LICENSE](LICENSE). Copyright © 2026 [Tomasz Bołoz](https://www.damtox.pl).

Created by [Tomasz Bołoz](https://www.damtox.pl). Inspired by Headroom AI.
