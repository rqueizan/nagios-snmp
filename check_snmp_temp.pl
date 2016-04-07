#!/usr/bin/perl -w
#
# SNMP temperature check - version 1.0.0
#
# inspired by script written by one inspired from Corey Henderson
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

use strict;
use warnings;
use Switch;
use Snmp::rqueizan qw(Instance Add_Arg Connect LoadTableValues LoadValue LoadKeysValues LoadValues Nagios_Die Nagios_Exit Add_Perfdata AutoScaleNumbers AutoScaleNumbersLower Add_Perfdata_AutoScale Round);

my @devices = ("huawei");
Instance(
   "Usage: %s -H <host> (-C <community>|-u <user> -a <authPass> -A <authProt> -p <privPass> -P <privProt>) -w <warn> -c <crit> -d <device>",
   "1.0.1",
   "Temp",
   5,
   "this plugin calculates the used memory in linux and huawei",
   "Example:\n   check_snmp_temp.pl -H 127.0.0.1 -C public -w 80 -c 90 -d linux\n   check_snmp_temp.pl -H 127.0.0.1 -u user -a authPass -A SHA -p privPass -P AES -w 80 -c 90 -d linux",
   1,
   \@devices);
Connect();
my $average = 0;
my $warn  = $Snmp::rqueizan::warn;
my $crit  = $Snmp::rqueizan::crit;
my $device = $Snmp::rqueizan::device;
switch ($device) {
   case "huawei"
   {
      my ($keysR, $valuesR) = LoadKeysValues("1.3.6.1.4.1.2011.5.25.31.1.1.1.1.11", 15);
      my @keys = @{ $keysR };
      my @values = @{ $valuesR };
      my $count = 0;
      for (my $i=0;$i<=$#values;$i++)
      {
         if ($values[$i] > 0)
         {
            $count++;
            $average = $average + $values[$i];
            Add_Perfdata_AutoScale($keys[$i], $values[$i], "C", $warn, $crit, 0, $crit, 0, 2);
         }
      }
      $average = Round($average/$count,2);
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("average temp: $average °C" );
