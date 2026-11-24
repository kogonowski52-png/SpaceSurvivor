# Galaxy Strike · 1.2.0 Android Release Candidate

Wersja bazuje na 1.1.0 z commita `4f3c0e7`. Kampania zachowuje 10 poziomów i trzech bossów. Zapis profilu nadal używa schematu 6, a cztery statki, hangar, uprawnienia, waluty, zakupy w grze i bezterminowy Helion korzystają z dotychczasowych identyfikatorów. Płatności produkcyjne pozostają wyłączone. [Archiwalny APK 1.1.0](https://github.com/kogonowski52-png/SpaceSurvivor/tree/apk-v1.1.0)

## APK DEBUG

Pakiet `com.galaxystrike.spacesurvivor`, wersja **1.2.0**, kod **14**, target **API 36**, min **API 24**, ABI **arm64-v8a** i **x86_64**. Rozmiar **196 995 291 bajtów**. Zweryfikowano podpis v2, CRC archiwum, wyrównanie ZIP i segmentów ELF do 16 KB oraz skompilowane klasy Mobile Ads, UMP i Billing. Godot Linux uruchomił projekt wyjęty z APK. Odcisk klucza debug pokrywa się z wydanym APK 1.1.0. [APK debug](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.2.0/GalaxyStrike-1.2.0-debug.apk)

```text
SHA-256 78c22a343a642314d77f70519b05e81295aa9779013c9ae927c8537ab5587dea
```

Manifest ma testową aplikację Google, pusty adres portfela i blokady zarówno katalogu propozycji, jak i okna Google Play. APK zawiera oba ABI i wspólny projekt Godot. [Plik sumy SHA-256](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.2.0/GalaxyStrike-1.2.0-debug.apk.sha256) · [Zrzuty PNG i logi weryfikacji](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.2.0/GalaxyStrike-1.2.0-evidence.zip)

## GOTOWE I PRZETESTOWANE

| Obszar | Wykonana próba |
| --- | --- |
| Kampania | Skrypt ukończył po kolei 10 lotów w ok. 22 min 42 s zegara gry. Osiągnął wszystkie fazy Asteriona, Vesperona i Nadira. Zapis po otwarciu zachował wyniki i gwiazdy. Próba korzystała z przyspieszonej symulacji. |
| Hangar i zapis | W normalnej scenie dało się wybrać cztery kadłuby. Sprawdzono przejście do warsztatu, magazynu, sklepu i nagród, zakupy lokalne, kosmetyki, Crystals, Helion oraz migrację istniejących profili. |
| Stabilność | Regresja uzbrojenia, przeciwników, wspólnych ekranów i 600 s utrzymanego trybu przeszła bez błędów. Po wymuszonym zakończeniu procesu pionowej kampanii świeży start zachował zapisane ulepszenie i udostępnił nowy lot. Wznowienie po symulowanym przejściu do tła wymagało świadomego powrotu, a gest dotyku został zwolniony. |
| Rewarded | Symulator i test sygnałów granicznych obsłużyły pięć miejsc, błędy, przerwanie, opóźniony i ponowiony callback. Stan wyciszenia przy odtworzeniu i powrocie był poprawny. Androidowa paczka zawiera natywny SDK i oficjalną jednostkę testową. |
| Billing i portfel | 13 testów serwera przeszło z kontrolowanym Publisher API. Macierz 10 SKU pokrywa oczekiwanie, weryfikację, ponowienie, zwrot, rozliczenie, odtworzenie salda i uprawnień. Test Godot sprawdził także brak sieci, lokalną dostawę materiałów, blokady katalogu i ceny pobrane ze spreparowanych ProductDetails. |
| Grafika i diagnostyka | Trzy jakości, niezależne suwaki, limit 30 FPS i oszczędzanie zapisują się razem z dźwiękiem. Mniejszy budżet obejmuje dekoracyjne iskry, gwiazdy i fragmenty. Kadłuby, ostrzeżenia i pociski zachowują swoje zasoby. Raport JSON zadziałał w regresji i odrzucił identyfikator sesji oraz nieznany stan. |

## Przegląd obrazu

Zapisano **66 zrzutów z uruchomionego Godot**. Trzy rozdzielczości 720×1280, 1080×1920 i 1080×2400 obejmują ekran tytułu, atlas, ustawienia, hangar, warsztat, ekwipunek, sklep, Helion, walkę, pauzę i porażkę. Dodatkowe klatki pokazują wszystkie loty, ostrzeżenia trzech bossów i końcowy rozpad Nadira. Próby kadrów bossa korzystają z ustawienia sceny przez skrypt, a pełne walki zweryfikował osobny przebieg kampanii.

Zrzuty pokazują zróżnicowane sylwetki statków, odmienne materiały trzech okrętów i czytelne oznaczenia groźnych pasów. W ustawieniach jasne wypełnienie wyróżnia wybór, a panel diagnostyczny nie zakrywa obszaru, do którego może dolecieć statek. Model wcięcia i pasków przeliczono w testach geometrii. Wyższy ekran zachowuje pełną kartę ustawień oraz przyciski. Najdrobniejsze sygnały w ostrzale Nadira, kolory na ekranie o niskiej jasności i Power-Upy w ruchu wymagają oceny z telefonu. [Galeria](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v1.2.0/GalaxyStrike-1.2.0-gallery.jpg)

## Wydajność · Linux programowy

Renderowanie llvmpipe w X11, 1080×1920, z wyłączoną synchronizacją pionową i limitem FPS na czas pomiaru. Każdy wariant uruchomiono w osobnym procesie. Mierzono odcinki walki z rzeczywistą symulacją pocisków i wejścia sterującego. Odcinki z Nadirem kończą się przy utracie kadłuba, stąd różnice w czasie próby.

| Scena i jakość | Próbka | Średni FPS | P95 klatki | Szczyt pamięci Godot | Przygotowanie lotu |
| --- | ---: | ---: | ---: | ---: | ---: |
| Przesmyk Ognia · Standardowa | 12,00 s | 20,24 | 77,02 ms | 55,3 MiB | 15,0 ms |
| Przesmyk Ognia · Niska | 12,03 s | 25,02 | 59,31 ms | 55,3 MiB | 11,2 ms |
| Nadir · Standardowa | 10,12 s | 21,06 | 68,73 ms | 59,0 MiB | 11,6 ms |
| Nadir · Niska | 9,64 s | 22,10 | 67,72 ms | 58,9 MiB | 10,8 ms |

Przygotowanie widoku menu zajęło 8,8–9,5 ms od wejścia do `_ready`, a szczyt RSS całego procesu wyniósł około 421,9 MiB dla ustawienia Standardowa i 420,6 MiB dla Niska. Wartości RSS obejmują programowy sterownik grafiki. Czasy przygotowania scen mierzą pracę kodu i dodanie widoku do drzewa. Pomiar Android PSS, czasu ładowania od uruchomienia procesu i celu 60 FPS pozostaje otwarty.

## WYMAGA TESTU NA TELEFONIE

Instalacja i aktualizacja z rzeczywistym zapisem 1.1.0, sterowanie dotykowe, zachowanie przy wcięciu, pomiar FPS, PSS i baterii oraz powrót po zablokowaniu ekranu. Pięć natywnych Rewarded, odmowa i zmiana wyboru UMP oraz cały przebieg zakupu licencyjnego w Google Play pozostają **NIEPRZETESTOWANE** na urządzeniu. [Plan testów telefonu](ANDROID_TEST_PLAN_1_2.md)

## WYMAGA KONFIGURACJI WŁAŚCICIELA

APK debug jest dostępny dla testera. Eksport AAB wymaga klucza przesyłania, konta testera licencyjnego, aplikacji AdMob z formularzami UMP, publicznej polityki i osobnego testowego portfela przez HTTPS. Skrypt zatrzymał próbę AAB na braku klucza przesyłania. Wydanie nie zawiera AAB. Pięć propozycji SKU wymaga zatwierdzenia do katalogu testowego i zgodnych flag klienta oraz serwera. [Konfiguracja AdMob](ADMOB_SETUP_PL.md) · [Katalog, backend i podpis](PLAY_BILLING_SETUP_PL.md)

## BLOKUJE PUBLIKACJĘ

Ten kandydat służy do testów urządzeniowych. Przejście na Google Play wymaga podpisania AAB właściciela, walidacji kanału i zaliczenia prób na telefonie. Bezpośrednie odczytanie bieżących stron Google dotyczących target API, UMP i licencji zwróciło HTTP 403 z proxy. Zweryfikowany target paczki to 36. Właściciel potwierdza obowiązujące wymagania i deklaracje w Play Console. Produkcyjnej dystrybucji i płatności nie uruchomiono.

## Odtworzenie prób

```sh
bash tests/run.sh --full-mission
godot --headless --fixed-fps 60 --script res://tests/chapter_one.gd
python3 -m unittest discover -s server -v
godot --resolution 1080x1920 --disable-vsync --audio-driver Dummy --script res://tests/chapter_capture.gd -- --stress-chapter
godot --resolution 1080x1920 --disable-vsync --audio-driver Dummy --script res://tests/chapter_capture.gd -- --stress-chapter --graphics-low
```
