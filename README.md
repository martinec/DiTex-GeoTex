# DiTex-GeoTex
> Electronic dictionaries (DELA) of toponyms using GeoNames DB

## Installation

- You need first to create the GeoNames.sqlite database, for that install sqlite3, e.g. under Debian or Ubuntu :

```
$ sudo apt-get install sqlite3  
```

Then,  type the following command to create de DB:

```
$ GeoNamesDB/bootstrap.sh
```

- In order to run the ```GeoTex.pl``` script you'll need a Perl environment with the following modules installed from your distro packages or from CPAN:

```
Text::Unaccent::PurePerl
DBI
GIS::Distance
DBD::SQLite
```

## Usage

```
Usage: ./GeoTex.pl <geonames.org sqlite database file> <dictionary type> [fr,en,...] [FR,US,...] [MIN_POPULATION]
 1: World Countries (+Country)
 2: Capitals Cities (+City+Capital)
 3: Cities with population >= 5000 (+City)
 4: Popular cities with population >= 5000 (+City)
 5: Regions with population>= 5000 (+Region)
 6: Lakes (+Hydronym+Lake)
 7: Mountains (+Oronym+Mountain)
 8: Roads (+Hodonym+Road)
 9: Universities (+Oikonym+University)
 10: Airports (+Oikonym+Airport)
 11: Administrative division (+Division)
```

## Example

```
./GeoTex.pl GeoNames.db 3 fr FR 0 > ditex/ditex-cities-fr.dic
```

```
...
Maisons-Laffitte,Maisons-Laffitte.N+Toponym+ISO=FR+LAT=48\.95264+LNG=2\.14521+GID=GNA2996564
Maisonsgoutte,Maisonsgoutte.N+Toponym+ISO=FR+LAT=48\.35294+LNG=7\.26246+GID=GNA2996565
Maisons-en-Champagne,Maisons-en-Champagne.N+Toponym+ISO=FR+LAT=48\.74801+LNG=4\.49851+GID=GNA2996566
Maisons-du-Bois-Lievremont,Maisons-du-Bois-Lievremont.N+Toponym+ISO=FR+LAT=46\.96667+LNG=6\.41667+GID=GNA2996567
Maisons du Bois Lievremont,Maisons-du-Bois-Lievremont.N+Toponym+ISO=FR+LAT=46\.96667+LNG=6\.41667+GID=GNA2996567
Maisons-du-Bois-Lièvremont,Maisons-du-Bois-Lievremont.N+Toponym+ISO=FR+LAT=46\.96667+LNG=6\.41667+GID=GNA2996567
Maisons-Alfort,Maisons-Alfort.N+Toponym+ISO=FR+LAT=48\.81171+LNG=2\.43945+GID=GNA2996568
Maison-Rouge,Maison-Rouge.N+Toponym+ISO=FR+LAT=48\.55875+LNG=3\.15065+GID=GNA2996572
Maison-Roland,Maison-Roland.N+Toponym+ISO=FR+LAT=50\.12755+LNG=2\.0218+GID=GNA2996575
...
```

## License

GeoTex is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License v3 or the
Perl Artistic License. GeoNames is licensed under a Creative Commons 
Attribution 3.0 License.
