# Portfel Crystals · serwer 0.7.0

Wersja 0.7.0 obsługuje zamknięte testy licencyjne. Dostarczony APK ma wyłączone okno zakupu i pusty adres serwera. Kompilacja i serwer odrzucają włączenie rzeczywistych płatności. Do przeprowadzenia testu Google Play właściciel musi wdrożyć osobny serwer testowy i nadać uprawnienia w Play Console.

## Tożsamość i saldo

- W testach operator przydziela każdemu graczowi stały, unikalny identyfikator pilota oraz indywidualny losowy kod. Serwer rozpoznaje kod po SHA-256. Kod pozwala zalogować się, więc należy go przekazywać w prywatnym kanale. Nie umieszczaj go w logach, kompilacji ani repozytorium.
- Serwer oblicza `obfuscatedAccountId` przez HMAC-SHA-256 ze stałego identyfikatora gracza. Tylko serwer ma klucz HMAC. Aplikacja przekazuje wynik do Google Play. Weryfikacja wymaga zgodności powiązania konta, pakietu, SKU, jednej sztuki, środowiska i stanu `PURCHASED`. Identyfikator instalacji służy wyłącznie do dostarczenia dodatkowych 600 lokalnych Credits z pakietu startowego.
- SQLite zapisuje przyznanie Crystals pod unikalnym skrótem tokenu Google Play. Inne urządzenie po zalogowaniu do tego samego konta odczytuje bieżące saldo oraz uprawnienia. Ponowny odbiór zużytego tokenu nie daje drugiej wypłaty. Worker potwierdza lub zużywa zakup w Google Play dopiero po zatwierdzeniu transakcji w bazie i ponawia nieudane próby.
- Zakup za Crystals z konta zatwierdza serwer po cenie z własnego katalogu. Sprawdzenie salda, debet i przyznanie przedmiotu zachodzą w jednej transakcji SQLite. Idempotencję wymusza identyfikator żądania i unikalność oferty na koncie. Po przerwanym połączeniu odśwież portfel, żeby poznać wynik. Wydatki offline z konta są blokowane. Zdobyte w grze Crystals i Credits nadal trafiają do lokalnego profilu.
- Ponowne uruchomienie telefonu bez sieci nie odtwarza portfela konta. Jeśli połączenie zniknie w otwartej sesji, gra zachowuje ostatnio pobrane elementy kolekcji w pamięci. Następna udana synchronizacja sprawdza te uprawnienia ponownie. Po reinstalacji lub utracie lokalnego zapisu połącz ponownie to samo konto. Misje, Credits i zdobyte lokalnie Crystals korzystają z osobnego zapisu.
- Worker co pięć minut sprawdza `Voided Purchases`, przechodzi po wszystkich stronach i rejestruje każdy zwrot raz, także gdy token dotrze przed żądaniem weryfikacji. Cofnięcie wypłaty może utworzyć ujemne saldo. Dostępne Crystals spadają do zera, gra pokazuje kwotę do rozliczenia i wstrzymuje przedmioty kupione z portfela do wyrównania salda. Zwrot cofa też uprawnienia pakietu startowego lub przepustki. Już wykorzystane lokalne nagrody przepustki i bonus Credits zachowują dotychczasowe działanie. [Voided Purchases API](https://developers.google.com/android-publisher/voided-purchases)

API przyjmuje `POST /v2/play/session`, `verify`, `wallet`, `spend` i `received`. Wszystkie żądania używają `Authorization: Bearer …`. `verify` przyjmuje token zakupu i SKU, `spend` identyfikator oferty oraz 32-znakowy identyfikator żądania, `received` potwierdza dostarczenie dodatkowych lokalnych Credits. Portfel zwraca saldo, zadłużenie, rewizję i aktywne uprawnienia. W starszych wydaniach ścieżki `/v1/play` służyły do dostawy lokalnej.

## Uruchomienie środowiska testowego

1. W oddzielnym projekcie Google Cloud włącz Android Publisher API. Nadaj zarządzanej tożsamości serwera dostęp do aplikacji `com.galaxystrike.spacesurvivor` i uprawnienia do odczytu i zarządzania zakupami w Play Console. Skonfiguruj Application Default Credentials. Gdy hosting obsługuje zarządzaną tożsamość, przypisz ją do procesu. Ewentualny plik poświadczeń trzymaj w menedżerze sekretów lub poza repozytorium. [Google Play Developer API](https://developers.google.com/android-publisher/getting_started)
2. Załóż prywatne środowisko `python3 -m venv` i zainstaluj `python -m pip install -r server/requirements.txt`. Dla testów użyj jednej instancji usługi i trwałego dysku z SQLite. Uruchamiaj proces z dedykowanego konta systemowego. Przechowuj szyfrowane kopie z API SQLite Backup wraz z kluczem powiązania i mapą kont. Sprawdź odtwarzanie kopii w osobnym środowisku przed udostępnieniem usługi testerom.
3. Ustaw zmienne poniżej w prywatnym środowisku procesu i uruchom `python server/play_server.py`. Dla każdego pilota wygeneruj kod przez `secrets.token_urlsafe(32)`, a w mapie zapisz jego skrót obliczony przez `hashlib.sha256(code.encode()).hexdigest()`. Rotując kod, wydaj nowy, zapisz jego skrót, usuń stary wpis i uruchom usługę ponownie. Zachowaj stały identyfikator pilota i klucz HMAC.
4. Wystaw serwis przez HTTPS przed `127.0.0.1:8080`. Przekaż ścieżki `/v2/play/` do procesu i wyłącz logowanie nagłówków uwierzytelnienia oraz treści żądań. Ustaw limit rozmiaru i częstotliwości żądań oraz krótkie limity czasu na proxy. Monitoruj błędy weryfikacji, opóźnienie odczytu zwrotów i nierozliczone zamówienia. API Google obejmuje ograniczone okno historii zwrotów. Po awarii obejmującej okno uzgodnij zamówienia z Play Console przed ponownym uruchomieniem zakupów.
5. Zbuduj osobną kompilację z `GALAXY_PLAY_MODE=test`, `GALAXY_PURCHASE_SERVER=https://…` i `GALAXY_ENABLE_LICENSE_CHECKOUT=1`. W sklepie wybierz **Oferta → Połącz konto zakupów**. Jeśli płatność Google Play nie pokazuje testowej metody płatności, zamknij ją. [Konfiguracja budowy i produktów](../ANDROID_INTEGRATION.md)

| Zmienna | Ustawienie |
| --- | --- |
| `STRIKE_PLAY_DATABASE` | Ścieżka prywatnej, trwałej bazy testowej SQLite |
| `STRIKE_ACCOUNT_BINDING_KEY` | Stały losowy klucz zapisany szesnastkowo, co najmniej 32 bajty |
| `STRIKE_SESSION_DIGESTS` | Mapa JSON skrótów SHA-256 do unikalnych identyfikatorów pilota |
| `STRIKE_PLAY_MODE` | `test` |
| `STRIKE_ENABLE_LICENSE_CHECKOUT` | `1` wyłącznie w środowisku ograniczonym do testów licencyjnych |
| `STRIKE_PLAY_PORT` | Port pętli zwrotnej, domyślnie `8080` |

Konfiguracja `live` ma blokadę nowych rozliczeń. Bazy `test` i `live` są rozdzielone także kontrolą w schemacie. Blokadę testowego okna zakupu można przywrócić przez wyłączenie `STRIKE_ENABLE_LICENSE_CHECKOUT`, zachowując synchronizację i rozliczanie wcześniej wystawionych testowych zamówień.

## Dane wersji 0.6 i dalsze warunki

Aktualizacja zachowuje dotychczasowy profil lokalny i istniejącą tabelę `orders`. Wpisy starego rejestru oraz tokeny już rozliczone poza nowym rejestrem nie zawierają informacji o wcześniejszych wydatkach. Automatyczna dopłata do konta na podstawie samych tokenów byłaby podatna na duplikację. Właściciel powinien uzgodnić ewentualną migrację sald z historią zakupów i zapisami z obsługi gracza. Uprawnienia potwierdzone w Play można synchronizować oddzielnie.

Przed pracą nad odblokowaniem płatności właściciel musi zastąpić kody testowe zarządzanym logowaniem, odzyskiwaniem konta i krótkotrwałymi sesjami. Serwer powinien identyfikować konto po zweryfikowanych `issuer` i `subject`, egzekwować `audience` i czas ważności tokenu oraz zachować istniejące powiązania Play. Potrzebne są również testy licencyjne na telefonach, procedura uzgadniania zwrotów i cofnięcia wdrożenia oraz uzgodniony zakres retencji danych i usuwania kont. Publiczne płatności pozostają wyłączone w 0.7.0. [Bezpieczeństwo Google Play Billing](https://developer.android.com/google/play/billing/security)
