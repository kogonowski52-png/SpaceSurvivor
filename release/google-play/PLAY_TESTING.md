# Plan testów wewnętrznych i zamkniętych

## Przed wysłaniem zaproszeń

- Podpisz wariant A kluczem przesyłania właściciela. Sprawdź **App integrity**, kod wersji i raport **App bundle explorer**. Przejdź najpierw przez grupę wewnętrzną i zachowaj jedno konto testowe z nowym zapisem oraz jedno z zapisem po aktualizacji.
- W **Testers** dodaj listę e-mail lub grupę Google. Aktywuj odpowiednie wydanie i skopiuj link uczestnictwa. Tester musi wybrać w Google Play to samo konto, które widnieje na liście. W teście zamkniętym wybierz także dostępne kraje.
- Jeżeli Dashboard pokazuje wymóg nowego konta osobistego, zaplanuj 12 osób pozostających zapisanych przez 14 kolejnych dni. Utrzymuj zapas zapisanych osób, zbieraj uwagi w trakcie testów i zachowuj daty wersji. Zastosuj aktualny warunek wyświetlany przez konto. [Wymóg testu zamkniętego](https://support.google.com/googleplay/android-developer/answer/14151465)

## Wiadomość dla testerów

> Proszę o udział w teście Galaxy Strike 1.3.0-rc1. Otwórz [[LINK_DO_DOŁĄCZENIA]] na zaproszonym koncie Google, zaakceptuj udział i zainstaluj grę z Google Play. Zagraj co najmniej dwa razy w różnych dniach. Sprawdź sterowanie jednym palcem, pauzę i jeden lot z bossem. Spróbuj też jednej dostępnej reklamy testowej. W tym wariancie zakupy za pieniądze są wyłączone. Prześlij uwagi do [[KANAŁ_ZGŁOSZEŃ]]. Jeśli uczestniczysz w wymaganym teście zamkniętym, pozostań zapisany do końca podanego okresu.

## Scenariusze

| Sytuacja | Co sprawdzić |
| --- | --- |
| Instalacja przez Play | Właściwy pakiet i wersja, start bez awarii, ekran gry dostępny bez logowania, zachowanie na ARM64 i telefonie z Androidem 15/16 oraz 16 KB, jeśli dostępny. |
| Aktualizacja | Przejście z wcześniejszej wersji o tym samym podpisie. Zachowanie rekordów, walut, wyposażenia, statku i praw Helionu. Porównaj dane przed i po. |
| Kampania | Kolejno wszystkie 10 misji. Wszystkie fazy Asteriona, Vesperona i Nadira. Wyniki i gwiazdy zostają po restarcie. |
| Ekrany i dotyk | Menu, atlas, hangar, warsztat, ekwipunek, sklep, nagrody, wynik, pauza i ustawienia. Jeden palec, wcięcie i gesty systemowe. Przetestuj ekran dłuższy niż 16:9. |
| Offline | Uruchom tryb samolotowy przed startem i w trakcie misji. Sprawdź zapis, sklep za zdobyte waluty i czytelny brak reklamy. |
| Powrót do aplikacji | Home i blokada ekranu, wznowienie na pauzie, ponowne uruchomienie, brak utraty zapisanego wyniku. |
| Testowe Rewarded i UMP | Pięć miejsc. Sukces, przerwanie, przejście do tła przed załadowaniem, brak sieci, odmowa i zmiana prywatności. Wypłata maksymalnie raz. |
| Wydajność | Zmierz FPS, P95, PSS, czas przygotowania i zużycie energii podczas bossów na co najmniej dwóch urządzeniach. Użyj podpisanego debug APK dla panelu diagnostycznego. Oddziel wynik od danych Play i Linux. |
| Billing licencyjny | Na oddzielnym zatwierdzonym wydaniu sprawdź każdy SKU, cenę, pending, odtworzenie, zwrot i odrzucenie podwójnego przyznania. Potwierdź testową metodę płatności przed użyciem. |

Szczegółowe przebiegi i oczekiwania są w [planie Androida](../../ANDROID_TEST_PLAN_1_2.md). Próby sprzętowe w tym kandydacie pozostają otwarte.

## Formularz błędu

```text
Numer zgłoszenia / data:
Wersja aplikacji i kod wersji:
Kanał: APK / wewnętrzny / zamknięty / licencyjny
Telefon, wersja Android, rozdzielczość i ustawienie grafiki:
Poziom lub ekran:
Połączenie: Wi-Fi / komórkowe / offline
Kroki od uruchomienia do błędu:
Oczekiwane zachowanie:
Rzeczywisty wynik:
Powtarzalność:
Wpływ: blokada gry / utrata danych / rozliczenie / UX
Załącznik: zrzut lub filtrowany raport diagnostyczny
```

Przekazuj zgłoszenia wskazanym kanałem bez kodów portfela, tokenów, danych karty i numerów zamówień.

## Przed wnioskiem o dostęp produkcyjny

- Zebrano uwagi testerów, zachowano okres wymaganej obecności i zarejestrowano konkretne poprawki.
- Sprawdzono raport przed uruchomieniem, Android vitals, rzeczywiste telefony, kluczowe przejścia i problemy z wydajnością.
- Potwierdzono testowany AAB, podpis, target API, zasoby karty i lokalizacje.
- Zatwierdzono HTTPS polityki, Data Safety, reklamy, grupę odbiorców, IARC i zakres udostępnionej wersji.
- Zablokowano niewdrożoną monetyzację i rozstrzygnięto otwarte problemy związane z płatnościami i utratą danych.
- Właściciel świadomie składa wniosek, a późniejszy termin publikacji zatwierdza w Play Console.

[Instrukcja właściciela](../../JAK_OPUBLIKOWAC_GALAXY_STRIKE_GOOGLE_PLAY.md) · [Raport kandydata](../../VERSION_VERTICAL_1_3_0_RC1.md)
