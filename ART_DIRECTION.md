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

- Ilustracja menu i mgławica areny powstały dla tego projektu z użyciem generatora obrazów. Ilustrację menu w etapie 4 opracowano na podstawie ortogonalnego sprite’a Peregrine i kompozycji pierwszej ilustracji. Obie tekstury zapisano w JPEG.
- Cztery statki wygenerowano razem w spójnej stylistyce. Każdy ma oddzielną teksturę PNG z oczyszczoną alfą i dłuższą krawędzią 320 px. Metalowe poszycie, otwory wentylacyjne, kabiny i światła są częścią tekstur. Jasność i ruch napędu oraz trafień są rysowane w Godot.
- Sześć jednostek etapu 2 powstało w dwóch nowych arkuszach dla tej gry. Z arkuszy wycięto pojedyncze tekstury PNG, oczyszczono krawędzie alfy i dobrano rozdzielczości do różnych rozmiarów jednostek na arenie. Statki wykorzystują filtrowanie z mipmapami, które ogranicza migotanie detali w ruchu.
- Trzy statki gracza i wnętrze hangaru etapu 3 powstały w osobnych materiałach dla tej gry. Tekstury statków mają oczyszczone krawędzie alfy. Hangar pokazuje Peregrine z pierwotnej grafiki w większej rozdzielczości niż tekstura bojowa, która pozostała bez zmian.
- Ikona gry, glify i efekty dźwiękowe powstały w tym projekcie. Dźwięki są syntetyzowane bez zewnętrznych próbek. [Licencje typografii](assets/fonts/README.md)

## Ocena etapu 1

Próba statków złożonych na tle areny w skali 46–80 px pokazała wyraźne różnice między jasnym myśliwcem, klinem Scouta, skrzydłami Lancera i blokową sylwetką Bastionu. Drobne nity i malowanie są najlepiej widoczne w ilustracji menu oraz w większych jednostkach. Niewielki Scout zachowuje czytelny kontur i kolor. Na zrzutach uruchomionej gry w 720×1280 główna akcja menu odcina się od ilustracji, podczas walki widać smugi napędu, pociski i punkty XP, a przyciemnienie areny pozostawia czytelne opisy trzech kart awansu.

Pierwsza ilustracja myśliwca dzieliła ze sprite’em podwójny napęd i kabinę, ale różniła się geometrią poszycia. Ocena czytelności pod kątem jasności i kontrastu na fizycznych telefonach pozostaje otwarta.

## Ocena etapu 2

W próbie kompozycji na docelowym tle oba okręty dowodzenia łatwo rozróżnić po proporcjach. Aegis jest smukły i ciężki w części rufowej, a Leviathan zajmuje szerokie pole z fioletowym rdzeniem pośrodku. Dron Strażnik zachowuje czytelną białą obudowę nawet przy niewielkiej skali. Światło i detale powierzchni przeznaczono do identyfikacji jednostek, a geometria ataków i sygnały faz mają prowadzić reakcję gracza w ruchu.

## Ocena etapu 3

W próbie kompozycji cztery statki dają rozróżnialne sylwetki zarówno w hangarze, jak i w skali 93 px na tle areny. Jasny Peregrine ma bardziej kanciasty obrys niż Aurora. Szerokie płyty Aegisa kontrastują z wąską igłą Spectera. Ciemne warianty korzystają z krawędziowego światła i jasnej kabiny, które pozostają widoczne między efektami napędu. Widok hangaru używa ujęcia statku z góry, zgodnie z widokiem w walce.

## Ocena etapu 4

Ilustracja menu pokazuje Peregrine pod kątem, z odtworzonymi białymi grodziami rufowymi, granatowymi skrzydłami, wydłużoną cyjanową kabiną i parą prostokątnych wylotów. Zachowano ciemny obszar na tekst przy górnej i dolnej krawędzi oraz łuk atmosfery za sylwetką. Menu używa ilustracji referencyjnej. W hangarze i walce kształt pochodzi z tej samej grafiki ortogonalnej, w dwóch rozdzielczościach.

W nowych wariantach referencyjnych Razora i Widma lepiej widać stalowe krawędzie skrzydeł oraz podział grafitowych i bordowych płyt. W statycznym porównaniu na tle areny przy wysokościach 58 i 99 px obie jednostki zachowują wcześniejsze sylwetki i charakterystyczne kolory kabin. Tekstury zachowały kanał alfa i mipmapy. Ocena materiałów i sygnałów poprzedzających ataki w ruchu przy niskiej jasności wymaga próby na fizycznym telefonie.

## Dopracowanie 0.7.1

- Scout, Razor i Widmo otrzymały matowy granatowy podrys i cienką krawędź w kolorze klasy, wypalone do tekstury z istniejącego kadłuba. W walce efekty dekoracyjne słabną przy statku pilota, a ostrzeżenia bossów trafiają nad eskortę. Pociski i animowana wiązka korzystają z jednego wypalonego atlasu oświetlenia. [Generator obrysu](tools/bake_enemy_rims.gd) · [Generator atlasu](tools/bake_flight_lights.gd)
- Hangar używa kadru istniejącej hali, większych miniatur i animowanego odbicia na teksturach czterech statków. Odbicie ogranicza się do sylwetki kadłuba. W wyposażeniu hierarchię rozdzielają gniazda bieżącego statku, wartości, opisy i magazyn.
- Ilustracje zasobnika, kontenera i rdzenia Crystals oraz pięciu klas wyposażenia wygenerowano dla tej wersji. Tekstury WebP w `assets/art/crystals/` i `assets/art/modules/` zachowują przezroczystość. Wizualizacje wyposażenia pokazują typ modułu. Jego nazwę, rzadkość i efekt określa karta nagrody. Fiolet odróżnia Epic, a ciepły metal i większa ilustracja podkreślają Legendary.

## Kampania Próg Helionu

Pole lotu 9:16 używa trzech nowych teł przygotowanych dla tego projektu. Chłodny pierścień w Echu pasa prowadzi wzrok ku polu formacji. Pył i fioletowe światło Załamania Pryzmatu odróżniają spiralę i srebrne eskadry. Bursztynowe obrzeża Progu Helionu cofają się przed sylwetką okrętu dowodzenia. Jaśniejsze detale teł znajdują się przede wszystkim poza torem statku. Dwie warstwy gwiazd i powolne przewijanie mgławic nadają scenom ruch.

| Rola | Kolor | Użycie |
| --- | --- | --- |
| Echo pasa | `#6FE5F2` | Krawędzie pierścienia, akcent karty etapu |
| Załamanie Pryzmatu | `#BEABFF` | Pył, karta etapu i oprawa modułu wiązki |
| Próg Helionu | `#FFBC86` | Horyzont, karta etapu i metal Asteriona |
| Zagrożenie | `#FF938B` | Pociski wroga i oznaczenia niebezpiecznych pasów |

- Peregrine, Scout, Razor i kadłub użyty dla Wardena pochodzą z własnych zasobów 0.7.1. Matowy obrys wrogów i punktowe światło wspierają rozpoznawanie sylwetek na różnych tłach.
- Asterion ma oryginalną teksturę WebP z kanałem alfa. Opracowano ją jako widok od góry z dwiema rozsuniętymi bateriami, centralnym rdzeniem i grafitowym pancerzem. Okręt rozpada się na osobno animowane fragmenty poszycia i krótkie rozbłyski.
- Ilustrację Asteriona i trzy tła przygotowano dla tej gry przy pomocy generatora obrazów. Tła wykadrowano i zapisano jako JPEG. Pozostałe zasoby, dźwięki i typografia zachowują opisane wyżej pochodzenie.
- Obszar walki ma czytelny kierunek. Przyjazny ogień rozróżniają pociski świetlne, plazma, złote ślady rakiet i fioletowa wiązka. Efekty trafienia są krótkie. Ostrzeżenie o kurtynie pokazuje granice zagrożonych pasów jeszcze przed strzałem.
- U góry pola są nazwa etapu, numer fali i pasek bossa. Kadłub oraz tryb i ranga broni znajdują się w dolnym HUD. Wspólna typografia i panele łączą kampanię z istniejącym hangarem i sklepem.

Ocena czytelności w ruchu, kontrastu na ekranie telefonu i jakości dźwięku na głośniku wymaga fizycznego urządzenia. [Weryfikacja obrazu i ograniczenia](VERSION_VERTICAL_0_8_0_DEV.md)
