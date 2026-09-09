# FuelSwitch AI — Native macOS v2

Pakiet projektowy, bez podmiany produkcyjnego UI.

- [Design system](DESIGN-SYSTEM.md)
- [Interakcje i stany](INTERACTIONS.md)
- [Ikona ICNS](FuelSwitch.icns)
- [Light](main-light.png), [dark](main-dark.png), [compact](compact-light.png)
- Widget rozwinięty: [light](widget-expanded-light.png), [dark](widget-expanded-dark.png).
- Widget kompaktowy — poziomy pasek, nie okno: [light](widget-compact-bar-light.png), [dark](widget-compact-bar-dark.png).
- [Źródło prototypu AppKit](NativePreview.swift)

Uruchomienie lokalnego podglądu:

```sh
rtk proxy swiftc -swift-version 6 design/macos-native-v2/NativePreview.swift -o /tmp/fuelswitch-native-preview
rtk proxy /tmp/fuelswitch-native-preview
```

Eksport makiet (ostatni argument: absolutny katalog wynikowy):

```sh
rtk proxy /tmp/fuelswitch-native-preview --export /Volumes/Kingston/www/fuelswitch-ai/design/macos-native-v2
rtk proxy bash design/macos-native-v2/export-icon.sh
rtk proxy swiftc -swift-version 6 design/macos-native-v2/WidgetPreview.swift -o /tmp/fuelswitch-widget-preview
rtk proxy /tmp/fuelswitch-widget-preview /Volumes/Kingston/www/fuelswitch-ai/design/macos-native-v2
```

Podgląd nie loguje się do kont, nie korzysta z Keychain i nie wykonuje operacji OAuth. Teksty i wartości są demonstracyjne. AppKit renderuje kontrolki zgodnie z wersją macOS hosta; wygląd nie jest zamrożony na Big Sur. Ikona `.icns` realizuje styl Big Sur+, a nie nowy warstwowy format Icon Composer.

## Prompt ikony

Użyto wbudowanego imagegen, nie CLI/API fallback. Wynik 1254 × 1254 z alfa przeskalowano systemowym `sips` do 1024 × 1024 i wariantów, a `iconutil` zbudował ICNS. Bez podmiany `Resources/AppIcon.icns`.

> Use case: stylized-concept. Create a production macOS Big Sur-style application icon for FuelSwitch AI, square 1024x1024. Single premium three-dimensional fuel storage tank / compact metal jerrycan with rounded body, integrated carry handle and short fuel cap, slightly isometric perspective, large readable silhouette. Brushed warm silver metal edges and an inset glass fuel-level window visibly filled about two-thirds with rich orange fuel. Restrained physical detailing, top-left soft studio light, polished edge highlights, subtle reflections and contact shadow. Background tile: orange gradient with extremely subtle fine grain, macOS continuous squircle shape with generous standard icon safe-area margins, genuinely transparent outside tile. Tank occupies most of tile but comfortable margins; no text, letters, numbers, logos, watermarks, extra objects, scene, mockup presentation or multiple icons. Deliver one beautifully finished app icon; readability at 32 pixels matters.
