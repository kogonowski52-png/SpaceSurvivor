# Materiały karty Google Play · 1.3.0-rc1

| Plik | Parametry |
| --- | --- |
| `icon-512.png` | 512 × 512, PNG RGBA. Zachowana ikona wyrzutni z myśliwcem Peregrine. |
| `pl-PL/feature-1024x500.jpg` | 1024 × 500, JPEG RGB. Grafika promocyjna z podtytułem „Próg Helionu”. |
| `en-US/feature-1024x500.jpg` | 1024 × 500, JPEG RGB. Grafika promocyjna z podtytułem „The Helion Gate”. |
| `pl-PL/screenshots/01–08` i `en-US/screenshots/01–08` | Po 8 zdjęć telefonu 1080 × 1920, JPEG RGB, w kolejności do przesłania. |
| `pl-PL/alternatives/09-equipment.jpg` i odpowiednik EN | Zrzut ekwipunku do zastąpienia dowolnego miejsca w galerii. |
| `raw-frames.sha256` | Sumy kontrolne dziewięciu źródłowych klatek PNG w paczce QA. |
| `source/feature-backdrop.webp` | Tło robocze grafiki promocyjnej. Katalog źródłowy wystarcza do odtworzenia kompozycji. |

Pierwsze pięć obrazów pokazuje walkę, rozwinięte uzbrojenie i trzy starcia z bossami. Następne pokazują hangar, mapę ukończonej kampanii i warsztat. Jeśli chcesz wyróżnić wyposażenie, zamień nim jedno z ośmiu miejsc. Oryginalne klatki zachowano w paczce dowodowej.

Wszystkie klatki przechwycono w uruchomionej grze. Automatyczny pilot przeszedł pełną kampanię, rozwijał kadłub i wyposażenie za zdobyte środki, a klatki bossów pochodzą z aktywnych faz walki. W plikach Google Play zrzut jest proporcjonalnie zmniejszony w całości i ma lokalny podpis w wąskim pasie nad klatką. Interfejs w obu wersjach pozostał polski zgodnie z rzeczywistą wersją gry.

Grafika promocyjna to kompozycja z faktycznych tekstur Nadira i Peregrine oraz tła przygotowanego dla projektu generatorem obrazu. Pismo Oxanium pochodzi z zasobów gry i ma dołączoną licencję OFL. [Pochodzenie tekstur](../../../ART_DIRECTION.md) · [Licencja Oxanium](../../../assets/fonts/Oxanium-OFL.txt)

Odtworzenie plików z oryginalnych PNG. [Skrypt materiałów](../../../tools/render_play_assets.py) · [Próba rozgrywki](../../../tests/play_listing_capture.gd) · [Specyfikacja zasobów Google Play](https://support.google.com/googleplay/android-developer/answer/9866151)
