# Ekonomia Galaxy Strike 1.1.0

Kampania, nagrody za pierwsze ukończenia, ceny ulepszeń i pięć istniejących produktów Google Play zachowują wartości z 1.0.0. Credits i zdobyte Crystals można wydawać lokalnie. Zakupione Crystals rozlicza portfel konta. Sklep informuje, z którego salda pobierze cenę. Ten sam przedmiot zużywa w całości jedno saldo.

## Wypłaty kampanii

Poniższe wartości pochodzą z symulacji wypłat na podstawie zarejestrowanych czasów, trafień i stanu kadłuba z dziesięciu pełnych lotów regresji 1.1. Pierwsza i powtórna wygrana mają po 4 Crystals. Do podstawowej skrzyni po zwycięstwie dochodzą skrzynie za pierwszego pokonanego bossa i los odzysku zależny od oceny. Ostatnia kolumna podaje szansę dodatkowej skrzyni dla oceny uzyskanej w próbie.

| Lot | Czas próby | Credits pierwszy / powtórka | Materiały pierwsze / powtórka | Szansa odzysku |
| --- | ---: | ---: | ---: | ---: |
| 1 · Echo pasa | 2:13 | 393 / 293 | 51 / 28 | 21% |
| 2 · Załamanie Pryzmatu | 2:23 | 446 / 346 | 78 / 55 | 21% |
| 3 · Próg Helionu | 2:37 | 513 / 413 | 118 / 95 | 21% |
| 4 · Wrakowisko Tytana | 2:16 | 461 / 341 | 99 / 69 | 20% |
| 5 · Burza magnetyczna | 2:14 | 471 / 341 | 116 / 82 | 26% |
| 6 · Strażnik Ciemności | 2:07 | 585 / 400 | 171 / 124 | 25% |
| 7 · Rozpad Gwiazdy | 2:11 | 542 / 404 | 133 / 96 | 26% |
| 8 · Mgławica Widm | 2:10 | 550 / 405 | 145 / 105 | 24% |
| 9 · Przesmyk Ognia | 2:13 | 564 / 407 | 161 / 118 | 27% |
| 10 · Serce Otchłani | 2:17 | 644 / 404 | 222 / 157 | 30% |
| **Razem** | **22:42** | **5 169 / 3 754** | **1 294 / 929** | |

Ceny pierwszego poziomu kadłuba, napędu i uzbrojenia to odpowiednio 120, 135 i 155 Credits oraz po 18 materiałów. Rozwój do konfiguracji 2/1/2 kosztuje 939 Credits i 130 materiałów. Ekwipunek patrolowy kosztuje 720 Credits, orbitalny 80 Crystals. Skórki Ion, Frost i Sol kosztują odpowiednio 45 Crystals, 55 Crystals i 950 Credits. Ekwipunek trafia także do skrzyń odzysku. W kampanii Aegis, Specter i Aurora odblokowują się po 1, 3 i 7 zwycięstwach, czyli w tej próbie po około 2:13, 7:13 i 16:02 samego lotu.

## Siedem dni rozgrywki

Skrypt uruchamia rzeczywiste funkcje zapisu, wypłat i ulepszeń na trzech profilach. Plan to 2, 1, 2, 1, 2, 1 i 1 wygrany lot kolejno każdego dnia. Każdy profil odbiera dostępny kalendarz, zadania, osiągnięcia i darmowy Helion. Każdy kupuje zestaw patrolowy i dąży do konfiguracji 2/1/2. Symulacja pomija czas porażek, menu i otwierania skrzyń.

| Profil | Reklamy w próbie | Credits / materiały / Crystals po 1. dniu | Credits / materiały / Crystals po 7. dniu | Patrol i 2/1/2 |
| --- | ---: | ---: | ---: | --- |
| Bez zakupów i reklam | 0 | 670 / 294 / 16 | 11 380 / 2 814 / 95 | Dzień 1 |
| Z reklamami | 24 | 1 266 / 417 / 20 | 16 203 / 4 245 / 123 | Dzień 1 |
| Z pakietami testowymi | 0 | 2 150 / 434 / 136 | 12 860 / 2 954 / 245 | Dzień 1 |

- Profil bez zakupów uzyskał 40 Crystals z dziesięciu wygranych, 40 z darmowego Helionu i 15 za siódmy dzień kalendarza. Zestaw orbitalny jest w zasięgu po odbiorze kalendarza. Niezależna regresja rozgrywki ukończyła 10 lotów bez zakupów i ulepszeń wymagających płatności.
- Wariant reklamowy odbiera dwa dzienne bonusy, jedną podwojoną wygraną dziennie i 35 materiałów po każdym z trzech bossów. Otrzymuje dodatkowe 4 823 Credits, 1 431 materiałów, 28 Crystals i 15 skrzyń w tej próbie. Dzienne bonusy to odpowiednio 150 Credits i 45 materiałów. Podwojenie obejmuje tylko pierwotną wypłatę zapisaną w wyniku.
- Wariant zakupowy symuluje jednorazowo pakiet startowy, uzbrojenie, zaopatrzenie hangaru i Helion. Pakiety dodają 1 080 Credits, 140 materiałów, 120 Crystals, skórkę i dwa moduły Rare. Dodatkowy tor Helionu daje 400 Credits, 30 Crystals i skórkę. Wydajność gracza i przebieg lotów są takie same we wszystkich trzech wariantach, więc porównanie mierzy zasoby, a nie przewagę bojową.

Obecne nagrody w zupełności pozwalają osiągnąć podstawowe ulepszenia bez wydatków. Podwojenia mają większy wpływ na bilans niż dzienne bonusy. W testach na telefonie warto porównać saldo po piątym locie i czas potrzebny do zmiany statku. Rozsądnym pierwszym eksperymentem, jeśli podwojenia przyspieszą wyczerpanie progresji, jest wyłączenie z nich premii pierwszego ukończenia w osobnej grupie testowej. Ceny i wypłaty pozostają zgodne z powyższymi wartościami.

## Propozycje cen do zatwierdzenia

Kwoty PLN są roboczymi propozycjami dla właściciela i przykładowymi cenami wyraźnie oznaczonymi w symulatorze. Zakładka Androida wyświetla cenę wyłącznie z Google Play ProductDetails. Wszystkie pakiety mają jawną, stałą zawartość.

| Produkt | SKU | Zawartość | Kwota testowa | Status SKU |
| --- | --- | --- | ---: | --- |
| Pakiet startowy | `gs_starter_v1` | 600 Credits, 120 Crystals, Peregrine Ion | 14,99 zł | Istniejący |
| Zasobnik | `gs_crystals_100` | 100 Crystals | 7,99 zł | Istniejący |
| Kontener | `gs_crystals_350` | 350 Crystals | 19,99 zł | Istniejący |
| Magazyn | `gs_crystals_900` | 900 Crystals | 39,99 zł | Istniejący |
| Helion | `gs_helion_pass_v1` | Bezterminowy dodatkowy tor nagród | 19,99 zł | Istniejący |
| Pakiet uzbrojenia | `gs_arsenal_v1` | Podajnik impulsowy i rdzeń kolektora | 14,99 zł | Propozycja |
| Zaopatrzenie hangaru | `gs_hangar_supply_v1` | 480 Credits, 140 materiałów | 11,99 zł | Propozycja |
| Specter · Noctis | `gs_skin_specter_noctis_v1` | Poszycie i światła Spectera | 11,99 zł | Propozycja |
| Aurora · Vesper | `gs_skin_aurora_vesper_v1` | Poszycie i światła Aurory | 11,99 zł | Propozycja |
| Prism | `gs_pilot_fx_prism_v1` | Smugi silnika i kolor pocisków | 9,99 zł | Propozycja |

## Projekt kolejnych wydarzeń

Pierwszym etapem powinna być bezpłatna próba wydarzenia PvE o prawdziwych, ogłoszonych datach w UTC. Postęp i odbiór nagród mają osobne klucze wydarzenia. Po zamknięciu okresu gry można wyznaczyć dodatkowy, wcześniej ogłoszony okres odbioru nagród. Handlowy wariant sezonu potrzebuje osobnej akceptacji ekonomii i osobnego uprawnienia. Bezterminowy Helion pozostaje pasem archiwalnym z istniejącym SKU i nagrodami.

Jeśli po pomiarach będzie rozważany interstitial, osobny eksperyment powinien obejmować wyłącznie przerwy między lotami, np. maksymalnie jedną reklamę w sesji po trzech zakończonych lotach, z grupą bez interstitiali. Mierzyć należy porzucenie sesji i retencję. W 1.1.0 dostępne są wyłącznie dobrowolne Rewarded.

Odtworzenie symulacji w Godot 4.7.2. [Skrypt symulacji](tests/economy_1_1.gd) · [Testy i dowody](MONETIZATION_QA.md)
