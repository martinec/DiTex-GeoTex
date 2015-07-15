# allCountries.zip
wget -N http://download.geonames.org/export/dump/allCountries.zip 
rm allCountries.txt
unzip allCountries.zip
rm  allCountries.zip
#sed -i '/\x27/s/"/\x27\x27/g'  allCountries.txt
#sed -i '/”/s/"/\x27\x27/g'  allCountries.txt
#sed -i '/[^\t]*"[^\t]*[^\t]*"/s/"/\x27\x27/g' allCountries.txt
#sed -i '/"/s/"/\x27\x27/g'  allCountries.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' allCountries.txt

# alternateNames.zip
wget -N http://download.geonames.org/export/dump/alternateNames.zip
rm alternateNames.txt
unzip alternateNames.zip
rm alternateNames.zip
#sed -i '/\x27/s/"/\x27\x27/g' alternateNames.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' alternateNames.txt

# iso-languagecodes
# wget -N http://download.geonames.org/export/dump/iso-languagecodes.txt
sed -i '1d' iso-languagecodes.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' iso-languagecodes.txt

# admin1CodesASCII
wget -N http://download.geonames.org/export/dump/admin1CodesASCII.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' admin1CodesASCII.txt

# admin2Codes
wget -N http://download.geonames.org/export/dump/admin2Codes.txt
#sed -i '/\x27/s/"/\x27\x27/g' admin2Codes.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' admin2Codes.txt

# featureCodes_en
wget -N http://download.geonames.org/export/dump/featureCodes_en.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' featureCodes_en.txt

# hierarchy
wget -N http://download.geonames.org/export/dump/hierarchy.zip
rm hierarchy.txt
unzip hierarchy.zip
rm hierarchy.zip
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' hierarchy.txt

# timeZones
wget -N http://download.geonames.org/export/dump/timeZones.txt
sed -i '1d' timeZones.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' timeZones.txt

# countryInfo
wget -N -O countryData.txt http://download.geonames.org/export/dump/countryInfo.txt 
cat countryData.txt | grep -v "^#" > countryInfo.txt
rm countryData.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' countryInfo.txt


# continentCodes
echo -e "AF\tAfrica\t6255146
AS\tAsia\t6255147
EU\tEurope\t6255148
NA\tNorth America\t6255149
OC\tOceania\t6255151
SA\tSouth America\t6255150
AN\tAntarctica\t6255152" > continentCodes.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' continentCodes.txt

# postal codes
wget -N -O allPostalCodes.zip http://download.geonames.org/export/zip/allCountries.zip  
unzip allPostalCodes.zip -d /tmp
mv /tmp/allCountries.txt ./allPostalCodes.txt
sed -i 's/"/""/g ; s/^/\"/ ; s/$/\"/ ; s/\t/\"\t\"/g' allPostalCodes.txt
rm allCountries.zip

rm GeoNames12.db
sqlite3 GeoNames12.db < geonames-sqlite_scheme.sql 
sqlite3 GeoNames12.db < geonames-sqlite_load.sql
