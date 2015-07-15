-- ======================================================================  
-- geonames-sqlite.sql : Script for creating tables from geonames.org
-- ======================================================================  
-- V 1.1  2012 by Cristian Martinez <me-at-martinec.org>
-- You can redistribute and/or modify this under the terms of the WTFPL
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

.import ./allCountries.txt tab_geoname

.import ./alternateNames.txt tab_altname

.import ./iso-languagecodes.txt tab_language

.import ./admin1CodesASCII.txt tab_admin1

.import ./admin2Codes.txt tab_admin2

.import ./featureCodes_en.txt tab_fcode

.import ./hierarchy.txt tab_hierarchy

.import ./timeZones.txt tab_timezone

.import ./countryInfo.txt tab_country

.import ./divisionInfo.tsv tab_division

.import ./continentCodes.txt tab_continent

.import ./allPostalCodes.txt tab_postalcode

--LOAD DATA INFILE './allCountries.txt' 
          --INTO TABLE tab_geoname
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './alternateNames.txt' 
          --INTO TABLE tab_altname
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './iso-languagecodes.txt' 
          --INTO TABLE tab_language
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './admin1CodesASCII.txt' 
          --INTO TABLE tab_admin1
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './admin2Codes.txt' 
          --INTO TABLE tab_admin2
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './featureCodes_en.txt' 
          --INTO TABLE tab_fcode
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';


--LOAD DATA INFILE './hierarchy.txt' 
          --INTO TABLE tab_hierarchy
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './timeZones.txt' 
          --INTO TABLE tab_timezone
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';
          
--LOAD DATA INFILE './countryInfo.txt' 
          --INTO TABLE tab_country
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';

--LOAD DATA INFILE './continentCodes.txt' 
          --INTO TABLE tab_continent
          --FIELDS TERMINATED BY '\t' 
          --LINES TERMINATED BY '\n';                                 
