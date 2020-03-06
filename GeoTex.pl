#!/usr/bin/perl -w
# ======================================================================
# geo2dic v1.1.0 - Geonames.org to DiTex DELAF GeoTex
# Converts a geonames SQLite database to Unitex DELA format
# ======================================================================
# This script is free software; you can redistribute it and/or modify it
# under the terms of either: the GNU General Public License v3 or the
# Perl Artistic License.
# ======================================================================
# Copyright 2011, by Cristian Martinez <me-at-martinec.org>
# ======================================================================
use strict;
use warnings;
use Text::Unaccent::PurePerl qw(unac_string);
use Scalar::Util qw(looks_like_number);
# ======================================================================
use utf8;                              # Enables to type utf8 in program code
use open        ':encoding(utf8)';     # input and output streams legacy utf8
use open        ':std';                # STDIN(utf8), STDOUT(utf8), STDERR(utf8)
# ======================================================================
use List::MoreUtils qw(uniq);
# ======================================================================
use DBI;
use feature qw{ switch };
use Switch;
# ======================================================================
use Data::Dumper;
# ======================================================================
use GIS::Distance;
my $min_distance_kilometers = 9000 / 1000; # kilometers
my $max_match_score = 8;
my $gis = GIS::Distance->new();
use constant true  => 1;
use constant false => 0;
# ======================================================================
# Constants
# ======================================================================
#
use constant mSemantic  => "N+Toponym"; # General information

# ======================================================================
# Fine-grained configurations
# ======================================================================
# 5000
my $min_population      = 5000;    # default minimal population (inclusive)
my $use_langages        = "en";    # comma separated list of languages to use
my @use_langages_list   = ('en');  # list of language to use
my $use_countries       = "";      # list of countries to use
my $use_country_langage = 0;       # use also the national language of the country
my $print_hierarchy     = 0;       # print or not R1, R2, R3, R4 codes
my $print_postal_code   = 0;       # print or not PC codes
my $min_toponym_length  = 1;       # minimal length of a toponym
my $default_langage     = "";      # defined at runtime
my $gid_format          = "GNA%d"; # default GID format is GeoNAmes

# ======================================================================
# Dictionary contents
# ======================================================================
my $PL_S      = "+";      # Plus
my $SP_S      = ",";      # Sep Symbol
my $CO_S      = ":";      # Colon
my $SL_S      = "/";      # Slash
my $ES_S      = "\\";     # Escape Symbol
my $NL_S      = "\n";     # New Line Symbol
my $DT_S      = ".";      # Dot Symbol
my $HY_S      = "=";      # Hypen Symbol

# ======================================================================
# General
# ======================================================================
#
use constant gLAT      => "+LAT=";      # Latitude
use constant gLONG     => "+LNG=";      # Longitude
use constant gACC      => "+AC=";       # Accuracy of lat/lng from 1=estimated to 6=centroid
use constant gLang     => "+LANG=";     # Language
use constant gID       => "+GID=";      # Identifier
use constant gPCod     => "+PC=";       # Postal code
use constant gADM1     => "+R1=";       # Region1
use constant gADM2     => "+R2=";       # Region2
use constant gADM3     => "+R3=";       # Region3
use constant gADM4     => "+R4=";       # Region4
# ======================================================================
# Country stuff
# ======================================================================
#
use constant mCountry => "+Country";    # Country
use constant gCISO    => "+ISO=";        # ISO 3166-1 alpha-2 country code,
# ======================================================================
# Region
# ======================================================================
#
use constant mRegion   => "+Region";       # Region
use constant gRISO     => "+RegionIso=";   # ISO 3166-2 alpha-6 region code
# ======================================================================
# Capital and city stuff
# ======================================================================
use constant mCity          => "+City";       # City
use constant mCapital       => "+Capital";    # Capital
use constant mPopulated     => "+Populated";  # Populated place
use constant mDivion        => "+Division";   # Populated place
# ======================================================================
# UTF-8
# ======================================================================
#
#use open ':encoding(utf8)';
#binmode(STDOUT, ":encoding(utf8)");
#binmode(STDERR, ":encoding(utf8)");
#binmode(STDIN,  ":encoding(utf8)");
use utf8;           # enables to type utf8 in program code
use open ':encoding(utf8)';   # input and output streams legacy utf8
use open ':std';        # STDIN, STDOUT, STDERR to comply with utf8
# ======================================================================
my $sqlAlternateNames;
my $sthAlternateNames;
my $sqlAdmin1;
my $sthAdmin1;
my $sqlAdmin2;
my $sthAdmin2;
my $sqlAdmin3;
my $sthAdmin3;
my $sqlAdmin4;
my $sthAdmin4;
my $sqlPostalCode;
my $sthPostalCode;
#my $sqlAltPostalCode;
#my $sthAltPostalCode;
my $sqlClosestPostalCode;
my $sthClosestPostalCode;
# ======================================================================
# Functions
# ======================================================================
#
# ======================================================================
sub normalize($){
 my $str = shift;
 $str =~ s/^\s+//g;             # ltrim
 $str =~ s/\s+$//g;             # rtrim
 $str =~ s/-/ /g;               # replace - by space
 $str =~ s/$SP_S//g;            # remove ,
 $str =~ s/\.//g;               # remove .
 $str =~ s/$HY_S//g;            # remove =
 $str =~ s/['’‘`]([^\s])(\s|$)/$1/g;  # replace '[a-z] by [a-z]
 $str =~ s/['’‘`]/ /g;          # replace ' by space
 $str =~ s/\s+/ /g;             # collapse multiple spaces
 $str =~ s/[[:cntrl:]]//gi;     # remove control characters
 my $unac = unac_string($str);  # unaccent
}
# ======================================================================
sub fingerprint($){
 my $str = shift;
 my $unac = unac_string(normalize($str));  # unaccent
}
# ======================================================================
# escape_str: escape strings for compatibility with DELAF format
sub escape_str($){
  my $str = shift;
  $str =~ s/^\s+//g;             # ltrim
  $str =~ s/\s+$//g;             # rtrim
  $str =~ s/’/'/g;               # ’ by '

  $str =~ s/\+/$ES_S$PL_S/g;     # Replace + by \+
  $str =~ s/$SP_S/$ES_S$SP_S/g;  # Replace , by \,
  $str =~ s/$CO_S/$ES_S$CO_S/g;  # Replace : by \:
  $str =~ s/$SL_S/$ES_S$SL_S/g;  # Replace / by \/
  $str =~ s/\./$ES_S$DT_S/g;     # Replace . by \.
  $str =~ s/$HY_S/$ES_S$HY_S/g;  # Replace = by \=

  $str =~ s/\s+/ /g;             # collapse multiple spaces

  return $str;
}
# ======================================================================
# escape_num: escape numbers for compatibility with DELAF format
sub escape_num($){
   my $str = shift;
   $str =~ s/\./$ES_S\./g;  # Replace . by \.
   $str =~ s/\,/$ES_S\,/g;  # Replace , by \,
   $str =~ s/\+/$ES_S\+/g;  # Replace + by \+
   return $str;
}

# ======================================================================
sub is_valid_name($) {
  my $name = shift;
  return 0 if ($name =~ /\p{P}/  and # disallow all punctuation
               $name !~ /\p{Pd}/ and # but allow dashes (-)
               $name !~ /[&.]/);     # ampersands (&) and dots (.)
  return 1;
}
# ======================================================================
# getCountryLang:
sub getCountryLang($){
  my $langs = shift;
  if(defined $langs and length($langs)>0 and $use_country_langage == 1) {
    return substr $langs, 0, 2;   # returns the two firsts characters
  } else {
    return $default_langage;
  }
}
# ======================================================================
# getAlternateNames:
sub getAlternateNames($$$){
  my $id      = shift;
  my $lng     = shift;
  my $entries = shift;

  $sthAlternateNames->execute($id,$lng) || die $DBI::errstr;
  
  # gat all altames with lang group
  while (my $row = $sthAlternateNames->fetchrow_hashref){
    my $altname = $row->{altname_name};
    # if altname has latin codepage characters
    if($altname =~ /\p{Latin}/){
      

      # continue if altname contains Punctuation (P) chars with the exception of dashes (Pd) and apersand (&)
      next if (!is_valid_name($altname));

      # add lang group to name that is already in hash
      $entries->{$altname} =   defined  $entries->{$altname} ?
           $entries->{$altname} ."," . $row->{altname_group_lang}  :
           defined $row->{altname_group_lang} ? $row->{altname_group_lang} : 'en' . ',' . $lng ;
      # split by , sort and join by |
      if(defined  $entries->{$altname}){
        my @langs = split(/,/, $entries->{$altname});
        $entries->{$altname} = join(";", uniq(sort(@langs)));
      }

      # generate alternative fingerprint name from alternative name
      my $fpaltname = fingerprint($altname);
      # if finger name is diferent from alternative name
      if($altname ne $fpaltname) {
        # add lang group to name that is already in hash
        $entries->{$fpaltname} = defined $entries->{$fpaltname} ?
             $entries->{$fpaltname} ."," . $row->{altname_group_lang} :
             defined $row->{altname_group_lang} ? $row->{altname_group_lang} : 'en' ;
         # split by , sort and join by |
        if(defined  $entries->{$fpaltname}){
           my @fplangs = split(/,/, $entries->{$fpaltname});
           $entries->{$fpaltname} = join(";", uniq(sort(@fplangs)));
        }
      }

    }
  }

  #print Dumper($entries);
  return $entries;
}
# ======================================================================
# dic_WorldCountries:
sub dic_WorldCountries($){
  my $dbh = shift;
  # get country info
  my $sql = "SELECT * from tab_country as c , tab_geoname as g
             WHERE c.geoname_id = g.geoname_id ";
  my $sth = $dbh->prepare($sql) || die $DBI::errstr;
  $sth->execute || die $DBI::errstr;
# my $rep = $sth->fetchrow_hashref;
  my $country;
  my $language;
  my $bSemantic;
  my $lat;
  my $lng;
  my $id;
  my %entries = ();
  while (my $c = $sth->fetchrow_hashref) {
       $id        = sprintf($gid_format,$c->{geoname_id}) ;
       $country   = $c->{country_name};

       $language  = getCountryLang($c->{country_languages});

       $lat       = $c->{geoname_lat};
       $lng       = $c->{geoname_lng};

       $bSemantic =  $DT_S  .
               mSemantic .
               mCountry  .
               gCISO  . $c->{country_iso} .
               gLAT  . escape_num($c->{geoname_lat})  .
               gLONG . escape_num($c->{geoname_lng});

       if ($language =~ /en/) {
          if (is_valid_name($country)) {
           $entries{$country} = 'en';
           $entries{fingerprint($country)}  = 'en';
          }

          if (is_valid_name($c->{geoname_name})) {
           $entries{$c->{geoname_name}}  = 'en';
           $entries{fingerprint($c->{geoname_name})}  = 'en';
          }

          if (is_valid_name($c->{geoname_asciiname})) {
           $entries{$c->{geoname_asciiname}} = 'en';
           $entries{fingerprint($c->{geoname_asciiname})}  = 'en';
          }
       }

       my $alternateNames =  getAlternateNames($c->{geoname_id},$language,\%entries);
       foreach (keys(%{$alternateNames})) {
          if(length($alternateNames->{$_})>0) {
            if (scalar(@use_langages_list) > 2 or $use_country_langage ==  1) {
              print escape_str($_) . $SP_S  . escape_str($country) . $bSemantic .
              gLang . $alternateNames->{$_} . gID . $id . $NL_S;
            } else {
              print escape_str($_) . $SP_S  . escape_str($country) . $bSemantic .
              gID . $id . $NL_S;
            }
          }
          delete $alternateNames->{$_};
       }
  }
  $sth->finish();
}
# ======================================================================
# fetchprint_sql:
sub fetchprint_sql($$$){
  my $dbh = shift;
  my $sql = shift;
  my $tSemantic = shift;
  my $sth = $dbh->prepare($sql) || die $DBI::errstr;
  $sth->execute || die $DBI::errstr;
  my $asciiname;
  my $geoname;
  my $language;
  my $bSemantic;
  my $id;
  my %entries = ();
  while (my $c = $sth->fetchrow_hashref) {
       $id        = sprintf($gid_format,$c->{geoname_id}) ;
       $language  = getCountryLang($c->{country_languages});
       $asciiname = length($c->{geoname_asciiname})>0? $c->{geoname_asciiname}:
                                                    fingerprint($c->{geoname_name});
       $geoname   = length($c->{geoname_name})>0? $c->{geoname_name} :
                                            $c->{geoname_asciiname};
       $bSemantic =  $DT_S  .
               mSemantic .
               $tSemantic .
               gCISO  . $c->{country_iso} .
               gLAT  . escape_num($c->{geoname_lat})  .
               gLONG . escape_num($c->{geoname_lng});

       # geoname names are in English by default
       if ($language =~ /en/) {
          if (is_valid_name($geoname)) {
           $entries{$geoname}  = $language;
           $entries{fingerprint($geoname)}  = $language;
          }

          if (is_valid_name($asciiname)) {
           $entries{$asciiname} = $language;
           $entries{fingerprint($asciiname)}  = $language;
          }
       }

       my $alternateNames = getAlternateNames($c->{geoname_id},$language,\%entries);

       foreach (keys(%{$alternateNames})) {
        if (scalar(@use_langages_list) > 2 or $use_country_langage ==  1) {
          print  escape_str($_) . $SP_S  . escape_str($asciiname) . $bSemantic .
               gLang . $alternateNames->{$_} . gID . $id . $NL_S;
        } else {
          print  escape_str($_) . $SP_S  . escape_str($asciiname) . $bSemantic .
               gID . $id . $NL_S;
        }
        delete $alternateNames->{$_};
       }
  }

  $sth->finish();
}
# ======================================================================
# loopPostalCodes
sub loopPostalCodes($$$$$$$$$){
 my $sth       = shift;
 my $country   = shift;
 my $geoname   = shift;
 my $lat       = shift;
 my $lng       = shift;
 my $admin1    = shift;
 my $admin2    = shift;
 my $admin3    = shift;
 my $admin4    = shift;
 my $match_country  = 0;
 my $match_code  = 0;
 my $match_name  = 0;
 my $n_codes     = 0;
 my $n_names     = 0;
 my @postalcodes = ();

 while (my $row = $sth->fetchrow_hashref){
   $match_code  = 0;
   $match_name  = 0;
   $n_codes     = 0;
   $n_names     = 0;

    # country_iso
    if(length($row->{country_iso})>0){
      if(length($country) > 0){
        if ($row->{country_iso} eq $country){
          $match_country++;
         }else{
          next;
         }
       }
    }

    # admin1 code
    if(length($row->{geoname_admin1})>0){
      $n_codes++;
      if(length($admin1->{code}) > 0){
        if ($row->{geoname_admin1} eq $admin1->{code}){
          $match_code++;
         }else{
          next;
         }
       }
    }

    # admin2 code
    if(length($row->{geoname_admin2})>0){
      $n_codes++;
      if(length($admin2->{code}) > 0){
        if ($row->{geoname_admin2} eq $admin2->{code}){
          $match_code++;
         }else{
          next;
         }
       }
    }

    # admin3 code
    if(length($row->{geoname_admin3})>0){
      $n_codes++;
      if(length($admin1->{code}) > 0){
        if ($row->{geoname_admin3} eq $admin3->{code}){
          $match_code++;
         }else{
          next;
         }
       }
    }

    # admin1 name
    if(length($row->{admin1_name})>0){
      $n_names++;
      if(length($admin1->{name}) > 0){
         if (index($admin1->{name},$row->{admin1_name}) > -1 ||
             index($row->{admin1_name},$admin1->{name}) > -1){
              $match_name++;
         }
       }
    }

    # admin2 name
    if(length($row->{admin2_name})>0){
      $n_names++;
      if(length($admin2->{name}) > 0){
        if (index($admin2->{name},$row->{admin2_name}) > -1 ||
            index($row->{admin2_name},$admin2->{name}) > -1){
              $match_name++;
         }
       }
    }

    # admin3 name
    if(length($row->{admin3_name})>0){
      $n_names++;
      if(length($admin3->{name}) > 0){
        if (index($admin3->{name},$row->{admin3_name}) > -1 ||
            index($row->{admin3_name},$admin3->{name}) > -1){
              $match_name++;
         }
       }
    }

    # admin4 name
    if(length($row->{geoname_name})>0){
      if(length($geoname) > 0){
        if (index($geoname,$row->{geoname_name}) > -1 ||
            index($row->{geoname_name},$geoname) > -1){
              $match_name++;
        }
       }
      if(length($admin4->{name}) > 0){
        $n_names++;
        if (index($admin4->{name},$row->{geoname_name}) > -1 ||
            index($row->{geoname_name},$admin4->{name}) > -1){
              $match_name++;
        }
       }
    }

    # calculate the distance between the postalcode (lat,lng) and the toponyme  (lat,lng)
    my $distance = $gis->distance($row->{postalcode_lat}, $row->{postalcode_lng} => $lat,$lng );

    # if admins codes match or toponymes names match or the distance is shorter than 9km
    if($match_country > 0 and ($match_code >= $n_codes || $match_name >= $n_names ||
       $distance->kilometers() <= $min_distance_kilometers)){
       my $postalcode  = {'geoname' => "", 'group' => "",  'lat' => "", 'lng' => "" , 'acc' => "", 'distance' => -1,
                          'match_code' => 0, 'match_name' => 0 };

       $postalcode->{'geoname'}    = $row->{geoname_name};
       $postalcode->{'group'}      = $row->{group_postalcode};
       $postalcode->{'lat'}        = $row->{postalcode_lat};
       $postalcode->{'lng'}        = $row->{postalcode_lng};
       $postalcode->{'acc'}        = $row->{postalcode_acc};
       $postalcode->{'distance'}   = $distance->kilometers();
       $postalcode->{'match_code'} = $match_code;
       $postalcode->{'match_name'} = $match_name;

       push(@postalcodes,$postalcode);

       $admin1->{code} =  length($admin1->{code}) > 0 ? $admin1->{code} : $row->{geoname_admin1};
       $admin2->{code} =  length($admin2->{code}) > 0 ? $admin2->{code} : $row->{geoname_admin2};
       $admin3->{code} =  length($admin3->{code}) > 0 ? $admin3->{code} : $row->{geoname_admin3};
       $admin1->{name} =  length($admin1->{name}) > 0 ? $admin1->{name} : $row->{admin1_name};
       $admin2->{name} =  length($admin2->{name}) > 0 ? $admin2->{name} : $row->{admin2_name};
       $admin3->{name} =  length($admin3->{name}) > 0 ? $admin3->{name} : $row->{admin3_name};

    }else{
      print Dumper($match_code, $match_name, $row, $distance->kilometers(), $geoname, $lat, $lng, $n_codes, $n_names);
      die("Hello World");
    }
  }

  # MAX(match_code) =  3
  # MAX(match_name) =  5
  # sort by best score = MAX(match_code + match_name + 2/distance)
  if(@postalcodes > 0){
    @postalcodes = sort { $b->{match_code} + $b->{match_name} + 2/($b->{distance} + 0.00000000000001) <=>
                          $a->{match_code} + $a->{match_name} + 2/($a->{distance} + 0.00000000000001) } @postalcodes;
  }
  return @postalcodes
}
# ======================================================================
# ======================================================================
# getPostalCode
sub getPostalCodes($$$$$$$$$$){
   my $gid       = shift;
   my $country   = shift;
   my $geoname   = shift;
   my $lang      = shift;
   my $lat       = shift;
   my $lng       = shift;
   my $admin1    = shift;
   my $admin2    = shift;
   my $admin3    = shift;
   my $admin4    = shift;
  $sthPostalCode->execute($country,$geoname, $gid, $lang) || die $DBI::errstr;

  my @postalcodes = loopPostalCodes($sthPostalCode,$country,$geoname,
                                    $lat,$lng,$admin1,$admin2,$admin3,$admin4);
  return @postalcodes;
}
# ======================================================================
# getClosestPostalCode
sub getClosestPostalCodes($$$$$$$$){
   my $country   = shift;
   my $geoname   = shift;
   my $lat       = shift;
   my $lng       = shift;
   my $admin1    = shift;
   my $admin2    = shift;
   my $admin3    = shift;
   my $admin4    = shift;
   my $KILOMETER_RHO = 6371.64;
   my $deg_ratio     = 0.0174532925199433;
   my $degrees       = $min_distance_kilometers / ( $deg_ratio * $KILOMETER_RHO );
   my $lng1          = $lng-$degrees;
   my $lng2          = $lng+$degrees;
   my $lat1          = $lat-$degrees;
   my $lat2          = $lat+$degrees;
   $sthClosestPostalCode->execute($country,$lng1, $lat1,$lng2,$lat2) || die $DBI::errstr;
   my @postalcodes = loopPostalCodes($sthClosestPostalCode,$country,$geoname,
                                     $lat,$lng,$admin1,$admin2,$admin3,$admin4);

   if(@postalcodes > 0){
     my $best_postalcode = {'geoname'    => $geoname,
                            'group'      => (split(/,/, $postalcodes[0]->{group}))[0],
                            'lat'        => $lat,
                            'lng'        => $lng,
                            'acc'        => 1,
                            'distance'   => 0,
                            'match_code' => $postalcodes[0]->{match_code},
                            'match_name' => $postalcodes[0]->{match_name} };

     @postalcodes=();
     push(@postalcodes,$best_postalcode);


     #my @select_postalcodes = ();
     #my $max_match = 0;
     ## Morocco
     #if($country eq 'FR'){
       #my $i=0;
       #while($i <= $#postalcodes &&
             #(my $match_score = $postalcodes[$i]->{match_code} + $postalcodes[$i]->{match_name})>= $max_match){
              #if($match_score < $max_match_score){
                 #$postalcodes[$i]->{lat}   = $lat;
                 #$postalcodes[$i]->{lng}   = $lng;
                 #$postalcodes[$i]->{group} = (split(/,/, $postalcodes[$i]->{group}))[0];
                 #$max_match = $max_match_score+1;
                 #push(@select_postalcodes,$postalcodes[$i]);
              #}else{
                #push(@select_postalcodes,$postalcodes[$i]);
                #$max_match = $match_score;
              #}
            #$i++;
       #}
       #@postalcodes =  @select_postalcodes;
     #}


   }
   return @postalcodes;
}
# ======================================================================
# getHierarchy
sub getHierarchy($$$$$){
  my $country   = shift;
  my $admin1    = shift;
  my $admin2    = shift;
  my $admin3    = shift;
  my $admin4    = shift;
  my $hierarchy = "";
  if(defined $admin1->{'code'} && length($admin1->{'code'})>0){
    $sthAdmin1->execute($country.'.'.$admin1->{'code'}) || die $DBI::errstr;
    my $row1 = $sthAdmin1->fetchrow_hashref;
    if ( defined $row1->{geoname_id} and length($row1->{geoname_id}) > 0){
      my $id_admin1 = sprintf($gid_format,$row1->{geoname_id}) ;
      $admin1->{'id'}   = $row1->{geoname_id};
      $admin1->{'name'} = $row1->{admin1_name};
      $hierarchy = $hierarchy . gADM1 . $id_admin1;
    }
   }
  if(defined $admin2->{'code'} && length($admin2->{'code'})>0){
    $sthAdmin2->execute($country.'.'.$admin1->{'code'}.'.'.$admin2->{'code'}) || die $DBI::errstr;
    my $row2 = $sthAdmin2->fetchrow_hashref;
    if ( defined $row2->{geoname_id} and length($row2->{geoname_id}) > 0){
      my $id_admin2 = sprintf($gid_format,$row2->{geoname_id}) ;
      $admin2->{'id'}   = $row2->{geoname_id};
      $admin2->{'name'} = $row2->{admin2_name};
      $hierarchy = $hierarchy . gADM2 . $id_admin2;
    }
  }
  if(defined $admin3->{'code'} && length($admin3->{'code'})>0){
     $sthAdmin3->execute($country,$admin1->{'code'},$admin2->{'code'},$admin3->{'code'})|| die $DBI::errstr;
     my $row3 = $sthAdmin3->fetchrow_hashref;
    if ( defined $row3->{geoname_id} and length($row3->{geoname_id}) > 0){
      my $id_admin3 = sprintf($gid_format,$row3->{geoname_id}) ;
      $admin3->{'id'}   = $row3->{geoname_id};
      $admin3->{'name'} = $row3->{geoname_name};
      $hierarchy = $hierarchy . gADM3 . $id_admin3;
    }
  }
  if(defined $admin4->{'code'} && length($admin4->{'code'})>0){
     $sthAdmin4->execute($country,$admin1->{'code'},$admin2->{'code'},$admin3->{'code'},$admin4->{'code'})|| die $DBI::errstr;
     my $row4 = $sthAdmin4->fetchrow_hashref;
    if ( defined $row4->{geoname_id} and length($row4->{geoname_id}) > 0){
      my $id_admin4 = sprintf($gid_format,$row4->{geoname_id}) ;
      $admin4->{'id'}   = $row4->{geoname_id};
      $admin4->{'name'} = $row4->{geoname_name};
      $hierarchy = $hierarchy . gADM4 . $id_admin4;
    }
  }
  return $hierarchy;
}
# ======================================================================
sub cleanPostalCode($){
  my $str = shift;
  $str =~ s/\s+cedex.*$//gi;     # remove 'cedex'
  $str =~ s/\s+cityssimo.*$//gi; # remove 'cityssimo'
  $str =~ s/\s+air.*$//gi;       # remove 'air'
  $str =~ s/\s+sp.*$//gi;        # remove 'sp'
  $str =~ s/^\s+//g;             # ltrim
  $str =~ s/\s+$//g;             # rtrim
  return $str;
}
# ======================================================================
# ======================================================================
# fetchprint_sql:
sub fetchprint_hierarchy_sql($$$$){
  my $dbh = shift;
  my $sql = shift;
  my $tSemantic = shift;
  my $geoRegex = shift;
  my $sth = $dbh->prepare($sql) || die $DBI::errstr;
  $sth->execute || die $DBI::errstr;
  my $count   = 0;

  while (my $c = $sth->fetchrow_hashref) {
       my $asciiname;
       my $geoname;
       my $language;
       my $bSemantic;
       my $bCoord;
       my $gid;
       my $id;
       my $country;
       my $country_id;
       my $lat;
       my $lng;
       my $bHierarchy="";
       my ($admin1, $admin2, $admin3, $admin4);
       my %entries = ();
       my $alternateNames;
       $count = $count + 1;

       $gid       = $c->{geoname_id};
       $id        = sprintf($gid_format,$c->{geoname_id}) ;
       $country   = $c->{country_iso};
       $country_id= sprintf($gid_format,$c->{country_id});
       $admin1    = {'code' => $c->{geoname_admin1}, 'id'  => "" , 'name' => ""};
       $admin2    = {'code' => $c->{geoname_admin2}, 'id'  => "" , 'name' => ""};
       $admin3    = {'code' => $c->{geoname_admin3}, 'id'  => "" , 'name' => ""};
       $admin4    = {'code' => $c->{geoname_admin4}, 'id'  => "" , 'name' => ""};
       $language  = getCountryLang($c->{country_languages});

       $asciiname = length($c->{geoname_asciiname})>0? $c->{geoname_asciiname}:
                                                       fingerprint($c->{geoname_name});
       $geoname   = length($c->{geoname_name})>0? $c->{geoname_name} :
                                             $c->{geoname_asciiname};

       if($print_hierarchy == 1) {
         $bHierarchy  = getHierarchy($country, $admin1,$admin2,$admin3,$admin4);
       } else {
         getHierarchy($country, $admin1,$admin2,$admin3,$admin4);
       }

       $bSemantic =  $DT_S  .
               mSemantic .
               $tSemantic .
               gCISO  .  $country;

       $lat    = $c->{geoname_lat};
       $lng    = $c->{geoname_lng};

       $bCoord =
          gLAT  . escape_num($lat)  .
          gLONG . escape_num($lng);

       if ($language =~ /en/) {
          if (is_valid_name($geoname)) {
           $entries{$geoname}  = 'en';
           $entries{fingerprint($geoname)}  = 'en';
          }

          if (is_valid_name($asciiname)) {
           $entries{$asciiname} = 'en';
           $entries{fingerprint($asciiname)}  = 'en';
          }
       }

       $alternateNames  = getAlternateNames($c->{geoname_id},$language,\%entries);

       # espape alternative names
       foreach (keys(%{$alternateNames})) {
          $_ = escape_str($_);
       }

       my @postalcodes_list = ();
       
       if( $print_postal_code == 1) {
         @postalcodes_list = getPostalCodes($gid, $country, $geoname . $geoRegex, $language, $lat, $lng, $admin1,$admin2,$admin3,$admin4);

         unless(@postalcodes_list){
            @postalcodes_list = getClosestPostalCodes($country, $geoname, $lat, $lng, $admin1,$admin2,$admin3,$admin4);
         }
       }

      my $escape_ascii = escape_str($asciiname);

      if(@postalcodes_list > 0){
        foreach my $postalcodes (@postalcodes_list){
          my @postalcode = split(/,/, $postalcodes->{'group'});
          my $postal_lat = length($postalcodes->{'lat'}) > 0 ?
                           escape_num($postalcodes->{'lat'}) : escape_num($c->{geoname_lat}) ;
          my $postal_lng = length($postalcodes->{'lng'}) > 0 ?
                           escape_num($postalcodes->{'lng'}) : escape_num($c->{geoname_lng}) ;

          my $postal_geoname     = normalize($postalcodes->{'geoname'});
          my $postal_geoname_fp  = fingerprint($postalcodes->{'geoname'});
          my $use_postal_geoname = 0;
          my $use_postal_geoname_fp = 0;

          if ( $postal_geoname  =~ /\p{Latin}/ and
               is_valid_name($postal_geoname) and
               ! exists $alternateNames->{$postal_geoname } ) {
              $use_postal_geoname = 1;
          }

          if ( $postal_geoname ne $postal_geoname_fp and
               $postal_geoname_fp  =~ /\p{Latin}/ and
               is_valid_name($postal_geoname_fp) and
               ! exists $alternateNames->{$postal_geoname_fp } ) {
              $use_postal_geoname_fp = 1;
          }

          foreach my $p (@postalcode) {
            foreach (keys(%{$alternateNames})) {
                my $entry_suffix = $SP_S  . $escape_ascii .
                       $bSemantic .
                       gPCod . cleanPostalCode($p) .
                       gLAT  . $postal_lat .
                       gLONG . $postal_lng .
                       $bHierarchy .
                       gID   . $id .
                       ((scalar(@use_langages_list) > 2 or $use_country_langage ==  1) ? gLang . $alternateNames->{$_} : '') .
                       $NL_S;

                if(length($_) > $min_toponym_length) { print  lc($_) .  $entry_suffix; }


                if ($use_postal_geoname == 1) {
                    if(length($postal_geoname) > $min_toponym_length)    {  print  lc($postal_geoname) .  $entry_suffix;    }
                }
                if ($use_postal_geoname_fp == 1) {
                    if(length($postal_geoname_fp) > $min_toponym_length) {  print  lc($postal_geoname_fp) .  $entry_suffix; }
                }
            }
          }
        }
      }else{
            foreach (keys(%{$alternateNames})) {
              if(length($_) > $min_toponym_length) {
                print  lc($_) . $SP_S  . $escape_ascii .
                       $bSemantic .
                       $bCoord .
                       $bHierarchy .
                       gID . $id .
                       ((scalar(@use_langages_list) > 2 or $use_country_langage ==  1) ? gLang . $alternateNames->{$_} : '') .
                       $NL_S;
              }
           }
      }
  }

  #print Dumper($count);
  #exit 1;

  $sth->finish();
}
# ======================================================================
# dic_CapitalCities:
sub dic_CapitalCities($){
  my $dbh = shift;
  # get city info
  #my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             #g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             #g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             #c.country_languages, c.geoname_id as country_id FROM  tab_geoname as g , tab_country as c
              #WHERE g.geoname_fclass IS 'P'
              #AND   g.geoname_fcode  IN ('PPLC')
              #AND  c.country_iso = g.country_iso";
  #my $tSemantic = mCity . mCapital;
  #fetchprint_sql  $dbh,$sql, $tSemantic;

  ## get city info
  ## only places with a population higher than min_population or featuring
  ## at least an alternative name of type link, e.g. a link to the wikipedia or
  ## having a postalcode
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'P'
              AND  g.geoname_fcode IN ('PPLC')
              AND  c.country_iso = g.country_iso";
  my $tSemantic = mCity . mCapital;
  fetchprint_hierarchy_sql  $dbh,$sql, $tSemantic, '%';

}
# ======================================================================
# dic_DivisionMatch:
sub DivisionMatch($){
  my $dbh = shift;
  my $sql = "SELECT * FROM tab_division";
  my $sth = $dbh->prepare($sql) || die $DBI::errstr;
  $sth->execute || die $DBI::errstr;
  my $sql_adm1 = "SELECT DISTINCT(A.admin1), A.admin1_asciiname, A.geoname_id from tab_admin1 as A, tab_altname as T
                    WHERE T.geoname_id = A.geoname_id AND
                    A.admin1_code LIKE ?
                    AND (A.admin1 = ? OR
                         A.admin1 LIKE ? OR
                         A.admin1_asciiname LIKE ?  OR
                         T.altname LIKE ? OR
                         A.admin1_asciiname LIKE ?  OR
                         T.altname LIKE ?
                         )COLLATE NOCASE";
  my $sql_adm2 = "SELECT DISTINCT(A.admin2), A.admin2_asciiname, A.geoname_id from tab_admin2 as A, tab_altname as T
                    WHERE T.geoname_id = A.geoname_id AND
                    A.admin2_code LIKE ?
                    AND (A.admin2 = ? OR
                         A.admin2 LIKE ? OR
                         A.admin2_asciiname LIKE ?  OR
                         T.altname LIKE ? OR
                         A.admin2_asciiname LIKE ?  OR
                         T.altname LIKE ?
                         ) COLLATE NOCASE";
  my $sql_reg = "SELECT * FROM tab_region WHERE
                     region_iso = ? OR
                     region LIKE ?";
  my $sth_adm1 = $dbh->prepare($sql_adm1) || die $DBI::errstr;
  my $sth_adm2 = $dbh->prepare($sql_adm2) || die $DBI::errstr;
  my $sth_reg  = $dbh->prepare($sql_reg) || die $DBI::errstr;
  while (my $r = $sth->fetchrow_hashref) {
    my $ciso = $r->{country_iso};
    my $diso = $r->{division_iso};
    my $division = $r->{division};
    my $fcode  = $r->{geoname_fcode};
    my $p1   = $ciso . '%';
    my $p2   = '%' . $division .'%';
    my $p3   = '%' . unac_string($division) .'%';
    if( $fcode eq 'ADM2' ){
      $sth_adm2->execute($p1,$p2,$p2,$p2,$p2,$p3,$p3) || die $DBI::errstr;
      my  $row2 = $sth_adm2->fetchrow_hashref;
      if(defined $row2){
        printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,$row2->{admin2},$row2->{admin2_asciiname},"A",$r->{geoname_fcode},$row2->{geoname_id};
      }else{
         $sth_reg->execute($diso,$division);
         my  $row3 = $sth_reg->fetchrow_hashref;
         if(defined $row3){
           printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,$row3->{region},$row3->{region_asciiname},"A",$r->{geoname_fcode},$row3->{geoname_id};
         }else{
            printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,"\"\"","\"\"","A",$r->{geoname_fcode},"\"\"",$division;
         }
      }
    }else{
      $sth_adm1->execute($p1,$p2,$p2,$p2,$p2,$p3,$p3) || die $DBI::errstr;
      my  $row1 = $sth_adm1->fetchrow_hashref;
      if(defined $row1){
        printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,$row1->{admin1},$row1->{admin1_asciiname},"A",$r->{geoname_fcode},$row1->{geoname_id};
      }else{
        $sth_adm2->execute($p1,$p2,$p2,$p2,$p2,$p3,$p3) || die $DBI::errstr;
        my  $row2 = $sth_adm2->fetchrow_hashref;
        if(defined $row2){
          printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,$row2->{admin2},$row2->{admin2_asciiname},"A",$r->{geoname_fcode},$row2->{geoname_id};
        }else{
         $sth_reg->execute($diso,$division);
         my  $row3 = $sth_reg->fetchrow_hashref;
         if(defined $row3){
           printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,$row3->{region},$row3->{region_asciiname},"A",$r->{geoname_fcode},$row3->{geoname_id};
         }else{
            printf "\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\t\"%s\"\n",$ciso,$diso,"\"\"","\"\"","A",$r->{geoname_fcode},"\"\"",$division;
         }
        }
      }
    }
  }
  $sth->finish();
  $sth_adm1->finish();
  $sth_adm2->finish();
  $sth_reg->finish();
}
# ======================================================================
# dic_NotableCities:
sub dic_NotableCities($$){
  my $dbh       = shift;
  my $countries = shift;
  # get city info
  # only places with a population higher than min_population or featuring
  # at least an alternative name of type link, e.g. a link to the wikipedia or
  # having a postalcode
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'P'
              AND  g.country_iso IN ($countries)
              AND  g.geoname_fcode NOT IN ('PPLC','PPLH','PPLCH','PPLQ','PPLW','STLMT')
              AND  (g.geoname_popult >= $min_population
              OR    g.geoname_id IN(SELECT DISTINCT(geoname_id) FROM tab_altname
                      WHERE geoname_id = g.geoname_id AND
                            altname_lang = 'link' )
              OR    g.geoname_name IN(SELECT DISTINCT(geoname_name) FROM tab_postalcode
                      WHERE country_iso    = c.country_iso AND
                            geoname_name   = g.geoname_name AND
                            geoname_admin1 = g.geoname_admin1)
              )
              AND  c.country_iso = g.country_iso";
  my $tSemantic = mCity;
  fetchprint_hierarchy_sql  $dbh,$sql, $tSemantic, '';
}
#  SELECT g.geoname_id, g.geoname, g.geoname_asciiname,
#             g.geoname_lat, g.geoname_lng, g.country_iso,
#             c.country_languages FROM  tab_geoname as g , tab_country as c
#              WHERE geoname_fclass IS 'P'
#              AND   geoname_fcode  IN  ('PPL')
#              AND   geoname_popult >= $min_population
#              AND  c.country_iso = g.country_iso";
# ======================================================================
# dic_AdminDivisions:
sub dic_AdminDivisions($$){
  my $dbh = shift;
  my $countries = shift;
  # get city info
  # only places with a population higher than min_population or featuring
  # at least an alternative name of type link, e.g. a link to the wikipedia or
  # having a postalcode
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE     ((g.geoname_fclass IS 'A'
               AND  (   g.geoname_fcode IS 'ADM1'
                     OR g.geoname_fcode IS 'ADM2'
                     OR g.geoname_fcode IS 'ADM3'
                     OR g.geoname_fcode IS 'ADM4'
                     OR g.geoname_fcode IS 'ADM5'
                    )
              ) OR
              (g.geoname_fclass IS 'P'
               AND  (   g.geoname_fcode IS 'PPLA'
                     OR g.geoname_fcode IS 'PPLA2'
                     OR g.geoname_fcode IS 'PPLA3'
                     OR g.geoname_fcode IS 'PPLA4'
                    )
              ))
              AND  g.country_iso IN ($countries)
              AND  (g.geoname_popult >= $min_population
              OR    g.geoname_id IN(SELECT DISTINCT(geoname_id) FROM tab_altname
                      WHERE geoname_id = g.geoname_id AND
                            altname_lang = 'link' )
              OR    g.geoname_name IN(SELECT DISTINCT(geoname_name) FROM tab_postalcode
                      WHERE country_iso    = c.country_iso AND
                            geoname_name   = g.geoname_name AND
                            geoname_admin1 = g.geoname_admin1)
              )
              AND  c.country_iso = g.country_iso";

  my $tSemantic = mDivion;
  fetchprint_hierarchy_sql  $dbh,$sql, $tSemantic, '';
}
# ======================================================================
# dic_Regions:
sub dic_Regions($$){
  my $dbh = shift;
  my $countries = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'A'
              AND  g.country_iso IN ($countries)
              AND  g.geoname_admin1 IS NOT '00'
              AND  g.geoname_popult >= $min_population
              AND  c.country_iso = g.country_iso";
  my $tSemantic = mRegion;
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Lakes:
sub dic_Lakes($$){
  my $dbh = shift;
  my $countries = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'H'
              AND   g.geoname_fcode IS 'LK'
              AND   g.country_iso IN ($countries)
              AND   c.country_iso = g.country_iso
            ";
  my $tSemantic = "+Hydronym+Lake";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Mountains:
sub dic_Mountains($$){
  my $dbh = shift;
  my $countries = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
            WHERE geoname_fclass IS 'T'
            AND (geoname_fcode  IS 'MT' OR
                 geoname_fcode  IS 'MTS')
              AND   g.country_iso IN ($countries)
              AND   c.country_iso = g.country_iso
            ";
  my $tSemantic = "+Oronym+Mountain";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Roads:
sub dic_Roads($$){
  my $dbh = shift;
  my $countries = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE geoname_fclass IS 'R'
              AND   g.country_iso IN ($countries)
              AND   c.country_iso = g.country_iso
            ";
  my $tSemantic = "+Oronym+Road";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Universities:
sub dic_Universities($$){
  my $dbh = shift;
  my $countries = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE   geoname_fclass IS 'S'
              AND   geoname_fcode IS 'UNIV'
              AND   g.country_iso IN ($countries)
              AND   c.country_iso = g.country_iso
            ";
  my $tSemantic = "+Oikonym+University";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Airports:
sub dic_Airports($$){
  my $dbh = shift;
   my $countries = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE   geoname_fclass IS 'S'
              AND   geoname_fcode IS 'AIRP'
              AND   g.country_iso IN ($countries)
              AND   c.country_iso = g.country_iso
            ";
  my $tSemantic = "+Oikonym+Airport";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_PopulatedPlaces:
sub dic_PopulatedPlaces($$){
	my $dbh = shift;
  my $countries = shift;
	# get city info
	my $sql = "SELECT g.geoname_id, g.geoname_name, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_iso, c.country_languages, c.geoname_id as country_id FROM
              tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'P'
              AND  g.geoname_popult >= $min_population
              AND  g.country_iso IN ($countries)
              AND  c.country_iso = g.country_iso";

	my $tSemantic = "";
	fetchprint_sql 	$dbh,$sql, $tSemantic;
}
# ======================================================================
# Main program
# ======================================================================
#
if ($#ARGV < 1 or $#ARGV > 4) {
 die "Usage: $0 <geonames.org sqlite database file> <dictionary type> [fr,en,...] [FR,US,...] [MIN_POPULATION]
 1: World Countries (+Country)
 2: Capitals Cities (+City+Capital)
 3: Cities with population >= $min_population (+City)
 4: Popular cities with population >= $min_population (+City)
 5: Regions with population>= $min_population (+Region)
 6: Lakes (+Hydronym+Lake)
 7: Mountains (+Oronym+Mountain)
 8: Roads (+Hodonym+Road)
 9: Universities (+Oikonym+University)
 10: Airports (+Oikonym+Airport)
 11: Administrative division (+Division)\n";
}
my $db_fn   = $ARGV[0];       # geonames.org sqlite database file
my $dictype = $ARGV[1];       # output dictionary

# if the langages are passed from the command line
if (defined($ARGV[2]) and length($ARGV[2]) > 0) {
  $use_langages = $use_langages . "," . $ARGV[2];
  @use_langages_list = (split /\,/, $use_langages);
}

# from "en,fr,es" -> "'en','fr','es','abbr',?"
my $sql_use_langages = "'" . join("','", @use_langages_list) . "','abbr',?";


# 'xx' means the default spoken language of a country
if ($sql_use_langages =~ /'xx'/) {
  $use_country_langage=1;
  $sql_use_langages =~ s/^'xx',?//g;            # xx at the begin
  $sql_use_langages =~ s/,'xx'$//g;             # xx at the end
  $sql_use_langages =~ s/,'xx',/,/g;            # xx in the middle
}

# define the default langage
$default_langage = (split /\,/, $sql_use_langages)[0];
if (length($default_langage) == 0 or $default_langage eq "'abbr'") {
  $default_langage="en";
}

# if the countries are passed from the command line
if (defined($ARGV[3]) and length($ARGV[3]) > 0) {
  $use_countries = uc($ARGV[3]);
}

# minimal population
if (defined($ARGV[4]) and length($ARGV[4]) > 0) {
  $min_population = $ARGV[4];
  if (not looks_like_number($min_population)) {
    die "Bad minimal population: $min_population\n";
  }
}

# from "US,CO,FR" -> "'US','CO','FR'"
my $sql_use_countries = "'" . join("','", (split /\,/, $use_countries)) . "'";

(-e $db_fn) or
  die "File doesn't exist: $db_fn\n";
#DBI->trace( 1 );
my $dbargs = {sqlite_unicode => 1,  # turn the UTF-8 flag for all text strings
              AutoCommit => 0,
              RaiseError   => 1}; #
my $dbh = DBI->connect(       # connect to database
    "dbi:SQLite:dbname=$db_fn",   # DSN: dbi, driver, database file
    "",                           # no user
    "",                           # no password
    $dbargs,                # complain if something goes wrong
) or die("Error: $DBI::errstr.\n");

$dbh->do('PRAGMA encoding = "UTF-8"');
$dbh->do('PRAGMA default_synchronous = "OFF"');
$dbh->do('PRAGMA foreign_keys = "OFF"');
$dbh->do('PRAGMA journal_mode = "MEMORY"');
$dbh->do('PRAGMA cache_size = "800000"');

# (altname_lang IN ('en','es','fr','pt','it','de',?) OR
# length(altname_lang) = 0)
$sqlAlternateNames = "SELECT GROUP_CONCAT(altname_lang) as altname_group_lang, altname_name FROM tab_altname
                              WHERE geoname_id = ? AND
                              altname_collq <> 1 AND
                              altname_lang IN ($sql_use_langages)
                              GROUP BY altname_name";
$sthAlternateNames = $dbh->prepare($sqlAlternateNames) || die $DBI::errstr;
$sqlAdmin1 = "SELECT geoname_id, admin1_name from tab_admin1
                     where admin1_code = ?";
$sthAdmin1  =  $dbh->prepare($sqlAdmin1) || die $DBI::errstr;
$sqlAdmin2 = "SELECT geoname_id, admin2_name from tab_admin2
                     where admin2_code = ?";
$sthAdmin2  =  $dbh->prepare($sqlAdmin2) || die $DBI::errstr;
$sqlAdmin3 = "SELECT geoname_id, geoname_name FROM tab_geoname WHERE
               geoname_fclass IS 'A' AND
               geoname_fcode  IS 'ADM3' AND
               country_iso = ? AND
               geoname_admin1  = ? AND
               geoname_admin2  = ? AND
               geoname_admin3  = ?";
$sthAdmin3  =  $dbh->prepare($sqlAdmin3) || die $DBI::errstr;
$sqlAdmin4 = "SELECT geoname_id, geoname_name FROM tab_geoname WHERE
               geoname_fclass IS 'A' AND
               geoname_fcode  IS 'ADM4' AND
               country_iso = ? AND
               geoname_admin1  = ? AND
               geoname_admin2  = ? AND
               geoname_admin3  = ? AND
               geoname_admin4  = ?";
$sthAdmin4  =  $dbh->prepare($sqlAdmin4) || die $DBI::errstr;
#$sqlPostalCode = "SELECT country_iso, GROUP_CONCAT(postalcode) as group_postalcode,  geoname, admin1,
#             geoname_admin1, admin1, geoname_admin2, admin2, geoname_admin3, admin3,
#             postalcode_lat, postalcode_lng
#             FROM tab_postalcode WHERE
#             country_iso = ?  AND
#             geoname = ?
#             GROUP BY country_iso, geoname, admin1, geoname_admin1, admin2, geoname_admin2, admin3, geoname_admin3, postalcode_lat, postalcode_lng";
$sqlPostalCode = "SELECT country_iso, GROUP_CONCAT(postalcode) as group_postalcode,  geoname_name, admin1_name,
                 geoname_admin1, admin1_name, geoname_admin2, admin2_name, geoname_admin3, admin3_name,
                 postalcode_lat, postalcode_lng, postalcode_acc
                 FROM tab_postalcode WHERE
                 country_iso = ?  AND
                 (geoname_name LIKE ? OR
                  geoname_name IN (SELECT DISTINCT(altname_name) FROM tab_altname
                             WHERE geoname_id = ? AND
                             altname_collq <> 1 AND
                            (altname_lang IN ($sql_use_langages) OR
                             length(altname_lang) = 0)))
                 GROUP BY country_iso, geoname_name, admin1_name, geoname_admin1, admin2_name,
                 geoname_admin2, admin3_name, geoname_admin3, postalcode_lat, postalcode_lng, postalcode_acc";
$sthPostalCode = $dbh->prepare($sqlPostalCode) || die $DBI::errstr;
$sqlClosestPostalCode  = "SELECT country_iso, GROUP_CONCAT(postalcode) as group_postalcode,  geoname_name, admin1_name,
             geoname_admin1, admin1_name, geoname_admin2, admin2_name, geoname_admin3, admin3_name,
             postalcode_lat, postalcode_lng, postalcode_acc
             FROM tab_postalcode WHERE
             country_iso = ? AND (
             postalcode_lng >= ? AND postalcode_lat >= ? AND
             postalcode_lng <= ? AND postalcode_lat <= ?)
             GROUP BY country_iso, geoname_name, admin1_name, geoname_admin1, admin2_name,
             geoname_admin2, admin3_name, geoname_admin3, postalcode_lat, postalcode_lng, postalcode_acc";
$sthClosestPostalCode =  $dbh->prepare($sqlClosestPostalCode) || die $DBI::errstr;
switch ($dictype){
  case 1   { dic_WorldCountries($dbh); }
  case 2   { dic_CapitalCities($dbh); }
  case 3   { dic_PopulatedPlaces($dbh, $sql_use_countries); }
  case 4   { dic_NotableCities($dbh, $sql_use_countries); }
  case 5   { dic_Regions($dbh, $sql_use_countries); }
  case 6   { dic_Lakes($dbh, $sql_use_countries); }
  case 7   { dic_Mountains($dbh, $sql_use_countries); }
  case 8   { dic_Roads($dbh, $sql_use_countries); }
  case 9   { dic_Universities($dbh, $sql_use_countries); }
  case 10  { dic_Airports($dbh, $sql_use_countries); }
  case 11  { dic_AdminDivisions($dbh, $sql_use_countries); }
  default { die("Error: Invalid dictionary number"); }
}

$sthAlternateNames->finish();
$sthAdmin1->finish();
$sthAdmin2->finish();
$sthAdmin3->finish();
$sthAdmin4->finish();
$sthPostalCode->finish();
$sthClosestPostalCode->finish();
$dbh && $dbh->disconnect();
exit 0;
