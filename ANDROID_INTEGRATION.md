# Galaxy Strike · Android 0.6

Pakiet to **`com.galaxystrike.spacesurvivor`**, zgodny z dotychczasowym APK. Wersja aplikacji to **0.6.0**, kod wersji to **6**, a oba presety Androida ustawiają **target SDK 36** i **min SDK 24**. ABI obejmują arm64-v8a oraz x86_64. Zachowaj ten identyfikator w Google Play Console i AdMob.

## Zweryfikowane wersje

| Komponent | Wersja |
| --- | --- |
| Godot i szablon Android | 4.7.2.stable |
| Gradle / Android Gradle Plugin | 8.11.1 / 8.6.1 |
| Java / Android SDK / Build Tools | JDK 17 / Android 36 / 36.1.0 |
| Google Mobile Ads | 25.5.0 |
| User Messaging Platform | 4.0.0 |
| Google Play Billing | 9.1.0 |

Konfiguracja i wrapper pochodzą z taga Godot 4.7.2. Natywny most korzysta z mechanizmu pluginu v2 i adnotacji `@UsedByGodot`. Wersje SDK Google sprawdzono w aktualnych metadanych Google Maven oraz skompilowano z pobranymi bibliotekami. Przykład Rewarded od Google potwierdza sposób użycia SDK i UMP oraz identyfikatory reklam testowych. [Godot 4.7.2 Android](https://github.com/godotengine/godot/tree/4.7.2-stable/platform/android/java) · [Godot v2](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/platform/android/android_plugin.rst) · [Mobile Ads](https://dl.google.com/dl/android/maven2/com/google/android/gms/play-services-ads/maven-metadata.xml) · [UMP](https://dl.google.com/dl/android/maven2/com/google/android/ump/user-messaging-platform/maven-metadata.xml) · [Billing](https://dl.google.com/dl/android/maven2/com/android/billingclient/billing/maven-metadata.xml) · [Przykład Google Rewarded](https://github.com/googleads/googleads-mobile-android-examples/tree/eac5db1a64ff2858676c98889c275cef926e3ab6/java/admob/RewardedVideoExample)

Wartość 36 jest jawna w obu presetach i została sprawdzona w gotowym APK. Bezpośredni odczyt stron pomocy Google Play w tej chmurze zwracał HTTP 403. Przed pierwszym zgłoszeniem aplikacji sprawdź wymagania obowiązujące w Play Console. [Wymagania poziomu docelowego Google Play](https://support.google.com/googleplay/android-developer/answer/11926878)

## Budowa i instalacja APK

1. Zainstaluj JDK 17, oficjalne szablony eksportowe Godot 4.7.2 stable oraz pakiety Android SDK `platforms;android-36`, `build-tools;36.1.0` i `platform-tools`. Zaakceptuj licencje SDK. W Godot ustaw ścieżki **Editor Settings → Export → Android** do JDK i SDK.
2. W katalogu repozytorium uruchom poniższe polecenia. Skrypt przygotowania korzysta z `android_source.zip` i przypina sumę kontrolną wrappera Gradle. Przy niestandardowej lokalizacji przekaż ścieżkę do archiwum jako argument. Wygenerowany katalog `android/build` pozostaje lokalny.

```sh
bash tools/prepare_android.sh
mkdir -p build/android
godot --headless --editor --import
godot --headless --export-debug Android build/android/GalaxyStrike-Android-debug.apk
adb install -r build/android/GalaxyStrike-Android-debug.apk
```

APK debug i podpis aplikacji z Google Play wykorzystują zwykle inne klucze. Jeśli telefon ma zainstalowaną inną wersję o tym samym pakiecie, Android może odrzucić aktualizację. Do zachowania danych używaj aktualizacji podpisanych tym samym kluczem lub wybierz osobne urządzenie do testów. [Godot i eksport na Androida](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/export/exporting_for_android.rst)

## AdMob i formularze prywatności

- Domyślna kompilacja używa przykładowego ID aplikacji Google `ca-app-pub-3940256099942544~3347511713` oraz oficjalnej jednostki Rewarded `ca-app-pub-3940256099942544/5224354917`. Etykieta **Test AdMob** wskazuje prawdziwe żądanie reklamy testowej. Kompilacja debug zawsze używa testowej jednostki Rewarded.
- We własnym AdMob utwórz aplikację Android o podanej nazwie pakietu i trzy jednostki Rewarded odpowiadające bonusowi dziennemu, podwojeniu wyniku i ożywieniu. Do kompilacji przypisz zmienne `GALAXY_ADMOB_APP_ID`, `GALAXY_ADMOB_REWARDED_BONUS`, `GALAXY_ADMOB_REWARDED_DOUBLE` i `GALAXY_ADMOB_REWARDED_REVIVE`. Podanie własnego App ID wymaga poprawnego ID każdej jednostki.
- W **Privacy & messaging** opublikuj wymagane regionalnie komunikaty i powiąż je z aplikacją. Przy uruchomieniu gry UMP aktualizuje status i pokazuje wymagany formularz. SDK reklam pobiera reklamę dopiero po potwierdzeniu `canRequestAds()`. Przycisk **Opcje prywatności reklam** w ustawieniach otwiera formularz, jeśli status UMP to `REQUIRED`. AdMob służy też do dodania telefonów testowych do konta i sprawdzenia statusów zgód właściwych dla aplikacji.
- Sprawdź wszystkie trzy dobrowolne wejścia. Odbierz nagrodę po ukończeniu reklamy, zamknij kolejną reklamę przed nagrodą i sprawdź tryb bez sieci. Kod przyznaje nagrodę na podstawie sygnału SDK `onUserEarnedReward`, po zamknięciu widoku. Zamknięcie i błąd bez sygnału nagrody nie przyznają wypłaty. W Play Console uzupełnij deklarację reklam i Kartę bezpieczeństwa danych zgodnie z konfiguracją SDK. [Rewarded](https://developers.google.com/admob/android/rewarded) · [Reklamy testowe](https://developers.google.com/admob/android/test-ads) · [UMP](https://developers.google.com/admob/android/privacy)

## Produkty i testy Google Play

Utwórz aktywne **produkty jednorazowe** z pojedynczą zwykłą opcją zakupu. Wyłącz zakup wielu sztuk jednocześnie. Ustal ceny w Google Play Console. Gra pobiera z `ProductDetails` nazwę, token opcji i cenę sformatowaną w walucie sklepu gracza. Niedostępna oferta nie otrzymuje ceny zastępczej.

| Identyfikator | Rozliczenie po stronie serwera |
| --- | --- |
| `gs_starter_v1` | `acknowledge` |
| `gs_crystals_100` | `consume` |
| `gs_crystals_350` | `consume` |
| `gs_crystals_900` | `consume` |
| `gs_helion_pass_v1` | `acknowledge` |

Dodaj konta w **License testing** i udostępnij podpisaną kompilację w kanale wewnętrznym. Na urządzeniu użyj konta testera i sprawdź, czy ekran Google Play pokazuje metodę testową. Użyj wyłącznie karty testowej przy weryfikacji. Sklep pyta o aktualne zakupy przy uruchomieniu i wznowieniu oraz po wybraniu **Przywróć zakupy Google Play**. Płatność oczekująca pozostaje bez wypłaty do potwierdzenia. Przetestuj powodzenie, anulowanie, kartę odrzuconą, kartę testową z opóźnioną płatnością oraz przywrócenie na tym samym koncie po restarcie. [Integracja Billing](https://developer.android.com/google/play/billing/integrate) · [Testowanie Google Play Billing](https://developer.android.com/google/play/billing/test)

## Weryfikator zakupów

Kod referencyjny w `server/` weryfikuje tokeny przez `purchases.productsv2.getproductpurchasev2`. Porównuje pakiet, konto, SKU, typ środowiska, stan `PURCHASED` i jedną sztukę produktu. Kwoty ustala katalog gry. Baza SQLite utrwala pojedyncze rozliczenie powiązane z kontem i instalacją. Po zapisie osobny proces rozliczania wywołuje odpowiednią operację Google i ponawia ją po przejściowym błędzie. Gra zapisuje identyfikator dostawy i nagrodę w jednej rewizji profilu i potwierdza odbiór. Przywrócenie gotowej dostawy działa również, kiedy Play zdążył już zużyć token. Odzyskanie zakupów trwałych przyznaje uprawnienie bez ponownej wypłaty waluty. [API Android Publisher](https://github.com/googleapis/google-api-go-client/blob/main/androidpublisher/v3/androidpublisher-api.json) · [Weryfikator](server/play_server.py)

1. Udostępnij serwis pod HTTPS za własnym reverse proxy. Utwórz konto usługi Google z dostępem do tej aplikacji i operacji zakupowych w Play Console. Skonfiguruj Application Default Credentials na serwerze. Używaj poświadczeń zarządzanych lub pliku poza repozytorium.
2. Utwórz środowisko Python i zainstaluj `server/requirements.txt`. Przechowuj bazę oraz kopie w miejscu z ograniczonym dostępem. Ustaw poniższe zmienne w konfiguracji serwera, a następnie uruchom `python3 server/play_server.py`. Serwis słucha na adresie pętli zwrotnej i domyślnym porcie 8080.
3. W kompilacji Androida ustaw publiczny adres `GALAXY_PURCHASE_SERVER` i `GALAXY_PLAY_MODE=test`. W aplikacji otwórz **Sklep → Oferta → Połącz konto zakupów**. Użyj unikalnego kodu konta wystawionego przez właściciela serwera. Gra zapisuje go w prywatnym obszarze Androida, a zakup wiąże z kontem gry przez `obfuscatedAccountId`. W kolejnym wspieranym wydaniu można wystawiać te sesje z istniejącego systemu logowania.
4. Przed publikacją skonfiguruj osobny adres i bazę dla `STRIKE_PLAY_MODE=live` i zbuduj wydanie z `GALAXY_PLAY_MODE=live`. Debug wymusza środowisko testowe. Serwer testowy akceptuje wyłącznie zakupy licencyjne potwierdzone przez Google. Środowiska mają osobne profile i lokalne sesje. Zapis Androida ze starszych wersji symulatora pozostaje oddzielny.

| Zmienna backendu | Wartość |
| --- | --- |
| `STRIKE_PLAY_DATABASE` | Ścieżka do trwałej, prywatnej bazy SQLite |
| `STRIKE_ACCOUNT_BINDING_KEY` | Stały losowy klucz w postaci co najmniej 32 bajtów zapisanych szesnastkowo |
| `STRIKE_SESSION_DIGESTS` | Mapa JSON skrótów SHA-256 kodów do stałych identyfikatorów kont |
| `STRIKE_PLAY_MODE` | `test` lub `live` |
| `STRIKE_PLAY_PORT` | Lokalny port za reverse proxy, domyślnie 8080 |

Kod sesji może pochodzić z `secrets.token_urlsafe(32)`. Serwer przechowuje jego skrót, a klient otrzymuje indywidualny kod poza repozytorium. Rotując kod, zachowaj identyfikator konta i klucz powiązania, żeby wcześniejsze uprawnienia nadal odpowiadały kontu Google Play.

Waluta gry jest przechowywana w lokalnym profilu po dostarczeniu. Po usunięciu danych na telefonie można odzyskać uprawnienia trwałe z Google Play. Wypłacone pakiety waluty nie są przyznawane ponownie. Przenoszenie salda między instalacjami i automatyczne odwoływanie zwróconych uprawnień wymagają wspólnego portfela po stronie serwera oraz obsługi powiadomień o zwrotach. [Bezpieczeństwo Google Play Billing](https://developer.android.com/google/play/billing/security)

## Podpisany AAB do dystrybucji

Włącz **Play App Signing**. Właściciel aplikacji używa własnego klucza przesyłania zgodnego z aplikacją w Play Console. Ścieżkę do klucza trzymaj poza repozytorium. Przekaż ścieżkę, alias i hasło przez prywatne zmienne środowiskowe lub menedżer sekretów CI, a potem uruchom eksport. [Podpisywanie Androida](https://developer.android.com/studio/publish/app-signing)

```sh
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/prywatna/sciezka/do/klucza.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=alias_klucza_przesylania
read -rs GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
godot --headless --export-release "Android Play AAB" build/android/GalaxyStrike-Play.aab
unset GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
```

Zweryfikuj podpis poleceniem `jarsigner -verify` i porównaj odcisk certyfikatu z kluczem przesyłania w Play Console. Zwiększ `version/code` w obu presetach, jeśli Play Console widziało już numer **6**.

## Testy projektu

```sh
python3 -m unittest discover -s server -v
bash tests/run.sh --full-mission
```

Test serwera korzysta z kontrolowanych odpowiedzi Publisher API. Test Godot weryfikuje obsługę dostawy, błędu zapisu, duplikatu i odtwarzania uprawnienia. Windows i pozostałe systemy stacjonarne nadal korzystają z jawnie oznaczonych symulatorów. Próby reklam, formularzy UMP i transakcji na telefonie wymagają urządzenia oraz konfiguracji kont Google.
