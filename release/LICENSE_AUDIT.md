# Weryfikacja zasobów wydania 0.6.1

| Zasoby | Pochodzenie i wynik | Warunki w paczce |
| --- | --- | --- |
| Statki gracza, przeciwnicy i dron | Tekstury powstały dla projektu. Historia i opisy w repo obejmują wygenerowanie arkuszy, wycięcie sylwetek i korektę alfy. | Ewidencja projektu i właściciela. [Pochodzenie grafiki](../ART_DIRECTION.md) |
| Menu, hangar, mgławica, ikona i grafika promocyjna | Ilustracje pochodzą z zapisanej historii projektu. Nowa ikona 512 × 512 i banner 1024 × 500 wykorzystują istniejące ilustracje i sylwetkę Peregrine. | Grafika promocyjna korzysta z Oxanium. Licencja fontu pozostaje przy źródłach. [Pochodzenie grafiki](../ART_DIRECTION.md) |
| 19 efektów WAV i 2 podkłady OGG | Niezależnie uruchomiono generator z repozytorium. WAV są identyczne bajtowo. Dekodowany PCM obu plików OGG jest identyczny. | CC0 1.0. [Oświadczenie o pochodzeniu](../assets/audio/PROVENANCE.md) · [Kod syntezy](../audio/render_scores.py) |
| Oxanium i Barlow Medium | Metadane obu fontów wskazują SIL OFL 1.1. Pliki są identyczne bajtowo z pobranymi z katalogu Google Fonts. | Zachowano oba teksty OFL. [OFL Oxanium](../assets/fonts/Oxanium-OFL.txt) · [OFL Barlow](../assets/fonts/Barlow-OFL.txt) |
| Godot 4.7.2 stable | Pochodzenie z oficjalnej dystrybucji. Presety eksportu przenoszą informacje licencyjne do paczki. | MIT oraz wykaz składników. [Licencja](../licenses/Godot-LICENSE.txt) · [Komponenty](../licenses/Godot-COPYRIGHT.txt) |
| Mobile Ads, UMP i Billing | Zależności Gradle z Google Maven. W APK zweryfikowano obecność kodu trzech SDK. Usługi podlegają warunkom Google i konfiguracji właściciela. | [Zasady AdMob](https://support.google.com/admob/answer/6128543) · [Warunki deweloperskie Google Play](https://play.google.com/about/developer-distribution-agreement.html) · [Wersje zależności](../android/bridge/galaxy.gradle) |

Audyt potwierdza spójność zasobów z pochodzeniem zapisanym w repozytorium, plikami źródłowymi i dołączonymi licencjami. Prawa operatora do korzystania z wygenerowanych ilustracji i nazwy produktu powinny zostać udokumentowane przez właściciela w dokumentacji dystrybucji. Zasoby przygotowane do karty sklepu korzystają z tych samych źródeł, a zrzuty pokazują rzeczywisty render gry.
