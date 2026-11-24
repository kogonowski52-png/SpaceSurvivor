# Galaxy Strike · Rozdział I · 1.0.0

Dziesięć misji i 91 fal na gałęzi pionowej strzelanki. Punkt odniesienia to kompletna wersja 0.9.0 pod `2622f61`. Rozszerzenie rozwija ten sam projekt Godot 4.7.2 stable i ten sam profil pilota. Kod APK pochodzi z `ad1ab24`. [Gałąź kampanii](https://github.com/kogonowski52-png/SpaceSurvivor/tree/feature/vertical-shooter) · [Wersja 0.9.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/apk-v0.9.0) · [Archiwum Survivor 0.7.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/archive/survivor-0.7.0)

**[Pobierz APK debug 1.0.0](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.0.0/GalaxyStrike-1.0.0-debug.apk)** · [SHA-256](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.0.0/GalaxyStrike-1.0.0-debug.apk.sha256) · [Zrzuty i logi QA](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.0.0/GalaxyStrike-1.0.0-QA.zip) · [Nagranie finału](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.0.0/GalaxyStrike-1.0-Nadir.mp4)

## Poziomy i wynik pełnej próby gry

Czasy obejmują całą misję w symulacji Godot. Sterowanie pochodzi z automatycznego pilota w scenie gry. Próba korzystała z fabrycznego Peregrine, zwykłych Power-Upów zbieranych w locie i pojedynczego wejścia do każdego odblokowanego poziomu. Ożywienie było wyłączone.

| Lot | Przebieg | Fale | Czas | Kadłub na końcu |
| --- | --- | ---: | ---: | ---: |
| 01 Echo pasa | Nauka lotu i odbiór pierwszego rdzenia | 10 | 2:13,18 | 83% |
| 02 Załamanie Pryzmatu | Spirale, rakiety i ciężka osłona | 10 | 2:22,82 | 72% |
| 03 Próg Helionu | Eskorta i Asterion w trzech fazach | 10 | 2:37,48 | 87% |
| 04 Wrakowisko Tytana | Dryfujące wraki i ciężkie torpedy | 9 | 2:16,10 | 38% |
| 05 Burza magnetyczna | Wyładowania, pola osłon i skoordynowane grupy | 9 | 2:13,90 | 54% |
| 06 Strażnik Ciemności | Bastion, rozbieralne baterie Vesperona i trzy fazy | 8 | 2:07,08 | 72% |
| 07 Rozpad Gwiazdy | Odłamki, rozbłyski i szybkie naloty flankowe | 9 | 2:11,45 | 72% |
| 08 Mgławica Widm | Maskowanie, łuki ognia i odsłonięcia Phantomów | 9 | 2:09,75 | 41% |
| 09 Przesmyk Ognia | Naloty z obu stron i sekwencja zapłonu | 9 | 2:13,22 | 59% |
| 10 Serce Otchłani | Eskorta, miny, cztery fazy i trzy moduły Nadira | 8 | 2:16,55 | 87% |

**Przeciwnicy.** Interceptor szybko nurkuje i wypuszcza parę pocisków. Shield Carrier przejmuje część obrażeń sąsiednich kadłubów, dopóki wystarcza mu osłony. Bomber wysyła torpedę tworzącą oznaczone pole wybuchu. Phantom maskuje się na krótko, traci namiar rakiet i odsłania się przed salwą. Każda klasa ma własny sprite, wytrzymałość, napęd i rozpad poszycia.

**Bossowie.** Asterion zachowuje rozwidloną salwę, kurtynę i wir. Vesperon używa ruchomych baterii, przecinających szyn i zapowiadanych pól bombowych. Nadir zmienia walkę od szczeliny w kurtynie przez przecinające się ogniska i naprzemienne miny po zaćmienie. Trafione moduły odłączają się od kadłuba i zmniejszają liczbę dostępnych dział. Ostatnia faza każdego bossa wykonuje atak przed zakończeniem walki. Paski pokazują HP i progi, a nowe okręty także liczbę czynnych modułów.

**Atlas.** Cztery sektory połączone trasą, przewijanie, skoki do sektorów, dziesięć ponumerowanych lotów i oznaczenia bossów. Karty mają rekord, ocenę, stan odblokowania i podgląd nagrody. Powtórka jest dostępna od chwili ukończenia. Powrót z pierwszej wygranej do atlasu przewija do nowo odblokowanej karty i podświetla ją. Kolejne poziomy dodaje się przez identyfikatory, definicje i zakresy sektorów w katalogu. [Atlas i bossowie](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v1.0.0/Atlas-i-bossowie.jpg) · [Siedem nowych scenerii](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v1.0.0/Nowe-loty.jpg)

**Zasoby.** Dodano 21 oryginalnych tekstur przygotowanych dla gry. Są to siedem scenerii, atlas, cztery nowe kadłuby, dwa okręty, trzy odłamki i cztery komponenty bojowe. Scenerie mają własną kolorystykę, osobną warstwę paralaksy, gwiazdy i zapowiedzi niebezpieczeństw. Muzyka Pogranicza i sześć sygnałów bitewnych są własnymi nagraniami z procedury syntezy. [Kierunek artystyczny](ART_DIRECTION.md)

## Gwiazdy, ekonomia i migracja

- Pierwsza gwiazda przysługuje za zwycięstwo. Druga wymaga zniszczenia 70% przewidzianych celów. Trzecia wymaga dodatkowo co najmniej 54% kadłuba i braku ożywienia. Profil zachowuje najwyższą ocenę i najwyższy wynik z każdego lotu.
- Za misję wpływają dotychczasowe Credits, materiały i nagrody. Pierwsze ukończenie dodaje premię 100–240 Credits i 23–65 materiałów zależnie od lotu. Pierwsze zwycięstwa nad bossami dają dodatkową skrzynię. Każda wygrana ma też zależną od gwiazdek szansę 15–30% na dodatkową skrzynię. Rozliczenie jest jedną operacją zapisu i jest przypisane do identyfikatora lotu.
- Profil w wersji 5 zachowuje zapisy wersji 4. Dawne zwycięstwa dostają jedną gwiazdę oraz dotychczasowy rekord. Premia pierwszego ukończenia dotyczy etapów, których zapis jeszcze nie oznaczał jako ukończone. Regresja obejmowała waluty, Aurorę, wyposażenie, ulepszenie, skórkę, zakupione uprawnienie i wcześniejsze pokwitowanie.
- Produkcyjne płatności są wyłączone. APK ma tryb testowy, testowy identyfikator AdMob i pusty adres serwera płatności. Sklep, Billing, AdMob i serwerowy rejestr portfela korzystają z dotychczasowej integracji.

## Symulacja balansu bez zakupów

Każda konfiguracja została sprawdzona w samodzielnych pełnych lotach 3, 6 i 10. Sterowanie ma odpowiednio 100, 133 i 167 ms przerwy między decyzjami. W każdej próbie gracz doszedł do wszystkich faz i wygrał bez kontynuacji.

| Wyposażenie | Asterion czas / kadłub | Vesperon czas / kadłub | Nadir czas / kadłub |
| --- | ---: | ---: | ---: |
| Fabryczny Peregrine | 2:36,22 / 73% | 2:07,17 / 72% | 2:15,55 / 51% |
| Aegis, ulepszenia 2/1/2 i trzy zwykłe moduły | 2:32,20 / 86,7% | 2:03,48 / 86,2% | 2:13,58 / 75,8% |
| Specter, ulepszenia 4/4/4 i wyposażenie wysokiej klasy | 2:27,53 / 92,8% | 1:59,43 / 84,4% | 2:10,40 / 92,8% |

## Weryfikacja i dowody

- **Regresja Godot.** Bazowe testy 0.9.0, kampania otwierająca po zmianie silnika, przebieg wszystkich dziesięciu lotów, testy nowych klas, obszarów obrażeń i niezależnie niszczonych modułów. Sprawdzono rozliczenie i powtórkę, zapis gwiazdek, wczytanie profilu w nowej instancji, przejścia, zakup ulepszenia, sklep, nagrody oraz ustawienia. Regresja dawnej sceny Survivor i 10 testów serwerowego portfela też przeszły.
- **Zrzuty.** 72 klatki wyrenderowane w Godot w 720×1280, 1080×1920 i 1080×2400 obejmują atlas, wszystkie loty i trzy walki z bossami. Profile i wybrane momenty faz ustawiono w skrypcie dowodowym, by można było powtórzyć ujęcia. Pełna regresja kampanii odbyła się od pierwszej fali w zwykłym przepływie gry.
- **APK.** Podpis debug, integralność ZIP, wyrównanie 16 KB, wersja `1.0.0` z kodem 12, min API 24, target API 36, arm64-v8a i x86_64. Eksport zawiera wszystkie nowe tekstury, dźwięki i skrypty. Zasoby wyjęte z pliku uruchamiają scenę Godot w Linuksie.
- **Nagranie.** 31,52 s walki z dźwiękiem w 450×800 i 30 kl./s. Ustawiono ostatnią falę Serca Otchłani i rangę 7. Następnie pilot przez zwykłe wejścia przeszedł cztery fazy, zniszczył trzy moduły, pokonał Nadira i odebrał wynik. FFmpeg zweryfikował dekodowanie obrazu i dźwięku. Oceniono klatkę rzeczywistego nagrania w ostatniej fazie.

### Przyspieszenie i pomiary

Silnik ogranicza aktywne eskadry do 36, pociski do 196 w tym 88 przyjaznych, a zagrożenia przestrzenne do 22. Eskadry, pociski, strefy oraz efekty są ponownie wykorzystywane. Pełna próba dziesięciu lotów zaobserwowała maksymalnie 10 aktywnych jednostek i 67 pocisków. W próbach konfiguracji licznik sięgnął 88 pocisków.

Pomiary natywnego okna Godot na Linuksie z Mesa llvmpipe. Scena testowa ustawia ostatnią falę Przesmyku i osobno czwartą fazę Nadira. Pomiar trwa do 12 s po rozgrzewce, a próba Nadira kończy się po jego pokonaniu.

| Scenariusz | Raster | Czas pomiaru | Średnia FPS | 95. percentyl klatki | Pamięć silnika |
| --- | --- | ---: | ---: | ---: | ---: |
| Zapłon przesmyku | 720×1280 | 12,01 s | 57,39 | 28,09 ms | 51,3 MiB |
| Zaćmienie Nadira | 720×1280 | 9,67 s | 56,55 | 26,72 ms | 52,7 MiB |
| Zapłon przesmyku | 1080×2400 | 12,03 s | 24,53 | 52,82 ms | 54,7 MiB |
| Zaćmienie Nadira | 1080×2400 | 9,91 s | 22,91 | 62,27 ms | 58,3 MiB |

Szczytowy RSS całego procesu wraz ze sterownikiem wyniósł 374,9 MiB w 720×1280 i 389,7 MiB w 1080×2400. Renderer programowy pozostał poniżej 60 FPS. Wydajność mobilnego GPU jest osobnym kryterium testu na urządzeniu.

### Odtwarzanie prób

```sh
godot --headless --editor --import
godot --headless --fixed-fps 60 --script res://tests/chapter_one.gd
godot --headless --fixed-fps 60 --script res://tests/chapter_one.gd -- --balance-chapter
bash tests/run.sh --full-mission
python3 -m unittest discover -s server -v

mkdir -p /tmp/galaxy-strike-chapter
godot --resolution 720x1280 --fixed-fps 30 --script res://tests/chapter_capture.gd -- \
  --capture-dir /tmp/galaxy-strike-chapter --expect-size 720x1280 --quick-capture
godot --resolution 720x1280 --disable-vsync --script res://tests/chapter_capture.gd -- --stress-chapter --quick-capture
godot --fixed-fps 30 --write-movie /tmp/galaxy-strike-chapter/nadir.avi \
  --script res://tests/chapter_capture.gd -- --record-live --quick-capture
```

## Plan prób ręcznych na telefonie

1. **Pierwszy kontakt.** Dwie osoby zaczynają na świeżym profilu bez wyposażenia. Grają loty 1–5 po jednym podejściu, a potem powtarzają najtrudniejszy. Zapisujemy czas, utracony kadłub, liczbę nietrafionych Power-Upów i momenty, w których ostrzeżenie zostało odczytane za późno.
2. **Wyzwania.** Osobno sprawdzamy osłonę i torpedę w locie 5, zmianę wysokości przy bombach Vesperona, odsłonięcie Phantoma i szczelinę Nadira. Gracz próbuje raz rozbić boczne moduły, a za drugim razem polega na unikach i atakuje kadłub. Po porażce powinien wrócić do gry jednym przyciskiem. Trzy konfiguracje z tabeli pozwalają porównać tempo i tolerancję błędów.
3. **Profil, sklep i cykl życia.** Na testowym urządzeniu aktualizujemy podpisane 0.9.0 plikiem 1.0.0. Porównujemy saldo, wyposażenie, uprawnienia, rekordy i dostępne sektory. Włączamy i wznawiamy grę z tła podczas lotu. Sprawdzamy tryb samolotowy, restart po wygranej oraz powrót ze sklepu i ustawień. Testy reklam i płatności prowadzimy na właściwych kontach i konfiguracji testowej.
4. **Płynność.** Na średniej klasy Androidzie wykonujemy 15-minutową sesję z pełnym przejściem 6, 9 i 10. Zapisujemy czasy klatek, FPS, rozmiar pamięci, temperaturę i momenty skoków w ostatnich fazach. Sprawdzamy małe pociski na najjaśniejszym tle, widoczność portów i efektów uszkodzeń oraz czytelność przy niskiej jasności.

## Ograniczenia

Fizyczny Android pozostaje **NIEPRZETESTOWANY**. Dotyczy to instalacji, przywrócenia uprawnień na fizycznym urządzeniu, dotyku systemowego, stabilnych 60 FPS, baterii i integracji Google. Pancerze bossów zmieniają wygląd przez warstwy uszkodzeń, oświetlenie i odłączane moduły. Weryfikacja standardu oprawy w ruchu na różnych telefonach oraz ręczne strojenie trudności są częścią planu powyżej.
