# FuelSwitch AI — natywny macOS / projekt v2

Status: projekt i izolowany prototyp AppKit, nie zmiana produkcyjnego interfejsu. Data: 9 września 2026. Platforma bazowa: macOS 13+. Interfejs jest systemowy; pomarańczowy identyfikuje markę i ostrzeżenie o paliwie, nie zastępuje preferowanego akcentu użytkownika.

## Materiały

- `FuelSwitch.icns`: gotowy kontener ikon dla obecnego bundla macOS.
- `icon-1024.png`: master 1024 × 1024 z kanałem alfa; `icon-source.png`: oryginalny raster wygenerowany narzędziem imagegen.
- `png/`: rozmiary 16, 32, 64, 128, 256, 512 @1x i @2x. `FuelSwitch.iconset/`: standardowy zestaw iconutil; 64 px reprezentuje wpis 32@2x, bo osobny wpis icon_64x64 nie należy do standardowego schematu.
- `main-light.png`, `main-dark.png`: render głównego okna AppKit, obszar treści 1200 × 800 pt, z dodatkowym natywnym titlebarem.
- `compact-light.png`: render obszaru treści 800 × 600 pt, zwinięty sidebar i uproszczony toolbar.
- `widget-expanded-light.png`, `widget-expanded-dark.png`: rozwinięty widget 360 × 362 pt.
- `widget-compact-bar-light.png`, `widget-compact-bar-dark.png`: kompaktowy widget jako poziomy pasek 900 × 56 pt; nie mylić z wąskim oknem głównym.
- `WidgetPreview.swift`: odtwarzalny render obu widgetów bez nazw kont i bez połączeń sieciowych.
- `NativePreview.swift`: kompilowalny prototyp, bez OAuth, dostępu do kont i zmian ustawień. Kontrolki działają demonstracyjnie; nie implementuje całej poniższej specyfikacji.
- `INTERACTIONS.md`: stany, skróty, bezpieczeństwo, lokalizacja i kryteria odbioru.

## Założenia i korekty briefu

1. Wszystkie wymiary UI są w **punktach**, nie pikselach. Raster Retina @2x ma dwa piksele na punkt. Przekątna ekranu nie określa obszaru roboczego: testujemy efektywną szerokość okna.
2. AppKit rysuje traffic lights, hover, focus ring, kształt i wysokość kontrolek. Nie narzucamy focus ring „4 px blur / 2 px spread” ani niebieskiego koloru; respektujemy system i dostępność.
3. Toolbar około 52 pt jest celem kompozycyjnym, nie sztywnym constraintem. System może zmienić jego wysokość i materiały między macOS 13 a 26.
4. SF wybieramy przez `NSFont.systemFont`, nie przez zapisane nazwy plików „SF Pro Display/Text”. Pozostawiamy systemowe tracking i metryki.
5. HIG to wytyczne, nie certyfikat. Nie deklarujemy 100% zgodności bez testów VoiceOver, klawiatury, kilku wersji macOS, kontrastu i rzeczywistych zachowań.
6. „Każda akcja ma Undo” nie jest bezpieczną obietnicą dla OAuth, aktualizacji lub restartu Codex. Odwracalne ustawienia wspierają Undo; zewnętrzne operacje mają potwierdzenie, anulowanie tam, gdzie możliwe, i precyzyjny wynik.
7. Ikona Big Sur w `.icns` realizuje wymagany wariant historyczny. Bieżące HIG promują niemaskowane warstwy i Icon Composer. Dostarczony raster nie jest warstwowym `.icon` i nie stanowi dokładnej geometrycznej kopii szablonu Apple. Ten drugi wariant wymaga osobnego przygotowania warstw; nie należy nakładać efektów Liquid Glass na już wyrenderowane światło i cień bez kontroli.

## Architektura informacji

```text
FuelSwitch AI
├── Konta i limity
│   ├── Wszystkie konta
│   ├── Codex
│   ├── Claude
│   └── Gemini
├── Historia użycia
├── Automatyzacja
└── Ustawienia (osobne okno, ⌘,)
    ├── Ogólne / wygląd / język
    ├── Pasek menu i widget
    ├── Synchronizacja aplikacji Codex (opt-in)
    └── Aktualizacje (sprawdzanie i pobieranie osobno)
```

Główny widok to narzędzie do porównywania kont, nie pulpit marketingowy. Jedna tabela pokazuje dostawcę, rozpoznawalną nazwę konta, pozostałe limity i stan. Wybór wiersza ujawnia szczegóły i jedno działanie główne „Przełącz konto…”. Historia i automatyzacja nie konkurują z codziennym sprawdzaniem limitów.

W aplikacji menu-bar-only trzeba dodać jawne polecenie „Otwórz FuelSwitch AI”. Gdy główne okno jest otwarte, zapewnić normalne menu aplikacji i zarządzanie oknami; zamknięcie okna nie kończy monitorowania.

## Układ i responsywność

| Element | Regular ≥900 pt | Compact 800–899 pt |
|---|---|---|
| Okno | cel: content 1200 × 800 | minimum content 800 × 600 |
| Sidebar | 240 pt, zakres 200–300, divider drag | ukryty; przycisk otwiera natywny NSPopover z tą samą nawigacją |
| Toolbar | sidebar, search 190–240, odśwież, dodaj | sidebar, search, odśwież, dodaj |
| Filtr Wszystkie/Aktywne | natywny segment bezpośrednio nad tabelą | nad tabelą, nadal dostępny z klawiatury |
| Tabela | konto min 240; limity 160–200 każdy; stan 100–120 | konto min 200; limity min 140; stan może przejść do szczegółów |
| Szczegóły | pod tabelą; opcjonalny inspector 280 przy ≥1160 | pod tabelą, tekst zawijany, bez stałego inspectora |
| Wiersz | 56–64 pt przy dwóch liniach | 64 pt; zwiększać przy większym tekście |
| Insets | 20 pt od krawędzi treści | 20 pt |
| Sekcje | 24–32 pt | 20–24 pt |

NSSplitViewController z NSSplitViewItem dla sidebara; `minimumThickness = 200`, `maximumThickness = 300`, `canCollapse = true`. Nie pozostawiać jednocześnie sidebara overlay i stałego. Przy powrocie do regular przywrócić wybór użytkownika. Prototyp renderuje warianty szerokości; produkcyjny observer resize i overlay pozostają zadaniem implementacyjnym.

NSScrollView przewija tabelę. Długie opisy szczegółów nie mogą wypychać toolbaru ani zasłaniać wierszy; przy dużym tekście przewijany staje się także obszar szczegółów. Żaden stały height constraint nie może obcinać tłumaczenia. Dozwolone pionowe powiększenie układu, nie zmniejszanie czcionek.

Full Screen: `.fullScreenPrimary`, bez własnego przycisku pełnego ekranu. Split View: wspierać tiling systemu w granicach minimum 800 pt. Na ekranie, którego połowa ma mniej niż 800 pt, nie obiecywać układu pół-na-pół; użytkownik potrzebuje szerszego tile lub innego skalowania.

## Kolory semantyczne: jedna paleta, dwie interpretacje

| Token | API AppKit | Light / dark |
|---|---|---|
| text.primary | NSColor.labelColor | systemowo ciemny / jasny |
| text.secondary | NSColor.secondaryLabelColor | objaśnienia, opis konta |
| text.tertiary | NSColor.tertiaryLabelColor | wyłącznie niekrytyczne metadane |
| text.disabled | NSColor.disabledControlTextColor | stan niedostępny kontrolki |
| surface.window | NSColor.windowBackgroundColor | bazowe tło okna |
| surface.control | NSColor.controlBackgroundColor | kontrolki i grupy |
| surface.input | NSColor.textBackgroundColor | pola i treść edytowalna |
| border.separator | NSColor.separatorColor | systemowe rozdzielenie |
| action.accent | NSColor.controlAccentColor | wybór użytkownika, nie hardcoded orange |
| selection | NSColor.selectedContentBackgroundColor | systemowy wybór wiersza |
| selection.text | NSColor.alternateSelectedControlTextColor | czytelność na zaznaczeniu |
| fuel.warning | NSColor.systemOrange | znak paliwa, gdy pozostało <20%, z etykietą |
| error | NSColor.systemRed | rzeczywisty błąd, nigdy sam kolor |
| sidebar.material | NSVisualEffectView.Material.sidebar | systemowa przezroczystość i vibrancy |

Bez kodów HEX w UI. `systemOrange` jest semantycznym wyjątkiem ostrzegawczym z wcześniejszego wymagania, a nie kolorem wszystkich działań. Ikona może mieć własne gradienty i metaliczne światło. Reduced Transparency wymusza nieprzezroczyste tło, Increase Contrast polega na semantycznych system colors i systemowych separatorach. Nie budować CSS-owych imitacji szkła, cieni ani focus rings.

## Typografia i spacing

| Rola | System font | Wielkość |
|---|---|---|
| Tytuł widoku | semibold | 26 pt, zakres 22–28 |
| Wartość podsumowania | semibold | 22 pt |
| Body / nazwa konta | regular / semibold | 13 pt |
| Caption / pomoc | regular | 11 pt |
| Toolbar | system control font, medium tam gdzie potrzebne | systemowy rozmiar, orientacyjnie 11 pt |
| Procent | monospacedDigitSystemFont medium | 13 pt |
| Techniczny identyfikator | monospacedSystemFont regular | 12 pt |

Baza spacing 4: 4, 8, 12, 16, 20, 24, 32, 40, 48 pt. Label i pole: 8; ikona i label: 8; działania w grupie: 8–12; sekcje: 24. Nie rozciągać małych etykiet na siatkę tylko dla symetrii. Systemowe odstępy wewnętrzne kontrolek mają pierwszeństwo. Docelowa interlinia tekstu objaśniającego 1,2–1,4, ale nie wymuszać stałej wysokości przy innych skryptach i rozmiarach tekstu.

macOS 13 nie daje identycznego modelu Dynamic Type jak iOS. Używać preferowanych stylów fontów tam, gdzie dostępne, obserwować ustawienia dostępności i zapewnić rozmiary tekstu 100/125/150% w aplikacji, jeśli system nie skaluje danej powierzchni. Testować zmianę wysokości wierszy, nie samo powiększenie fontu.

## Komponenty i SF Symbols

| Funkcja | Natywny komponent | Symbol |
|---|---|---|
| Okno i chrome | NSWindow, NSToolbar | systemowe traffic lights |
| Nawigacja | NSOutlineView / source-list NSTableView w NSSplitView | sidebar.left, square.stack |
| Konto | NSTableView, alternating rows | person.crop.circle |
| Codex / Claude / Gemini | etykiety nazw, bez podrabiania logo | terminal / text.bubble / sparkles |
| Pozostały limit | determinate NSProgressIndicator + liczba | fuelpump.fill przy ostrzeżeniu |
| Odświeżanie | NSButton / NSToolbarItem | arrow.clockwise |
| Dodanie konta | NSButton | plus |
| Filtr | NSSegmentedControl | etykiety tekstowe |
| Wyszukiwanie | NSSearchField | natywna lupa i clear |
| Preferencje | NSButton checkbox / switch, NSPopUpButton | gearshape |
| Uwierzytelnianie | natywny sheet / NSAlert | lock, exclamationmark.triangle |
| Postęp sieci | indeterminate NSProgressIndicator | bez fikcyjnego procentu |
| Szczegóły / compact sidebar | NSPopover / split inspector | sidebar.trailing |

Symbole pobierać `NSImage(systemSymbolName:accessibilityDescription:)`. Zweryfikować dostępność na macOS 13; fallback musi mieć etykietę, nigdy pusty przycisk. Toolbar target: symbol około 18–20 pt w systemowej strefie kliknięcia. Nie dodawać własnych checkboxów, radio buttons ani strzałek dropdown. Karty nie są domyślnym kontenerem wszystkiego: preferować NSBox separator i naturalne grupowanie.

## Jedno źródło limitów

W modelu prezentacyjnym przechowywać: provider, accountID, active, windowKind, usedPercent, remainingPercent, resetAt, fetchedAt, loading, error. Pasek menu, panel, okno i widget używają tego samego snapshotu. Wartość `remaining = clamp(100 − used, 0...100)` tylko jeśli źródło podaje wykorzystanie. Gdy podaje remaining, nie odejmować ponownie.

Paski maleją wraz z zużyciem. Procent nigdy nie znika w wariancie compact. Próg ostrzegawczy to **ściśle mniej niż 20%**, nie ≤20. Niewiadoma to „— / Brak danych”, a nie 0%. Po zmianie konta nie pokazywać starych wartości pod nową nazwą. Jeśli Gemini nie raportuje 5 h lub tygodnia, użyć faktycznego okna albo „Brak danych”; układ makiety nie jest dowodem istnienia konkretnego limitu u dostawcy.

Przykładowe 43% w mockupie odpowiada 57% wykorzystania. Dane są demonstracyjne, bez realnych adresów e-mail i tokenów. Widok details powinien pokazywać rzeczywisty reset i czas pobrania, nie statyczne „przed chwilą”.

## Źródła i weryfikacja

Sprawdzono aktualne treści Apple HIG 9.09.2026:

- https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- https://developer.apple.com/design/human-interface-guidelines/app-icons

HIG dla Mac podkreśla resizable windows, menu commands, skróty, personalizację toolbarów i obsługę wielu sposobów wejścia. HIG ikon (aktualizacja 8.06.2026) zaleca warstwy, Icon Composer, systemowe maskowanie i efekty. Dlatego retro `.icns` nie jest deklarowane jako pełna realizacja najnowszego systemu ikon.

Umiejętność apple-design wykorzystano dla zasad przewidywalności, dostępności i przerwalnego feedbacku. Jej przykłady webowe **nie są** implementacją tego projektu. Makiety powstały z AppKit, nie HTML/CSS.
