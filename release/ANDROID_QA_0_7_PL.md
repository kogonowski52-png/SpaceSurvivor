# Galaxy Strike 0.7.0 · testy na telefonie

Podstawowy APK debug ma pakiet `com.galaxystrike.spacesurvivor`, `versionCode` 8, target API 36 i min API 24. Używa przykładowej jednostki Rewarded AdMob. Okno zakupu jest wyłączone. Testy integracji Google Play i pełnej konfiguracji UMP wymagają osobnych kompilacji i uprawnień opisanych poniżej. W środowisku chmurowym sprawdzono plik APK i uruchomiono testy desktopowe. Każdy wiersz tej listy dotyczy rzeczywistego Androida.

## Instalacja i zapis pomiarów

1. Użyj testowego telefonu z włączonym debugowaniem USB. Zapisz model, pamięć RAM, wersję Androida, proporcje i częstotliwość odświeżania. Włącz **Nie przeszkadzać** i zarezerwuj co najmniej 20 minut na nieprzerwaną sesję. Na drugim telefonie sprawdź najwęższy obsługiwany ekran oraz otwór aparatu lub wcięcie.
2. Sprawdź sumę SHA-256 dostarczonego APK. Uruchom `adb devices -l`, a następnie `adb install -r GalaxyStrike-0.7.0-debug.apk`. Gdy system zgłasza różnicę podpisu, użyj osobnego telefonu lub testowego profilu. Usunięcie dotychczasowej aplikacji usuwa jej dane lokalne.
3. Wybierz **Ustawienia → Diagnostyka lotu** i wyrusz na misję. Panel co dwie sekundy pokazuje FPS, liczbę aktywnych przeciwników i pamięć procesu PSS w MiB. `n/d` oznacza brak próbki. Diagnostyka działa w kompilacji debug. Przełącznik dotyczy bieżącego uruchomienia.
4. Zrób zrzuty debug podczas początku, szczytu fali, bossa i ponownego lotu. Zapisz `adb shell dumpsys meminfo com.galaxystrike.spacesurvivor` przed walką, podczas bossa i po powrocie do menu. Do oceny przycięć zbierz klatki w Android Studio System Trace lub Perfetto i porównaj rozrzut czasu klatki. Zmierz też zachowanie z wyłączonym panelem, bez ładowania telefonu. Zapisz warunki, błędy i czas wykonania każdej próby. [Perfetto](https://perfetto.dev/docs/quickstart/android-tracing)

## Scenariusze

| Próba | Przebieg i warunek zaliczenia | Stan na telefonie |
| --- | --- | --- |
| 15 minut nieprzerwanej gry | Graj przez pełną 10-minutową misję, odbierz wynik, od razu rozpocznij następny lot i zbierz 15 minut czasu walki w jednym procesie. Zanotuj FPS, PSS i wrogów oraz przycięcia, temperaturę, wyjścia lub zawieszenia. | NIEPRZETESTOWANE |
| Walka z bossem | Dotrzyj do finału. Wykonaj uniki przed ostrzeganymi wzorcami, zniszcz bossa i odbierz wynik raz. W osobnej próbie przegraj i użyj restartu. | NIEPRZETESTOWANE |
| Menu i hangar | Przejdź pięć razy menu → hangar → wybór statku → ekwipunek → menu. Otwórz sklep, nagrody, skrzynie i ustawienia. Przewiń długie listy oraz sprawdź, czy obszary dotyku omijają wcięcia i paski systemowe. | NIEPRZETESTOWANE |
| Pauza i wznowienie | Użyj pauzy z HUD, systemowego Wstecz, przejścia do tła i blokady ekranu w trakcie walki. Czas misji ma się zatrzymać. Po powrocie wznów świadomie i sprawdź wejście dotykowe. | NIEPRZETESTOWANE |
| Zapis i ponowne uruchomienie | Odbierz nagrodę misji, wyposaż przedmiot, zmień głośność, zakończ przez `adb shell am force-stop com.galaxystrike.spacesurvivor` i uruchom z ikony. Porównaj saldo, wyposażenie, nagrody i ustawienia. Na osobnej instalacji testowej odczytaj starszą kopię po uszkodzeniu najnowszej. | NIEPRZETESTOWANE |
| Rewarded AdMob | Użyj wersji z etykietą **Test AdMob**. Sprawdź bonus dzienny, podwojenie wyniku i ożywienie. Ukończenie reklamy przyznaje każdą nagrodę maksymalnie raz. W próbie z przerwaniem, niedostępną reklamą i bez sieci saldo nie rośnie. | NIEPRZETESTOWANE |
| UMP i prywatność | Na czystych danych odegraj zgodę, odmowę, zmianę decyzji przez **Opcje prywatności reklam** i uruchomienie bez sieci. Porównaj EOG, regulowany stan USA i obszar bez formularza zgodnie z ustawieniami AdMob. Przycisk prywatności ma być dostępny, gdy SDK tego wymaga. | NIEPRZETESTOWANE |
| Test licencyjny Google Play | Użyj konta testera, kompilacji z oddzielnym backendem testowym i metody płatności oznaczonej przez Play jako testowa. Sprawdź sukces, anulowanie, odrzucenie, oczekiwanie, uznanie opóźnionej płatności i ponowne wznowienie. Potwierdź `consume` i `acknowledge` w backendzie oraz jedną wypłatę mimo ponowień. | NIEPRZETESTOWANE |
| Odtworzenie i zwrot | Kup Crystals kartą testową. Połącz drugie urządzenie z tym samym kontem, wydaj Crystals z obydwu urządzeń i porównaj saldo. Powtórz po reinstalacji. Zweryfikuj anulowanie i zwrot/revoke w Play Console, odczyt przez worker i odebranie uprawnienia po synchronizacji. | NIEPRZETESTOWANE |
| Brak internetu | Uruchom grę w trybie samolotowym, rozegraj lot, odbierz nagrodę i wydaj zdobyte lokalnie Crystals. W próbie z kontem odłącz sieć przed zatwierdzeniem wydatku i zaraz po nim. Po połączeniu ponów odczyt salda. Serwer ma rozliczyć jedną skutecznie zapisaną operację, a gra ma dalej działać lokalnie. | NIEPRZETESTOWANE |

Do raportu z urządzenia zapisz identyfikator kompilacji, dokładne kroki, oczekiwany i uzyskany wynik, zrzuty ekranu oraz próbkę logu bez kodów kont, danych zakupowych i identyfikatorów urządzenia. Powtórzony błąd z blokadą wejścia, utratą danych lub różnicą salda powinien wstrzymać szerszą dystrybucję.

## Przygotowanie UMP i Play Billing

- UMP dla aplikacji właściciela wymaga skonfigurowanego App ID, aktywnych komunikatów **Privacy & messaging** i publicznego adresu polityki. Na kompilacji debug przepisz lokalnie 32-znakowy skrót telefonu z komunikatu UMP w Logcat. Przy kolejnej prywatnej kompilacji ustaw `GALAXY_UMP_DEBUG_DEVICE` i `GALAXY_UMP_DEBUG_GEOGRAPHY=eea`, `us` lub `other`. Wyczyść wyłącznie dane osobnej instalacji testowej przed każdym scenariuszem pierwszego uruchomienia. Do kompilacji release debugowa geografia i skrót nie są dołączane. [Testowanie UMP](https://developers.google.com/admob/android/privacy#testing)
- Przygotuj produkty i konta **License testing** oraz wdroż oddzielny portfel 0.7.0. Ustaw trzy zmienne kompilacji licencyjnej i włącz `STRIKE_ENABLE_LICENSE_CHECKOUT=1` wyłącznie na tym backendzie. Rozpocznij od kanału wewnętrznego Google Play lub sideload debug zgodnie z instrukcją Google dla testerów licencyjnych i wymaganiami podpisu. Przed zatwierdzeniem zweryfikuj metodę testową na ekranie Google Play. Jeśli Play pokazuje prawdziwą kartę lub pobranie opłaty, zamknij okno. [Testy Google Play Billing](https://developer.android.com/google/play/billing/test) · [Integracja Android](../ANDROID_INTEGRATION.md) · [Konfiguracja portfela](../server/WALLET_0_7_PL.md)
