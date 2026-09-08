# FuelSwitch AI - Codex, Gemini, Claude Usage Widget + Switcher Account

macOS menu bar app and floating HUD that monitors Claude Code, Codex, and Gemini CLI usage limits, with 1-click account switching.

[![CI](https://img.shields.io/github/actions/workflow/status/tomaszboloz/FuelSwitch-AI/ci.yml?branch=main)](https://github.com/tomaszboloz/FuelSwitch-AI/actions)
[![Release](https://img.shields.io/github/v/release/tomaszboloz/FuelSwitch-AI)](https://github.com/tomaszboloz/FuelSwitch-AI/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 13+](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://www.swift.org)
[![Languages: 12](https://img.shields.io/badge/localized-12%20languages-informational.svg)](#localization)

[Why](#why) • [Features](#features) • [Installation](#installation) • [Settings](#settings-reference) • [CLI switching](#cli-account-switching) • [Architecture](#architecture) • [Security](#security) • [Contributing](#contributing)

---

## Why

Every CLI usage tracker on GitHub tells you your percentage *after* you've already hit the wall mid-task. None of them warn you before it happens, none of them switch you to a fresh account automatically, and none of them talk to more than one provider at a time.

FuelSwitch AI is a native Swift menu bar app for engineers juggling multiple **Claude Code**, **Codex**, and **Gemini CLI** accounts. It polls all three, in the background, and gets out of your way until something needs your attention.

## Features

### Live usage tracking
- **Three providers, one glyph each** — Claude Code, Codex, and Gemini CLI usage side by side in the menu bar, no need to open a panel.
- **5-hour and weekly windows** — every account's session and weekly quota tracked independently, with reset countdowns so you know exactly when a window clears, not just the current percentage.
- **Pace projection** — a glyph next to each account's usage showing whether it's ahead of, on, or burning faster than its quota window's pace, so a 60% number at 20% elapsed time reads differently than the same 60% at 90% elapsed.
- **Configurable menu bar metric** — pick what the glyph itself reports per provider: the active account, the best (emptiest) account, the busiest account, or how many accounts still have room.
- **Menu bar icon styles** — gauge, battery, percent-only, or monochrome, independent of the metric above.
- **Floating HUD** — a draggable, always-on-top panel with the same live data as the main window, in expanded or compact layout, for anyone who wants the numbers on screen at all times instead of behind a click.

### Account management
- **1-click CLI switching** — swap active credentials for Claude Code (`~/.claude.json` + Keychain), Codex (`~/.codex/auth.json`), and Gemini CLI without restarting anything.
- **Account nicknames** — label accounts (`work`, `personal`, `client-a`, …) instead of reading raw email addresses off the panel.
- **Per-profile launcher** — a generated shell snippet (`fs-work`, `fs-personal`, …) that switches the active CLI account straight from the terminal via a `fuelswitch://` URL, no need to open the app.
- **Auto-switch on quota hit** — when the active account runs dry, automatically switch to the best-available same-provider account, with a cooldown against flapping. Opt-in, off by default.

### Alerts and integration
- **Threshold notifications** — a native macOS notification at 75/90/95% usage (configurable), for each account and window, before you hit the wall, not after.
- **Claude Code statusline integration** — installs a generated script as your Claude Code `statusLine`, showing Claude, Codex, and Gemini usage together in one line inside every Claude Code session.
- **Update check** — a single, read-only request to GitHub Releases compares your installed version against the latest tag with real semver ordering, so it never nags you about a "newer" version you already have installed.

### Everything else
- **Adaptive refresh** — shortens the poll interval automatically after recent CLI activity, layered on top of your manually chosen interval.
- **Light, dark, and system themes.**
- **12 languages**, RTL-aware — see [Localization](#localization).
- **Universal binary** — one `lipo`-merged executable for both Apple Silicon and Intel, macOS 13 Sonoma and newer, built on Combine/`ObservableObject` rather than the macOS 14-only Observation framework specifically so Intel Macs on macOS 13 keep working.
- **Local-only** — account tokens live in `~/Library/Application Support/FuelSwitch/accounts.json` (`0600` permissions). No servers, no analytics, no telemetry.
- **Every feature above has its own off switch** in Settings — nothing new ships as forced-on.

## Localization

The app UI is available in 12 languages, switchable from Settings independent of your system locale:

English · Polski · Español · हिन्दी · 中文 · 日本語 · Deutsch · Français · Português · العربية · Русский · 한국어

Arabic renders right-to-left automatically. Every string in the app ships in all 12 languages — it's a hard test gate in CI, not a best-effort translation.

## Installation

### Requirements

- macOS 13 (Ventura) or later, Apple Silicon or Intel.
- Xcode 16 / Swift 6 toolchain to build from source.

### Build from source

```bash
git clone https://github.com/tomaszboloz/FuelSwitch-AI.git
cd FuelSwitch-AI
swift test
make app        # builds .build/FuelSwitch AI.app (ad-hoc signed, this machine only)
make run
```

### Prebuilt release

Download `FuelSwitch-AI.dmg` from the [Releases](https://github.com/tomaszboloz/FuelSwitch-AI/releases) page and verify it against the matching `.sha256` file.

This build is not notarized by Apple (no Apple Developer Program membership behind it), so first launch shows *"Apple could not verify that FuelSwitch AI is free of malware"*. To open it anyway:

- Right-click (Control-click) the app → **Open** → **Open**, once, or
- In Terminal: `xattr -cr "/Applications/FuelSwitch AI.app"`

The `Makefile` has a full `make release` target (sign, notarize, staple, package) for anyone building with their own Developer ID certificate and notarytool credentials.

## CLI account switching

| CLI | Config file | Keychain |
| --- | --- | --- |
| Claude Code | `~/.claude.json` | `Claude Code-credentials` |
| Codex | `~/.codex/auth.json` | — (file-based) |
| Gemini CLI | provider-managed OAuth token | — (file-based) |

Click an account in the menu bar panel or the HUD, then **Engage** — the CLI picks up the new credentials on its next call.

## Settings reference

Every row below is a real toggle or picker in Settings, not a build-time flag — each one defaults the way it's marked and can be switched off without touching another setting.

| Setting | Default | What it controls |
| --- | --- | --- |
| Menu bar metric | Active account | Which number the glyph reports per provider |
| Menu bar icon style | Gauge | Gauge / battery / percent-only / monochrome |
| Show percent in menu bar | On | Whether the numeric text renders next to the glyph |
| Threshold notifications | Off | 75/90/95% usage alerts per account/window |
| Notification sound | On | Whether threshold alerts play a sound |
| Auto-switch on quota hit | Off | Automatic same-provider failover when an account runs dry |
| Pace estimation | On | The ahead/on-pace/burning-fast glyph |
| Adaptive refresh | Off | Shortens polling after detected CLI activity |
| Floating widget | Off | The always-on-top HUD, expanded or compact |
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

## Architecture

```
FuelSwitchCore   domain logic: Account/LimitWindow/AccountUsage models,
                 usage polling, OAuth/PKCE flows, CLISwitcher, AccountStore,
                 localization, notifications logic, update checking
FuelSwitch       SwiftUI menu bar UI, settings, and the AppKit floating HUD
```

`FuelSwitchCore` has no UI dependencies and is covered by its own test target — 200 tests across 15 suites, including a completeness check that fails the build if any UI string is missing from any of the 12 language files.

## Security

- Account tokens live only on disk at `~/Library/Application Support/FuelSwitch/accounts.json`, `0600` permissions.
- Token values are redacted from any `CustomStringConvertible` description.
- OAuth exchanges use PKCE (32-byte verifier) and a validated `state` parameter via `SecRandomCopyBytes`.
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
