# Balans hangaru i pierwszych pięciu godzin

Pętla zaczyna się w Peryhelium. Pilot dostaje 420 kredytów, 90 materiałów, pięć modułów Common i jedną skrzynię z modułem Rare albo Epic. Trzy pierwsze poziomy modernizacji kosztują łącznie 410 kredytów i 54 materiały. Można od razu poprawić kadłub, napęd i uzbrojenie albo zachować zasoby. Moduły z magazynu można montować w niezależnych konfiguracjach statków.

## Kamienie milowe

| Zwycięstwa | Dostęp |
| ---: | --- |
| 0 | Peregrine i Peryhelium. |
| 1 | Aegis i Umbra. Aegis daje większy zapas HP oraz redukcję obrażeń kosztem prędkości. |
| 3 | Specter. Krótszy cykl działa i większa prędkość kosztem HP. |
| 4 | Zenith. Gęstsze fale elit i ciężkich jednostek, wyższe nagrody i dwie skrzynie za zwycięstwo. |
| 7 | Aurora. Drony od startu, dodatkowe HP, XP i większy zasięg zbierania. |

Umbra zwiększa bazową wypłatę o 17%, Zenith o 38%. Sektory różnią się też czasami nadejścia bossów, trasą i składem fal oraz kolorystyką areny. Wybór sektora można zmienić między misjami.

## Gospodarka

- Kadłub dodaje 8 HP za poziom, napęd 4 punkty procentowe prędkości, a uzbrojenie 8 punktów procentowych obrażeń. Każdy tor ma pięć poziomów. Cena rośnie z poziomem. Pełna modernizacja jednego statku kosztuje 7780 kredytów i 1230 materiałów.
- Kredyty zależą od czasu lotu, zestrzeleń i zwycięstwa. Materiały są wypłacane według wyniku walki. Skrzynia przypada za zwycięstwo lub porażkę po co najmniej 3 minutach. Zwycięstwo w Zenith wypłaca dwie.
- Po skrzyni startowej szanse Common / Rare / Epic / Legendary wynoszą 68 / 28 / 4 / 0% przed pierwszym zwycięstwem, 54 / 33 / 12 / 1% po pierwszym oraz 35 / 39 / 22 / 4% po czwartym. Po czterech kolejnych wynikach poniżej Epic następna skrzynia losuje z Epic i Legendary zgodnie z aktualną wagą. W ramach wylosowanej rzadkości pierwszeństwo mają brakujące moduły. Duplikaty dają 24, 50, 90 lub 160 materiałów.
- Trzy zadania odnawiają się według lokalnej daty urządzenia. Cztery osiągnięcia rozlicza się raz na profil. Kalendarz wydaje kolejną z siedmiu nagród co najwyżej raz dziennie, bez utraty kolejki za opuszczony dzień. Zakupy za realne pieniądze są zbędne do osiągnięcia wszystkich progów.

## Symulacja pięciu godzin czasu walki

`godot --headless --script res://tests/balance.gd` podaje reprezentatywne wyniki misji do tych samych zasad wypłat, losowania i zakupów, których używa gra. Obie symulacje wybierają ostatni dostępny sektor, wydają środki równomiernie na modernizacje Peregrine i odbierają dostępne nagrody w jednym dniu kalendarza.

| Scenariusz | Loty / wygrane | Umbra i Aegis | Specter | Zenith | Aurora | Stan po ok. 5 h |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Nauka, jedna wygrana na cztery loty | 39 / 9 | 31 min | 92 min | 122 min | 214 min | 16 modułów, trzy tory Peregrine na poziomie 5, 5425 kredytów |
| Regularna gra, jedna wygrana na dwa loty | 33 / 16 | 18 min | 54 min | 72 min | 126 min | 16 modułów, trzy tory Peregrine na poziomie 5, 8336 kredytów |

Model zakłada wskazaną skuteczność także po zmianie sektora. Czasy pomijają menu i przerwy. Osobno rozegrano z użyciem skryptowanych wejść pełne 600 sekund każdego sektora, aby sprawdzić, że przeciwników oraz bossów można pokonać przy odpowiednim wyposażeniu. Tempo nauki i różnice między sterowaniem dotykowym a klawiaturą wymagają testów z graczami.
