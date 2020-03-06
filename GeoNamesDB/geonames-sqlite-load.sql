-- ======================================================================  
-- geonames-sqlite.sql : Script for creating tables from geonames.org
-- ======================================================================  
-- V 1.2  2017 by Cristian Martinez <me@martinec.org>
-- ======================================================================

-- SQLite--------------------B
   PRAGMA encoding = "UTF-8"; 
   PRAGMA default_synchronous = OFF;
   PRAGMA foreign_keys = OFF;
   PRAGMA journal_mode = MEMORY;
   PRAGMA cache_size = 800000;
-- SQLite--------------------E

--
-- Imports SQLite
--
.separator "\t"

.import ./db/allCountries.txt tab_geoname

.import ./db/alternateNames.txt tab_altname

.import ./db/iso-languagecodes.txt tab_language

.import ./db/admin1CodesASCII.txt tab_admin1

.import ./db/admin2Codes.txt tab_admin2

.import ./db/featureCodes_en.txt tab_fcode

.import ./db/hierarchy.txt tab_hierarchy

.import ./db/timeZones.txt tab_timezone

.import ./db/countryInfo.txt tab_country

.import ./db/continentCodes.txt tab_continent

.import ./db/allPostalCodes.txt tab_postalcode

--LOAD DATA INFILE './db/allCountries.txt' 
          --INTO TABLE tab_geoname
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './db/alternateNames.txt' 
          --INTO TABLE tab_altname
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './db/iso-languagecodes.txt' 
          --INTO TABLE tab_language
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './db/admin1CodesASCII.txt' 
          --INTO TABLE tab_admin1
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './db/admin2Codes.txt' 
          --INTO TABLE tab_admin2
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './db/featureCodes_en.txt' 
          --INTO TABLE tab_fcode
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './db/hierarchy.txt' 
          --INTO TABLE tab_hierarchy
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './db/timeZones.txt' 
          --INTO TABLE tab_timezone
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';
          
--LOAD DATA INFILE './db/countryInfo.txt' 
          --INTO TABLE tab_country
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './db/continentCodes.txt' 
          --INTO TABLE tab_continent
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';                                 
