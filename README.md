# Galaxy Strike: Space Survivor

Pionowa gra akcji 2D w Godot 4.7.2 stable. W misji **Peryhelium** pilotujesz myśliwiec Peregrine i próbujesz przeżyć cztery minuty. Statek sam atakuje wrogów w zasięgu. Zdobywaj rdzenie XP pozostające po zestrzeleniach i wybieraj jedno z trzech ulepszeń przy każdym awansie. Wybór karty przywraca też do 10 HP. Rakiety Widmo i Pierścień jonowy odblokowują nowe automatyczne ataki.

## Uruchomienie

Zaimportuj `project.godot` w Godot **4.7.2 stable** i uruchom projekt klawiszem **F5**. Na komputerze steruj **WASD** lub **strzałkami**. **Esc** i **P** wstrzymują i wznawiają lot. Na telefonie dotknij pola gry i przytrzymaj palec po przeciągnięciu w wybranym kierunku. Uniesienie palca zwalnia wirtualny drążek. W prawym górnym rogu jest przycisk pauzy.

Możesz też uruchomić grę z terminala w katalogu repozytorium.

```sh
godot --headless --editor --import
godot
```

Bazowy obszar gry ma 540 × 960 jednostek. Na wyższych ekranach zwiększa się widoczny obszar nad i pod statkiem. Renderer Compatibility obsługuje Windows i Androida. Interfejs uwzględnia bezpieczny obszar zgłaszany przez Androida.

## Eksport

Zainstaluj oficjalne szablony eksportu zgodne z Godot 4.7.2 stable. Na Androida skonfiguruj ścieżki JDK i Android SDK w ustawieniach edytora. Preset **Android** buduje testowe APK dla arm64-v8a oraz x86_64. Weryfikację podpisu umożliwia `apksigner verify GalaxyStrike.apk`. Preset **Windows** buduje program x86-64 z danymi gry osadzonymi w pliku wykonywalnym.

```sh
mkdir -p build/android build/windows
godot --headless --export-debug Android build/android/GalaxyStrike.apk
godot --headless --export-debug Windows build/windows/GalaxyStrike.exe
```

Testowy klucz Androida jest przechowywany w lokalnych ustawieniach edytora. Opublikowanie gry wymaga własnej konfiguracji podpisu dystrybucyjnego.

## Testy

```sh
bash tests/run.sh --full-mission
bash tests/capture.sh /sciezka/do/zrzutow
```

Pierwsze polecenie importuje projekt, testuje normalną scenę wejściową i prowadzi statek skryptowanym sterowaniem przez czterominutową misję. Drugie wymaga aktywnego serwera graficznego. Zapisuje klatki wyrenderowane w Godot w rozdzielczościach 720 × 1280, 1080 × 1920 i 1080 × 2400.

## Architektura

- `main.tscn` i `main.gd` przełączają menu, lot, awans, pauzę i wynik. Arena przekazuje statystyki i zdarzenia sygnałami.
- `combat/` zawiera symulację areny, zachowania floty, bronie i efekty walki. Liczby aktywnych jednostek, pocisków i efektów są ograniczone.
- `ui/` korzysta z własnej typografii, glifów i palety. Rozgrywka i interfejs mogą rozwijać się niezależnie.
- `data/missions/`, `data/hangar/`, `data/weapons/` i `data/store/` zawierają typy zasobów dla przyszłej selekcji misji, wyposażenia statków, broni i ofert sklepowych.
- [Kierunek artystyczny i pochodzenie zasobów](ART_DIRECTION.md)
- [Licencja Godot](licenses/Godot-LICENSE.txt) · [Informacje licencyjne komponentów Godot](licenses/Godot-COPYRIGHT.txt) · [Licencje krojów pisma](assets/fonts/README.md)
