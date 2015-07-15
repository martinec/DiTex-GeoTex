#!/usr/bin/perl -w
# ======================================================================
# geo2dic v1.0.0 - Geonames.org to DiTex DELAF GeoTex
# Converts a geonames SQLite database to Unitex DELA format
# ======================================================================
# This script is free software; you can redistribute it and/or modify it
# under the terms of either: the GNU General Public License v3 or the
# Perl Artistic License.
# ======================================================================
# Copyright 2011, by Cristian Martinez <me@martinec.org>
# ======================================================================
use strict;
use warnings;
use Text::Unaccent::PurePerl qw(unac_string);
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
use GIS::Distance;
my $min_distance_kilometers = 9000 / 1000; # kilometers
my $max_match_score = 8;
my $gis = GIS::Distance->new();
$gis->formula( 'Haversine' );
use constant true  => 1;
use constant false => 0;
# ======================================================================
# Constants
# ======================================================================
#
use constant mSemantic  => "N+Toponym"; # General information
# ======================================================================
# Dictionary contents
# ======================================================================
my $SP_S      = ",";      # Sep Symbol
my $ES_S      = "\\";     # Escape Symbol
my $NL_S      = "\n";     # New Line Symbol
my $DT_S      = ".";      # Dot Symbol
my $HY_S      = "=";      # Hypen Symbol
# ======================================================================
# General
# ======================================================================
#
use constant gLAT     => "+Lat=";         # Latitude
use constant gLONG    => "+Lng=";         # Longitude
use constant gLang    => "+Lang=";        # Language
use constant gID      => "+Uid=";         # Identifier
use constant gPCod    => "+PostalCode=";  # Postal code
use constant gADM1     => "+Region1=";       # Region1
use constant gADM2     => "+Region2=";       # Region2
use constant gADM3     => "+Region3=";       # Region3
use constant gADM4     => "+Region4=";       # Region4
# ======================================================================
# Country stuff
# ======================================================================
#
use constant mCountry => "+Country";      # Country
use constant gCISO    => "+CountryISO=";  # ISO 3166-1 alpha-2 country code,
# ======================================================================
# Region
# ======================================================================
#
use constant mRegion   => "+Region";       # Region
use constant gRISO     => "+RegionIso=";   # ISO 3166-2 alpha-6 region code
# ======================================================================
# Capital and city stuff
# ======================================================================
#
my $MIN_POPULATION  = 5000; # Minimum population (inclusive)
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
my $sqlClosestPostalCode;
my $sthClosestPostalCode;
# ======================================================================
# ======================================================================
# Functions
# ======================================================================
#
# ======================================================================
sub fingerprint($){
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
# escape_str: escape strings for compatibility with DELAF format
sub escape_str($){
  my $str = shift;
  $str =~ s/^\s+//g;             # ltrim
  $str =~ s/\s+$//g;             # rtrim
  $str =~ s/’/'/g;               # ’ by '
  $str =~ s/$SP_S/$ES_S$SP_S/g;  # Replace , by \,
  $str =~ s/\./$ES_S\./g;        # Replace . by \.
  $str =~ s/$HY_S/$HY_S$DT_S/g;  # Replace = by \=
  $str =~ s/\s+/ /g;             # collapse multiple spaces
  return $str;
}
# ======================================================================
# escape_num: escape numbers for compatibility with DELAF format
sub escape_num($){
   my $str = shift;
   $str =~ s/\./$ES_S\./g;  # Replace . by \.
   $str =~ s/\+/$ES_S\+/g;  # Replace + by \+
   $str =~ s/-/$ES_S\-/g;   # Replace - by \-
   return $str;
}
# ======================================================================
# getCountryLang:
sub getCountryLang($){
  my $langs = shift;
  return substr $langs, 0, 2;   # returns the two firsts characters
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
    my $altname = $row->{altname};
    # if altname has latin codepage characters
    if($altname =~ /\p{Latin}/){
      # add lang group to name that is already in hash
      $entries->{$altname} =   defined  $entries->{$altname} ?
           $entries->{$altname} ."," . $row->{altname_group_lang}  :
           defined $row->{altname_group_lang} ? $row->{altname_group_lang} : 'en' . ',' . $lng ;
      # split by , sort and join by |
      if(defined  $entries->{$altname}){
        my @langs = split(/,/, $entries->{$altname});
        $entries->{$altname} = join("|", uniq(sort(@langs)));
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
           $entries->{$fpaltname} = join("|", uniq(sort(@fplangs)));
        }
      }
    }
  }
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
  my $id;
  my %entries = ();
  while (my $c = $sth->fetchrow_hashref) {
       $id        = sprintf("GN%.8d",$c->{geoname_id}) ;
       $country   = $c->{country};
       $language  = getCountryLang($c->{country_languages});
       $bSemantic =  $DT_S  .
               mSemantic .
               mCountry  .
               gCISO  . $c->{country_iso2}    .
               gLAT  . escape_num($c->{geoname_lat})  .
               gLONG . escape_num($c->{geoname_lng});
       $entries{$country} = 'en';
       $entries{fingerprint($country)}  = 'en';
       $entries{$c->{geoname}}  = 'en';
       $entries{fingerprint($c->{geoname})}  = 'en';
       $entries{$c->{geoname_asciiname}} = 'en';
       $entries{fingerprint($c->{geoname_asciiname})}  = 'en';
       my $alternateNames =  getAlternateNames($c->{geoname_id},$language,\%entries);
       foreach (keys(%{$alternateNames})) {
          print escape_str($_) . $SP_S  . escape_str($country) . $bSemantic .
                gLang . $alternateNames->{$_} . gID . $id . $NL_S;
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
       $id        = sprintf("GN%.8d",$c->{geoname_id}) ;
       $language  = getCountryLang($c->{country_languages});
       $asciiname = length($c->{geoname_asciiname})>0? $c->{geoname_asciiname}:
                                                    fingerprint($c->{geoname});
       $geoname   = length($c->{geoname})>0? $c->{geoname} :
                                            $c->{geoname_asciiname};
       $bSemantic =  $DT_S  .
               mSemantic .
               $tSemantic .
               gCISO  . $c->{country_iso2} .
               gLAT  . escape_num($c->{geoname_lat})  .
               gLONG . escape_num($c->{geoname_lng});
       $entries{$geoname}  = 'en';
       $entries{fingerprint($geoname)}  = 'en';
       $entries{$asciiname} = 'en';
       $entries{fingerprint($asciiname)}  = 'en';
       my $alternateNames = getAlternateNames($c->{geoname_id},$language,\%entries);
       foreach (keys(%{$alternateNames})) {
        print  escape_str($_) . $SP_S  . escape_str($asciiname) . $bSemantic .
               gLang . $alternateNames->{$_} . gID . $id . $NL_S;
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
 my $match_code  = 0;
 my $match_name  = 0;
 my @postalcodes = ();
 while (my $row = $sth->fetchrow_hashref){
   $match_code  = 0;
   $match_name  = 0;
    if(length($row->{geoname_admin1})>0){
      if(length($admin1->{code}) > 0){
        if ($row->{geoname_admin1} eq $admin1->{code}){
          $match_code++;
         }else{
          next;
         }
       }
    }
    if(length($row->{geoname_admin2})>0){
      if(length($admin2->{code}) > 0){
        if ($row->{geoname_admin2} eq $admin2->{code}){
          $match_code++;
         }else{
          next;
         }
       }
    }
    if(length($row->{geoname_admin3})>0){
      if(length($admin1->{code}) > 0){
        if ($row->{geoname_admin3} eq $admin3->{code}){
          $match_code++;
         }else{
          next;
         }
       }
    }
    if(length($row->{admin1})>0){
      if(length($admin1->{name}) > 0){
         if (index($admin1->{name},$row->{admin1}) > -1 ||
             index($row->{admin1},$admin1->{name}) > -1){
              $match_name++;
         }
       }
    }
    if(length($row->{admin2})>0){
      if(length($admin2->{name}) > 0){
        if (index($admin2->{name},$row->{admin2}) > -1 ||
            index($row->{admin2},$admin2->{name}) > -1){
              $match_name++;
         }
       }
    }
    if(length($row->{admin3})>0){
      if(length($admin3->{name}) > 0){
        if (index($admin3->{name},$row->{admin3}) > -1 ||
            index($row->{admin3},$admin3->{name}) > -1){
              $match_name++;
         }
       }
    }
    if(length($row->{geoname})>0){
      if(length($geoname) > 0){
        if (index($geoname,$row->{geoname}) > -1 ||
            index($row->{geoname},$geoname) > -1){
              $match_name++;
        }
       }
      if(length($admin4->{name}) > 0){
        if (index($admin4->{name},$row->{geoname}) > -1 ||
            index($row->{geoname},$admin4->{name}) > -1){
              $match_name++;
        }
       }
    }
    my $distance = $gis->distance($row->{postalcode_lat}, $row->{postalcode_lng} => $lat,$lng );
    if($match_code > 0 || $match_name > 2 ||
       $distance->kilometers() <= $min_distance_kilometers){
       my $postalcode  = {'geoname' => "", 'group' => "",  'lat' => "", "lng" => "" , 'distance' => -1,
                          'match_code' => 0, 'match_name' => 0 };
       $postalcode->{'geoname'}    = $row->{geoname};
       $postalcode->{'group'}      = $row->{group_postalcode};
       $postalcode->{'lat'}        = $row->{postalcode_lat};
       $postalcode->{'lng'}        = $row->{postalcode_lng};
       $postalcode->{'distance'}   = $distance->kilometers();
       $postalcode->{'match_code'} = $match_code;
       $postalcode->{'match_name'} = $match_name;
       push(@postalcodes,$postalcode);
       $admin1->{code} =  length($admin1->{code}) > 0 ? $admin1->{code} : $row->{geoname_admin1};
       $admin2->{code} =  length($admin2->{code}) > 0 ? $admin2->{code} : $row->{geoname_admin2};
       $admin3->{code} =  length($admin3->{code}) > 0 ? $admin3->{code} : $row->{geoname_admin3};
       $admin1->{name} =  length($admin1->{name}) > 0 ? $admin1->{name} : $row->{admin1};
       $admin2->{name} =  length($admin2->{name}) > 0 ? $admin2->{name} : $row->{admin2};
       $admin3->{name} =  length($admin3->{name}) > 0 ? $admin3->{name} : $row->{admin3};
    }else{
      die('Hello Wold');
    }
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
   # Best score = MAX(match_code + match_name + 1/distance)
   if(@postalcodes > 0){
     my @sorted_postalcodes =  sort { $b->{match_code} + $b->{match_name} + 1/$b->{distance} <=>
                                      $a->{match_code} + $a->{match_name} + 1/$a->{distance} } @postalcodes;
     my @select_postalcodes = ();
     my $max_match = 0;
     if($country eq 'MA'){
       my $i=0;
       while($i <= $#sorted_postalcodes &&
             (my $match_score = $sorted_postalcodes[$i]->{match_code} + $sorted_postalcodes[$i]->{match_name})>= $max_match){
              if($match_score < $max_match_score){
                 $sorted_postalcodes[$i]->{lat}   = $lat;
                 $sorted_postalcodes[$i]->{lng}   = $lng;
                 $sorted_postalcodes[$i]->{group} = (split(/,/, $sorted_postalcodes[$i]->{group}))[0];
                 $max_match = $max_match_score+1;
                 push(@select_postalcodes,$sorted_postalcodes[$i]);
              }else{
                push(@select_postalcodes,$sorted_postalcodes[$i]);
                $max_match = $match_score;
              }
            $i++;
       }
       @postalcodes =  @select_postalcodes;
     }
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
  my $hierarchy = undef;
  if(defined $admin1->{'code'} && length($admin1->{'code'})>0){
    $sthAdmin1->execute($country.'.'.$admin1->{'code'}) || die $DBI::errstr;
    my $row1 = $sthAdmin1->fetchrow_hashref;
    if ( defined $row1->{geoname_id} and length($row1->{geoname_id}) > 0){
      my $id_admin1 = sprintf("GN%.8d",$row1->{geoname_id}) ;
      $admin1->{'id'}   = $row1->{geoname_id};
      $admin1->{'name'} = $row1->{admin1};
      $hierarchy = $hierarchy . gADM1 . $id_admin1;
    }
   }
  if(defined $admin2->{'code'} && length($admin2->{'code'})>0){
    $sthAdmin2->execute($country.'.'.$admin1->{'code'}.'.'.$admin2->{'code'}) || die $DBI::errstr;
    my $row2 = $sthAdmin2->fetchrow_hashref;
    if ( defined $row2->{geoname_id} and length($row2->{geoname_id}) > 0){
      my $id_admin2 = sprintf("GN%.8d",$row2->{geoname_id}) ;
      $admin2->{'id'}   = $row2->{geoname_id};
      $admin2->{'name'} = $row2->{admin2};
      $hierarchy = $hierarchy . gADM2 . $id_admin2;
    }
  }
  if(defined $admin3->{'code'} && length($admin3->{'code'})>0){
     $sthAdmin3->execute($country,$admin1->{'code'},$admin2->{'code'},$admin3->{'code'})|| die $DBI::errstr;
     my $row3 = $sthAdmin3->fetchrow_hashref;
    if ( defined $row3->{geoname_id} and length($row3->{geoname_id}) > 0){
      my $id_admin3 = sprintf("GN%.8d",$row3->{geoname_id}) ;
      $admin3->{'id'}   = $row3->{geoname_id};
      $admin3->{'name'} = $row3->{geoname};
      $hierarchy = $hierarchy . gADM3 . $id_admin3;
    }
  }
  if(defined $admin4->{'code'} && length($admin4->{'code'})>0){
     $sthAdmin4->execute($country,$admin1->{'code'},$admin2->{'code'},$admin3->{'code'},$admin4->{'code'})|| die $DBI::errstr;
     my $row4 = $sthAdmin4->fetchrow_hashref;
    if ( defined $row4->{geoname_id} and length($row4->{geoname_id}) > 0){
      my $id_admin4 = sprintf("GN%.8d",$row4->{geoname_id}) ;
      $admin4->{'id'}   = $row4->{geoname_id};
      $admin4->{'name'} = $row4->{geoname};
      $hierarchy = $hierarchy . gADM4 . $id_admin4;
    }
  }
  return $hierarchy;
}
# ======================================================================
sub cleanPostalCode($){
  my $str = shift;
  $str =~ s/\s+cedex.*$//gi;   # remove 'cedex'
  $str =~ s/\s+air.*$//gi;     # remove 'air'
  $str =~ s/\s+sp.*$//gi;      # remove 'sp'
  $str =~ s/^\s+//g;           # ltrim
  $str =~ s/\s+$//g;           # rtrim
  return $str;
}
# ======================================================================
# ======================================================================
# fetchprint_sql:
sub fetchprint_hierarchy_sql($$$){
  my $dbh = shift;
  my $sql = shift;
  my $tSemantic = shift;
  my $sth = $dbh->prepare($sql) || die $DBI::errstr;
  $sth->execute || die $DBI::errstr;
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
       $gid       = $c->{geoname_id};
       $id        = sprintf("GN%.8d",$c->{geoname_id}) ;
       $country   = $c->{country_iso2};
       $country_id= sprintf("GN%.8d",$c->{country_id});
       $admin1    = {'code' => $c->{geoname_admin1}, 'id'  => "" , 'name' => ""};
       $admin2    = {'code' => $c->{geoname_admin2}, 'id'  => "" , 'name' => ""};
       $admin3    = {'code' => $c->{geoname_admin3}, 'id'  => "" , 'name' => ""};
       $admin4    = {'code' => $c->{geoname_admin4}, 'id'  => "" , 'name' => ""};
       $language  = getCountryLang($c->{country_languages});
       $asciiname = length($c->{geoname_asciiname})>0? $c->{geoname_asciiname}:
                                                       fingerprint($c->{geoname});
       $geoname   = length($c->{geoname})>0? $c->{geoname} :
                                             $c->{geoname_asciiname};
       $bHierarchy  = getHierarchy($country, $admin1,$admin2,$admin3,$admin4);
       $bSemantic =  $DT_S  .
               mSemantic .
               $tSemantic .
               gCISO  .  $country;
       $lat    = $c->{geoname_lat};
       $lng    = $c->{geoname_lng};
       $bCoord =
          gLAT  . escape_num($lat)  .
          gLONG . escape_num($lng);
       $entries{$geoname}  = 'en' . ',' . $language;
       $entries{fingerprint($geoname)}  = 'en';
       $entries{$asciiname} = 'en';
       $entries{fingerprint($asciiname)}  = 'en';
       $alternateNames  = getAlternateNames($c->{geoname_id},$language,\%entries);
       # espape alternative names
       foreach (keys(%{$alternateNames})) {
          $_ = escape_str($_);
       }
       my @postalcodes_list = getPostalCodes($gid, $country, $geoname, $language, $lat, $lng, $admin1,$admin2,$admin3,$admin4);
       unless(@postalcodes_list){
          @postalcodes_list = getClosestPostalCodes($country, $geoname, $lat, $lng, $admin1,$admin2,$admin3,$admin4);
       }
      my $escape_ascii = escape_str($asciiname);
      if(@postalcodes_list > 0){
        foreach my $postalcodes (@postalcodes_list){
          my @postalcode = split(/,/, $postalcodes->{'group'});
          my $postal_lat = length($postalcodes->{'lat'}) > 0 ?
                           escape_num($postalcodes->{'lat'}) : escape_num($c->{geoname_lat}) ;
          my $postal_lng = length($postalcodes->{'lng'}) > 0 ?
                           escape_num($postalcodes->{'lng'}) : escape_num($c->{geoname_lng}) ;
          foreach my $p (@postalcode) {
            foreach (keys(%{$alternateNames})) {
                    print  lc($_) . $SP_S  . $escape_ascii .
                           $bSemantic .
                           gPCod . cleanPostalCode($p) .
                           gLAT  . $postal_lat .
                           gLONG . $postal_lng .
                           $bHierarchy .
                           gID   . $id .
                           gLang . $alternateNames->{$_} .
                           $NL_S;
            }
          }
        }
      }else{
            foreach (keys(%{$alternateNames})) {
                    print  lc($_) . $SP_S  . $escape_ascii .
                           $bSemantic .
                           $bCoord .
                           $bHierarchy .
                           gID . $id .
                           gLang . $alternateNames->{$_} .
                           $NL_S;
           }
      }
  }
  $sth->finish();
}
# ======================================================================
# dic_CapitalCities:
sub dic_CapitalCities($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso2, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_languages, c.geoname_id as country_id FROM  tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'P'
              AND   g.geoname_fcode  IN ('PPLC','PPLCH')
              AND  c.country_iso2 = g.country_iso2";
  my $tSemantic = mCity . mCapital;
  fetchprint_sql  $dbh,$sql, $tSemantic;
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
sub dic_NotableCities($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT g.geoname_id, g.geoname, g.geoname_asciiname, g.geoname_altername,
             g.geoname_lat, g.geoname_lng, g.country_iso2, g.geoname_fclass, g. geoname_fcode,
             g.geoname_admin1, g.geoname_admin2, g.geoname_admin3, g.geoname_admin4,
             c.country_languages, c.geoname_id as country_id FROM  tab_geoname as g , tab_country as c
              WHERE g.geoname_fclass IS 'P'
              AND  g.country_iso2 = 'MA'
              AND  g.geoname_fcode  NOT IN ('PPLC','PPLCH')
              AND  g.geoname_popult >= $MIN_POPULATION
              AND  c.country_iso2 = g.country_iso2";
  my $tSemantic = mCity;
  fetchprint_hierarchy_sql  $dbh,$sql, $tSemantic;
}
#  SELECT g.geoname_id, g.geoname, g.geoname_asciiname,
#             g.geoname_lat, g.geoname_lng, g.country_iso2,
#             c.country_languages FROM  tab_geoname as g , tab_country as c
#              WHERE geoname_fclass IS 'P'
#              AND   geoname_fcode  IN  ('PPL')
#              AND   geoname_popult >= $MIN_POPULATION
#              AND  c.country_iso2 = g.country_iso2";
# ======================================================================
# dic_AdminDivisions:
sub dic_AdminDivisions($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  geoname
              WHERE     (fclass IS 'A'
                         AND  (   fcode  IS 'ADM1'
                               OR fcode  IS 'ADM2'
                               OR fcode  IS 'ADM3'
                               OR fcode  IS 'ADM4'
                              )
                        ) OR
                        (fclass IS 'P'
                         AND  (   fcode  IS 'PPLA'
                               OR fcode  IS 'PPLA2'
                               OR fcode  IS 'PPLA3'
                               OR fcode  IS 'PPLA4'
                              )
                        )
            ";
  my $tSemantic = mDivion;
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Regions:
sub dic_Regions($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  geoname
              WHERE fclass IS 'A'
              AND   admin1 IS NOT '00'
              AND   population >= 5*$MIN_POPULATION";
  my $tSemantic = mRegion;
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Lakes:
sub dic_Lakes($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  geoname
              WHERE isoAlpha2 IS 'US'
              AND   fclass IS 'H'
              AND   fcode  IS 'LK'
              LIMIT 1000
            ";
  my $tSemantic = "+Hydronym+Lake";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Mountains:
sub dic_Mountains($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  tab_geoname
            WHERE country_iso2 IS 'CM'
            AND geoname_fclass IS 'T'
            AND (geoname_fcode  IS 'MT' OR
                 geoname_fcode  IS 'MTS')
            LIMIT 1000
            ";
  my $tSemantic = "+Oronym+Mountain";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Roads:
sub dic_Roads($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  geoname
              WHERE isoAlpha2 IS 'US'
              AND   fclass IS 'R'
              AND   fcode  IS 'RD'
            ";
  my $tSemantic = "+Oronym+Mountain";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Universities:
sub dic_Universities($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  geoname
              WHERE   fclass IS 'S'
              AND   fcode  IS 'UNIV'
            ";
  my $tSemantic = "+Oikonym+University";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# dic_Airports:
sub dic_Airports($){
  my $dbh = shift;
  # get city info
  my $sql = "SELECT * from  geoname
              WHERE   fclass IS 'S'
              AND   fcode  IS 'AIRP'
            ";
  my $tSemantic = "+Oikonym+Airport";
  fetchprint_sql  $dbh,$sql, $tSemantic;
}
# ======================================================================
# Main program
# ======================================================================
#
if ($#ARGV != 1 ) {
 die "Usage: $0 <geonames.org sqlite database file> <dictionary type>
 1: World Countries (+Country)
 2: World Capitals Cities (+City+Capital)
 3: World Other Cities with population >= $MIN_POPULATION (+City)
 4: World Regions with population  >= 5*$MIN_POPULATION (+Region)
 5: US Lakes (+Hydronym+Lake)
 6: US Mountains (+Oronym+Mountain)
 7: US Roads (+Hodonym+Road)
 8: World Universities (+Oikonym+University)
 9: World Airports (+Oikonym+Airport)
10: Administrative division (+Division)\n";
}
my $db_fn   = $ARGV[0];       # geonames.org sqlite database file
my $dictype = $ARGV[1];       # output dictionary
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
$sqlAlternateNames = "SELECT GROUP_CONCAT(altname_lang) as altname_group_lang, altname FROM tab_altname
                              WHERE geoname_id = ? AND
                              altname_collq <> 1 AND
                              (altname_lang IN ('en','es','fr','pt','it','de',?) OR
                               length(altname_lang) = 0)
                              GROUP BY altname";
$sthAlternateNames = $dbh->prepare($sqlAlternateNames) || die $DBI::errstr;
$sqlAdmin1 = "SELECT geoname_id, admin1 from tab_admin1
                     where admin1_code = ?";
$sthAdmin1  =  $dbh->prepare($sqlAdmin1) || die $DBI::errstr;
$sqlAdmin2 = "SELECT geoname_id, admin2 from tab_admin2
                     where admin2_code = ?";
$sthAdmin2  =  $dbh->prepare($sqlAdmin2) || die $DBI::errstr;
$sqlAdmin3 = "SELECT geoname_id, geoname FROM tab_geoname WHERE
               geoname_fclass IS 'A' AND
               geoname_fcode  IS 'ADM3' AND
               country_iso2 = ? AND
               geoname_admin1  = ? AND
               geoname_admin2  = ? AND
               geoname_admin3  = ?";
$sthAdmin3  =  $dbh->prepare($sqlAdmin3) || die $DBI::errstr;
$sqlAdmin4 = "SELECT geoname_id, geoname FROM tab_geoname WHERE
               geoname_fclass IS 'A' AND
               geoname_fcode  IS 'ADM4' AND
               country_iso2 = ? AND
               geoname_admin1  = ? AND
               geoname_admin2  = ? AND
               geoname_admin3  = ? AND
               geoname_admin4  = ?";
$sthAdmin4  =  $dbh->prepare($sqlAdmin4) || die $DBI::errstr;
#$sqlPostalCode = "SELECT country_iso2, GROUP_CONCAT(postalcode) as group_postalcode,  geoname, admin1,
#             geoname_admin1, admin1, geoname_admin2, admin2, geoname_admin3, admin3,
#             postalcode_lat, postalcode_lng
#             FROM tab_postalcode WHERE
#             country_iso2 = ?  AND
#             geoname = ?
#             GROUP BY country_iso2, geoname, admin1, geoname_admin1, admin2, geoname_admin2, admin3, geoname_admin3, postalcode_lat, postalcode_lng";
$sqlPostalCode = "SELECT country_iso2, GROUP_CONCAT(postalcode) as group_postalcode,  geoname, admin1,
                 geoname_admin1, admin1, geoname_admin2, admin2, geoname_admin3, admin3,
                 postalcode_lat, postalcode_lng
                 FROM tab_postalcode WHERE
                 country_iso2 = ?  AND
                 (geoname = ? OR
                  geoname IN (SELECT DISTINCT(altname) FROM tab_altname
                             WHERE geoname_id = ? AND
                             altname_collq <> 1 AND
                            (altname_lang IN ('en','es','fr','pt','it','de',?) OR
                             length(altname_lang) = 0)))
                 GROUP BY country_iso2, geoname, admin1, geoname_admin1, admin2,
                 geoname_admin2, admin3, geoname_admin3, postalcode_lat, postalcode_lng";
$sthPostalCode = $dbh->prepare($sqlPostalCode) || die $DBI::errstr;
$sqlClosestPostalCode  = "SELECT country_iso2, GROUP_CONCAT(postalcode) as group_postalcode,  geoname, admin1,
             geoname_admin1, admin1, geoname_admin2, admin2, geoname_admin3, admin3,
             postalcode_lat, postalcode_lng
             FROM tab_postalcode WHERE
             country_iso2 = ? AND (
             postalcode_lng >= ? AND postalcode_lat >= ? AND
             postalcode_lng <= ? AND postalcode_lat <= ?)
             GROUP BY country_iso2, geoname, admin1, geoname_admin1, admin2,
             geoname_admin2, admin3, geoname_admin3, postalcode_lat, postalcode_lng";
$sthClosestPostalCode =  $dbh->prepare($sqlClosestPostalCode) || die $DBI::errstr;
switch ($dictype){
  case 1  { dic_WorldCountries($dbh); }
  case 2  { dic_CapitalCities($dbh);}
  case 3  { dic_PopulatedCities($dbh);}
  case 4  { dic_Regions($dbh);}
  case 5  { dic_Lakes($dbh);}
  case 6  { dic_Mountains($dbh);}
  case 7  { dic_Roads($dbh);}
  case 8  { dic_Universities($dbh);}
  case 9  { dic_Airports($dbh);}
  case 10 { dic_AdminDivisions($dbh);}
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
