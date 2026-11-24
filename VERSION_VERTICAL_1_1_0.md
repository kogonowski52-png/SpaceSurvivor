# Galaxy Strike · 1.1.0 Monetization Premium

Pionowa kampania zachowuje dziesięć poziomów, trzech bossów i poprzednie postępy. Sklep ma sześć zakładek, kampania i hangar obsługują pięć dobrowolnych miejsc Rewarded, a Helion zachowuje bezterminowy dostęp. Produkcyjne płatności pozostają wyłączone.

## APK debug 1.1.0

Pakiet `com.galaxystrike.spacesurvivor`, kod wersji **13**, target **API 36**, min **API 24**, ABI **arm64-v8a** i **x86_64**. Rozmiar 196 977 204 bajtów. Podpis APK Signature Scheme v2 i wyrównanie ZIP 16 KB zostały zweryfikowane. W manifeście potwierdzono testową aplikację AdMob, tryb `test`, pusty adres serwera i zablokowaną ścieżkę zakupów. [Pobierz APK debug](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.1.0/GalaxyStrike-1.1.0-debug.apk)

```text
SHA-256 181418806274e3421b507d270fca8225b066edd5fd0742a340951888b93303ff
```

[Plik sumy SHA-256](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.1.0/GalaxyStrike-1.1.0-debug.apk.sha256) · [Wyniki i podpis APK](MONETIZATION_QA.md)

## Zmiany i obraz

| Obszar | Rezultat |
| --- | --- |
| Oferty specjalne i Crystals | Pakiet startowy, uzbrojenie i zaopatrzenie hangaru mają oddzielne ilustracje, skład i dostępność. Trzy rozmiary Crystals zachowują dotychczasowe wypłaty. Ceny testowe są oznaczone. |
| Statki i skórki | Cztery podglądy korzystają z rzeczywistych kadłubów gry. Dwa nowe poszycia i kosmetyka Prism zmieniają wygląd w locie. Statki odblokowuje kampania. |
| Wyposażenie | Pakiety pokazują stałą zawartość oraz stan posiadania. Można używać Credits lub zdobytych Crystals zgodnie z oznaczeniem produktu. |
| Helion | Złota ilustracja i pasek postępu łączą darmowy i dodatkowy tor. Nagrody mają ilustracje, próg, stan i animację odbioru. Wartości, SKU oraz wcześniejsze prawa pozostają zachowane. |
| Darmowe nagrody | Dzienna reklama wypłaca 150 Credits lub 45 materiałów w dwóch osobnych miejscach. Ekran wyniku obsługuje podwojenie wypłaty i dodatkowe 35 materiałów za bossa. Ożywienie działa raz na lot. |
| Waluty i weryfikacja | Serwer rozlicza wiarygodny stan anulowania bez czekania na okresowy odczyt zwrotów. Aplikacja może zsynchronizować saldo i cofnięte uprawnienia od razu. Zapis 6 zachowuje historię z wersji 5. |

Sześć nowych ilustracji WebP uzupełnia grafikę Crystals, okrętów i modułów z 1.0.0. Przełączanie zakładek, otwarcie paczki uzbrojenia i odbiór nagród mają animacje. Menu wykorzystuje panele i typografię kampanii. Zrzuty potwierdzają czytelność hierarchii na trzech rozdzielczościach X11. Wrażenia z dotyku, jasność panelu OLED i czytelność w słońcu wymagają próby na telefonie. Skórki są wariantami poszycia i świateł na istniejących kadłubach. [Galeria](https://github.com/kogonowski52-png/SpaceSurvivor/blob/apk-v1.1.0/GalaxyStrike-1.1.0-gallery.jpg) · [Pełne PNG i logi](https://github.com/kogonowski52-png/SpaceSurvivor/raw/refs/heads/apk-v1.1.0/GalaxyStrike-1.1.0-evidence.zip) · [Pochodzenie ilustracji](ART_DIRECTION.md#sklep-i-helion-110)

## Co sprawdzono

- Regresja Godot sprawdziła zakupy lokalne, testowe i powtórzone, płatność oczekującą, przywracanie, reklamy ukończone i przerwane, brak sieci, uprawnienia, migrację oraz restart. Automatyczna próba kampanii ukończyła 10 lotów z trzema bossami bez zakupów.
- Jedenaście testów serwera sprawdziło idempotencję, dostęp do konta po reinstalacji, współbieżne wydawanie, anulowanie, zwroty i ponowne przetworzenie potwierdzenia.
- Siedmiodniowa symulacja porównała grę bez wydatków, wariant z Rewarded i wariant z pakietami testowymi. Każdy wariant osiągnął podstawowe wyposażenie w pierwszym dniu. Bez zakupów i reklam profil uzyskał 95 Crystals po siedmiu dniach.
- Telemetria liczy wydarzenia w pamięci sesji. Raport QA pokazuje wyniki symulatora i definicje metryk. [Testy i analityka](MONETIZATION_QA.md) · [Balans i propozycje cen](ECONOMY_1_1.md)

## Wymaga działania właściciela

| Temat | Status i krok |
| --- | --- |
| AdMob i UMP | **NIEURUCHOMIONE** dla rzeczywistej konfiguracji. Właściciel konfiguruje aplikację, jednostki Rewarded, wymagane formularze zgód i deklaracje Play Console. Próbę wykonuje na fizycznym Androidzie. |
| Google Play Billing | **NIEURUCHOMIONE**. Potrzebne są podpisane testy wewnętrzne, testerzy licencyjni, aktywny katalog dotychczasowych pięciu produktów i osobny backend testowy z Publisher API. |
| Pięć nowych SKU | **NIEURUCHOMIONE** w Google Play. Projekty działają w symulatorze. Przed publikacją wymagają zatwierdzenia cen i zawartości oraz serwerowego rozliczania nowych praw. |
| Produkcyjny portfel | **WYŁĄCZONY**. Testy nie zastępują zweryfikowanej tożsamości produkcyjnej, procedury przywracania i sprawdzenia zwrotów na koncie testowym. Już odebrane nagrody lokalne ze starego startera lub Helionu nie są cofane przez portfel. |
| Analityka | **NIEURUCHOMIONA** poza sesją lokalną. Wymaga wyboru dostawcy, konfiguracji prywatności, zgód i polityki retencji przed wysyłką. |

APK nadaje się do rozpoczęcia prób urządzeniowych. Rekomendacja to dalsze testy na telefonie z wyłączonymi płatnościami produkcyjnymi. [Konfiguracja AdMob i Google Play](ANDROID_INTEGRATION.md) · [Gałąź źródłowa](https://github.com/kogonowski52-png/SpaceSurvivor/tree/feature/vertical-shooter)
