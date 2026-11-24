# Google Play Billing · testy wewnętrzne 1.2.0

Wersja 1.2.0 korzysta z Billing 9.1.0, pakietu `com.galaxystrike.spacesurvivor`, kodu 14 i target API 36. Publiczne płatności pozostają wyłączone. APK debug wymusza blokadę zakupu i pusty adres portfela. Natywne okno zakupu wymaga bezdebugowej kompilacji testowej zainstalowanej przez Google Play, flagi licencyjnej oraz autoryzacji z osobnego serwera w trybie testowym.

## Konfiguracja właściciela

1. Użyj tej samej aplikacji w Play Console i sprawdź bieżące zasady target API. Włącz Play App Signing. W razie wykorzystania kodu 14 w Play Console zwiększ kod obu presetów Androida przed kolejnym eksportem. [Wymagania target API](https://support.google.com/googleplay/android-developer/answer/11926878) · [Podpisywanie Androida](https://developer.android.com/studio/publish/app-signing)
2. Dodaj konta do **Testy → Testy wewnętrzne** i do **License testing**. Konto wybrane w Google Play na telefonie musi należeć do obu list. Wyślij testerom link kanału po sprawdzeniu wersji. Link dystrybuuje właściciel na zatwierdzone konta. [Testowanie Google Play Billing](https://developer.android.com/google/play/billing/test)
3. Podłącz pięć istniejących produktów jednorazowych według tabeli. Każdy potrzebuje jednej zwykłej opcji zakupu z ceną i obsługą ilości 1. Gra odczytuje wyłącznie sformatowaną cenę opcji z `ProductDetails`. Konto gracza ma osobne salda Crystals zdobytych w grze i Crystals zakupionych.
4. Dla propozycji włącz ścieżkę tylko po zatwierdzeniu **testowego** katalogu przez właściciela. Włącz `GALAXY_ENABLE_DRAFT_CATALOG=1` w kompilacji i `STRIKE_ENABLE_DRAFT_CATALOG=1` w testowym backendzie. Sprawdź zasięg aktywacji produktów w Play Console przed jakąkolwiek zmianą, ponieważ produkty są przypisane do aplikacji. W domyślnej konfiguracji nowe produkty pozostają zablokowane w Androidzie.
5. Wdróż oddzielną usługę `server/play_server.py` za HTTPS, z własną bazą SQLite, konfiguracją ADC i dostępem Android Publisher API do tej aplikacji. Ustaw `STRIKE_PLAY_MODE=test`, `STRIKE_ENABLE_LICENSE_CHECKOUT=1` i pozostałe zmienne z przewodnika. Wydaj odrębny kod konta każdemu testerowi. Przekaż kod prywatnym kanałem i użyj go w opcji połączenia portfela w sklepie. [Wdrożenie i odtwarzanie portfela](server/WALLET_0_7_PL.md) · [Android Publisher API](https://developers.google.com/android-publisher/getting_started)
6. Podpisz kompilację kluczem przesyłania zarejestrowanym dla tej aplikacji. Wczytaj zmienne od właściciela z menedżera sekretów lub osobistej powłoki. Ustaw wartość `BUNDLETOOL_JAR` na oficjalne narzędzie do weryfikacji pakietu. Trzymaj klucz poza katalogiem repozytorium i poza załącznikami do raportu. [Bundletool](https://developer.android.com/tools/bundletool)

```sh
export GALAXY_PLAY_MODE=test
export GALAXY_ENABLE_LICENSE_CHECKOUT=1
# Ustaw prywatnie zweryfikowany GALAXY_PURCHASE_SERVER, GALAXY_ADMOB_APP_ID,
# GALAXY_PRIVACY_POLICY_URL, BUNDLETOOL_JAR i trzy zmienne GODOT_ANDROID_KEYSTORE_RELEASE_*.
bash tools/build_android_rc.sh play-license /tmp/GalaxyStrike-internal.aab
```

Skrypt porównuje certyfikat AAB z aliasem klucza przesyłania i uruchamia `bundletool validate`, jeśli podano narzędzie. Przed przesłaniem porównaj odcisk z Play Console i wybierz wyłącznie kanał wewnętrzny. **Przed zatwierdzeniem każdego testowego zakupu sprawdź, czy okno Google Play pokazuje testową formę płatności. Jeśli pokazuje zwykłą kartę, zamknij okno i sprawdź konto licencyjne.** Serwer odrzuca potwierdzenia bez kontekstu zakupu testowego.

## Katalog i rozliczenie

| Produkt jednorazowy | Obsługa po potwierdzeniu Publisher API | Dostawa |
| --- | --- | --- |
| `gs_starter_v1` | Acknowledge | 120 Crystals na konto, prawo do Ion oraz jednorazowa dostawa 600 Credits na przypisaną instalację |
| `gs_crystals_100` | Consume | 100 Crystals na konto |
| `gs_crystals_350` | Consume | 350 Crystals na konto |
| `gs_crystals_900` | Consume | 900 Crystals na konto |
| `gs_helion_pass_v1` | Acknowledge | Bezterminowe uprawnienie Helion |
| `gs_arsenal_v1` | Acknowledge w zatwierdzonym katalogu testowym | Dwa moduły z uprawnienia konta |
| `gs_hangar_supply_v1` | Acknowledge w zatwierdzonym katalogu testowym | Jednorazowa dostawa 480 Credits i 140 materiałów na przypisaną instalację |
| `gs_skin_specter_noctis_v1` | Acknowledge w zatwierdzonym katalogu testowym | Uprawnienie do poszycia Spectera |
| `gs_skin_aurora_vesper_v1` | Acknowledge w zatwierdzonym katalogu testowym | Uprawnienie do poszycia Aurory |
| `gs_pilot_fx_prism_v1` | Acknowledge w zatwierdzonym katalogu testowym | Uprawnienie do efektów Prism |

Serwer dopasowuje konto, SKU, jedną sztukę, środowisko testowe i stan zakupionego produktu. Przyznaje walutę i prawo w jednej transakcji, a worker potwierdza albo zużywa zamówienie po zapisie. Portfel odtwarza saldo i uprawnienia po ponownym połączeniu konta. Dodatki do zapisu lokalnego wypłaca jednorazowo przypisanej instalacji. Już wykorzystane dodatki lokalne i przyjęte nagrody Helionu zachowują wcześniejsze zasady. Zwrot zmienia saldo konta i cofa prawo, a ujemne saldo po wydatkach blokuje użycie zakupionych Crystals do czasu rozliczenia.

Sprawdź każdy wiersz tabeli według scenariuszy planu. **NIEURUCHOMIONE** pozostają próby natywnego checkoutu, aktywny katalog w Play Console, wdrożenie testowej bazy i podpisany AAB właściciela. [Testy zakupów i zwrotów](ANDROID_TEST_PLAN_1_2.md) · [Konfiguracja AdMob i UMP](ADMOB_SETUP_PL.md)
