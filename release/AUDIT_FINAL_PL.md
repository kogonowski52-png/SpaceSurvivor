# Galaxy Strike · audyt przed wydaniem 0.6.1

**Rekomendacja.** Przekazać APK do testów na telefonach, następnie przygotować wydanie do kanału wewnętrznego podpisane przez właściciela. Publikację produkcyjną wstrzymać. Pakiet audytowy zawiera natywne SDK Google w konfiguracji testowej. Audyt aplikacji na telefonie oraz aktywowanych usług Google pozostaje otwarty.

## Gotowe

- Kandydat **0.6.1**, wersja Android **7**, pakiet `com.galaxystrike.spacesurvivor`, min SDK 24 i target SDK 36. APK ma zweryfikowany podpis debug. Techniczny AAB ma zweryfikowany podpis QA i przechodzi `bundletool validate`. Oba obejmują arm64-v8a i x86_64. Sprawdzono wyrównanie APK oraz segmentów ELF bibliotek do 16 KiB.
- Gra i zapis przechodzą regresję. Brak poprawnych kopii profilu uruchamia tryb tylko do odczytu i zachowuje oba pliki. Uszkodzony pojedynczy slot wciąż pozwala odzyskać starszą poprawną rewizję. Przy uszkodzonym zapisie sklep nie rozpoczyna nowej płatności.
- Przywracanie przez weryfikator odbiera wcześniej zatwierdzoną, nieodebraną dostawę, gdy połączenie z Google Play jest niedostępne. Idempotencja dostawy i zapis profilu pozostają częścią transakcji.
- W ustawieniach jest wejście do publicznej polityki prywatności po skonfigurowaniu jej adresu. UMP zachowuje odrębną akcję zarządzania zgodą. Gradle wymaga publicznego adresu HTTPS przy produkcyjnej konfiguracji Billing lub AdMob.
- Ikona aplikacji 512 × 512, grafika promocyjna 1024 × 500, opisy PL i EN, instrukcja publikacji i projekty dokumentów dotyczących danych. [Karta sklepu](store) · [Dokumenty prywatności](policy) · [Instrukcja publikacji](PUBLICATION_PL.md)

## Testy i dowody

| Obszar | Rzeczywiście wykonana kontrola |
| --- | --- |
| Pełna rozgrywka | Godot headless przeprowadził pełną 600-sekundową misję z obiema klasami bossów, ośmioma typami przeciwników i zapisem zwycięstwa. Sprawdzono sterowanie z klawiatury, symulowany dotyk, naturalną porażkę, karty awansu, restart, przejścia do hangaru i menu. |
| Pauza i ponowne uruchomienie | Regresja sprawdziła ręczną pauzę i wznowienie. Próba w natywnym procesie X11 wywołała zdarzenia utraty i odzyskania fokusu w silniku. Po zewnętrznym sygnale SIGTERM drugi proces odczytał zapisane ulepszenie i uruchomił świeży lot. |
| Długa sesja | Na X11 ukończono pełny lot po 723,3 s czasu ściennego. Wersja odniesienia `312f93e` również ukończyła lot, po 671,9 s. Oba skrypty gry zapisały zwycięstwo oraz 0 nieudanych sprawdzeń, lecz opakowania pomiarowe zakończyły się kodem 1 o nieustalonej przyczynie. Próba SIGTERM i odczytu w oddzielnym procesie zakończyła się poprawnie. |
| Uszkodzenia i migracja zapisu | Sprawdzono odzysk poprzedniego slotu, zachowanie dwóch uszkodzonych plików, schemat nowszej wersji, migrację starszych zapisów oraz odrzucenie transakcji przy błędzie zapisu. |
| Zakupy, reklamy i połączenie | Kontrolowany adapter zasymulował sukces, anulowanie, zakup oczekujący, ponowny callback, błąd sieci i brak nagrody. Test weryfikatora sprawdził odzyskanie dostawy przy niedostępnym Play, a sześć testów Python sprawdziło m.in. przypisanie jednego tokena do dostawy i ponawianie finalizacji. Testy nie kontaktowały się z usługą Google Play w sprawie rzeczywistej transakcji. |
| Budowanie i podpis | Na Godot 4.7.2, JDK 17 i Gradle 8.11.1 utworzono APK i AAB. Sprawdzono manifest, natywne biblioteki Google, podpis, format i sumy SHA-256. AAB testowy nie używa klucza przesyłania właściciela. |
| Licencje | Sprawdzono manifest i zawartość licencyjną APK. Odtworzono pliki audio z autorskiego generatora i porównano fonty z oryginałami. [Audyt zasobów](LICENSE_AUDIT.md) |

Wyrenderowano i sprawdzono **24 kadry na każdą z trzech rozdzielczości** 720 × 1280, 1080 × 1920 i 1080 × 2400. Są to menu, walka, karty, hangar, ekwipunek, statki, sektory, nagrody, skrzynia, warsztat, pauza, wyniki, ustawienia oraz pięć zakładek sklepu i stany transakcji. Cztery dodatkowe klatki 1080 × 1920 pokazują ostrzeżenia i aktywne ataki bossów. Ekrany wyników korzystają z powtarzalnych danych scenariusza. Kadry są renderem uruchomionego Godot. Zestaw testów sprawdza dostępność i położenie głównych przycisków oraz zachowanie w opisanych stanach brzegowych.

Menu i duże podglądy statków zachowują spójność wizualną. Główne działania i ostrzeżenia są rozróżnialne w testowanych kadrach. Gęsty kalendarz i opisy wyposażenia na najniższej rozdzielczości oraz status sklepu przy dolnej krawędzi długiego ekranu wymagają oceny na urządzeniu pod kątem czytelności i obszaru dotyku. Przy niskiej jasności trzeba sprawdzić kontrast ciemnych statków oraz pocisków i telegraphów w ruchu. Ekrany Google Play i formularze UMP nie były dostępne do oceny na urządzeniu.

## Wydajność

W pętli testów kolizji obszar odrzucenia wylicza się raz dla odcinka. Kierunek obrotu przeciwników korzysta z jednego współczynnika na klatkę fizyki. Renderer pomija jednolitą pełnoekranową warstwę pod nieprzezroczystą mgławicą i wykorzystuje przygotowany prostokąt statku. Natychmiastowy restart w tym samym sektorze współdzieli teksturę nieba, co usuwa drugą kopię tekstury 640 × 1080 RGBA8 na przejściu. Dysza wykorzystuje wspólną przygotowaną teksturę. Limity pul pocisków oraz efektów pozostają aktywne.

Pomiary wykonano na linuksowym X11 z OpenGL Compatibility i Mesa llvmpipe. To renderer programowy w chmurze. Pomiary RSS obejmują pamięć procesu i zasoby tego renderera. Pomiary FPS, pamięci i temperatury na telefonie pozostają otwarte. Otwieranie menu w teście jest mierzone od załadowania sceny, a restart obejmuje przygotowanie nowej areny bez czasu startu procesu.

| Próba | Wynik |
| --- | --- |
| 597 próbek FPS z długiego lotu 720 × 1280 | 5. percentyl 3 FPS, mediana 12 FPS, maksimum próbek 22 FPS przy referencyjnym rendererze programowym. |
| Pamięć długiego lotu | 8 próbek z końcowego odcinka 35 s odczytało 280,5 MiB RSS. Systemowy szczyt procesu wyniósł 282,8 MiB. |
| 9 000 testów odcinek–wróg, 62 wrogów | Mediana z trzech uruchomień 172,1 → 170,4 ms. Suma trafień identyczna. Rozrzut pomiarów jest większy od różnicy. |
| Powtórne utworzenie areny w tym samym sektorze | Mediana 1,47 → 0,43 ms w pomiarze headless. Mediany wejścia do menu 455,8 → 449,3 ms, wejścia do pierwszego lotu 45,2 → 46,4 ms. |
| Render kontrolowanej sceny 720 × 1280 | Pojedyncza para 10,95 → 16,03 FPS, p95 czasu klatki 109,3 → 97,4 ms. Stała scena 62 wrogów, 110 pocisków i 10 pierścieni, z wyłączoną aktualizacją fizyki. |

## Co blokuje publikację

1. **Test na urządzeniach.** Brak fizycznego telefonu i dostępu do Play Console w środowisku. Nadal potrzebne są próby sterowania i czytelności na telefonach z różnymi proporcjami oraz wcięciami, testy stabilności i pamięci, odtwarzanie audio oraz pełne przejścia przez natywne okna AdMob, UMP i Billing.
2. **Płatne saldo i zwroty.** Dostarczone Crystals pozostają w lokalnym profilu. Utrata danych między instalacjami powoduje utratę takiego salda, a zwroty nie są automatycznie rozliczane w profilu. Produkcyjny sklep wymaga odtwarzalnego salda i obsługi zwrotów. Dostępność trwałych uprawnień po przywróceniu jest osobnym przypadkiem, uwzględnionym już w kodzie.
3. **Konsola, dane i podpis właściciela.** Wymagane są aktywne produkty i testerzy, opublikowane komunikaty zgody, polityka pod publicznym HTTPS, zatwierdzona deklaracja Data Safety, procedura wniosków o dane, dostęp do portalu i klucz przesyłania.
4. **Polityka Google Play.** Serwery dokumentacji odrzuciły połączenie z chmury odpowiedzią 403. Progi testu zamkniętego i aktualny target SDK sprawdza właściciel we własnej konsoli. Elementem odniesienia dla nowych kont osobistych jest zapis co najmniej 12 testerów przez 14 kolejnych dni. [Instrukcja i oficjalne strony](PUBLICATION_PL.md)

## Pliki do przekazania

| Nazwa | Zastosowanie |
| --- | --- |
| `GalaxyStrike-0.6.1-debug.apk` | Bezpośrednia instalacja testowa na Androidzie |
| `GalaxyStrike-0.6.1-QA-only.aab` | Sprawdzony technicznie pakiet z podpisem audytowym |
| `SHA256SUMS.txt` | Sumy obu pakietów Android |
| `GalaxyStrike-Karta-Sklepu.zip` | Ikona, banner, opisy PL i EN oraz kadry gry |
| `GalaxyStrike-Dowody-Audytu.zip` | Logi regresji, exportu i pomiarów oraz galeria z uruchomionej gry |
| `GalaxyStrike-Projekt.zip` i `GalaxyStrike-Git.bundle` | Źródła i historia Git |
