# GeoTex
> Create electronic dictionaries (DELA) of toponyms using GeoNames DB

## Usage

```
Usage: GeoTex.pl <geonames.org sqlite database file> <dictionary type>
 1: World Countries (+Country)
 2: World Capitals Cities (+City+Capital)
 3: World Other Cities with population >= 5000 (+City)
 4: World Regions with population  >= 5*5000 (+Region)
 5: US Lakes (+Hydronym+Lake)
 6: US Mountains (+Oronym+Mountain)
 7: US Roads (+Hodonym+Road)
 8: World Universities (+Oikonym+University)
 9: World Airports (+Oikonym+Airport)
10: Administrative division (+Division)
```

## Example

```
./GeoTex.pl ./GeoNamesDB/GeoNames12.db 1 > examples/DiTex-WorldCountries.dic
```

```
...
Socialist Republic of Montenegro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=en+Uid=GN03194884
PeoplesRepublic of Montenegro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=+Uid=GN03194884
People's Republic of Montenegro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=+Uid=GN03194884
République du Monténégro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=fr+Uid=GN03194884
Crna Gora,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=sr+Uid=GN03194884
Montenegro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=de|en|es|it|pt|fr+Uid=GN03194884
Republika Crna Gora,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=|sr+Uid=GN03194884
Republic of Montenegro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=en+Uid=GN03194884
Republique du Montenegro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=fr+Uid=GN03194884
Monténégro,Montenegro.N+Toponym+Country+CountryISO=ME+Lat=42\.5+Lng=19\.3+Lang=fr+Uid=GN03194884
...
```

## License

GeoTex is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License v3 or the
Perl Artistic License. GeoNames is licensed under a Creative Commons 
Attribution 3.0 License. 


