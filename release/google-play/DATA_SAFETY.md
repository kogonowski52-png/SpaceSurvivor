# Data safety · Galaxy Strike

Materiał do wypełnienia i zatwierdzenia przez operatora. Formularz w Play Console opisuje rzeczywiste wydania dostępne w Google Play. Zestaw poniżej uwzględnia testy wewnętrzne, zamknięte oraz zmianę zakresu przy przyszłym włączeniu portfela i reklam.

**Wariant A** korzysta z Google Mobile Ads 25.5.0 i UMP 4.0.0. Billing 9.1.0 jest w pakiecie, a klient nie otwiera płatności i nie uruchamia katalogu płatnych produktów. APK i niesygnowany AAB mają pusty adres portfela. Jeśli właściciel ustawi serwer tylko do synchronizacji praw, dodaj wskazane niżej dane portfela.

**Wariant licencyjny** ma osobny portfel testowy i produkty Google Play po konfiguracji. Przyszły wariant płatny wymaga ponownego zatwierdzenia deklaracji zgodnie z faktycznie uruchomioną usługą.

| Pole orientacyjne w Google Play | Dane i źródło | Cel i decyzja do potwierdzenia przez operatora |
| --- | --- | --- |
| Location → Approximate location | Google Mobile Ads może wnioskować przybliżoną lokalizację z IP | Reklamy, pomiar i zapobieganie nadużyciom. Brak uprawnienia lokalizacji urządzenia. |
| App activity → App interactions | Żądania, wyświetlenia, interakcje z reklamami, dane SDK. UMP przetwarza wybór prywatności | Obsługa reklam, pomiar i komunikaty. Połączenie UMP może nastąpić przy starcie. |
| App info and performance → Diagnostics | Zdarzenia SDK, diagnostyka i sygnały wydajności usług Google | Obsługa, stabilność i bezpieczeństwo SDK. Sprawdź zakres dla faktycznej wersji. |
| Device or other IDs | Dostępne identyfikatory SDK i usługi, zależnie od Androida i zgód. Identyfikator instalacji w przypadku połączenia portfela | Obsługa reklam i bezpieczeństwo, rozliczenie portfela. Wyłączono opcjonalne uprawnienia reklamowe w kandydatach. |
| Personal info → User IDs | Pseudonim konta i sesja połączenia w aktywowanym portfelu | Uwierzytelnienie i odtwarzanie praw. Dotyczy konfiguracji z portfelem. |
| Financial info → Purchase history | SKU, token, transakcje, prawa, zwroty i saldo w konfiguracji portfela | Rozliczanie, przywracanie i ochrona przed duplikacją. Dane karty pozostają u Google Play. |
| Dane pozostające lokalnie | Postęp, zdobyte waluty, dźwięk i grafika, pamięciowy bufor zdarzeń | Gra nie eksportuje ich automatycznie. Raport z APK debug wymaga świadomej akcji eksportu. |

SDK mogą przetwarzać dane także wtedy, gdy aplikacja używa oficjalnej jednostki reklam testowych. Odpowiedź o zbieraniu i udostępnianiu powinna uwzględnić dostawców SDK, ich działanie i wyjątki z formularza. Potwierdź wymagane i opcjonalne przetwarzanie. Nie opieraj odpowiedzi wyłącznie na liście uprawnień Androida. [Dane Google Mobile Ads](https://developers.google.com/admob/android/privacy/play-data-disclosure) · [Jak wypełnić Data safety](https://support.google.com/googleplay/android-developer/answer/10787469)

Portfel wymaga HTTPS. Przed odpowiedzią o szyfrowaniu całej transmisji potwierdź również faktyczną konfigurację wszystkich SDK i hostingu. Ustal retencję, kontakt, obsługę usunięcia i treść odpowiedzi o danych. Bufor analityczny gry działa w pamięci i nie ma zewnętrznego dostawcy. [Polityki PL i EN](privacy) · [Wdrożenie portfela](../../server/WALLET_0_7_PL.md)
