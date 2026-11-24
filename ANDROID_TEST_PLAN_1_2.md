# Plan testów na telefonie · Galaxy Strike 1.2.0

**Status sprzętowy** · poniższe próby są **NIEPRZETESTOWANE**. W chmurze wykonano próby Godot, serwera i paczki Android. Do prób licencyjnych potrzebny jest podpisany wewnętrzny AAB i konto właściciela z konfiguracją testową.

## APK debug na telefonie

| Próba | Czynności | Oczekiwany wynik |
| --- | --- | --- |
| Instalacja i aktualizacja | Sprawdź wersję 1.2.0 i sumę APK. Na dodatkowym profilu Android zainstaluj APK 1.1.0, wygraj pierwszy lot, zmień statek i wykonaj ulepszenie. Zaktualizuj przez `adb install -r GalaxyStrike-1.2.0-debug.apk`. | Zgodny podpis umożliwia aktualizację. Stan statku, wynik, gwiazdki i salda pozostają dostępne. Inny podpis wymaga dodatkowego profilu lub telefonu, żeby zachować istniejące dane. |
| Pierwsze uruchomienie | Uruchom aplikację od zera. Obejrzyj ekran tytułu, atlas, hangar, warsztat, ekwipunek, sklep, Helion i ustawienia. Otwórz wszystkie zakładki. | Nawigacja działa. Nagłówki, CTA i salda mieszczą się przy aparacie, gestach i paskach systemowych. |
| 10 poziomów | Na czystym zapisie ukończ kolejno Echo pasa, Załamanie Pryzmatu, Próg Helionu, Wrakowisko Tytana, Burzę magnetyczną, Strażnika Ciemności, Rozpad Gwiazdy, Mgławicę Widm, Przesmyk Ognia i Serce Otchłani. Powtórz jeden etap. | Kolejne loty odblokowują się po zwycięstwach. Gwiazdy i wyniki są zapisane. Widać wszystkie fazy Asteriona, Vesperona i Nadira. Powtórka wypłaca tylko podstawową nagrodę i ewentualny odzysk. |
| Sterowanie | Dotykaj z lewej i prawej strony statku, przeciągaj jednym palcem, zwolnij i rozpocznij następny gest. Wznów po Home przy wciąż trzymanym poprzednim palcu. | Statek zachowuje przesunięcie dotyku. Stare przechwycenie jest zwalniane, a lot czeka na świadome wznowienie. |
| Obraz i wydajność | Włącz panel w **Ustawienia → Diagnostyka**. Na bossach 3, 6 i 10 porównaj Standardową, Niską i Wysoką jakość. Wykonaj 15 minut mieszanej gry, w tym powtórki i pauzę. Zapisz osobny raport dla każdego ustawienia. | Sprawdź P95 czasu klatki, średni FPS, Android PSS i czas budowy sceny. Docelowo około 16,7 ms na klatkę przy 60 FPS. Limit 30 i oszczędzanie energii powinny działać bez zmiany sterowania i prędkości walki. |
| Czytelność w walce | Przy jasności około połowy sprawdź różne kadłuby, szwy osłony, pociski w tle magnesu, Power-Upy oraz ostrzeżenia laserowe i obszarowe bossa. Włącz gesty systemowe, a potem nawigację trzema przyciskami. | W obu układach ekranowych ostrzeżenia i HUD są dostępne. Efekty nie zasłaniają wrogiej salwy. Dotyk działa przy bezpiecznych krawędziach. |
| Pauza, tło i restart | Pauzuj w bezpiecznym momencie i w trakcie wzorca bossa. Przejdź Home, zablokuj ekran na 30 sekund, wróć. Po wypłacie nagrody zabij proces i otwórz aplikację ponownie. | Wznowienie zachowuje świadomą pauzę i głośność ustawioną uprzednio. Przerwany lot nie dopisuje fikcyjnej nagrody. Zakończony lot i ustawienia wracają po starcie. |
| Brak sieci | Ustaw tryb samolotowy na ekranie menu, w trakcie lotu i przed prośbą o reklamę. Spróbuj odebrać nagrody lokalne i wykonać zakup za Credits. | Walka, hangar i zapisy nadal działają. Natywna reklama kończy żądanie czytelnym stanem i można dalej grać. |

## Rewarded i UMP

1. Otwórz pięć miejsc Rewarded opisanych w konfiguracji AdMob. Na każdym obejrzyj jedną pełną reklamę testową i jedną przerwij, jeśli format to pozwoli. Sprawdź status i saldo przed reklamą i po niej. Pokonaj bossa i odbierz jego premię przed podwojeniem lotu.
2. Przejdź do tła, gdy reklama nadal się ładuje. Po powrocie sprawdź brak spóźnionego otwarcia. Podczas wyświetlanej reklamy dźwięk gry powinien być wyciszony. Po zamknięciu i powrocie aplikacji sterowanie i poprzednie poziomy głośności działają ponownie.
3. Na oddzielnej instalacji przetestuj pierwszy start z wymuszonym EEA i regulowanym stanem USA oraz start offline. Sprawdź wymaganą planszę, odmowę, zmianę decyzji w opcjach prywatności i wznowienie po powrocie z tła. Gdy UMP blokuje żądania, status nie powinien przechodzić do `loading`. Gdy UMP pozwala żądać reklam, właściwy rezultat zależy od konfiguracji konsoli i dostępności reklamy.
4. Zapisz w raporcie status SDK, UMP, miejsce, wypłatę i wynik. Eksport w ustawieniach przygotowuje JSON bez identyfikatorów sesji reklamowych, kont i zakupów. [Przygotowanie AdMob i UMP](ADMOB_SETUP_PL.md)

## Wewnętrzny Google Play

Dla każdego z dostępnych SKU wykonaj poniższą sekwencję zaczynając od czystego konta testowego lub potwierdzonego zwrotu wcześniejszego zakupu. Pięć propozycji wykonaj dopiero po dopuszczeniu katalogu testowego. Używaj testowych metod płatności Google Play.

1. Sprawdź dane ProductDetails i walutę na co najmniej dwóch zatwierdzonych kontach w różnych lokalizacjach. Potem odłącz sieć i odtwórz zachowanie sklepu.
2. Otwórz okno i anuluj. Wykonaj zakup metodą sukcesu, odrzuconą kartą testową oraz metodą oczekującą. Sprawdź brak wypłaty w trakcie oczekiwania i pojedynczą wypłatę po potwierdzeniu.
3. Zamknij grę po potwierdzeniu i przed odświeżeniem. Po powrocie uruchom przywrócenie dwa razy. Skontroluj stan consume albo acknowledge po stronie Play i stan portfela. Na odrębnej instalacji połącz to samo konto i potwierdź odtworzenie salda i trwałych praw.
4. Prowadząc jedną próbę na dwóch urządzeniach, wydaj saldo i wyślij równoczesne żądania na dwa różne przedmioty. Kupione Crystals nie powinny być wydawane offline, a odzyskane połączenie powinno zsynchronizować pojedynczy koszt.
5. Wykonaj zwrot lub cofnięcie z Play Console. Sprawdź skorygowane saldo, ewentualny dług, cofnięcie uprawnienia i ponowne odczytanie zwrotu bez dodatkowego obciążenia.
6. Zapisz wynik jako zaliczony lub niezaliczony per SKU i scenariusz. Nie przekazuj numerów zamówień, tokenów ani kodów testowych w raporcie eksportowanym z gry. [Katalog i konfiguracja licencyjna](PLAY_BILLING_SETUP_PL.md)

## Lista otwarta

- Rzeczywista instalacja lub aktualizacja Androida, rozgrywka dotykowa, wcięcia, sterowanie i przerwanie przez system.
- Pomiar GPU, czasu klatek, PSS i czasu ładowania na telefonie.
- Pięć natywnych Rewarded w sukcesie, zamknięciu, bez sieci i przy powrocie z tła.
- UMP przy pierwszym uruchomieniu, braku sieci, zmianie decyzji i powrocie z tła.
- ProductDetails i ceny lokalne, zakup, błąd, oczekiwanie, restore, consume, acknowledge i zwrot w Play Console.
- Podpis i walidacja AAB właściciela oraz potwierdzenie zasad Google Play w konsoli.
