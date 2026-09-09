# Interakcje, stany i kryteria odbioru

## Menu i klawiatura

| Menu | Polecenia / skróty |
|---|---|
| FuelSwitch AI | O aplikacji, Ustawienia ⌘,, Sprawdź aktualizacje, Usługi, Ukryj ⌘H, Zakończ ⌘Q |
| Plik | Dodaj konto ⌘N, Zamknij okno ⌘W; eksport tylko jawnie zanonimizowany |
| Edycja | Cofnij ⌘Z / Ponów ⇧⌘Z dla wspieranych lokalnych zmian; Wytnij/Kopiuj/Wklej zgodnie z responder chain |
| Widok | Odśwież ⌘R, Szukaj ⌘F, Sidebar ⌃⌘S, Inspector ⌥⌘I, Pokaż widget, Full Screen przez system |
| Konto | Pokaż szczegóły, Przełącz konto…, Zaloguj ponownie…, Usuń z FuelSwitch… |
| Okno | Minimalizuj ⌘M, powiększanie i lista okien systemowa |
| Pomoc | Pomoc FuelSwitch, diagnostyka bez sekretów |

Tab/Shift-Tab przechodzi przez rzeczywiste kontrolki, a nie dekoracyjne procenty. Strzałki poruszają po liście, Enter otwiera szczegóły; przełączenie konta wymaga jawnego działania. Escape zamyka popover/sheet lub anuluje operację, jeśli anulowanie jest jeszcze możliwe. Space na wierszu otwiera krótkie szczegóły w NSPopover; nie nazywamy tego systemowym Quick Look dla plików, których aplikacja nie ma. Nie przechwytywać spacji w polu tekstowym.

## Stany komponentów

| Komponent | Hover | Pressed / selected | Focus | Disabled |
|---|---|---|---|---|
| NSButton | systemowy feedback + tooltip ikony | natywny stan wciśnięcia | system ring, bez ręcznego blur | `.isEnabled = false`, tekst powodu obok |
| Tabela | standardowa interakcja wiersza | systemowy selection, niezależny od aktywnego konta | full keyboard access | zablokować tylko konfliktujące działania |
| Search / tekst | bez dodatkowego overlay | caret i selection systemowe | responder chain | natywna prezentacja disabled |
| Checkbox / segment | natywne | stan od razu widoczny | natywny | wyłączać zależne opcje i objaśnić zależność |
| Progress | brak fikcyjnej interakcji | wartość i tekst aktualizowane razem | nie dodawać do Tab | brak danych jest odrębnym stanem, nie pustym disabled paskiem |

Wiersz zaznaczony oznacza „oglądam”, a „Aktywne” oznacza konto używane przez danego dostawcę. To dwa różne stany. Powód niedostępności nie może być dostępny tylko po hover, ponieważ użytkownik klawiatury i VoiceOver też go potrzebuje.

## Pobieranie limitów

- Pierwsze pobranie: spinner, „Sprawdzanie limitów…”, bez sztucznych liczb.
- Sukces: nazwa konta, obydwa dostępne okna, remaining %, reset, fetchedAt w jednym snapshotcie.
- Odświeżanie: zachować ostatni snapshot oznaczony datą; spinner przy działaniu, nie blokować okna.
- Offline / 429 / 5xx: czytelny błąd, ostatni poprawny odczyt z datą albo „Brak danych”, „Spróbuj ponownie”. Backoff nie może tworzyć ruchu co sekundę.
- Niski limit: `systemOrange` fuelpump i „Pozostało 18%”, bez migania i bez samego koloru.
- Zero: „0% pozostało”, pusty pasek i znany reset. Unknown: „—”, żadnego twierdzenia o wyczerpaniu.

## Zmiana konta i synchronizacja

1. Wybierz wiersz i „Przełącz konto…”.
2. Gdy synchronizacja Codex jest włączona, sheet jasno informuje o restarcie i możliwym przerwaniu pracy. Przyciski „Anuluj” i „Przełącz i uruchom ponownie”; brak mylącego „OK”.
3. W trakcie zapisu wyłączyć kolejne przełączenie tego dostawcy. Pozostałe funkcje pozostają dostępne.
4. Sukces dopiero po potwierdzonym zapisie i wymaganym etapie synchronizacji; nie po kliknięciu. Wskaźnik aktywnego konta i wszystkie powierzchnie aktualizują się razem.
5. Odmowa zamknięcia Codex lub błąd zapisu: jawny stan częściowy/błąd i faktyczne aktywne konto. Nie force-kill.
6. Nie dodawać „Cofnij” imitującego rollback tokenów. Powrót do poprzedniego konta jest nową operacją uwierzytelniania.

## Automatyczne aktualizacje

„Automatycznie sprawdzaj aktualizacje w tle” i „Automatycznie pobieraj i instaluj aktualizacje” są osobne. Wyłączenie pierwszej wyłącza drugą. Ręczne „Sprawdź teraz” dostępne również przy wyłączonej automatyzacji. Stany: sprawdzanie → nowa wersja / aktualna / błąd. Błąd nigdy nie przechodzi do „aktualna”. Weryfikację podpisu i dialog instalacji prowadzi Sparkle.

## Drag & drop, context menus, Services

- Context menu na wierszu: szczegóły, przełącz, zmień lokalną nazwę, ponowne logowanie, usuń z aplikacji. Nie dodawać menu do nieinteraktywnych etykiet tylko dla spełnienia hasła „wszystko”.
- Drag & drop: porządkowanie lokalnych skrótów/faworytów z Undo; identyczna alternatywa klawiaturowa „Przenieś wyżej/niżej”. Nigdy nie eksportować tokenów przeciągnięciem konta na pulpit.
- Import plików: tylko jeśli osobno zostanie zdefiniowany bezpieczny format. Nie akceptować dowolnego auth.json w ciemno.
- Services: standardowa obsługa zaznaczonego, niesekretnego tekstu przez responder chain. Raport przez NSSharingServicePicker tylko po podglądzie anonimizacji. Tokeny, nagłówki Authorization, ścieżki sekretów i e-maile domyślnie wyłączone.
- Touch Bar: opcjonalne odśwież / szukaj, żadnej unikalnej funkcji dostępnej wyłącznie tam.

## Widget i menu bar

Widget regular: 320 × minimum 180 pt; nazwa aktywnego konta, 5 h i tydzień, liczby i malejące paski. Compact: 240 × minimum 110 pt; „Codex · Praca”, „5 h 100% · tydzień 43%”, dwa krótkie paski. Jeśli tekst nie mieści się w danym języku, zwiększyć wysokość, nie usuwać liczb. Nazwa dostawcy i rodzaju okna zawsze jawna.

NSStatusItem korzysta z monochromatycznego template symbolu paliwa na normalnym poziomie; poniżej progu może użyć `.systemOrange` i tekstu dostępności. Ikona Dock i favicon są brandingiem, a znak w menu jest uproszczonym symbolem stanu, nie miniaturą z metalicznymi refleksami. Jeśli wymagane jest absolutnie identyczne logo w każdej powierzchni, potrzebny jest osobny wektorowy wariant tego samego zbiornika dla 16–18 pt; nie skalować bezrefleksyjnie rastra 3D.

## Motion i dostępność

- Zmiana wartości bez dekoracyjnego bounce; ewentualne wygładzenie 0,2 s, natychmiast przerwalne nowym snapshotem.
- Sheet/popover: animacja systemowa; nie mnożyć warstw i custom cieni.
- Reduce Motion: bez przesuwania i sprężyn; stan/krótka zmiana opacity wystarcza.
- Reduce Transparency: tła nieprzezroczyste. Increase Contrast: semantyczne kolory i systemowa selekcja.
- VoiceOver: „Claude, Praca, aktywne konto. Limit tygodniowy, pozostało 18 procent. Niski limit”. Postęp ma min/max/value. Nie ogłaszać całej tabeli co każde odświeżenie.
- Każda ikona-działanie ma accessibilityLabel i tooltip; dekoracyjna ukryta z drzewa dostępności.
- Nie wyciągać realnych sekretów do makiet. Długie nazwy kont testować na sztucznych danych.

## Lokalizacja

Projekt tekstów jest po polsku; nie jest dodatkową nieprzetłumaczoną powierzchnią produkcji. Implementacja korzysta z istniejących 12 tabel lokalizacji, lokalizuje menu, toolbar, tooltipy, komunikaty błędów i etykiety AX. Testy completeness obejmują nowe klucze. Liczby i daty przez Formatter, nie konkatenowane angielskie jednostki.

Macierz: polski, niemiecki (ekspansja 40%), japoński, hindi, arabski RTL, plus pozostałe wspierane języki. RTL odwraca układ treści, nie ręcznie przerysowane traffic lights; nazw dostawców i adresów e-mail nie odwracać znak po znaku. Podgląd na 150% font size musi pozostawić wszystkie działania osiągalne.

## Weryfikacja i ograniczenia materiałów

Wykonano: kompilacja prototypu Swift 6/AppKit, render light/dark i compact, kontrola przycięcia kolumn w compact, eksport `.icns` i wariantów PNG. Render pochodzi z cacheDisplay natywnych widoków, nie z fotografii uruchomionej aplikacji ani z przeglądarki. Chrome offscreen może wyglądać jak nieaktywne okno; nie jest referencją koloru aktywnych traffic lights.

Do wykonania przy implementacji: pełny resize observer / compact overlay, prawdziwa nawigacja source list, działające wyszukiwanie i filtry, wszystkie menu i skróty z tabeli, Undo, Services, integracja danych, VoiceOver i klawiatura end-to-end. Prototyp nie deklaruje ich implementacji.

Kryteria odbioru na urządzeniach: 800×600, 900×650, 1200×800, 1440×900 i 2560×1440 efektywnego obszaru; @1x i @2x; light/dark; 100/125/150% tekst; contrast/transparency/motion; pełny ekran; tiling; 0 kont, 1 konto, 50 kont; 0/19/20/100% i unknown; bardzo długie nazwy; offline, 429, wygasłe OAuth, odrzucony restart. Testować 13/15/27-calowe konfiguracje, lecz wyniki raportować w efektywnych punktach, nie samych calach.
