# Jak opublikować Galaxy Strike w Google Play

Zacznij od testu wewnętrznego wersji **1.3.0-rc1**, potem uruchom test zamknięty. Pakiet to `com.galaxystrike.spacesurvivor`. W kodzie repozytorium ostatni użyty versionCode to 14, dlatego kandydat ma **15**. Przed przesłaniem sprawdź najwyższą wartość wykorzystaną na swoim koncie we wszystkich kanałach. Aktualizacja wymaga tej samej nazwy pakietu i zgodnej tożsamości podpisu.

Nazwy stron podano również po angielsku, żeby dało się użyć wyszukiwarki Play Console. Dostępność opcji zależy od roli konta i stanu aplikacji. Próby odczytu aktualnych stron Google 24 listopada 2026 r. zatrzymał HTTP 403 z proxy środowiska. Przed przesłaniem potwierdź target API, wymagania konta i walidację plików w swojej konsoli. Sprawdzony pakiet ma API 36. [Target API](https://support.google.com/googleplay/android-developer/answer/11926878) · [Wymagania testowania kont osobistych](https://support.google.com/googleplay/android-developer/answer/14151465)

## 1. Wejdź do Play Console

1. Otwórz [Google Play Console](https://play.google.com/console/) na koncie właściciela. Jeżeli widzisz kilka kont deweloperskich, wybierz konto, które ma być wydawcą gry.
2. Zakończ zadania weryfikacji tożsamości i kontaktu wyświetlone w panelu. Jeżeli konsola poprosi o weryfikację urządzenia dla nowego konta osobistego, wykonaj ją na zgodnym telefonie z aplikacją Play Console. [Tworzenie konta deweloperskiego](https://support.google.com/googleplay/android-developer/answer/6112435) · [Weryfikacja dostępu do urządzenia](https://support.google.com/googleplay/android-developer/answer/14316361)

## 2. Utwórz aplikację lub użyj istniejącej

1. W **All apps** sprawdź, czy Galaxy Strike jest już zarejestrowana. Jeśli tak, otwórz istniejącą aplikację. Użyj **Create app** tylko przy pierwszym tworzeniu wpisu dla gry.
2. Wprowadź język domyślny **Polski – pl-PL** i nazwę **Galaxy Strike: Próg Helionu**. Wybierz **Game** i **Free**. Przeczytaj i potwierdź dokumenty, których wymaga konsola.
3. Nazwa pakietu pochodzi z AAB. Po wczytaniu sprawdź, czy konsola rozpoznała `com.galaxystrike.spacesurvivor`. Użyj tej aplikacji także w AdMob i integracji Billing. [Tworzenie i konfiguracja aplikacji](https://support.google.com/googleplay/android-developer/answer/9859152)

## 3. Ustaw kategorię i bezpłatne pobranie

1. Otwórz **Store settings** w obszarze **Grow users → Store presence**. Wybierz typ **Game** i kategorię **Action**. Dobierz taką liczbę tagów, jaką dopuszcza konsola, na podstawie faktycznej rozgrywki. Dodaj działający adres e-mail wsparcia i witrynę właściciela.
2. Wyszukaj **App pricing** i sprawdź **Free**. Dostępność płatnych przedmiotów konfiguruje się osobno w katalogu produktów. [Kategorie, tagi i kontakt](https://support.google.com/googleplay/android-developer/answer/9859673) · [Cena aplikacji](https://support.google.com/googleplay/android-developer/answer/6334373)

## 4. Skonfiguruj klucze

**Klucz podpisu aplikacji** zabezpiecza aplikację dostarczaną przez Google. **Klucz przesyłania** podpisuje AAB, który wysyłasz do konsoli. Przy aplikacji istniejącej sprawdź zarejestrowany odcisk klucza przesyłania na stronie **App integrity** i użyj odpowiadającego mu magazynu.

Jeżeli tworzysz pierwszy klucz przesyłania, zainstaluj JDK 17. Utwórz magazyn poza repozytorium. `keytool` poprosi o hasło w terminalu.

```sh
keytool -genkeypair -v -keystore /prywatna/sciezka/galaxy-upload.p12 \
  -storetype PKCS12 -alias galaxy-upload -keyalg RSA -keysize 2048 -validity 10000

keytool -exportcert -rfc -keystore /prywatna/sciezka/galaxy-upload.p12 \
  -alias galaxy-upload -file /prywatna/sciezka/galaxy-upload-cert.pem
```

Przechowuj plik klucza w szyfrowanym magazynie i osobną szyfrowaną kopię zapasową. Hasło trzymaj w menedżerze haseł lub sekretów. Właściciel może przekazać publiczny certyfikat PEM, jeśli konsola o niego poprosi. Magazyn klucza i hasło pozostają prywatne. Na stronie **App integrity** wykonaj konfigurację **Play App Signing** zgodnie z obecnym stanem aplikacji. [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) · [Podpisywanie Androida](https://developer.android.com/studio/publish/app-signing)

## 5. Zbuduj podpisany AAB

1. Zainstaluj Godot 4.7.2 stable z jego szablonami eksportu, JDK 17, Android SDK Platform 36 i Build Tools 36.1.0. W **Editor Settings → Export → Android** wskaż katalogi JDK i SDK. Przygotuj również oficjalną dystrybucję Bundletool.
2. Uzupełnij i opublikuj politykę prywatności zgodnie z krokiem 8. W prywatnej powłoce ustaw dane podpisu. Ścieżki poniżej wskaż do swoich plików.

```sh
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/prywatna/sciezka/galaxy-upload.p12
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=galaxy-upload
read -rsp 'Hasło klucza przesyłania: ' GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
export GALAXY_PRIVACY_POLICY_URL=https://twoja-domena.example/privacy-pl.html
export BUNDLETOOL_JAR=/prywatna/sciezka/bundletool.jar
bash tools/build_android_rc.sh play build/android/GalaxyStrike-1.3.0-rc1-signed.aab
unset GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
```

3. W bezpiecznym wariancie `play` zakup pozostaje wyłączony, nawet jeśli powłoka miała wcześniej ustawioną flagę testu licencyjnego. Skrypt sprawdza podpis i dopasowanie certyfikatu, a z `BUNDLETOOL_JAR` wykonuje też walidację.
4. Porównaj certyfikat z kluczem przesyłania na stronie **App integrity**. Otwórz manifest paczki przez `bundletool dump manifest --bundle=ŚCIEŻKA_DO_AAB --module=base`. Sprawdź pakiet, versionCode, versionName i target SDK. W `bundletool dump config` sprawdź `PAGE_ALIGNMENT_16K`. Gdy Play Console wskazuje wyższe wymaganie target API, przygotuj zgodny SDK, podnieś target w presetach i powtórz walidację. [Obsługa stron 16 KB](https://developer.android.com/guide/practices/page-sizes) · [Bundletool](https://developer.android.com/tools/bundletool)
5. Kandydat niesygnowany w paczce dostawy służy do kontroli struktury i wydobycia testowego APK. Do Play przesyłasz oddzielny AAB podpisany kluczem przesyłania.

## 6. Otwórz wydanie wewnętrzne i prześlij AAB

1. Otwórz **Internal testing** w **Test and release → Testing**. W istniejącym kanale wybierz **Create new release**. Jeżeli konsola prosi o konfigurację podpisu, dokończ ustawienia z kroku 4.
2. Prześlij nowy podpisany AAB. Sprawdź pokazany pakiet, kod i ostrzeżenia. W **Release notes** dodaj treść PL i EN z kart opisów. Przejdź do sprawdzenia podsumowania. [Przygotowanie wydania](https://support.google.com/googleplay/android-developer/answer/9859348)
3. Gdy konsola przyjmie paczkę, otwórz ją w **App bundle explorer**. Sprawdź szczegóły i dostępne urządzenia. Zwróć uwagę na min API 24 (Android 7.0), ARM64 i obsługę 16 KB. Sprawdź wszystkie problemy blokujące widoczne w konsoli.

## 7. Wgraj kartę sklepu

1. Otwórz **Main store listing** w **Grow users → Store presence**. Dla polskiego wpisu użyj [gotowej karty PL](release/google-play/listing-pl.md). Wklej tylko nazwę, krótki opis i pełny opis. Limity przyjęte do przygotowania to 30, 80 i 4000 znaków.
2. W zasobach karty dodaj ikonę `icon-512.png`. Dodaj `pl-PL/feature-1024x500.jpg`. Do pola **Phone screenshots** prześlij osiem plików z `pl-PL/screenshots` w kolejności numerów.
3. Dodaj angielskie tłumaczenie **English (United States), en-US**. Wklej [gotową kartę EN](release/google-play/listing-en.md) i odpowiednie pliki z `en-US`. Opis EN podaje rzeczywisty język polskiego interfejsu gry. Zachowaj tę informację do czasu pełnej lokalizacji.
4. Przejrzyj podgląd karty. Podpisy klatek znajdują się poza obrazem gry. Zachowaj portfolio w [katalogu grafik](release/google-play/assets) i skorzystaj z walidacji przesłanych zasobów. [Specyfikacja ikon, grafiki i zrzutów](https://support.google.com/googleplay/android-developer/answer/9866151)

## 8. Wprowadź politykę, reklamy i ankiety

1. Opublikuj [HTML PL i EN](release/google-play/privacy/) pod dostępnym publicznie HTTPS. Zastąp pola operatora, adres kontaktowy, retencję i sposób obsługi danych. Otwórz URL w prywatnym oknie. Ustaw ten adres w **Privacy policy** w **App content** i w eksporcie Godot.
2. W **App content** wypełnij **Ads** jako **Yes, my app contains ads**. Nagrody są dobrowolne. Sprawdź też formularz **Advertising ID** zgodnie z manifestem, wersją SDK i faktycznym przetwarzaniem.
3. Wypełnij **Data safety** na podstawie [matrycy danych](release/google-play/DATA_SAFETY.md). Uwzględnij Google Mobile Ads i UMP także przy testowych jednostkach. Dodaj zakres Billing i portfela, jeśli jest dostępny w wysyłanej wersji.
4. W **App access** opisz dostęp bez logowania do kampanii. Dane dostępu dla ograniczonego testu portfela wpisuj w konsoli z osobnym kontem, przez prywatne pole. W **Target audience and content** wybierz rzeczywistych odbiorców. W **Content rating** wypełnij ankietę IARC. Gra zawiera fikcyjne walki statków i wybuchy. Wiek ustala ankieta. [Odpowiedzi i zakres zawartości](release/google-play/APP_CONTENT.md) · [App content](https://support.google.com/googleplay/android-developer/answer/9859455) · [Ocena treści](https://support.google.com/googleplay/android-developer/answer/9859655)

## 9. Uruchom test wewnętrzny

1. Na stronie **Internal testing**, w zakładce **Testers**, dodaj listę e-mail lub grupę Google. Każdy tester powinien zaakceptować udział kontem znajdującym się na liście.
2. Zapisz i uruchom wydanie na kanale wewnętrznym zgodnie z podsumowaniem. Po udostępnieniu wybierz link do dołączenia w informacji **How testers join your test**. Wyślij go wybranym testerom wraz z [planem i formularzem błędu](release/google-play/PLAY_TESTING.md).
3. Tester akceptuje udział i instaluje grę z Google Play. APK debug pozostaje dodatkową ścieżką diagnostyczną. Osoba aktualizująca instalację debug do wydania z Google Play powinna użyć oddzielnego urządzenia lub profilu, gdy podpisy się różnią. [Test wewnętrzny i zamknięty](https://support.google.com/googleplay/android-developer/answer/9845334)

## 10. Przejdź do testu zamkniętego

1. Otwórz **Closed testing** w **Test and release → Testing**. Wybierz kanał i dodaj testerów, kraje dostępności oraz wydanie z zatwierdzonym AAB. Po udostępnieniu skopiuj link do dołączenia z karty testerów. Wzór wiadomości jest w [planie dla testerów](release/google-play/PLAY_TESTING.md).
2. Dla kwalifikujących się kont osobistych utworzonych po 13 listopada 2023 r. planuj **co najmniej 12 testerów uczestniczących bez przerwy przez 14 kolejnych dni**. Liczy się potwierdzenie udziału w teście zamkniętym. Sprawdź warunek na **Dashboard** swojego konta przed wyznaczeniem terminu. Zachowaj zapas testerów, przejrzyj ich opinie i dokumentuj poprawki. [Wymóg nowego konta osobistego](https://support.google.com/googleplay/android-developer/answer/14151465)

## 11. Sprawdź raporty i zgłoś wydanie do weryfikacji

1. Otwórz **Pre-launch report** oraz **Android vitals**. Oceń awarie, ANR, dostępność i czytelność. Porównaj wyniki z próbami fizycznymi, planem testów oraz problemami zgłoszonymi przez testerów. [Pre-launch report](https://support.google.com/googleplay/android-developer/answer/9844487) · [Android vitals](https://support.google.com/googleplay/android-developer/answer/9844486)
2. Gdy wymagania konta zostaną spełnione, wybierz **Apply for production** na **Dashboard**, jeśli konsola pokazuje ten krok. Podaj liczbę uczestników, sposób ich testowania, zebrane opinie i wprowadzone poprawki.
3. Po przyznaniu dostępu produkcyjnego właściciel może utworzyć wydanie w **Production**. Przed złożeniem go do przeglądu usuń blokady wskazane w raporcie QA i potwierdź deklaracje, kraje oraz wersję. W **Publishing overview** zobacz listę zmian i użyj **Send changes for review** wtedy, gdy chcesz przekazać je do oceny. Kontrolę terminu można ustawić w **Managed publishing**, jeśli aplikacja i stan konsoli na to pozwalają. [Przesyłanie i zarządzanie publikacją](https://support.google.com/googleplay/android-developer/answer/9859654)

## 12. Prawdziwe reklamy i zakupy później

Najpierw zalicz UMP, pięć dobrowolnych miejsc Rewarded i stabilność Androida z reklamami testowymi. Skonfiguruj własną aplikację AdMob, stronę dewelopera, `app-ads.txt` i weryfikację. Wydanie z prawdziwymi reklamami wymaga osobnej decyzji właściciela i aktualizacji deklaracji.

Zakupy przejdź najpierw z zatwierdzonymi testerami licencyjnymi, oddzielnym backendem i udokumentowanym rozliczaniem. Zweryfikuj ceny, wszystkie SKU, pending, przywracanie i zwroty przed przygotowaniem płatnego wydania. [Przygotowanie AdMob, app-ads.txt i Billing](release/google-play/INTEGRATIONS.md) · [Stan kandydata i blokady](VERSION_VERTICAL_1_3_0_RC1.md)
