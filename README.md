# Bakje

Een simpele shelf voor macOS: leg bestanden tijdelijk in een bakje en sleep ze er later uit naar hun nieuwe plek.

## Bouwen

```sh
./build.sh            # bouwt naar build.noindex/Bakje.app
./build.sh --install  # zet hem in /Applications en start hem opnieuw
```

Nodig: de Swift-compiler (Xcode Command Line Tools). De Suisse Intl-font wordt bij het bouwen uit `~/Documents/Projecten/Servers/omelette-shop/static/fonts` gehaald en zit niet in deze repo.

## Wat het kan

- Bestanden erin via de notch, door te schudden tijdens het slepen, via het menubalk-icoon, op een open bakje of op Bakje.app.
- Compact stapeltje of uitgeklapt raster/lijst, sorteren, hernoemen, open met, Quick Look met spatie.
- Meerdere bakjes, onthouden na herstart, recente bakjes terughalen via het menubalk-menu.

`icon.swift` tekent het app-icoon; verwijder `AppIcon.icns` en bouw opnieuw om het te vernieuwen.
