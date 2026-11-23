# Ekonomia Galaxy Strike 0.5

Sklep jest dostępny z menu głównego i hangaru. Zakupy oznaczone **Symuluj zakup** oraz przyciski **Reklama testowa** korzystają z lokalnych adapterów. Kompilacja testowa nie pobiera pieniędzy, nie wyświetla reklam i nie łączy się z Google. Własny portfel umożliwia zakup części przedmiotów, a skórki można założyć z karty posiadanego produktu. Zmiana poszycia jest widoczna w hangarze i w walce.

## Portfel i oferta

| Zasób | Zdobywanie | Wydatki |
| --- | --- | --- |
| Credits | Loty, zadania, osiągnięcia i kalendarz. Opcjonalny bonus testowy daje 150 na dzień. | Ulepszenia w hangarze, wskazane skórki i moduły. |
| Crystals | 4 za każde zwycięstwo, 15 za siódmy odbiór kalendarza i 8, 12 oraz 20 za darmowe progi Helionu. Dostępne także przez symulację zakupu. | Wskazane skórki i zestaw orbitalny. |
| Materiały | Zdobycz z lotów i nagród. Są zasobem warsztatu. | Ulepszanie statków. |

| Produkt Google Play | Identyfikator | Typ | Zawartość symulacji |
| --- | --- | --- | --- |
| Pakiet startowy | `gs_starter_v1` | Jednorazowy | 600 Credits, 120 Crystals, poszycie Peregrine · Ion |
| 100 Crystals | `gs_crystals_100` | Zużywalny | 100 Crystals |
| 350 Crystals | `gs_crystals_350` | Zużywalny | 350 Crystals |
| 900 Crystals | `gs_crystals_900` | Zużywalny | 900 Crystals |
| Przepustka Helion | `gs_helion_pass_v1` | Jednorazowy | Prawo do odbioru dodatkowych progów Helionu |

Peregrine · Ion i Aegis · Frost kosztują odpowiednio 45 i 55 Crystals. Peregrine · Sol kosztuje 950 Credits. Zestaw patrolowy za 720 Credits zawiera pancerz ceramiczny i napęd plazmowy. Zestaw orbitalny za 80 Crystals zawiera reaktor ciemnej materii i kontroler skrzydła. Pakiety modułów mają stały skład. Karta informuje o posiadanych modułach przed zakupem, dodaje brakujące, a pełna kolekcja blokuje zakup. Moduły działają po wyposażeniu w hangarze. Skórki zmieniają tylko wygląd statku i akcent silnika.

Archiwum Helionu wykorzystuje trzy progi ukończonych lotów, po 1, 3 i 6. Każdy próg można odebrać raz. Przepustka pozwala odebrać również już osiągnięte progi, czyli 400 Credits, 30 Crystals i Peregrine · Helion. Postęp korzysta z istniejącego licznika ukończonych lotów. Tor darmowy jest dostępny od początku, a archiwum nie wygasa.

## Zakupy i reklamy testowe

- **Oferta → Scenariusze testowe** pozwala ustawić sukces, anulowanie, błąd zakupu, błąd sieci, niedostępność, oczekiwanie lub powtórzony callback. Symulacja oczekiwania przeżywa restart gry. **Zatwierdź oczekujące (test)** rozlicza oczekujące zamówienia, a **Przywróć zakupy testowe** odczytuje je z lokalnego dziennika i odzyskuje zatwierdzone, nierozliczone nagrody.
- **Podwój wypłatę** na ekranie wyniku przyznaje jeden dodatkowy komplet naliczonych Credits, Crystals, materiałów i skrzyń. Liczniki lotów, zwycięstw i osiągnięć pozostają na wartości rzeczywistego wyniku.
- **Ożyw** pojawia się po utracie kadłuba. Walka i jej zegar są zatrzymane do decyzji gracza. Ukończona symulacja przywraca połowę HP i daje krótką osłonę po powrocie. Ożywienie jest jednorazowe w danym locie. **Zakończ lot** natychmiast przechodzi do wyniku.
- **Bonus dzienny** w sklepie daje 150 Credits raz na dzień według daty urządzenia. Wybór scenariusza reklamy pozwala odtworzyć ukończenie, zamknięcie, błąd sieci, niedostępność i powtórzony callback. W czasie gry reklama nie jest wywoływana automatycznie.

## Rozliczenie i zapis

`PilotProgression` wczytuje zapis v2, zachowuje pole `coins` jako Credits i inicjuje portfel Crystals w wersji 3. Każda transakcja portfela zaczyna od kopii danych profilu. Nagroda i identyfikator rozliczenia trafiają w jednym zapisie do nowej zweryfikowanej rewizji. Błąd zapisu zostawia aktywną rewizję bez zmiany. Powtórzony token zakupu jest wykrywany po skrócie powiązanym z produktem. Dodatkowe blokady dotyczą jednorazowych produktów, progów sezonu, daty bonusu oraz identyfikatora lotu. Lokalny dziennik zamówień testowych jest osobny od profilu, więc można przywrócić zamówienie po przerwaniu rozliczenia. Przywracanie symulacji obejmuje tę instalację.

`BillingService` i `AdService` dopuszczają po jednym aktywnym żądaniu odpowiedniego typu. Adapter odsyła identyfikator żądania. Spóźnione i powtórzone callbacki są ignorowane, a brak odpowiedzi przez 35 sekund pokazuje komunikat o błędzie sieci. Serwis zakupów przed przyznaniem nagrody sprawdza stan, SKU i potwierdzenie w adapterze. Kwoty nagród pochodzą z katalogu gry. [Profil](data/pilot_progression.gd) · [Portfel](data/store/wallet.gd) · [Katalog](data/store/commerce_catalog.gd)

## Podłączenie Google Play Billing i AdMob

1. Zarejestruj wymienione produkty jednorazowe w Play Console. Adapter Androida powinien pobierać wersję językową i cenę z `ProductDetails`, uruchamiać zakup dla wybranego SKU oraz przekazywać `BillingService` odpowiedzi na głównym wątku z pierwotnym identyfikatorem żądania. Odpytywanie `queryPurchasesAsync` po wznowieniu i przy przywracaniu pomoże odnaleźć zakupy oczekujące oraz zatwierdzone podczas utraty połączenia. Przyciski zmieniające stan symulacji pozostają w kompilacji testowej. [Interfejs adaptera zakupów](commerce/billing_adapter.gd)
2. Dla zakupów rzeczywistych serwer powiąże token z kontem gracza oraz zweryfikuje w Google Play Developer API nazwę pakietu, SKU i stan `PURCHASED`. Potwierdzenie przyznania i aktualizacja portfela powinny być jedną idempotentną transakcją serwera. Potwierdzenie zakupu jednorazowego lub zużycie zakupu Crystals następuje po zapisaniu wyniku rozliczenia. Obecne `BillingService` przyznaje wyłącznie zweryfikowane nagrody testowe. Aplikacja rzeczywista powinna pobierać rozliczone uprawnienia i saldo z serwera. [Serwis zakupów](commerce/billing_service.gd)
3. Adapter AdMob użyje osobnych jednostek `RewardedAd` dla wyniku, ożywienia i bonusu. Zwróci ukończenie wyłącznie z `OnUserEarnedRewardListener` dla bieżącego żądania. Zamknięcie przed odebraniem nagrody zwróci anulowanie. W rzeczywistej ekonomii weryfikacja serwerowa AdMob z identyfikatorem gracza i typu nagrody pozwoli rozliczyć zweryfikowane zdarzenie raz. Przypisanie daty lub lotu do tego zdarzenia powinno odbywać się po stronie serwera. [Interfejs adaptera reklam](commerce/ad_adapter.gd)
4. Podłączenie SDK wymaga skonfigurowania wtyczki Androida, aplikacji i jednostek AdMob, produktów Play Console oraz zgody na dostęp do sieci w presecie Android. Obecny preset jest offline. Do tego czasu do obsługi scenariuszy służą adaptery testowe i lokalny zapis, który może edytować właściciel urządzenia.

## Uruchomienie testów

```sh
bash tests/run.sh --full-mission
```

Pakiet testów obsługuje sklep przez przyciski i sprawdza migrację, ponowne kliknięcie, obcy lub powtórzony callback, uszkodzoną ścieżkę zapisu, przywracanie, brak środków, nagrody darmowe oraz reklamy w dozwolonych momentach. Oddzielny test pełnej misji sprawdza rozgrywkę, dwa starcia z bossami i zapis wyniku. [Test ekonomii](tests/commerce.gd)

Przy aktywnym serwerze graficznym można zapisać natywne klatki sklepu, zamówienia oczekującego, ożywienia i wyniku. Przy innych proporcjach należy przekazać odpowiadające sobie wartości obu opcji rozdzielczości.

```sh
mkdir -p /tmp/galaxy-store-shots
godot --editor --headless --import
godot --resolution 1080x1920 --audio-driver Dummy --script res://tests/commerce.gd -- \
  --capture-dir /tmp/galaxy-store-shots --expect-size 1080x1920
```
