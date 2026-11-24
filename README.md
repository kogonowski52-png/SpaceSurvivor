# Galaxy Strike — Próg Helionu

Pionowa strzelanka 2D w Godot 4.7.2 stable. Pierwszy rozdział ma dziesięć lotów w czterech sektorach oraz trzy okręty dowodzenia. Zacznij w Echu pasa, przebij się przez Wrakowisko Tytana i pokonaj Nadira w Sercu Otchłani. Atlas pozwala powtarzać ukończone loty i poprawiać wynik oraz ocenę gwiazdkową. [Kandydat 1.3.0-rc1 i paczki](VERSION_VERTICAL_1_3_0_RC1.md) · [Kandydat 1.2.0](VERSION_VERTICAL_1_2_0.md) · [Kampania 1.0.0](VERSION_VERTICAL_1_0_0.md)

## Sterowanie

Na telefonie dotknij pola gry i przeciągaj palec. Statek zachowuje odstęp od punktu dotknięcia. Na komputerze można przeciągać lewym przyciskiem myszy lub użyć **WASD** albo **strzałek**. **Esc**, **P** i przycisk w prawym górnym rogu wstrzymują lot.

Broń strzela automatycznie w górę. Rdzenie zwiększają poziom siły ognia, a moduły przełączają Laser Cannon na plazmę, rakiety albo wiązkę. Pole walki zachowuje proporcje 9:16. Na wyższych ekranach dodatkowa przestrzeń rozdziela pole od krawędzi urządzenia.

## Hangar, zapis i sklep

Wybrany statek, ulepszenia i wyposażenie wpływają na kampanię. Hangar i magazyn nagród korzystają z tego samego profilu. Wersja 6 zapisu wczytuje dotychczasowy profil i przechowuje odblokowania, rekordy oraz gwiazdy kampanii. Kolejny numer transakcji i SHA-256 pozwalają wybrać aktualną z dwóch kopii zapisu. Nagroda i wynik poziomu zapisują się w jednej transakcji.

W sześciu zakładkach sklepu znajdziesz pakiety, Crystals, statki i skórki, wyposażenie, bezterminowy Helion i darmowe nagrody. Zakupy w symulatorze oraz ceny testowe są oznaczone. APK debug korzysta z testowego AdMob i wyłączonego okna Google Play Billing. [Ekonomia 1.1](ECONOMY_1_1.md) · [Integracja Androida](ANDROID_INTEGRATION.md)

## Uruchomienie i testy

Otwórz `project.godot` w Godot 4.7.2 stable i naciśnij **F5**, lub użyj poniższych poleceń w katalogu repozytorium.

```sh
godot --headless --editor --import
godot
```

```sh
godot --headless --fixed-fps 60 --script res://tests/chapter_one.gd
godot --headless --fixed-fps 60 --script res://tests/chapter_one.gd -- --balance-chapter
bash tests/run.sh --full-mission
```

Pierwszy test prowadzi pilota przez dziesięć lotów i sprawdza migrację, zapis, nowe jednostki oraz przejścia. Drugi symuluje trzy zestawy wyposażenia w lotach z bossami. Skrypt `tests/chapter_capture.gd` zapisuje klatki, nagranie i pomiary. Skrypt `tests/run.sh` uruchamia regresje wspólnych systemów oraz dziesięciominutową misję Survivor. Scena `res://main.tscn` nadal uruchamia Survivor w Godot. [Archiwum wersji 0.7.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/archive/survivor-0.7.0)

## Eksport Android

Zainstaluj szablony eksportu dokładnie dla Godot 4.7.2 stable. W edytorze ustaw JDK 17 i Android SDK 36. [Instrukcja Google Play i podpis](JAK_OPUBLIKOWAC_GALAXY_STRIKE_GOOGLE_PLAY.md) · [AdMob i Billing](release/google-play/INTEGRATIONS.md)

```sh
bash tools/build_android_rc.sh debug build/android/GalaxyStrike-Vertical.apk
```

Preset `Android` generuje debug APK dla arm64-v8a i x86_64. Aplikacja zachowuje identyfikator `com.galaxystrike.spacesurvivor`. Aktualizacja istniejącej instalacji wymaga zgodnego podpisu. Do równoległego testowania 0.7.x i kampanii użyj oddzielnych profili Android albo urządzeń.

## Projekt

- `vertical/campaign.gd` zawiera poziomy, harmonogram formacji, tempo i nagrody. Trwałe identyfikatory poziomów wiążą kampanię z zapisami.
- `vertical/field.gd`, `squadron.gd`, `ordnance.gd` i `commander.gd` odpowiadają za pole gry, przeciwników, uzbrojenie i bossa. Pociski i eskadry korzystają z puli obiektów.
- `vertical/main.tscn` korzysta ze wspólnej obsługi pauzy, ustawień, hangaru, audio i reklam z `main.gd`. `combat/` zawiera efekty i tryb Survivor.
- `data/pilot_progression.gd`, `data/store/` i `commerce/` przechowują profil, portfel i adaptery usług.
- [Kierunek artystyczny i pochodzenie zasobów](ART_DIRECTION.md) · [Licencje Godot](licenses/Godot-COPYRIGHT.txt) · [Licencje fontów](assets/fonts/README.md)
