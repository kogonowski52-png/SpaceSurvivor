# Testy monetyzacji 1.1.0

## Próby wykonane

| Scenariusz | Próba i rezultat |
| --- | --- |
| Credits i zdobyte Crystals | Godot uruchomił zakupy skórek i modułów, sprawdził koszty, efekt wyposażenia, brak środków i nieudany zapis. Nieudana transakcja zachowała saldo. |
| Katalog Google Play | Test interfejsu podał przykładowe ProductDetails w jenach. Sklep pokazał przekazaną cenę, oznaczył brakujące produkty i zablokował nowy SKU w natywnym katalogu. |
| Zamówienia | Symulator sprawdził sukces, anulowanie, błąd sieci, brak usługi, oczekiwanie, zatwierdzenie, ponowione i niezwiązane callbacki. Po restarcie przywrócenie uzupełniło oczekującą wypłatę bez duplikacji. |
| Weryfikacja zakupów i zwroty | 11 testów SQLite i kontrolowanego Publisher API. Sprawdzono reinstalację, równoczesne wydatki, podwójne rozliczenie, obce konto, środowisko testowe, zwrot po wydatku, anulowanie w trakcie weryfikacji i ponowienie workera. |
| Rewarded | Godot sprawdził wszystkie pięć miejsc. Sukces przyznawał nagrodę raz, a zamknięcie, niedostępność i błąd sieci nie przyznawały wypłaty. Ożywienie przywróciło połowę kadłuba. |
| Premia bossa i materiały | Podwojenie nie nalicza premii bossa po raz drugi. Porażka nie oferuje podwojenia. Sklep i hangar korzystają ze wspólnego limitu dziennego. Odbiór pozostaje zapisany po restarcie. |
| Zapis i Helion | Migracja profilu 5 zachowała 10 wyników, gwiazdy, oba salda, historię zakupu, skórki i odbiory obu torów. Symulator sprawdził trwałą przepustkę, odebranie skórki i efekty Prism w locie. |
| Kampania i kompatybilność | Pełne przejście 10 lotów i trzech bossów. Regresja Godot objęła hangar, ustawienia, dotychczasowy sklep, progresję, uszkodzony zapis i próbę 600 sekund istniejącego trybu Survivor. |
| Układy | Godot z rendererem X11 zapisał 12 rzeczywistych klatek na rozdzielczość. Sprawdzono 720×1280, 1080×1920 i 1080×2400. Zrzuty ofert po zakupie i nagrody bossa używają testowego profilu i jawnie symulowanych zdarzeń. |
| APK | Android Gradle wyeksportował APK debug. Zweryfikowano podpis v2, ZIP CRC, wyrównanie 16 KB, biblioteki obu ABI, klasy SDK w DEX, kod 13, API 36, katalog i ilustracje oraz próbny start wydobytego projektu w Godot Linux. |

```sh
bash tests/run.sh --full-mission
godot --headless --fixed-fps 60 --script res://tests/chapter_one.gd
python3 -m unittest discover -s server -v
godot --resolution 1080x2400 --fixed-fps 30 --script res://tests/monetization_1_1.gd -- --quick-capture --capture-dir /tmp/strike-captures --expect-size 1080x2400
```

Do ostatniego polecenia użyj istniejącego katalogu i monitora o odpowiedniej rozdzielczości. Zrzuty pochodzą z widoku gracza w Godot, a automatyczne próby kampanii mają przyspieszony czas symulacji. [Zrzuty i dzienniki QA](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.1.0/GalaxyStrike-1.1.0-evidence.zip)

## Android fizyczny · NIEPRZETESTOWANE

| Kolejność | Próba właściciela |
| --- | --- |
| 1 | Zainstaluj APK na osobnym telefonie albo zaktualizuj wersję z tym samym podpisem. Wejdź w każdą zakładkę i sprawdź obszary pod wcięcia, gesty przesuwania, minimalne rozmiary przycisków i kontrast przy typowej jasności ekranu. |
| 2 | Sprawdź Google UMP w obsługiwanych regionach, odmowę zgody, zmianę ustawień reklam, start i wznowienie gry. Sprawdź, że opcje prywatności są dostępne, gdy UMP ich wymaga. |
| 3 | Wykonaj każdą z pięciu dobrowolnych reklam testowych. Sprawdź ukończenie, zamknięcie przed nagrodą, brak reklamy, włączenie trybu samolotowego i ponowne włączenie internetu. Zweryfikuj wypłatę i przejście do gry po zamknięciu. |
| 4 | Na podpisanym kanale wewnętrznym i koncie licencyjnym sprawdź ProductDetails w co najmniej dwóch walutach. Przetestuj kartę testową sukcesu, odrzucenie, odroczoną płatność, anulowanie i przywrócenie po reinstalacji. Sprawdź consume i acknowledge w Play Console oraz portfel po zwrocie. |
| 5 | Odłącz testowy backend przed zakupem i po zatwierdzeniu w Google Play. Po odzyskaniu połączenia sprawdź przywrócenie bez powtórnej wpłaty. Upewnij się, że nadal da się wydawać zdobyte lokalnie Credits i Crystals. |

Brak fizycznego telefonu i dostępu do Play Console w sesji. Status działania natywnego AdMob, UMP, Billing oraz rzeczywistych zwrotów pozostaje **NIEURUCHOMIONE**. Próby serwera używają kontrolowanych odpowiedzi. Strony regulaminowe Google zwracały HTTP 403 z proxy środowiska. Właściciel weryfikuje bieżące wymogi w konsoli przed udostępnieniem wdrożenia. [Konfiguracja Androida](ANDROID_INTEGRATION.md) · [Zasady płatności Google Play](https://support.google.com/googleplay/android-developer/answer/10281818)

## Analityka · raport schematu

Zdarzenia są dostępne dla testów w pamięci bieżącej sesji, do 256 ostatnich wierszy. Moduł dopuszcza własne identyfikatory poziomu, oferty i miejsca reklamy oraz przyjęte wyniki. Kod nie zapisuje identyfikatorów osób, instalacji, tokenów zakupów ani kodów kont. Dostawca zewnętrzny i eksport danych są **NIEURUCHOMIONE**. Przyszła integracja używa sygnału `recorded` po ustaleniu konfiguracji prywatności i zgód. [Moduł analityczny](commerce/metrics.gd)

| Metryka | Sposób liczenia po akceptacji dostawcy | Symulacja QA |
| --- | --- | --- |
| D1 / D7 | Udział kohorty pierwszego uruchomienia, który wrócił dokładnie 1 / 7 dni później według stałej strefy czasowej | Brak danych kohort |
| ARPDAU | Suma przychodów z reklam i zakupów po uwzględnieniu zwrotów, podzielona przez aktywnych graczy danego dnia | Brak danych finansowych |
| Konwersja zakupowa | Odsetek aktywnych graczy z co najmniej jednym potwierdzonym rzeczywistym zakupem w danym okresie, rozliczonym po stronie serwera | Tylko scenariusze techniczne |
| Przychód reklamowy | Suma stawek z zaakceptowanego raportu rzeczywistych wyświetleń AdMob w jednej walucie | Brak danych finansowych |
| Przychód z zakupów | Zweryfikowane zamówienia według raportu Play pomniejszone o zwroty | Brak danych finansowych |
| Ukończenia poziomów | Zapisane zwycięstwa do rozpoczęć, według stabilnego identyfikatora poziomu | 1 ukończenie i 1 porażka na 2 starty |
| Rewarded | Prośby, dostępność, ukończenia i zatwierdzone wypłaty liczone oddzielnie | 6 próśb, 4 dostępne, 3 ukończone, 3 nagrody |

Wiersze z wynikami QA są symulowanymi zdarzeniami testu powtarzalnego. Zliczenia objaśniają instrumentację, a wartości finansowe pojawią się po zatwierdzonym wdrożeniu i raportowaniu rzeczywistych zdarzeń.
