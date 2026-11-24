# Galaxy Strike — Próg Helionu 0.9.0

Kompilacja testowa pionowej kampanii. Kod bazowy porównania pochodzi z 0.8.0-dev pod `0aa3ab3`. Przebudowa gry i zasobów znajduje się w `5e10cb3`. [Gałąź feature/vertical-shooter](https://github.com/kogonowski52-png/SpaceSurvivor/tree/feature/vertical-shooter) · [Archiwum Survivor 0.7.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/archive/survivor-0.7.0)

**[Pobierz APK debug 0.9.0](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v0.9.0/GalaxyStrike-0.9.0-debug.apk)** · [SHA-256](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v0.9.0/GalaxyStrike-0.9.0-debug.apk.sha256) · [Zrzuty i logi QA](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v0.9.0/GalaxyStrike-0.9.0-QA.zip) · [Nagranie z rozgrywki](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v0.9.0/Rozgrywka-Asterion-0.9.0.mp4)

## Co poprawiono

- **30 ułożonych fal.** Każdy z trzech etapów ma dziesięć fal podzielonych na wejścia eskadr. Linie, kliny, łuki, spirale, naloty i grupy mają rozpisane wejścia, kierunki, odległości i pierwsze salwy. Scout, Razor i Warden różnią się tempem, kątem ataku i przeżywalnością. Pozostałości rozbijanych myśliwców korzystają z małej puli animacji i rozbłysków.
- **Szybszy początek.** Ogień działa od pierwszych klatek, pierwsza formacja jest widoczna przed 1,1 s, a pierwszy rdzeń pojawia się po trafieniach otwierających lub najpóźniej przy 3,9 s symulacji. Rdzeń spada na tor pilota i zbliża się do statku w zasięgu magnetycznym. Przerwy po falach trwają 0,67–0,85 s.
- **Cztery rodzaje uzbrojenia.** Rangi 1–5 uruchamiają 1, 2, 3, 5 i 7 emiterów działa. Ranga 6 dołącza rakiety ze skrzydeł, a ranga 7 dodatkową lub dłuższą emisję wiązki. Kształt salwy, jej cykl, odrzut, dysze oraz pole mocy w HUD pokazują rozwój uzbrojenia. Rakiety mają własny sprite, plazma rozbłysk przy trafieniu, a wiązka rejestrowany punkt kontaktu.
- **Asterion.** Większy kadłub ma ruchome fragmenty baterii, oświetlenie zależne od fazy, spadek blasku pancerza i iskrzenie blisko końca walki. Rozwidlona salwa ma drugi rytm, kurtyna pokazuje dwa zagrożone pasy ze strzałkami, a wir wypuszcza przeciwbieżne zakrzywione pociski. Pasek nad okrętem pokazuje procent HP i progi faz. Zniszczenie wyzwala serię pięciu wybuchów po pierwszym trafieniu kończącym, rozpad poszycia i wynik.
- **Tła.** Przewijana mgławica, oddzielna płaszczyzna planet i trzy prędkości gwiazd tworzą paralaksę. Oświetlenie reaguje na podniesienie rdzenia i rozpad bossa. Korytarz lotu ma ograniczoną jasność i krótkie światła punktowe.

## Ekrany

| Ekran | Stan 0.9.0 |
| --- | --- |
| Menu | Nowa ilustracja Peregrine, postęp kampanii nad dużą akcją startu, osobne przyciski hangaru, sklepu i ustawień. |
| Kampania | Obraz nieba i planety na pełnej szerokości karty, czytelny stan blokady, rekord po przejściu. |
| Hangar | Nowe wnętrze, większa prezentacja aktywnego kadłuba z przejazdem oświetlenia, widoczne miniatury wszystkich czterech statków. |
| Warsztat | Podgląd aktualnego statku i ikon modułów, porównanie przed i po oraz animowany wzrost po zakupie ulepszenia. |
| Ekwipunek | Pięć gniazd w jednym rzędzie, większe ilustracje części w magazynie, działające wyposażenie i zdejmowanie modułów. |
| Walka | Kompaktowy HUD, siedem pól rozwoju broni, osobne podpisy modułów wzmacniających i pasek integralności Asteriona. |
| Wygrana i porażka | Oddzielna hierarchia wyniku i nagród. Każdy ekran umożliwia powtórzenie i powrót do kampanii lub hangaru. Porażka wyróżnia powtórkę jako akcję główną. |

[Porównanie interfejsu](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v0.9.0/Porownanie-interfejsu.jpg) · [Porównanie walki](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v0.9.0/Porownanie-walki.jpg) · [Cztery kadłuby w hangarze](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v0.9.0/Flota-0.9.0.jpg)

## Wymienione zasoby

Do `assets/art/premium/` dodano **24 tekstury** stworzone dla gry. Są tam cztery kadłuby gracza, trzy myśliwce, jeden okręt Asterion, pięć różnych przedmiotów Power-Up, trzy obrazy mgławic, trzy planety, ilustracja menu, wnętrze hangaru, tekstura eksplozji, rozbłysk plazmy i sprite rakiety. Z przezroczystych atlasów wycięto pojedyncze kadłuby i ikony, a alfy zapisano w WebP. Pochodzenie materiałów wcześniejszych i licencje fontów opisuje dokument artystyczny. [Kierunek artystyczny](ART_DIRECTION.md)

## Rzeczywiście uruchomione testy

| Próba kampanii | Czas gry automatycznego pilota | Fale | Zestrzelenia | Ranga finałowa |
| --- | ---: | ---: | ---: | ---: |
| Echo pasa | 2:18,18 | 10 | 185 | 5 |
| Załamanie Pryzmatu | 2:21,12 | 10 | 200 | 7 |
| Próg Helionu | 2:36,73 | 10 | 212 | 7 |

- **Godot 4.7.2 stable, kampania.** Trzy zwycięstwa przez zwykłe wejście gry i symulację kolizji. Sprawdzone przeciągnięcie z kompensacją, drugi palec, mysz, klawiatura, pięć Power-Upów, wszystkie liczby emiterów, kontakt uzbrojenia z celami, trzy baterie bossa, pauza, restart, ekran porażki, przejścia i odczyt wyniku po ponownym wczytaniu profilu. Pokryto migrację v3, zachowanie wyposażenia i ochronę przed podwójną nagrodą.
- **Regresja wspólnych systemów.** Przeszły testy Godot dla uzbrojenia, bossów, progresji, ustawień audio, sklepu i portfela. Pełna misja Survivor w scenie archiwalnego trybu dobiegła do 600 sekund i zakończyła się zwycięstwem. Dziesięć testów Pythona zweryfikowało scenariusze portfela po stronie serwera. Adapter testowy sprawdził reklamową nagrodę i ożywienie. Dodatkowa próba 0.9.0 otworzyła ustawienia, sklep i nagrody oraz wróciła do właściwej zakładki hangaru.
- **Porównania graficzne.** 98 rzeczywistych klatek PNG z dwóch wersji przy 720×1280, 1080×1920 i 1080×2400. W obu wersjach odwiedzono te same ekrany. Dodatkowe ujęcia hangaru w 1080×1920 pokazują cztery statki. Porównanie używa kontrolowanego profilu i wybranych kondycji pola walki, w tym HP bossa, dla powtarzalnych zrzutów. Pełne przejścia kampanii są osobnym testem.
- **Nagranie.** 26,45 s obrazu z Godot w 450×800 przy 30 kl./s. Test rozpoczyna się przy ostatniej fali Helionu z uzbrojeniem przygotowanym do starcia. Następnie pilot manewruje i pokonuje Asteriona przy użyciu rzeczywistych trafień. Po zniszczeniu widać ekran wyniku. Odtwarzanie sprawdzono przez dekoder FFmpeg i kontrolę klatek. Ścieżka audio wyjścia Movie Maker w tym środowisku jest cicha.
- **APK.** Podpis debug, SHA-256, integralność ZIP, wyrównanie do 16 KB, aplikacja `com.galaxystrike.spacesurvivor`, `versionCode 11`, `versionName 0.9.0`, min API 24, target API 36, arm64-v8a i x86_64. APK zawiera 24 nowe tekstury i skompilowane skrypty kampanii. Scena startowa uruchamia się z zasobów wypakowanych z APK w Godot na Linuksie.

### Pomiar renderowania

Pomiar czasu między klatkami przy końcowej fali Helionu i podejściu Asteriona. Około dwóch sekund rozgrzewki i 15 sekund pomiaru w każdej rozdzielczości. Linux, X11 i programowy renderer Mesa llvmpipe. FPS i pamięć dotyczą tego środowiska. Wartość pamięci silnika pochodzi z monitora Godot, a RSS jest maksymalnym użyciem pamięci procesu wraz ze sterownikiem.

| Raster | Średnia FPS | Mediana klatki | 95. percentyl | Pamięć silnika | RSS procesu |
| --- | ---: | ---: | ---: | ---: | ---: |
| 720×1280 | 57,86 | 16,22 ms | 26,45 ms | 48,84 MiB | 304,41 MiB |
| 1080×1920 | 34,28 | 27,22 ms | 40,14 ms | 52,58 MiB | 301,66 MiB |
| 1080×2400 | 30,03 | 31,64 ms | 44,63 ms | 52,58 MiB | 312,93 MiB |

Przy końcowej fali próba objęła do 6 aktywnych przeciwników i 54 pocisków jednocześnie. Programowy renderer pozostał poniżej celu 60 FPS. Wydajność mobilnego GPU i najgęstszych fragmentów kampanii wymaga pomiaru na telefonie.

### Odtwarzanie prób

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 --script res://tests/vertical_campaign.gd
bash tests/run.sh --full-mission
python3 -m unittest discover -s server -v
```

Próby obrazu wymagają aktywnego wyświetlacza. Wartość za `--resolution` i `--expect-size` powinna być taka sama.

```sh
mkdir -p /tmp/galaxy-strike-png
godot --resolution 720x1280 --fixed-fps 30 --disable-vsync --audio-driver Dummy \
  --script res://tests/premium_visual.gd -- --capture-dir /tmp/galaxy-strike-png --expect-size 720x1280 --quick-capture
godot --resolution 720x1280 --disable-vsync --audio-driver Dummy \
  --script res://tests/premium_visual.gd -- --measure-render --quick-capture
godot --fixed-fps 30 --write-movie /tmp/galaxy-strike.avi \
  --script res://tests/premium_visual.gd -- --record-live --quick-capture
```

## Co nadal wymaga weryfikacji przed wydaniem

**NIEPRZETESTOWANE NA TELEFONIE.** Instalacja i aktualizacja ze starszego APK, tempo i czytelność przy typowej jasności, krawędzie i wcięcia ekranu, opóźnienie dotyku, pauza po uśpieniu, FPS, pamięć, obciążenie baterii, reklamy testowe, zgody UMP oraz Google Play Billing. Produkcyjne płatności są wyłączone. Manifest ma tryb `test`, wyłączoną ścieżkę płatności i pusty adres serwera zakupów.

Klatki z PC pokazują wyraźne sylwetki i osobne ikony. W ruchu warto ocenić drobne pociski i napisy HUD na najwęższym telefonie, zwłaszcza w trzeciej fazie Asteriona. Uszkodzenia wykorzystują animowane fragmenty, warstwy oświetlenia i iskry na jednym bazowym kadłubie. Osobne kompletne modele poszycia dla każdej fazy dałyby widoczniejszą zmianę sylwetki. Tempo lotów jest zweryfikowane automatycznym pilotem, a strojenie trudności dla nowych graczy wymaga prób ręcznych. Status to kompilacja do testów Androida.
