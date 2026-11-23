# Galaxy Strike: Space Survivor 0.7.0

**Kandydat do testów na telefonach.** Prace kontynuowano na `main` od `c0c352548c64a7e99a0edc07d47aa7683f0ca691`. Zakres obejmuje dostęp do repozytorium, portfel zakupów, diagnostykę Androida i audyt grafiki. Istniejące misje, hangar i progresja są częścią tej wersji.

## GitHub

Wcześniejsze próby używały adresu repozytorium o nazwie `galaxy-strike-survivor`. Repozytorium przypisane do projektu to `kogonowski52-png/SpaceSurvivor`. `git ls-remote` potwierdził poprawny adres i początkowy brak gałęzi. Po zabezpieczeniu całej lokalnej historii jako `GalaxyStrike-0.6.1-backup.bundle` ustawiono `origin`, sprawdzono próbny push i zapisano `c0c3525` na `main`. Gałąź wydania 0.7.0 kontynuuje tę historię zwykłym fast-forward. Kod publikowano przez działający transport Git, mimo że kontrola niezależnego logowania `gh` zgłosiła nieważne uwierzytelnienie w tej sesji. [Repozytorium i gałąź `main`](https://github.com/kogonowski52-png/SpaceSurvivor/tree/main)

Jeśli dostęp później wygaśnie, właściciel może ponownie połączyć istniejące repozytorium z GitHub w ustawieniach środowiska chmurowego. Na własnej stacji może sprawdzić role repozytorium i relację `origin/main`, a do autoryzacji użyć `gh auth login --hostname github.com --git-protocol https --web` oraz `gh auth setup-git`. Gdy w prywatnej powłoce ustawiono wygasły `GH_TOKEN`, właściciel może go usunąć z otoczenia tego procesu przez `unset GH_TOKEN` przed logowaniem. Jeśli nie ma jeszcze `origin`, używa `git remote add origin` z poniższym adresem. W przypadku ochrony `main` składa PR z gałęzi roboczej w tym samym repozytorium.

```sh
git remote set-url origin https://github.com/kogonowski52-png/SpaceSurvivor.git
git ls-remote --symref origin HEAD refs/heads/main
git fetch origin
git log --left-right --oneline origin/main...HEAD
git push origin main
```

## Zmiany funkcjonalne

- **Zakupione Crystals.** Rejestr SQLite potwierdza tokeny przez Google Play Developer API i przypisuje zakup do stałej tożsamości gracza. Przyznania, wydatki i zwroty mają unikalne zdarzenia. Odtworzenie po reinstalacji wymaga ponownego połączenia tego samego konta. Debet i uprawnienie są zatwierdzane atomowo. Zaplanowany odczyt zwrotów i anulowań cofa wypłatę i właściwe uprawnienia.
- **Brak połączenia.** Płatne saldo wymaga serwera przy wydatku. Gra nadal zapisuje zdobyte Credits i Crystals lokalnie. W sklepie saldo konta i waluta zdobyta występują oddzielnie. Profil 0.6.1 zachowuje dotychczasowe dane. Historyczne lokalne kwoty z już rozliczonych zamówień wymagają uzgodnienia przez właściciela przed ewentualną migracją na konto.
- **Blokada płatności.** APK zawiera most Billing, ale ma wyłączone okno zakupu i pusty adres serwera. Rozliczanie produkcyjne jest zablokowane także po stronie serwera. Konfiguracja licencyjna wymaga odrębnego wdrożenia, uprawnień Play Console i konta testera. [Architektura i wdrożenie](server/WALLET_0_7_PL.md)
- **Android i diagnostyka.** Wersja pakietu to 0.7.0/8 z target API 36. Przełącznik **Ustawienia → Diagnostyka lotu** co dwie sekundy pokazuje FPS, liczbę aktywnych wrogów i pamięć procesu PSS na Androidzie. W desktopowej kompilacji debug panel pokazuje pamięć alokatora Godot. Debug obsługuje oddzielne ustawienia geografii testowej UMP. [Konfiguracja Androida](ANDROID_INTEGRATION.md)
- **Sklep i grafika.** Komunikaty o zakupach i reklamach są teraz pod zakładkami, widoczne niezależnie od przewinięcia. Audyt 313 kadrów wskazuje dalszą pracę nad czytelnością małych przeciwników, priorytetem efektów przy bossie, gęstym ekwipunkiem i kalendarzem. Na telefonie trzeba ocenić animacje, wcięcia i rzeczywistą jasność. [Audyt grafiki i porównanie](release/GRAPHICS_AUDIT_0_7_0.md)

## Rzeczywiście wykonane testy

| Próba | Wynik i materiał |
| --- | --- |
| Python, `python3 -m unittest discover -s server -v` | 10 zaliczonych przypadków. Obejmują HTTP na pętli zwrotnej, kontrolowane odpowiedzi Google, równoległą weryfikację i wydawanie na dwóch instalacjach, ponowienia, przywracanie, saldo po zwrocie, dług, rozdział test/live i finalizację. `qa-server.log` |
| Godot 4.7.2, `bash tests/run.sh --full-mission` | Wszystkie skrypty zakończyły się z kodem 0. Pełna misja osiągnęła 600 s, pokazała wszystkie osiem klas wrogów, rzeczywiście pokonała bossa i przyznała wynik raz. Regresja sprawdziła śmierć, restart, pauzę, klawiaturę i symulowany dotyk, przejścia menu i hangaru, karty awansu, zakup i reklamę w symulatorze, uszkodzone sloty profilu i odtworzenie portfela z kontrolowanego adaptera. `qa-godot.log` |
| 15 minut w jednym procesie, `tests/soak_15.gd` | 905,82 s czasu rzeczywistego i 900,05 s czasu misji. Autopilot rozegrał pierwszy lot, pokonał bossa i rozpoczął drugi przez przycisk restartu. Wynik 0 nieudanych sprawdzeń w Godot headless, przy normalnej prędkości symulacji. `qa-soak-15.log` |
| OpenGL i cykl życia | Natywne sesje w Godot użyły X11 i renderera Compatibility OpenGL z Mesa llvmpipe. Test zasymulował zdarzenia fokusu w silniku. Po zewnętrznym SIGTERM drugi proces wczytał ulepszenie, pominął wypłatę za przerwany lot i uruchomił świeżą arenę. `qa-lifecycle-before.log`, `qa-lifecycle-restart.log` |
| Kadry w 3 rozdzielczościach | Testy kadrów gry i sklepu zaliczyły 720 × 1280, 1080 × 1920 i 1080 × 2400. Dodatkowa próba bossów przy stałym kroku renderowania 20 FPS nie uchwyciła sygnału ataku finałowego bossa. Powtórzenie przy kroku 60 FPS zapisało cztery prawidłowe klatki i przeszło bez błędów. Na telefonie potrzebny jest osobny pomiar FPS. `qa-visual-*.log`, `qa-store-*.log`, `qa-boss-visual*.log` |
| Android, weryfikacja pliku | `apksigner verify` zaakceptował podpis APK v2. `aapt` potwierdził pakiet, wersję, API 36/24 i blokadę zakupów. Zweryfikowano wyrównanie ZIP i segmentów ELF do 16 KiB oraz obecność natywnych klas AdMob, UMP i Billing. Gradle odrzucił włączenie zakupu w trybie `live`. Kontrola manifestów konfiguracji testowej potwierdziła, że testowa geografia UMP trafia wyłącznie do wariantu debug. `qa-apk.txt`, `qa-gradle-license-gate.log`, `qa-gradle-test-manifests.log` |

**Android fizyczny i Google Play — NIEPRZETESTOWANE.** Środowisko nie udostępniało telefonu, Play Console właściciela ani usług AdMob i Publisher dla tej aplikacji. Nie zmierzono FPS, pamięci, temperatury, dotyku ani płynności na urządzeniu. Faktyczne wyświetlenie Rewarded, formularze i decyzje UMP, testowe zakupy, zwroty, reinstalacja z kontem i połączenie z wdrożonym portfelem wymagają prób właściciela. [Pełna macierz kroków na telefonie](release/ANDROID_QA_0_7_PL.md)

## Zweryfikowane pliki

`GalaxyStrike-0.7.0-debug.apk` ma 176 814 534 bajty. Identyfikator `com.galaxystrike.spacesurvivor`, `versionCode` 8, `compileSdk` i `targetSdk` 36, `minSdk` 24, arm64-v8a i x86_64. SHA-256 `7d1f7de41609f25de7ee70422bc6a60320e3f42c501a850ddec4647e563d778a`. Plik, suma kontrolna i pakiet dowodów są w katalogu udostępnionych plików `GalaxyStrike-0.7.0`. APK jest podpisany kluczem debug i przeznaczony do instalacji bezpośredniej. AAB 0.7.0 podpisany kluczem przesyłania właściciela wymaga jego konfiguracji. [Eksport i podpis AAB](ANDROID_INTEGRATION.md#podpisany-aab-do-dystrybucji)

## Decyzja o dystrybucji

Przekaż APK do bezpośrednich testów na telefonie. Po próbie instalacji wykonaj w jednym procesie 15 minut gry z bossem i odczytem diagnostyki, sprawdź powrót z tła, zapis, hangar i brak sieci. Następnie skonfiguruj testowe Rewarded i UMP oraz uruchom oddzielny portfel i testy licencyjne Google Play. Zatwierdź prywatność i zakres danych faktycznie uruchomionych usług przed udostępnieniem pakietu w konsoli. Produkcyjne płatności i publikacja pozostają zablokowane do czasu wdrożenia tożsamości, potwierdzenia zakupów i zwrotów, przejścia scenariuszy na telefonach i oceny grafiki w ruchu. [Macierz testów](release/ANDROID_QA_0_7_PL.md) · [Instrukcja Play Console](release/PUBLICATION_PL.md)
