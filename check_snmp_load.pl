#!/usr/bin/perl -w
#
# SNMP load check - version 1.0.5
#
# inspired by script written by one inspired from Corey Henderson
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

use strict;
use warnings;
use Switch;
use Snmp::rqueizan qw(Instance Connect LoadKeysValues LoadTableValues Nagios_Die Nagios_Exit Add_Perfdata Get_Warning Get_Critical Get_Device);

my @devices = ("linux", "huawei");
Instance(
   "Usage: %s -H <host> (-C <community>|-u <user> -a <authPass> -A <authProt> -p <privPass> -P <privProt>) -w <warn> -c <crit> -d <device>",
   "1.0.3",
   "Load",
   5,
   "this plugin calculates the load average in linux and huawei",
   "Example:\n   check_snmp_load.pl -H 127.0.0.1 -C public -w 5,4,3 -c 10,6,4 -d linux\n   check_snmp_load.pl -H 127.0.0.1 -u user -a authPass -A SHA -p privPass -P AES -w 5,4,3 -c 10,6,4 -d linux",
   3,
   \@devices);
Connect();
my @percent = (0,0,0);
my @warns  = Get_Warning();
my @crits  = Get_Critical();
my $device = Get_Device();
switch ($device) {
   case "linux"
   {
      my @labels = LoadTableValues(".1.3.6.1.4.1.2021.10.1.2");
      my @values = LoadTableValues(".1.3.6.1.4.1.2021.10.1.3");
      for (my $i=0;$i<3;$i++)
      {
         $percent[$i] = $values[$i];
         Add_Perfdata($labels[$i], $values[$i], undef, $warns[$i], $crits[$i], 0, $crits[$i]);
      }
   }
   case "huawei"
   {
      my ($keysR, $valuesR) = LoadKeysValues(".1.3.6.1.4.1.2011.6.3.4.1", 14);
      my @keys = @{ $keysR };
      my @values = @{ $valuesR };
      my $cpus = ($#values + 1) / 3;
      for (my $i=0;$i<$cpus;$i++)
      {
         $percent[0] = $percent[0] + $values[$i];
         $percent[1] = $percent[1] + $values[$i+$cpus];
         $percent[2] = $percent[2] + $values[$i+$cpus*2];
         Add_Perfdata("slot" . $keys[$i] . "-load", $values[$i], undef, $warns[0], $crits[0], 0, 100);
         Add_Perfdata("slot" . $keys[$i] . "-load1", $values[$i+$cpus], undef, $warns[1], $crits[1], 0, 100);
         Add_Perfdata("slot" . $keys[$i] . "-load5", $values[$i+$cpus*2], undef, $warns[2], $crits[2], 0, 100);
      }
      $percent[0] = $percent[0]/$cpus;
      $percent[1] = $percent[1]/$cpus;
      $percent[2] = $percent[2]/$cpus;
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("load average: $percent[0]%, $percent[1]%, $percent[2]%" );
