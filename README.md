# Galaxy Strike: Space Survivor

Pionowa gra akcji 2D w Godot 4.7.2 stable. W misji **Peryhelium** pilotujesz myśliwiec Peregrine przez dziesięć minut. Przetrwaj osiem fal i zniszcz Leviathana przed upływem czasu. Aegis pojawia się po 3:30, a Leviathan po 8:00. Oba okręty zapowiadają salwę pierścieniową, cięcie osiowe i pola detonacji. Zestrzelenia, fale i bossowie nagradzają rdzeniami odzysku, które są zapisywane w lokalnym profilu po zakończeniu lotu.

Statek sam atakuje. Zbieraj XP i przy każdym awansie wybieraj jedną z trzech kart. Talia zawiera sześć kart uzbrojenia, trzy ewolucje oraz trzy systemy pokładowe. Wybór karty przywraca też do 10 HP.

| Uzbrojenie | Działanie |
| --- | --- |
| Pulse Cannon | Salwa, która z poziomem zyskuje dodatkowe pociski. Ogień krzyżowy dodaje okresowy atak w czterech kierunkach. |
| Homing Missiles | Rakiety naprowadzane z wybuchem obszarowym. Głowica kasetowa rozrzuca rażące odłamki. |
| Laser Beam | Ciągła wiązka zadaje obrażenia na całej linii w trakcie emisji. |
| Plasma Orbitals | Krążące wokół statku ładunki uszkadzają wrogów na orbicie. |
| Tesla Chain | Łuk przeskakuje między celami. Ewolucja uruchamia dodatkowe odgałęzienia. |
| Drone Swarm | Drony eskorty wyszukują i atakują cele wokół statku. |

## Hangar i profil pilota

**Hangar** na ekranie tytułowym otwiera podgląd aktywnego statku i warsztat. Ulepszenia kadłuba, napędu i uzbrojenia są osobne dla każdego z czterech statków. W **Ekwipunku** można montować znalezione moduły w pięciu slotach. **Sektory** wybierają trasę następnego lotu, a **Nagrody** pozwalają otworzyć skrzynie i odebrać zadania, osiągnięcia oraz nagrody z siedmiodniowego kalendarza. [Założenia i symulacja pierwszych pięciu godzin](BALANCE.md)

Postępy zapisują się automatycznie po zakupie, wyposażeniu, odbiorze nagrody i zakończeniu lotu. Profil w wersji 3 używa dwóch kopii o kolejnych numerach transakcji, weryfikowanych sumą SHA-256. Zapis trafia najpierw do pliku tymczasowego, a po weryfikacji zastępuje starszą kopię. Gra wczytuje najnowszą poprawną kopię. Pierwszy start z dawnym zapisem `flight_profile.cfg` przenosi rdzenie odzysku do materiałów i zachowuje poprzedni plik. Rozgrywka i zdobywany w niej postęp działają lokalnie. Testowy portfel zakupów Androida wymaga osobnego wdrożenia serwera i połączenia konta.

## Sklep i waluty

**Sklep** w menu i hangarze obsługuje Credits, Crystals, skórki, zestawy modułów i przepustkę Helion. Crystals można zdobywać za zwycięstwa, z kalendarza i darmowego toru Helionu. Windows korzysta z jawnie oznaczonej symulacji. Android korzysta z Google Play Billing i AdMob, domyślnie z testową jednostką reklamy. Przyjmowanie płatności wymaga produktów Google Play i serwera właściciela. [Katalog i scenariusze testowe](COMMERCE.md) · [Integracja Android](ANDROID_INTEGRATION.md)

## Uruchomienie

Zaimportuj `project.godot` w Godot **4.7.2 stable** i uruchom projekt klawiszem **F5**. Na komputerze steruj **WASD** lub **strzałkami**. **Esc** i **P** wstrzymują i wznawiają lot. Na telefonie dotknij pola gry i przytrzymaj palec po przeciągnięciu w wybranym kierunku. Uniesienie palca zwalnia wirtualny drążek. W prawym górnym rogu jest przycisk pauzy.

Możesz też uruchomić grę z terminala w katalogu repozytorium.

```sh
godot --headless --editor --import
godot
```

Bazowy obszar gry ma 540 × 960 jednostek. Na wyższych ekranach zwiększa się widoczny obszar nad i pod statkiem. Renderer Compatibility obsługuje Windows i Androida. Interfejs uwzględnia bezpieczny obszar zgłaszany przez Androida.

## Eksport

Zainstaluj oficjalne szablony eksportu zgodne z Godot 4.7.2 stable. Na Androida skonfiguruj JDK 17 i Android SDK 36 w ustawieniach edytora. Preset **Android** buduje testowe APK dla arm64-v8a oraz x86_64. Preset **Android Play AAB** buduje paczkę Google Play. Preset **Windows** buduje program x86-64 z danymi gry osadzonymi w pliku wykonywalnym. [Konfiguracja Androida i podpisywanie](ANDROID_INTEGRATION.md)

```sh
mkdir -p build/android build/windows
bash tools/prepare_android.sh
godot --headless --export-debug Android build/android/GalaxyStrike.apk
godot --headless --export-debug Windows build/windows/GalaxyStrike.exe
```

Testowy klucz Androida jest przechowywany w lokalnych ustawieniach edytora. Opublikowanie gry wymaga własnej konfiguracji podpisu dystrybucyjnego.

## Testy

```sh
bash tests/run.sh --full-mission
bash tests/capture.sh /sciezka/do/zrzutow
```

Pierwsze polecenie importuje projekt, sprawdza uzbrojenie, bossów, hangar, audio i ekonomię, po czym prowadzi statek skryptowanym sterowaniem przez dziesięciominutową misję uruchomioną z menu. Testy wzorców używają osobnych prób, które ustawiają zegar tuż przed ostrzeżeniem o pojawieniu się bossa. Drugie polecenie wymaga aktywnego serwera graficznego. Zapisuje klatki wyrenderowane w Godot w rozdzielczościach 720 × 1280, 1080 × 1920 i 1080 × 2400.

## Architektura

- `main.tscn` i `main.gd` przełączają menu, lot, awans, pauzę i wynik. Arena przekazuje statystyki i zdarzenia sygnałami.
- `combat/` zawiera symulację areny, zachowania floty, bronie i efekty walki. Liczby aktywnych jednostek, pocisków i efektów są ograniczone.
- `ui/` korzysta z własnej typografii, glifów i palety. Rozgrywka i interfejs mogą rozwijać się niezależnie.
- `data/missions/`, `data/hangar/` i `data/weapons/` zawierają zasoby misji, wyposażenia i uzbrojenia. `data/store/` definiuje ofertę i operacje portfela, a `commerce/` obsługuje adaptery zakupów i reklam.
- [Kierunek artystyczny i pochodzenie zasobów](ART_DIRECTION.md)
- [Licencja Godot](licenses/Godot-LICENSE.txt) · [Informacje licencyjne komponentów Godot](licenses/Godot-COPYRIGHT.txt) · [Licencje krojów pisma](assets/fonts/README.md)

## Audyt przed wydaniem

Wersja 0.7.1 dopracowuje czytelność walki, prezentację floty, ekwipunek, sklep i nagrody. Kompilacja testowa Androida ma opcjonalną diagnostykę lotu i blokadę rzeczywistych płatności. [Raport 0.7.1](VERSION_0_7_1.md) · [Audyt 0.7.0](release/GRAPHICS_AUDIT_0_7_0.md) · [Testy na telefonie](release/ANDROID_QA_0_7_PL.md) · [Portfel testowy](server/WALLET_0_7_PL.md)
