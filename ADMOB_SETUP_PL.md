# AdMob i UMP · Galaxy Strike 1.2.0

## Co zawiera kandydat

Oba warianty testowe używają natywnego Google Mobile Ads 25.5.0 i UMP 4.0.0. APK z GitHub ma przykładowy identyfikator aplikacji `ca-app-pub-3940256099942544~3347511713`. Reklamę Rewarded pobiera z oficjalnej jednostki testowej `ca-app-pub-3940256099942544/5224354917`. Kandydat z własnym App ID wciąż używa tej jednostki. Ekran gry oznacza reklamę jako **Test AdMob**. [Reklamy testowe Google](https://developers.google.com/admob/android/test-ads)

| Wybór gracza | Nagroda |
| --- | --- |
| Darmowe w sklepie | 150 Credits raz dziennie |
| Odzysk materiałów w sklepie lub hangarze | 45 materiałów raz dziennie, ze wspólnym limitem |
| Wygrany lot | Jedno podwojenie podstawowej wypłaty |
| Wygrana z bossem | Jedna dodatkowa wypłata 35 materiałów |
| Utrata kadłuba | Jedno ożywienie z 50% kadłuba podczas danego lotu |

Reklama zaczyna się po dotknięciu przycisku. Nagrodę zatwierdza callback SDK `onUserEarnedReward`, a gra wypłaca ją po zamknięciu reklamy. Błąd, brak połączenia i anulowanie kończą żądanie bez wypłaty. Przejście do tła w trakcie ładowania anuluje żądanie, żeby gotowa reklama nie otworzyła się po powrocie. [Rewarded dla Androida](https://developers.google.com/admob/android/rewarded)

## Konfiguracja formularzy właściciela

1. Dodaj w AdMob aplikację Android z pakietem `com.galaxystrike.spacesurvivor`. Zachowaj **App ID** i wskaż publiczny adres HTTPS polityki prywatności.
2. W **Privacy & messaging** wybierz aplikację i skonfiguruj komunikaty odpowiednie dla jej odbiorców, w tym wymagane w europejskich i amerykańskich regionach obsługiwanych przez UMP. Uzupełnij języki, link do polityki i dostępne wybory. Opublikuj testowaną konfigurację komunikatu dla tej aplikacji i poczekaj, aż AdMob ją udostępni.
3. Przekaż `GALAXY_ADMOB_APP_ID` i `GALAXY_PRIVACY_POLICY_URL` jako zmienne lokalnej kompilacji. W **Settings → Test devices** dodaj telefon, jeśli potrzebujesz wymuszenia regionu. Dla prywatnej kompilacji debug można ustawić `GALAXY_UMP_DEBUG_DEVICE` na hash urządzenia i `GALAXY_UMP_DEBUG_GEOGRAPHY` na `eea`, `us` albo `other`. Testowy hash trzymaj poza repozytorium i dystrybucją publiczną. [Konfiguracja UMP](https://developers.google.com/admob/android/privacy)
4. Zbuduj prywatny APK poleceniem `bash tools/build_android_rc.sh debug /tmp/GalaxyStrike-UMP-debug.apk`. Kod wznawia odczyt zgody po błędzie przejściowym. Żądanie reklamy wymaga wyniku UMP `canRequestAds()`. Przy statusie `REQUIRED` **Ustawienia → Dźwięk → Opcje prywatności reklam** udostępniają zmianę decyzji.
5. Przed przekazaniem AAB testerom sprawdź w Play Console deklarację reklam, zawartość Karty bezpieczeństwa danych i adres polityki prywatności zgodnie z faktyczną konfiguracją. [Zasady przyznawania nagród w AdMob](https://support.google.com/admob/answer/7313578) · [Karta bezpieczeństwa danych](https://support.google.com/googleplay/android-developer/answer/10787469)

## Jak odczytać próbę z telefonu

W **Ustawienia → Diagnostyka** widać SDK, bieżący stan UMP i ostatni stan Rewarded. Decyzję o dopuszczeniu reklam pokazuje `consent_available` albo `consent_blocked`. Warunki dla emisji ograniczonej po wyborze ustala UMP.

Po dotknięciu przycisku sprawdź kolejno `requested`, `loading`, `ready`, `showing`, `earned`, `closed` i `granted`. Na pierwszej próbie pojawia się też `sdk_ready`. `earned` pochodzi z SDK. `granted` oznacza zapis nagrody w grze. Warianty błędów obejmują `unavailable`, `network_error`, `cancelled`, `background` i `timeout`. Eksport w ustawieniach zapisuje raport JSON i otwiera systemowe udostępnianie po wyborze gracza.

Kompilacja debug zapisuje do logcata wyłącznie skrócone kody oraz nazwy miejsc w ramach diagnostyki gry. Do raportu użyj przycisku eksportu lub wyfiltruj wpisy poleceniem `adb logcat | rg 'GalaxyStrikeQA'`. [Scenariusze telefonu](ANDROID_TEST_PLAN_1_2.md)

**Status** · Natywny most jest w skompilowanym APK. Wyświetlanie reklam testowych i scenariusze UMP na rzeczywistym urządzeniu oczekują na wykonanie.
