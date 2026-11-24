# Galaxy Strike · 1.3.0-rc1 · kandydat Google Play

Wydanie rozwija 1.2.0 z commita `29cd255`. Zachowuje pakiet `com.galaxystrike.spacesurvivor`, 10 misji, trzy starcia z bossami, cztery statki, hangar, sklep i schemat zapisu 6. Kod **15** jest następny po 14 w historii projektu. Potwierdzenie jego dostępności w Play Console wymaga konta właściciela.

## Pliki

| Plik | Stan |
| --- | --- |
| [APK debug](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.3.0-rc1/GalaxyStrike-1.3.0-rc1-debug.apk) | 196 995 967 bajtów. Podpis v2 zweryfikowany. Certyfikat debug zgodny z APK 1.2.0. |
| [Niesygnowany AAB do QA](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.3.0-rc1/GalaxyStrike-1.3.0-rc1-unsigned.aab) | 85 492 020 bajtów. Zweryfikowany przez Bundletool. Do przesłania potrzebny jest osobny AAB podpisany kluczem właściciela. |
| [Komplet materiałów i dowodów QA](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.3.0-rc1/GalaxyStrike-1.3.0-rc1-Play-kit.zip) | Grafiki PL/EN, oryginalne zrzuty PNG, instrukcje, HTML prywatności, deklaracje i logi. |

```text
APK debug SHA-256        b7fb56749ce6738ddd048d49e7374442c11d1c783ab7c718aa4978860a7d6878
AAB do QA SHA-256        ee8ad288e4b89c7b2ebb067663ac01df32e952f1b86b88dd3e2134f497e01abb
```

## Konfiguracja Androida

- Godot 4.7.2, min API 24, target i compile API 36, OpenGL ES 3.0, ABI arm64-v8a i x86_64. Zweryfikowano manifest, CRC i segmenty ELF 16 KiB. Bundletool potwierdził `PAGE_ALIGNMENT_16K` oraz moduł zasobów z dostawą podczas instalacji.
- Z niesygnowanej paczki zbudowano lokalny uniwersalny APK przy pomocy Bundletool i jednorazowego klucza QA. Sprawdzono jego podpis, wyrównanie ZIP 16 KB i start wydobytego projektu Godot w Linux. Próba nie obejmowała uruchomienia na urządzeniu Android ani akceptacji przez Google Play. AAB pozostał niesygnowany.
- W manifeście sprawdzono brak `AD_ID` i trzech opcjonalnych uprawnień AdServices. Pozostają uprawnienia sieciowe, Billing, ochrona odbiornika dynamicznego i uprawnienia zależności do działania w tle. `WAKE_LOCK` i `FOREGROUND_SERVICE` występują m.in. w deklaracji AndroidX WorkManager.
- Paczki zawierają Google Mobile Ads 25.5.0, UMP 4.0.0 i Billing 9.1.0. Testowy AAB nie ma adresu serwera ani aktywnego checkoutu. Płatne karty niedostępnych produktów są ukryte. Znane prawa, nagrody i zakupy za pozyskaną walutę pozostają dostępne. Wydanie release usuwa widok diagnostyki i wpisy debug gry. APK debug zachowuje je na potrzeby prób.
- Wariant `play` buduje podpisany AAB bez checkoutu. Lokalna próba z jednorazowym kluczem potwierdziła podpis i wyłączenie obu odziedziczonych flag licencyjnych. Klucz i próbny pakiet usunięto. `play-license` wymaga podpisu, przydzielonej instalacji ze sklepu, testowego backendu i aktywacji przez właściciela. Produkcja pozostaje zablokowana w tym kandydacie. [Warianty i konfiguracja AdMob/Billing](release/google-play/INTEGRATIONS.md)

## Wykonane próby

| Obszar | Wynik |
| --- | --- |
| Kampania i walka | Regresja przeszła 10 lotów i wszystkie fazy trzech bossów. Osobny pełny przebieg z aktywnym rendererem dostarczył źródłowe klatki do karty Google Play. |
| Dotyk, pauza i restart | Godot sprawdził wprowadzanie zdarzeń dotykowych, przerwanie i wznowienie, ponowienie lotu, wygraną i porażkę. |
| Aktualizacja i zapis | Proces na kodzie 1.2.0 zapisał profil pod ścieżką Android debug. Proces 1.3.0-rc1 odczytał identyczne salda, rekordy, wyposażenie, ulepszenia, pokwitowania i prawo Helion po normalizacji zapisu. Podpisy dwóch APK debug mają ten sam odcisk. |
| Sklep i offline | Udane scenariusze zakupów lokalnych, odtworzenia praw, przejściowej niedostępności serwera, wymuszonych błędów reklam i pojedynczych wypłat. Sprawdzono ukrycie płatnych produktów w wariancie A, mimo obecności zapisanej ceny. |
| Portfel | 13 testów przeszło z kontrolowanymi odpowiedziami Publisher API. Pokryto stany pending, rozliczenie, zwroty, powtórzenia, synchronizację, zakup testowy oraz dziesięć SKU w macierzy backendu. |
| Zrzuty i porównanie | 37 źródłowych PNG z Godot. Zestawy przy 720×1280 i 1080×2400 oraz pełna sesja karty w 1080×1920. Sprawdzono obraz bez modyfikacji stanu walk w przebiegu karty. |
| Materiały Google Play | 512×512 RGBA, dwa obrazy 1024×500 RGB, po osiem zdjęć telefonu plus zrzut alternatywny w PL i EN. Długości tytułu / skrótu / opisu / informacji o wersji to PL 27 / 74 / 1172 / 183 i EN 26 / 75 / 1145 / 176 znaków. |

### Pomiar na programowym Linux

W 1080×1920, przy jakości Standardowa, llvmpipe i wyłączonej synchronizacji pionowej. To pomiar wydajności środowiska X11.

| Fragment | Próbka | FPS | P95 | Szczyt pamięci Godot | Przygotowanie sceny |
| --- | ---: | ---: | ---: | ---: | ---: |
| Przesmyk Ognia | 12,03 s | 25,60 | 53,85 ms | 55,4 MiB | 15,2 ms |
| Nadir | 10,03 s | 23,32 | 55,70 ms | 59,0 MiB | 9,8 ms |

Proces osiągnął około 424,6 MiB RSS z programowym rendererem. Menu przygotowało się w 9,9 ms od rozpoczęcia `_ready`. Wyniki nie określają wydajności na telefonie. Pomiar FPS, pamięci Android PSS i zużycia energii pozostaje do wykonania na urządzeniu.

## Karta, zasady i blokady

- Karta PL zachowuje nazwę „Galaxy Strike: Próg Helionu”. EN używa „Galaxy Strike: Helion Gate” jako proponowanego tłumaczenia marketingowego i podaje polski język interfejsu. Ogólna nazwa „Galaxy Strike: Space Shooter” mieści się w limicie, a wyróżnik Helion nawiązuje do projektu. Wyszukania Google Play, App Store i TMview zwróciły blokadę HTTP 403 w środowisku. Status kolizji nazwy i znaków to **NIEZWERYFIKOWANE**.
- 24 listopada 2026 r. próbowano otworzyć oficjalne zasady target API, zasobów karty, wymogów testu zamkniętego i deklaracji SDK. Proxy zwróciło HTTP 403. Log jest w paczce dowodowej. Walidacja techniczna dotyczy API 36 i faktycznie zbudowanego pliku. Operator potwierdza bieżące wymagania w Play Console. Dla odpowiednich nowych kont osobistych plan obejmuje co najmniej 12 zapisanych testerów przez 14 kolejnych dni.
- **Blokada testów Play** · brak klucza przesyłania właściciela, podpisanego AAB i publicznej polityki uzupełnionej prawdziwymi danymi. Preflight podpisu zatrzymał się na braku `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`.
- **Blokada produkcji** · brak fizycznych prób Androida, weryfikacji konsoli i gotowych deklaracji właściciela. Konfiguracja własnego UMP, AdMob, app-ads.txt, test licencyjny i produkcyjny portfel pozostają nieuruchomione.

Kandydat nadaje się do rozpoczęcia testów APK i do przygotowania zamkniętych kanałów po podpisaniu oraz konfiguracji w konsoli. Publikacja produkcyjna wymaga zamknięcia zgłoszonych blokad i osobnej decyzji właściciela.

[Instrukcja publikacji](JAK_OPUBLIKOWAC_GALAXY_STRIKE_GOOGLE_PLAY.md) · [Karta PL](release/google-play/listing-pl.md) · [Karta EN](release/google-play/listing-en.md) · [Grafiki](release/google-play/assets) · [Testy i formularz błędu](release/google-play/PLAY_TESTING.md) · [Polityka i Data Safety](release/google-play/DATA_SAFETY.md)
