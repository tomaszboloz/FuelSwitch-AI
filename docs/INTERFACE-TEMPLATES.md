# ⛽ Interface templates

Available since **1.2.0 (build 11)** in Settings → Appearance → Interface template.

| Setting | Classic (default) | Native macOS |
| --- | --- | --- |
| Main surface | Existing menu-bar cockpit | Resizable account workspace, opened from menu bar |
| Navigation | Provider tabs/cards | Provider sidebar (dropdown below 900 pt), search, active filter |
| Widget | Existing expanded HUD or compact bar | System-colored expanded widget or horizontal compact bar |
| Settings | Shared settings window/panel | Same settings and functionality |
| Account state | Shared AppModel | Same model, no second poller or account store |
| Icon / favicon | Approved orange fuel tank | Exactly the same artwork |

The preference is stored as `interfaceTemplate`. Missing or unknown values fall back to `classic`. Changing templates does not change appearance, credentials, synchronization consent or polling settings. Closing the native workspace does not quit the menu-bar application.

The implementation adapts the earlier AppKit design with SwiftUI native controls and an AppKit window. The historical design specification includes aspirational features, not all implemented interactions. Account details support switching, refreshing, renaming and confirmed removal; available Codex reset credits are informational (redemption remains disabled). Settings deliberately remain shared.

## Production-view previews

After `make app`, run:

```sh
".build/FuelSwitch AI.app/Contents/MacOS/FuelSwitch" --render-previews docs/screenshots
```

This explicit command exits before creating the live application model. It renders both templates and widget styles in light/dark modes using synthetic `.example` accounts. No real account names are loaded; no polling, OAuth, migrations or update checks start. Screenshots show view content, not the titlebar. They are separate from older AppKit mockups in `design/macos-native-v2`.

## Brand pipeline

`make icon` copies the approved `design/macos-native-v2/FuelSwitch.icns` and its 32 px PNG into `Resources`. Both are bundled. `BrandIcon` reads the shared ICNS; OAuth HTML embeds the PNG as a data URL needing no second HTTP request. No template chooses a different app icon.

## Validation

Run `swift test --parallel`, `python3 -m unittest discover -s scripts -p 'test_*.py'`, `make app`, and `codesign --verify --deep --strict ".build/FuelSwitch AI.app"`.

Manual acceptance should additionally cover keyboard navigation, VoiceOver, RTL, changing templates with Settings/widget open, and switching a test account with optional Codex synchronization. Offline renders do not establish interactive OAuth or installer success.
