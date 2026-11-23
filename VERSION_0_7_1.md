# Galaxy Strike: Space Survivor 0.7.1

**Premium Visual Polish · kompilacja do testów.** Punktem odniesienia jest `240fa85`, wersja 0.7.0, oraz jej audyt. Wersja 0.7.1 aktualizuje prezentację istniejącej gry. Dane progresji, ceny, waluty, weryfikacja zakupów oraz reguły walki korzystają z dotychczasowych systemów. [Audyt 0.7.0](release/GRAPHICS_AUDIT_0_7_0.md) · [Kierunek artystyczny](ART_DIRECTION.md)

## Ocena przed i po

| Obszar | 0.7.0 | 0.7.1 i dalsza ocena |
| --- | --- | --- |
| Scout, Razor i Widmo | Zacienione krawędzie zlewały się z fragmentami mgławicy. | Cienka krawędź o barwie klasy i ciemny podrys tworzą rozróżnialne sylwetki na trzech tłach. Oryginalny kształt, proporcje i pancerz pozostały widoczne. Kontrast przy ruchu i niskiej jasności wymaga oceny na telefonie. |
| Leviathan i zagęszczona walka | Warstwy eskorty, ostrzeżeń, pocisków i pierścieni mocno konkurowały z graczem. | Sylwetka Leviathana i ostrzeżenia mają ustaloną kolejność. Wokół pilota pierścienie i odłamki tracą jasność, a gorąca końcówka wrogiego pocisku utrzymuje sygnał zagrożenia. W scenariuszu z gęstą salwą cały kadłub gracza jest czytelniejszy. Część statków wciąż nachodzi na siebie bezpośrednio pod bossem. |
| Laser i eksplozja | Wiązka korzystała z trzech niemal jednolitych linii. Rozpad bossa opierał się głównie na wraku i pierścieniach. | Atlas daje wiązce ruchomy rdzeń, filament i mały kontakt na pierwszej trafionej jednostce. Obrażenia wciąż przebijają wszystkie cele na torze. Wczesną fazę rozpadu akcentuje krótki rozbłysk w środku kadłuba. |
| Flota i hangar | Zablokowane miniatury były przygaszone. Detale ciemnych kadłubów ginęły na tle hali. | Większe miniatury zachowują widoczny kadłub i warunek odblokowania. Peregrine, Aegis, Specter i Aurora dostali oprawę inspekcyjną, światło odbite na istniejących teksturach i łagodny zawis. Ulepszenia stałe są widoczne pod wyborem statku. Wszystkie cztery kadłuby pochodzą z wcześniejszych etapów. |
| Ekwipunek i modernizacja | Gniazda, opisy i akcje były bardzo blisko siebie. Po zakupie porównanie pokazywało kolejny potencjalny poziom. | Każde gniazdo ma własny wiersz, czytelniejsze opisy i wyższe przyciski. Ekran potwierdza zmianę parametru od starej do nowej wartości. Obramowanie, przyrost paska i odbicie na wyposażeniu akcentują zapisany rezultat. Przy 720p większa typografia wymaga przewinięcia dalszych pozycji magazynu. |
| Crystals, kalendarz i skrzynie | Pakiety różniły się liczbą podobnych glifów. Kalendarz ściskał siedem pól, a zdobyty przedmiot używał małego wiersza. | Zasobnik, kontener i rdzeń mają własne ilustracje i układ na karcie. Kalendarz wyróżnia bieżący dzień i pokazuje pozostałe sześć w dwóch rzędach. Epic i Legendary mają duże ilustracje klasy modułu, etykietę rzadkości, nazwę, efekt i krótki refleks. Ilustracja reprezentuje typ modułu i może się powtarzać między przedmiotami tej samej klasy. |

Do kompozycji użyłem tekstur kadłubów i hali z istniejącego projektu. Zestaw trzech pakietów i pięciu klas modułów to grafiki wygenerowane na potrzeby gry. Brzeg trzech wrogów i mapy światła wypaliłem do tekstur. Rozgrywka nie wymaga dodatkowego przebiegu shaderów dla każdego małego przeciwnika. [Pochodzenie zasobów i generatory](ART_DIRECTION.md#dopracowanie-071)

## Dowody i odtworzenie porównania

`tests/polish_visual.gd` uruchamia tę samą sekwencję na `240fa85` i na nowych źródłach. Rejestruje ruchome UI gry przez rzeczywiste przyciski, cztery statki, modernizację, losowanie Epic i Legendary, trzy produkty oraz różne tła, laser i rozpad Leviathana. Dane misji, ziarna skrzyń i układ zagrożeń są kontrolowane. Walka w zrzutach jest zatrzymana w tej samej fazie do porównania. Pełne przejście walki i zdarzeń bossa sprawdza osobna regresja. Ceny i przepływy sklepu na Linuxie używają oznaczonego symulatora.

Pakiet dowodów zawiera po 18 oryginalnych klatek Godot dla każdej wersji i rozdzielczości, łącznie **54 pary**. Rozdzielczości to **720 × 1280**, **1080 × 1920** i **1080 × 2400**. Plik `GALERIA.html` wybiera rozdzielczość i stan gry. Katalog `porownanie/` zawiera skrócone zestawienia, a `manifest.tsv` przechowuje sumy SHA-256 i rozmiary oryginalnych PNG.

```sh
godot --path . --resolution 720x1280 --fixed-fps 30 --disable-vsync --audio-driver Dummy \
  --script res://tests/polish_visual.gd -- --capture-dir /sciezka/do/zrzutow --expect-size 720x1280 --quick-capture
```

Dla porównania 0.7.0 skopiuj wyłącznie skrypt testu do oddzielnego katalogu zawierającego `git archive 240fa85`. W obu wersjach zaimportuj projekt i uruchom scenariusz dla tych samych rozdzielczości. Wymagany jest natywny ekran lub serwer X11.

## Regresja i Android

- `bash tests/run.sh --full-mission` zakończył się z zerem nieudanych sprawdzeń. Obejmuje uzbrojenie, wszystkie wzorce bossów, hangar, zapis, portfel, pauzę, porażkę i pełną misję 600 s z pokonaniem Leviathana. Dodatkowe sprawdzenie potwierdziło, że rozbłysk lasera wskazuje pierwszy kadłub, a obrażenia obejmują oba cele na torze. Zaliczyło się także 10 testów rozliczeń serwera z kontrolowanymi odpowiedziami Google.
- `tests/soak_15.gd` rozegrał **900,00 s walki w 903,78 s czasu ściennego**, w jednym procesie Godot bez renderowania. Autopilot ukończył pierwszy lot, pokonał bossa i rozpoczął drugi przez restart. Zaliczone z zerem błędów. Końcowe korekty oprawy i podpisów zweryfikowały osobne testy X11 i regresja.
- `tests/release_perf.gd -- --render` zmierzył ten sam statyczny układ 62 jednostek, 110 pocisków i 10 pierścieni w 720 × 1280. Mediana z trzech prób na wersję wyniosła **13,62 → 19,43 FPS**, a mediana p95 czasu klatki **91,79 → 66,87 ms**. Suma kontrolna trafień była taka sama. Próba użyła programowego Mesa llvmpipe. Nie wystarcza do oceny docelowego FPS lub GPU Androida.
- APK debug `GalaxyStrike-0.7.1-debug.apk` ma `versionCode` 9, `minSdk` 24, target API 36 i pakiet `com.galaxystrike.spacesurvivor`. Kontrole podpisu, manifestu, nowych zasobów i wyrównania 16 KiB przeszły. Suma SHA-256 pliku wynosi `e9bc63bc50f1f7c6cca2f86dc8c3de155c7a83a32637f3bea9827c3c806595cf`. Domyślna wersja testowa ma zablokowane okno zakupu i pusty adres weryfikatora. [Integracja Android](ANDROID_INTEGRATION.md)

**Fizyczny Android — NIEPRZETESTOWANE.** Scenariusze na 16:9 i 20:9 wykonano w Godot na Linux/X11. Wydajność, jasność, kolory na rzeczywistym ekranie, dotyk i wcięcia wymagają prób na telefonach. Rewarded, UMP oraz sklep Google Play również wymagają konfiguracji i rzeczywistych prób. Najważniejsza próba przed oceną grafiki na telefonie to atak Leviathana przy niskiej jasności oraz porównanie diagnostyki i obszarów dotyku na dwóch proporcjach ekranu. [Macierz na urządzenie](release/ANDROID_QA_0_7_PL.md)
