# Galaxy Strike — Próg Helionu

Pionowa strzelanka kosmiczna 2D w Godot 4.7.2 stable. Kampania 0.9.0 obejmuje trzy poziomy po dziesięć fal. Każdy lot korzysta z osobnej kompozycji nieba, planety i zsynchronizowanych formacji. Przechwyć patrol w **Echu pasa**, rozbij spiralę w **Załamaniu Pryzmatu**, a na **Progu Helionu** pokonaj okręt dowodzenia Asterion. Każdy ukończony poziom otwiera następny i pozostaje dostępny do powtórki. [Raport 0.9.0 i pliki do pobrania](VERSION_VERTICAL_0_9_0.md)

## Sterowanie

Na telefonie dotknij pola gry i przeciągaj palec. Statek zachowuje odstęp od punktu dotknięcia. Na komputerze można przeciągać lewym przyciskiem myszy lub użyć **WASD** albo **strzałek**. **Esc**, **P** i przycisk w prawym górnym rogu wstrzymują lot.

Broń strzela automatycznie w górę. Rdzenie zwiększają poziom siły ognia, a moduły przełączają Laser Cannon na plazmę, rakiety albo wiązkę. Pole walki zachowuje proporcje 9:16. Na wyższych ekranach dodatkowa przestrzeń rozdziela pole od krawędzi urządzenia.

## Hangar, zapis i sklep

Wybrany statek, ulepszenia i wyposażenie wpływają na kampanię. Hangar i magazyn nagród korzystają z tego samego profilu. Wersja 4 zapisu wczytuje profil z 0.7.x oraz przechowuje odblokowania i najlepsze wyniki kampanii. Kolejny numer transakcji i SHA-256 pozwalają wybrać aktualną z dwóch kopii zapisu. Nagroda i wynik poziomu zapisują się w jednej transakcji.

Sklep zachowuje istniejące katalogi, Credits, Crystals, skórki, pakiety i tor nagród. W kompilacji testowej zakup za prawdziwe pieniądze jest wyłączony. [Ekonomia i dotychczasowe testy](COMMERCE.md) · [Integracja Androida](ANDROID_INTEGRATION.md)

## Uruchomienie i testy

Otwórz `project.godot` w Godot 4.7.2 stable i naciśnij **F5**, lub użyj poniższych poleceń w katalogu repozytorium.

```sh
godot --headless --editor --import
godot
```

```sh
godot --headless --fixed-fps 60 --script res://tests/vertical_campaign.gd
bash tests/run.sh --full-mission
```

Pierwszy test prowadzi pilota przez wszystkie trzy loty i sprawdza sterowanie, kolizje, uzbrojenie, wynik oraz zapis. Skrypt `tests/premium_visual.gd` uruchamia próby graficzne na aktywnym ekranie, zapis rozgrywki lub pomiar czasu klatek. Drugi uruchamia regresje wspólnych systemów oraz pełną dziesięciominutową misję Survivor. Scena `res://main.tscn` nadal uruchamia Survivor w Godot. [Archiwum wersji 0.7.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/archive/survivor-0.7.0)

## Eksport Android

Zainstaluj szablony eksportu dokładnie dla Godot 4.7.2 stable. W edytorze ustaw JDK 17 i Android SDK 36, a następnie przygotuj natywny most. [Konfiguracja Androida i podpisywanie](ANDROID_INTEGRATION.md)

```sh
mkdir -p build/android
bash tools/prepare_android.sh
GALAXY_PLAY_MODE=test godot --headless --export-debug Android build/android/GalaxyStrike-Vertical.apk
```

Preset `Android` generuje debug APK dla arm64-v8a i x86_64. Aplikacja zachowuje identyfikator `com.galaxystrike.spacesurvivor`. Aktualizacja istniejącej instalacji wymaga zgodnego podpisu. Do równoległego testowania 0.7.x i kampanii użyj oddzielnych profili Android albo urządzeń.

## Projekt

- `vertical/campaign.gd` zawiera poziomy, harmonogram formacji, tempo i nagrody. Trwałe identyfikatory poziomów wiążą kampanię z zapisami.
- `vertical/field.gd`, `squadron.gd`, `ordnance.gd` i `commander.gd` odpowiadają za pole gry, przeciwników, uzbrojenie i bossa. Pociski i eskadry korzystają z puli obiektów.
- `vertical/main.tscn` korzysta ze wspólnej obsługi pauzy, ustawień, hangaru, audio i reklam z `main.gd`. `combat/` zawiera efekty i tryb Survivor.
- `data/pilot_progression.gd`, `data/store/` i `commerce/` przechowują profil, portfel i adaptery usług.
- [Kierunek artystyczny i pochodzenie zasobów](ART_DIRECTION.md) · [Licencje Godot](licenses/Godot-COPYRIGHT.txt) · [Licencje fontów](assets/fonts/README.md)
