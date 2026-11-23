# Audyt wizualny i użytkowy

Porównanie dotyczy commita `33d03ba` i wersji 0.4.0. Priorytetem była czytelność w pionowym kadrze, spójność materiałów statków i hierarchia informacji podczas walki. Zasad uzbrojenia, misji i progresji nie zmieniano w ramach tego audytu.

## Co poprawiono

| Ekran | Niedociągnięcie w wersji wyjściowej | Zmiana |
| --- | --- | --- |
| Menu główne | Poszycie i geometria statku na ilustracji kojarzyły się z inną jednostką niż Peregrine. Strona miała słabą hierarchię akcji pobocznych. | Nowa ilustracja oparta na sprite’cie Peregrine. Zwięzły nagłówek misji, osobna akcja hangaru i dostęp do ustawień przez oznaczoną ikonę. |
| Rozgrywka | Czerwony błysk po trafieniu przykrywał cały kadr. W gęstych falach ciemne płyty Razora i Widma zlewały się z tłem. | Ostrzeżenie po trafieniu przeniesiono na krawędzie. Dwa sprite’y mają wyraźniejsze materiały i obrzeża. Linie, strefy i pierścienie pokazują narastanie ataku bossa. Po jego zniszczeniu widać zanikający wrak, impuls i osobny komunikat. |
| Karty ulepszeń | Rzadkość, typ i poziom konkurowały o uwagę z nazwą i opisem. Tło podczas awansu było mało czytelne albo rozpraszało. | Nazwa, efekt, ikona i metadane są rozdzielone. Metaliczne krawędzie odróżniają rzadkości. Przygaszona arena zostaje widoczna pod kartami. |
| Hangar | Podgląd był czytelny, ale nawigacja, skróty i panele miały podobną wagę. | Zawis statku z oszczędnym światłem lądowiska, wspólne ścięte krawędzie paneli, czytelny podział parametrów i start z nazwą wybranej trasy. |
| Wybór statku | Same nazwy kadłubów słabo komunikowały kształt i stan blokady. | Miniatury rzeczywistych sprite’ów, wyraźny aktywny kadłub i warunki odblokowania przy jednostkach. |
| Ulepszenia stałe | Koszt był czytelny, ale dominujący kolor przycisków rozmywał priorytet. | Oddzielna obecna i następna wartość z wyróżnionym przyrostem. Krótka animacja zakupu potwierdza aktualizację statystyki i salda. |
| Ekwipunek | Najrzadsze moduły były rozproszone, a stan zamontowania łatwo było przeoczyć przy przewijaniu. | Wyższe rzadkości trafiają na początek magazynu. Stałe ikony slotów, oznaczenia zamontowania i animowany detal złotej ramki Legendary. |
| Zwycięstwo i porażka | Oba wyniki miały bardzo podobną sylwetkę. Odczytanie nagrody wymagało przenoszenia wzroku między blokami. | Odrębne insygnia, kolory i komunikaty wyniku, czytelny rząd nagród i główna akcja powrotu do hangaru. |
| Nagrody i skrzynie | Informacja o zawartości skrzyni była przede wszystkim tekstem statusu. | Odkrycie eksponuje faktycznie wylosowaną ikonę, rzadkość i działanie modułu. Schematy nagród mają czytelniejsze stany dostępności. Dźwięk skrzyni odróżnia się od montażu i odbioru zadania. |
| Sektory | Trasy korzystały z jednakowo kadrowanej ilustracji. | Odrębne kadry i oprawa kolorystyczna. Karty czytelnie pokazują wybraną trasę, wypłatę i wymagania. |
| Ustawienia i pauza | Wersja wyjściowa nie miała ustawień dźwięku. | Głośność główna, muzyka i efekty mają suwaki z odsłuchem na żywo. Zapis utrwala zmianę, anulowanie przywraca poprzedni miks. Ustawienia z pauzy zachowują wstrzymanie walki. |

## Obraz i dźwięk

Ilustracja menu odwzorowuje kolor, kabinę i napęd Peregrine z hangaru. To autorska ilustracja przygotowana z referencji, więc detale mogą różnić się od rzeczywistego sprite’a. Dwie poprawione tekstury przeciwników zachowały proporcje i barwy pozwalające rozpoznać typ jednostki. [Kierunek artystyczny i źródła materiałów](ART_DIRECTION.md)

Poświaty mają ograniczony zasięg i są układane tak, aby zachować sylwetkę gracza. Odległe gwiazdy korzystają z buforowanej tekstury, a standardowy strumień napędu ze współdzielonego rastra. Eliminują one wiele poleceń rysowania i alokacji geometrii. Wybuchy i cząstki są limitowane, a rysowanie poza kadrem pomijane tam, gdzie to możliwe.

Dwa oryginalne utwory, *Docking Bay* i *Hostile Orbit*, mają odmienne tempa i wspólne brzmienie syntezatorów. Muzyka wygasza się między hangarem a walką i ścisza pod pauzą, awansem oraz wynikiem. Efekty trafienia, skrzyni, montażu, awansu, ostrzeżenia i zniszczenia bossa pełnią różne role. Miks ogranicza nakładanie najczęstszych dźwięków. Partytury i 19 efektów wygenerowano z kodu bez zewnętrznych nagrań i udostępniono na warunkach CC0. [Pochodzenie i licencja audio](assets/audio/PROVENANCE.md) · [Kod źródłowy dźwięku](audio/render_scores.py)

## Metoda porównania

Zrzuty PRZED i PO są klatkami wyrenderowanymi w Godot 4.7.2 w rozdzielczościach 720×1280, 1080×1920 i 1080×2400. Użyto Linuksa i programowego renderera. Układ porównywano przy podobnym wyposażeniu i identycznych stanach. Skrypt odtwarza menu, hangar, wybór statku, magazyn, sektory, nagrody, otwarcie skrzyni, warsztat, walkę, awans, pauzę i oba wyniki. W scenach kart i wyników użyto kontrolowanych danych wejściowych przekazanych do istniejących ścieżek gry. Przebieg pełnej misji stanowi osobny test. Ustawienia nie mają klatki PRZED, ponieważ ekran nie istniał w wersji wyjściowej.

Narzędzie `bash tests/capture_audit.sh <katalog>` wymaga aktywnego wyświetlacza graficznego. Archiwum zrzutów zachowuje pełne PNG w katalogach `before` i `after` pod identycznymi nazwami dla porównywalnych stanów. Dodatkowe klatki w `combat-detail` pokazują przygotowanie ataku i efekt zniszczenia Leviathana w kontrolowanym scenariuszu.

## Wyniki testów

| Próba | Wynik |
| --- | --- |
| Porównanie ekranów | 39 klatek PRZED i 42 PO. W każdej z trzech rozdzielczości sprawdzono nawigację, dostępność przycisków i ich położenie w widocznym obszarze. |
| Testy regresji Godot | Arsenał, oba starcia z bossami, progresja, ustawienia i pełny lot Peryhelium zaliczone. Wynik lotu Peregrine to 600 s, 1190 zestrzeleń i 501 materiałów. |
| Lot z naturalnym zegarem | Skryptowany pilot Aegis pokonał Leviathana i ukończył 600 s rozgrywki w 604,072 s rzeczywistego czasu. Wynik to 1179 zestrzeleń, poziom 38 i 506 materiałów. Test odbył się w trybie headless z przygotowaną konfiguracją statku. |
| Miks i zasoby audio | Programowy odbiornik ALSA potwierdził pętle, przejścia, ściszenie pod pauzą, ograniczenie powtórzeń i niezależne wyciszanie muzyki i efektów. Obie zakodowane pętle sprawdzono na styku końca i początku, a 19 efektów pod kątem amplitudy oraz ciszy na końcach. |

Polecenie `bash tests/run.sh --full-mission` uruchamia regresję. Test z naturalnym zegarem korzysta z `godot --headless --max-fps 60 --script res://tests/realtime_flight.gd` i raportuje także rzeczywisty czas.

## Pozostałe braki i kryteria odbioru

1. **Czytelność na fizycznym telefonie.** Zrzuty pokazują geometrię i hierarchię, ale nie oddają niskiej jasności OLED, wycięć matrycy, dotyku w ruchu ani pomiaru klatek. Potrzebny jest pełny lot i test menu na co najmniej jednym telefonie średniej klasy oraz starszym modelu, przy jasności dziennej i obniżonej.
2. **Spójność ujęć statku.** Największe różnice wytwarza odrębne przygotowanie ilustracji i sprite’a. W kolejnym przejściu artystycznym można przygotować jeden model źródłowy Peregrine, wyrenderować z niego ujęcie menu oraz rzut z góry i ujednolicić położenie wlotów oraz silników.
3. **Różnorodność sektorów.** Karty sektorów mają odrębny kadr i kolory, ale korzystają z jednej bazowej przestrzeni. Dedykowane ilustracje Umbry i Zenithu dałyby każdej trasie własny punkt orientacyjny bez zwiększania kontrastu w obszarze pocisków.
4. **Odsłuch na urządzeniach.** Poziomy i przełączanie miksu sprawdzono technicznie. Krótki odsłuch na małym głośniku telefonu i na słuchawkach pozwoli dopasować pasmo niskich impulsów, odróżnialność alarmu i poziom muzyki.
