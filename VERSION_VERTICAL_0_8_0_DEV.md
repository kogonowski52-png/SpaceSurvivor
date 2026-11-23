# Galaxy Strike — Próg Helionu 0.8.0-dev

Pierwsza grywalna kampania przebudowy ma trzy poziomy i czternaście fal. Domyślna scena otwiera kampanię. Wydanie ma status testowy. [Gałąź kampanii](https://github.com/kogonowski52-png/SpaceSurvivor/tree/feature/vertical-shooter) · [Archiwum Survivor 0.7.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/archive/survivor-0.7.0)

## Zakres przebudowy

- **Echo pasa** uczy przeciągania, zbierania rdzeni i korzystania z plazmy. **Załamanie Pryzmatu** dodaje spirale, ciężkie formacje, samonaprowadzające się rakiety i wiązkę. **Próg Helionu** kończy się pełnym starciem z Asterionem.
- Sterowanie dotykiem zachowuje odstęp od miejsca przyłożenia palca. Wsparcie komputera obejmuje mysz, strzałki oraz WASD. Statek porusza się w dolnej części pola i strzela w górę. Nowa fala rusza po rozstrzygnięciu poprzedniej przez zestrzelenie lub przelot przeciwników.
- Scout strzela w dół, Razor celuje w pilota, a ciężki Warden rozkłada salwę na trzy tory. Linie, kliny i łuki wchodzą w szyk z górnej krawędzi. Spirale krążą nad polem, a naloty schodzą w strefę pilota.
- Laser Cannon, Plasma Spread, Homing Rockets i Energy Beam mają własne rytmy, wygląd i zachowania. Rangi 1–5 dają 1, 2, 3, 5 i 7 emiterów. Na 6 i 7 dochodzą ogień flankujący, dodatkowy cykl wiązki lub wydłużenie jej emisji. Rdzeń ognia zwiększa rangę, trzy moduły zmieniają broń i zwiększają rangę, a naprawa przywraca do 32% kadłuba.
- Asterion ma trzy fazy. Rozwidloną salwę zapowiadają sygnały na bateriach. Kurtyna szynowa oznacza dwa zagrożone pasy przed rażeniem. Wir nadprzewodzący wypuszcza zakrzywione serie. Każda bateria odpala przed zniszczeniem bossa. Po rozpadzie kadłuba pojawia się wynik.
- Kadłub, silnik, uszkodzenia, tempo ognia, magnetyzm i eskorta korzystają z aktywnego wyposażenia. Moduły wpływające wcześniej na XP zwiększają punkty za zestrzelenia. Kampania zapisuje rekord i ukończenie poziomu razem z nagrodą. Każdy ukończony lot można powtórzyć.

## Repozytorium i zapis

Wersję 0.7.0 utrwalono na gałęzi archiwalnej pod `240fa85`. Przebudowa bazuje na `f44683f` z 0.7.1. Analiza `combat/arena.gd` wykazała powiązanie reżyserii misji, ruchu areny i awansów XP. Pionowe pole ma własną symulację, a wspólny kod dostarcza efekty trafień, silników, wiązki i rozpadu. Scena `res://main.tscn` nadal uruchamia Survivor.

Wspólne `main.gd` podłącza ustawienia, hangar, dźwięk, nagrody i sklep. Rejestr salda, katalog ofert oraz natywny most Android zachowano. W profilu wersji 4 dodano rekordy kampanii. Migracja z wersji 3 zachowuje między innymi waluty, wyposażenie, ulepszenia i skórki. Kontrola identyfikatorów lotów zapobiega powtórnemu rozliczeniu.

Dane poziomów zawierają trwałe identyfikatory, startową rangę, trudność, harmonogram, limit czasu i nagrodę. Wybór lotu pokazuje maksymalnie trzy karty naraz. Dodanie etapów polega na wpisaniu definicji i trwałych kluczy do trasy. Aktualna zawartość obejmuje trzy autorskie poziomy.

Identyfikator APK pozostaje `com.galaxystrike.spacesurvivor`. Zgodnie podpisana aktualizacja może korzystać z dotychczasowych danych. Do porównania z 0.7.x warto zachować osobne urządzenie lub profil Android. Starsza gra wykrywa nowszą wersję zapisu i blokuje jego nadpisanie.

## Referencja i obraz

Google Play i YouTube zwróciły w środowisku HTTP 403. Nagrania i materiałów graficznych źródła nie udało się przeanalizować. Punktem wyjścia do projektu były opisane mechaniki gatunku, a oprawa i układ kampanii są własne. [Google Play](https://play.google.com/store/apps/details?id=com.game.space.shooter2) · [Nagranie wskazane przez użytkownika](https://www.youtube.com/watch?v=K4Xgz4KL1Zg)

Asterion i trzy tła powstały dla tego projektu. Wykorzystano też cztery istniejące kadłuby gracza, trzy warianty kadłubów wrogów, typografię oraz efekty dźwiękowe. Na klatkach z gry sylwetki rozróżnia obrys i proporcje, tła zachowują ciemne pole dla drobnych pocisków, a plansza kurtyny pokazuje szerokość zagrożonych pasów. Przed oceną standardu komercyjnego pozostaje sprawdzenie w ruchu na telefonie, zwłaszcza drobnych podpisów HUD, jasnego tła Helionu oraz czytelności rakiet i pocisków w trzeciej fazie. Power-Upy mają wspólny model rdzenia, różnią się kolorem i podpisem. Poszczególne typy mogłyby otrzymać własne modele. [Kierunek artystyczny i licencje](ART_DIRECTION.md)

## Wyniki testów

| Poziom | Czas symulowanego lotu | Fale | Zestrzelenia | Ranga na końcu | Wynik |
| --- | ---: | ---: | ---: | ---: | ---: |
| Echo pasa | 37,90 s | 4 | 34 | 4 | 4 480 |
| Załamanie Pryzmatu | 45,07 s | 5 | 62 | 5 | 9 950 |
| Próg Helionu | 57,95 s | 5 | 75 | 7 | 19 198 |

- **Godot 4.7.2 stable, Linux, kampania.** Skrypt prowadził pilota przez wejścia klawiatury i kolizje. Ukończył trzy loty przez zwykły przepływ gry. Asterion odpalił trzy wzorce, a wynik wypłacił nagrodę i zapisał rekord. Czasy dotyczą automatycznego pilota i czasu symulacji.
- **Regresja kampanii.** Test sprawdził względne przeciąganie, ruch klawiaturą, ograniczenia pola, trafienia w kadłub pilota i jednostki wroga, wszystkie Power-Upy, liczby emiterów, obrażenia obszarowe, naprowadzanie oraz przebijanie wiązką. Sprawdził również pauzę, restart, śmierć, odmowę ożywienia, migrację v3, odczyt rekordu i nagrody reklamowe w symulacji.
- **Regresja Survivor i portfela.** Dotychczasowe testy Godot sprawdziły uzbrojenie, bossów, progresję, ustawienia i audio, handel oraz rozliczenie portfela. Skryptowany pilot wygrał dziesięciominutową misję Survivor. Dziesięć testów serwera portfela w Pythonie przeszło.
- **Render z Godot.** Zrzuty menu, kampanii, trzech lotów, Power-Upu, faz i zniszczenia Asteriona oraz wyniku mają dokładnie 720×1280, 1080×1920 i 1080×2400 px. Powtarzalna próba renderu ustawia wybrane fale, wyposażenie i HP bossa dla ujęć. Pełna próba kampanii odtwarza te zdarzenia rozgrywką bez ustawiania HP bossa.
- **APK.** Eksport debug przez Godot, Gradle i SDK 36. Statycznie zweryfikowano podpis, wyrównanie 16 KB, CRC, target API 36, min API 24, arm64-v8a, x86_64, skrypty i tekstury nowej kampanii. Zasoby wyciągnięte z APK uruchomiły scenę startową w Godot na Linuksie. Manifest zawiera tryb `test`, wyłączone płatności i pusty adres serwera zakupów.

Artefakt testowy jest dostępny na gałęzi dystrybucyjnej. [Pobierz APK debug](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-vertical-0.8.0-dev/GalaxyStrike-Vertical-0.8.0-dev.apk) · [Suma SHA-256](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-vertical-0.8.0-dev/GalaxyStrike-Vertical-0.8.0-dev.apk.sha256)

Pakiet QA zawiera 36 klatek PNG, porównanie trzech formatów i logi testów. [Podgląd kampanii](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-vertical-0.8.0-dev/Przebieg-kampanii.jpg) · [Pełny pakiet QA](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-vertical-0.8.0-dev/GalaxyStrike-Vertical-Dowody-QA.zip)

### Reprodukcja

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 --script res://tests/vertical_campaign.gd
bash tests/run.sh --full-mission
python3 -m unittest discover -s server -v
```

Próba renderu wymaga aktywnego serwera graficznego. W ostatnich dwóch argumentach podaj tę samą rozdzielczość.

```sh
mkdir -p /tmp/galaxy-strike-captures
godot --resolution 720x1280 --fixed-fps 30 --disable-vsync --audio-driver Dummy \
  --script res://tests/vertical_campaign.gd -- \
  --capture-dir /tmp/galaxy-strike-captures --expect-size 720x1280 --quick-capture
```

### Testy na fizycznym Androidzie

**NIEPRZETESTOWANE.** Instalacja APK, aktualizacja z 0.7.x, dotyk systemowy i krawędzie ekranu, pauzowanie po zminimalizowaniu, zużycie pamięci, FPS, odsłuch w głośniku telefonu, UMP, Rewarded z AdMob i ścieżki Google Play Billing. Próbę urządzenia najlepiej zacząć od pełnego przejścia trzech lotów w trybie samolotowym, a następnie sprawdzić wznawianie z tła i pojawianie się reklam testowych po odzyskaniu sieci. Porównaj czytelność kurtyny i wiązki Asteriona przy typowej jasności ekranu. Wersja jest przeznaczona do testów wewnętrznych.
