# Reklamy i płatności · wdrożenie po stronie właściciela

## Warianty Androida

| Wariant | Komenda eksportu | Reklamy | Zakupy |
| --- | --- | --- | --- |
| APK debug | `bash tools/build_android_rc.sh debug build/android/GalaxyStrike-debug.apk` | Natywne testowe Google i diagnostyka gry | Blokada w manifeście oraz w moście |
| A · bezpieczne testy Play | `bash tools/build_android_rc.sh play build/android/GalaxyStrike-signed.aab` | Natywne testowe Google, UMP, własny App ID opcjonalnie | Niedostępne płatne karty ukryte. Posiadane uprawnienia, zakupy lokalne i nagrody pozostają dostępne. |
| Test licencyjny przed B | `bash tools/build_android_rc.sh play-license build/android/GalaxyStrike-license.aab` | Natywne testowe Google i UMP | Instalacja ze sklepu, prywatny serwer testowy, zgoda serwera i konto licencyjne |
| Kontrola struktury | `bash tools/build_android_rc.sh qa-bundle build/android/GalaxyStrike-unsigned.aab` | Oficjalna jednostka testowa | Blokada. Lokalna walidacja paczki przed podpisem. |
| B · późniejsze wydanie płatne | Po zaliczonych testach oraz osobnym zatwierdzeniu | Zakres zgodny z rzeczywistą konfiguracją operatora | Wymaga oddzielnego zweryfikowanego wdrożenia. Tryb produkcyjny jest zablokowany w 1.3.0-rc1. |

Warianty Play podpisuje właściciel. Do bezpiecznej synchronizacji już rozliczonych praw testowych można podać ten sam HTTPS testowego portfela bez włączania checkoutu. Brak serwera oznacza działanie zapisu lokalnego. Rozlicz oczekujące zamówienia testowe w wariancie licencyjnym przed wyłączeniem jego katalogu.

## AdMob i app-ads.txt

1. W AdMob dodaj aplikację z faktycznym pakietem `com.galaxystrike.spacesurvivor`. Dla testów konfiguracji UMP użyj własnego App ID, formularzy w **Privacy & messaging** i prywatnej konfiguracji telefonu testowego. Kandydat nadal żąda oficjalnej jednostki testowej Google. [Konfiguracja UMP i pięciu miejsc Rewarded](../../ADMOB_SETUP_PL.md)
2. Ustaw prawdziwą witrynę dewelopera w informacjach kontaktowych karty Play. W AdMob skopiuj rekord `app-ads.txt` odpowiadający Twojemu identyfikatorowi wydawcy. Umieść go w pliku `/app-ads.txt` pod domeną witryny. Szablon wskazuje format. Uzupełnij identyfikator zgodny z wpisem skopiowanym z konta. [Szablon](app-ads.txt.template) · [Google app-ads.txt](https://support.google.com/admob/answer/9363762)
3. Otwórz adres z zewnętrznej sieci. Plik powinien być zwracany jako zwykły tekst, bez logowania. Sprawdź witrynę, stan odnajdywania pliku i status aplikacji w obszarze weryfikacji AdMob. Wykonaj weryfikację aplikacji zgodnie z instrukcjami wyświetlonymi na koncie. [Weryfikacja aplikacji](https://support.google.com/admob/answer/14538460)
4. Wykonaj scenariusze zgód z [planu telefonu](../../ANDROID_TEST_PLAN_1_2.md) oraz Rewarded w pięciu miejscach. Są to Credits, materiały, podwojenie wypłaty, premia za bossa i ożywienie. Sprawdź brak automatycznych reklam, pojedynczą wypłatę nagród i działanie offline.
5. Po zgodzie właściciela przygotuj osobny build. Wprowadź prawdziwe wartości za pomocą zmiennych z [przykładu konfiguracji](admob-production.env.example). W 1.3.0-rc1 Gradle dopuszcza tryb testowy i most wymusza oficjalną jednostkę testową. Przed zmianą tej blokady potwierdź status aplikacji, deklaracje reklam, identyfikatora reklamowego, politykę i Data Safety. Włącz emisję produkcyjną dopiero w świadomie zatwierdzonym wydaniu.

## Google Play Billing

1. W **License testing** dodaj zatwierdzone konta z testu wewnętrznego. Włącz tylko zatwierdzone produkty jednorazowe. Nakładka Play wyświetla cenę z ProductDetails dla dostępnej, zwykłej opcji produktu i właściwej waluty.
2. Skonfiguruj testowy portfel i konto. Użyj własnej trwałej bazy SQLite, Publisher API, ADC i HTTPS, oddzielonych od ewentualnej produkcji. Testowy serwer przyjmuje wyłącznie zakupy Play z potwierdzonym kontekstem testowym. [Testowy portfel](../../server/WALLET_0_7_PL.md)
3. Ustaw `GALAXY_ENABLE_LICENSE_CHECKOUT=1` w eksporcie licencyjnym oraz `STRIKE_ENABLE_LICENSE_CHECKOUT=1` w testowym backendzie. Ustaw `GALAXY_PURCHASE_SERVER` na adres tego testowego portfela. Dopiero po akceptacji nowych pięciu SKU włącz obustronne flagi katalogu propozycji. [Wykaz wszystkich SKU i sposób rozliczenia](../../PLAY_BILLING_SETUP_PL.md)
4. Przed potwierdzeniem każdego zakupu upewnij się, że ekran pokazuje metodę testową. Wykonaj po kolei pobranie ProductDetails i ceny, sukces, anulowanie, oczekiwanie, utratę sieci, przywrócenie na drugim urządzeniu, podwójne potwierdzenie i zwrot. Skontroluj consume i acknowledge przy odpowiednich typach. [Testowanie Billing](https://developer.android.com/google/play/billing/test)
5. W przyszłym B wdrożenie wymaga obsługi rzeczywistej tożsamości, bezpiecznego przywrócenia, procesu usuwania konta, zatwierdzonej konfiguracji produkcyjnej i monitorowania zwrotów. Dotychczasowy tryb `live` odrzuca nowe rozliczenia. Skrypt publikacji i kandydat nie aktywują produkcyjnych zakupów.
