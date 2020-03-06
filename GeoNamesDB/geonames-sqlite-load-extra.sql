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

.import ./extra/divisionInfo.txt tab_division

.import ./extra/alternateNames.txt tab_altname
