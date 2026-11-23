# Galaxy Strike: Space Survivor — kierunek artystyczny

Peryhelium rozgrywa się nad nocną stroną odległego księżyca. Twarde krawędzie płyt kadłuba, ceramiczne i grafitowe materiały oraz punktowe światło silników nadają statkom wyraźną skalę. Menu pokazuje myśliwiec pilota w zbliżeniu. Podczas walki ciasny kadr ustępuje spokojniejszej przestrzeni, w której od razu widać kierunek ruchu i zagrożenia.

## Paleta

| Rola | Kolor | Zastosowanie |
| --- | --- | --- |
| Przestrzeń | `#050912` | Najciemniejszy plan areny oraz obszary pod tekstem |
| Granat | `#101D2A` | Panele, cień kadłubów i powierzchnie przycisków |
| Biel chłodna | `#EAF4FF` | Tytuł, bieżące wartości i nazwy kart |
| Tekst pomocniczy | `#A6BBCC` | Opisy kart, instrukcje, metadane |
| Cyjan | `#58E1E5` | Statek gracza, akcja główna, wiązka i doświadczenie |
| Fiolet | `#BCAFFF` | Lancer oraz efekty impulsu |
| Bursztyn | `#FFC79B` | Szybki Scout |
| Koral | `#FFA4B1` | Bastion, ostrzeżenia i niski poziom integralności |

Wzrok mają prowadzić kontrasty jasności. Barwa wspiera rozpoznawanie obiektów wraz z kształtem, rozmiarem, ruchem i animacją trafień. Cyjan i fiolet świecą miejscowo na silnikach, końcach uzbrojenia i elementach interaktywnych. Szczegóły satynowego metalu i ceramiki pozostają widoczne obok emisji światła.

## Postacie i tło

| Jednostka | Sylwetka | Detal prowadzący wzrok |
| --- | --- | --- |
| Peregrine | Wydłużony nos, ostre skrzydła i para dysz | Chłodna owiewka kabiny oraz turkusowe lampy napędu |
| Aegis pilota | Zwarty kadłub i szerokie, opancerzone barki | Ciemny brąz i jadeitowe płyty |
| Specter | Smukła igła i ostre skrzydła powleczone grafitem | Indygo wokół kabiny i silników |
| Aurora | Miękko wygięte, oddzielone łuki skrzydeł | Perłowa ceramika i magentowe komory energii |
| Scout | Wąski profil z klinem i cofniętymi skrzydłami | Miedziany kadłub i bursztynowa optyka |
| Lancer | Szeroki łuk z wysuniętymi czubkami skrzydeł | Fioletowe panele poszycia |
| Bastion | Krótki i szeroki korpus z ciężkimi bokami | Czerwone płyty i szczeliny silnika |
| Razor | Stalowe ostrze z dwudzielnymi skrzydłami | Turkusowe krawędzie i lampy napędu |
| Siewca | Ciężki kadłub pomiędzy dwiema komorami min | Złoto i mosiądz na przemysłowych płytach |
| Widmo | Szerokie skrzydła z ostrymi widłami od strony dziobu | Magentowe panele i ciemna optyka |
| Aegis | Trzy równoległe części dziobowe, masywne boczne uzbrojenie | Bursztyn i miedź na ciężkim poszyciu |
| Leviathan | Szeroki sierp z wygiętymi ostrzami | Fioletowe szczeliny wyróżniają się na tle pancerza z włókna węglowego |
| Dron Strażnik | Niewielka podkowa z centralną optyką | Ceramika biała i jasnoniebieski wizjer |

Na arenie mgławica i krawędź księżyca budują najdalszą warstwę, a oddzielne pola gwiazd dodają paralaksę. Na pierwszym planie znajdują się sylwetki, pociski, trafienia i XP. Krótkie rozbłyski i kierunkowe smugi mają pokazać źródło trafienia podczas ruchu.

Hangar ma ten sam ciemny granat, ale wykorzystuje oświetlenie techniczne i głębię stalowych konstrukcji. Puste lądowisko stanowi tło dla wybranego statku. Oddzielny sprite pozwala wymieniać jednostkę i animować jej zawis nad platformą.

## Hierarchia interfejsu

1. **Menu.** Tytuł i nazwa gry otwierają ekran. Ilustracja prowadzi wzrok w dół do głównej akcji i informacji o misji. Ciemne marginesy obrazu utrzymują czytelność tekstu.
2. **Walka.** Czas, integralność kadłuba i doświadczenie są widoczne na obrzeżach. Środek jest polem gry. Pauza ma osobny punkt dotykowy przy krawędzi.
3. **Awans.** Trzy karty są rozróżnialne po nazwie i opisie efektu. Pole walki przygasa, a wybór wznawia rozgrywkę.
4. **Pauza i wynik.** Wznowienie albo ponowny start otrzymują najwyższy priorytet. Statystyki i powrót do menu zajmują niższy poziom hierarchii.
5. **Hangar.** Podgląd sylwetki i parametry są związane z wybranym statkiem. Akcja w dolnym obszarze odpowiada aktualnemu stanowi wyposażenia lub odblokowania.

W wysokim kadrze obrazy mogą wychodzić poza obszar bazowy. Układ kontrolny pozostaje przy krawędziach i pozostawia przestrzeń na sterowanie jedną ręką.

Oxanium nadaje tytułom i licznikom geometryczny rysunek. Barlow Medium ułatwia czytanie polskich opisów i wskazówek na mniejszym ekranie. [Źródła i warunki licencji fontów](assets/fonts/README.md)

## Zasoby i pochodzenie

- Ilustracja menu i mgławica areny powstały dla tego projektu z użyciem generatora obrazów. Kolor i układ kadrów dobrano do czytelności interfejsu. Obie tekstury zapisano w JPEG.
- Cztery statki wygenerowano razem w spójnej stylistyce. Każdy ma oddzielną teksturę PNG z oczyszczoną alfą i dłuższą krawędzią 320 px. Metalowe poszycie, otwory wentylacyjne, kabiny i światła są częścią tekstur. Jasność i ruch napędu oraz trafień są rysowane w Godot.
- Sześć jednostek etapu 2 powstało w dwóch nowych arkuszach dla tej gry. Z arkuszy wycięto pojedyncze tekstury PNG, oczyszczono krawędzie alfy i dobrano rozdzielczości do różnych rozmiarów jednostek na arenie. Statki wykorzystują filtrowanie z mipmapami, które ogranicza migotanie detali w ruchu.
- Trzy statki gracza i wnętrze hangaru etapu 3 powstały w osobnych materiałach dla tej gry. Tekstury statków mają oczyszczone krawędzie alfy. Hangar pokazuje Peregrine z pierwotnej grafiki w większej rozdzielczości niż tekstura bojowa, która pozostała bez zmian.
- Ikona gry, glify i efekty dźwiękowe powstały w tym projekcie. Dźwięki są syntetyzowane bez zewnętrznych próbek. [Licencje typografii](assets/fonts/README.md)

## Ocena etapu 1

Próba statków złożonych na tle areny w skali 46–80 px pokazała wyraźne różnice między jasnym myśliwcem, klinem Scouta, skrzydłami Lancera i blokową sylwetką Bastionu. Drobne nity i malowanie są najlepiej widoczne w ilustracji menu oraz w większych jednostkach. Niewielki Scout zachowuje czytelny kontur i kolor. Na zrzutach uruchomionej gry w 720×1280 główna akcja menu odcina się od ilustracji, podczas walki widać smugi napędu, pociski i punkty XP, a przyciemnienie areny pozostawia czytelne opisy trzech kart awansu.

Ilustracja myśliwca i jego sprite dzielą kolorystykę, podwójny napęd i charakterystyczną kabinę. Różni je dokładna geometria poszycia. Jeśli kolejne etapy wprowadzą hangar, wspólny model źródłowy pozwoli ujednolicić ujęcia z menu, walki i podglądu statku. Ocena czytelności pod kątem jasności i kontrastu na fizycznych telefonach pozostaje otwarta.

## Ocena etapu 2

W próbie kompozycji na docelowym tle oba okręty dowodzenia łatwo rozróżnić po proporcjach. Aegis jest smukły i ciężki w części rufowej, a Leviathan zajmuje szerokie pole z fioletowym rdzeniem pośrodku. Dron Strażnik zachowuje czytelną białą obudowę nawet przy niewielkiej skali. Światło i detale powierzchni przeznaczono do identyfikacji jednostek, a geometria ataków i sygnały faz mają prowadzić reakcję gracza w ruchu.

## Ocena etapu 3

W próbie kompozycji cztery statki dają rozróżnialne sylwetki zarówno w hangarze, jak i w skali 93 px na tle areny. Jasny Peregrine ma bardziej kanciasty obrys niż Aurora. Szerokie płyty Aegisa kontrastują z wąską igłą Spectera. Ciemne warianty korzystają z krawędziowego światła i jasnej kabiny, które pozostają widoczne między efektami napędu. Widok hangaru używa ujęcia statku z góry, zgodnie z widokiem w walce.
