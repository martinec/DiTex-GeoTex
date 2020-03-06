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
-- tab_geoname
--
CREATE TABLE IF NOT EXISTS tab_geoname (
  geoname_id          INTEGER NOT NULL PRIMARY KEY,
  geoname_name        VARCHAR(200),
  geoname_asciiname   VARCHAR(200),
  geoname_altername   VARCHAR(10000),
  geoname_lat         DECIMAL(10,7),
  geoname_lng         DECIMAL(10,7),
  geoname_fclass      CHAR(1),
  geoname_fcode       VARCHAR(10),
  country_iso         CHAR(2),
  geoname_altcod      VARCHAR(200),
  geoname_admin1      VARCHAR(20),
  geoname_admin2      VARCHAR(20),
  geoname_admin3      VARCHAR(20),
  geoname_admin4      VARCHAR(20),
  geoname_popult      INTEGER,
  geoname_elevat      INTEGER,
  geoname_dielev      INTEGER,
  geoname_timezn      VARCHAR(40),
  geoname_modate      DATE
);

CREATE INDEX IF NOT EXISTS IDX_FCLASS ON tab_geoname(geoname_fclass);
CREATE INDEX IF NOT EXISTS IDX_FCODE ON tab_geoname(geoname_fcode);
CREATE INDEX IF NOT EXISTS IDX_GISO2 ON tab_geoname(country_iso);
CREATE INDEX IF NOT EXISTS IDX_ADMIN1 ON tab_geoname(geoname_admin1);
CREATE INDEX IF NOT EXISTS IDX_ADMIN2 ON tab_geoname(geoname_admin2);
CREATE INDEX IF NOT EXISTS IDX_ADMIN3 ON tab_geoname(geoname_admin3);
CREATE INDEX IF NOT EXISTS IDX_ADMIN4 ON tab_geoname(geoname_admin4);


--
-- tab_altname
--
CREATE TABLE IF NOT EXISTS tab_altname (
  altname_id          INTEGER NOT NULL PRIMARY KEY,
  geoname_id          INTEGER,
  altname_lang        VARCHAR(7) DEFAULT NULL,
  altname_name        VARCHAR(400) DEFAULT NULL,
  altname_prefr       SMALLINT DEFAULT 0,
  altname_short       SMALLINT DEFAULT 0,
  altname_collq       SMALLINT DEFAULT 0,
  altname_histo       SMALLINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS IDX_GEONAME_ID ON tab_altname(geoname_id);
CREATE INDEX IF NOT EXISTS IDX_ALTNAME_LANG ON tab_altname(altname_lang);
CREATE INDEX IF NOT EXISTS IDX_ALTNAME ON tab_altname(altname_name);

--
-- tab_country
--
CREATE TABLE IF NOT EXISTS tab_country (
  country_iso         CHAR(2),
  country_iso3        CHAR(3),
  country_isonum      INTEGER,
  country_fipscod     VARCHAR(3),
  country_name        VARCHAR(200),
  country_capital     VARCHAR(200),
  country_areaskm     DOUBLE,
  country_popult      INTEGER,
  continent_code      CHAR(2),
  country_tld         CHAR(3),
  country_currcode    CHAR(3),
  country_currname    CHAR(20),
  country_phonecod    CHAR(10),
  country_poscodformt CHAR(20),
  country_poscodregex CHAR(20),
  country_languages   VARCHAR(200),
  geoname_id          INTEGER,
  country_neighbours  CHAR(20),
  country_eqfipscode  CHAR(10)
);
CREATE INDEX IF NOT EXISTS IDX_CISO ON tab_country(country_iso);
CREATE INDEX IF NOT EXISTS IDX_CGID on tab_country(geoname_id);

--
-- tab_division
--
CREATE TABLE IF NOT EXISTS tab_division (
  country_iso         CHAR(2),
  division_iso        CHAR(6) NOT NULL PRIMARY KEY,
  division_name       VARCHAR(200),
  division_asciiname  VARCHAR(200),
  geoname_fclass      CHAR(1),
  geoname_fcode       VARCHAR(10),  
  geoname_id          INTEGER
);

CREATE INDEX IF NOT EXISTS IDX_DCISO on tab_division(country_iso);
CREATE INDEX IF NOT EXISTS IDX_DGID on tab_division(geoname_id);

--
-- tab_language
--
CREATE TABLE IF NOT EXISTS tab_language(
  language_iso3       CHAR(4),
  language_iso2       VARCHAR(50),
  language_iso1       VARCHAR(50),
  language            VARCHAR(200)
);

--
-- tab_admin1
--
CREATE TABLE IF NOT EXISTS tab_admin1 (
  admin1_code         VARCHAR(23),
  admin1_name         TEXT,
  admin1_asciiname    TEXT,
  geoname_id          INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS IDX_ADMIN1_CODE ON tab_admin1(admin1_code);
CREATE INDEX IF NOT EXISTS IDX_ADMIN1  ON tab_admin1(admin1_name);
CREATE INDEX IF NOT EXISTS IDX_ADMIN1_ASCII  ON tab_admin1(admin1_asciiname);
CREATE INDEX IF NOT EXISTS IDX_ADMIN1_GID ON tab_admin1(geoname_id);


--
-- tab_admin2
--
CREATE TABLE IF NOT EXISTS tab_admin2 (
  admin2_code         VARCHAR(104),
  admin2_name         TEXT,
  admin2_asciiname    TEXT,
  geoname_id          INTEGER NOT NULL 
);

CREATE INDEX IF NOT EXISTS IDX_ADMIN2_CODE ON tab_admin2(admin2_code);
CREATE INDEX IF NOT EXISTS IDX_ADMIN2  ON tab_admin2(admin2_name);
CREATE INDEX IF NOT EXISTS IDX_ADMIN2_ASCII  ON tab_admin2(admin2_asciiname);
CREATE INDEX IF NOT EXISTS IDX_ADMIN2_GID ON tab_admin2(geoname_id);

--
-- tab_fcode
--
CREATE TABLE IF NOT EXISTS tab_fcode (
  fcode              CHAR(7),
  fcode_name         VARCHAR(200),
  fcode_desc         TEXT
);

--
-- tab_hierarchy
--
CREATE TABLE IF NOT EXISTS tab_hierarchy (
  hierarchy_pid     INTEGER,
  hierarchy_cid     INTEGER,
  hierarchy_type    CHAR(7)
);


--
-- tab_timezone
--
CREATE TABLE IF NOT EXISTS tab_timezone (
  country_iso      CHAR(2),
  timezone_id       VARCHAR(200),
  timezone_igm      DECIMAL(3,1),
  timezone_dst      DECIMAL(3,1),
  timezone_raw      DECIMAL(3,1)
);

--
-- tab_continent
--
CREATE TABLE IF NOT EXISTS tab_continent (
  continent_code CHAR(2),
  continent_name VARCHAR(20),
  geoname_id     INTEGER NOT NULL PRIMARY KEY
);


CREATE TABLE IF NOT EXISTS tab_postalcode(
  country_iso         CHAR(2),
  postalcode          VARCHAR(20),
  geoname_name        VARCHAR(200),
  admin1_name         TEXT,
  geoname_admin1      VARCHAR(20),
  admin2_name         TEXT,
  geoname_admin2      VARCHAR(80),
  admin3_name         TEXT,
  geoname_admin3      VARCHAR(20),
  postalcode_lat      DECIMAL(10,7),
  postalcode_lng      DECIMAL(10,7),
  postalcode_acc      SMALLINT
);

CREATE INDEX IF NOT EXISTS IDX_PISO2 ON tab_postalcode(country_iso);
CREATE INDEX IF NOT EXISTS IDX_POSTALCODE ON tab_postalcode(postalcode);
CREATE INDEX IF NOT EXISTS IDX_GEONAME ON tab_postalcode(geoname_name);
CREATE INDEX IF NOT EXISTS IDX_PADMIN1 ON tab_postalcode(admin1_name);
CREATE INDEX IF NOT EXISTS IDX_PGADMIN1 ON tab_postalcode(geoname_admin1);
CREATE INDEX IF NOT EXISTS IDX_PADMIN2 ON tab_postalcode(admin2_name);
CREATE INDEX IF NOT EXISTS IDX_PGADMIN2 ON tab_postalcode(geoname_admin2);
CREATE INDEX IF NOT EXISTS IDX_PADMIN3 ON tab_postalcode(admin3_name);
CREATE INDEX IF NOT EXISTS IDX_PGADMIN3 ON tab_postalcode(geoname_admin3);
CREATE INDEX IF NOT EXISTS IDX_PLAT ON tab_postalcode(postalcode_lat);
CREATE INDEX IF NOT EXISTS IDX_PLONG ON tab_postalcode(postalcode_lng);
