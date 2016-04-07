#!/usr/bin/perl -w
#
# SNMP memory check - version 1.0.2
#
# inspired by script written by one inspired from Corey Henderson
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

use strict;
use warnings;
use Switch;
use Snmp::rqueizan qw(Instance Add_Arg Connect LoadTableValues LoadValue LoadKeysValues LoadValues Nagios_Die Nagios_Exit Add_Perfdata AutoScaleNumbers AutoScaleNumbersLower Add_Perfdata_AutoScale Round);

my @devices = ("linux", "huawei");
Instance(
   "Usage: %s -H <host> (-C <community>|-u <user> -a <authPass> -A <authProt> -p <privPass> -P <privProt>) -w <warn> -c <crit> -d <device>",
   "1.0.1",
   "Memory",
   5,
   "this plugin calculates the used memory in linux and huawei",
   "Example:\n   check_snmp_mem.pl -H 127.0.0.1 -C public -w 80 -c 90 -d linux\n   check_snmp_mem.pl -H 127.0.0.1 -u user -a authPass -A SHA -p privPass -P AES -w 80 -c 90 -d linux",
   1,
   \@devices);
Connect();
my $percent = 0;
my $warn  = $Snmp::rqueizan::warn;
my $crit  = $Snmp::rqueizan::crit;
my $device = $Snmp::rqueizan::device;
switch ($device) {
   case "linux"
   {
      my @labels = ("Free", "Total", "Cached", "Buffers");
      my @values = LoadValues(".1.3.6.1.4.1.2021.4.6.0", ".1.3.6.1.4.1.2021.4.5.0", ".1.3.6.1.4.1.2021.4.15.0", ".1.3.6.1.4.1.2021.4.14.0");
      $values[0] = $values[0] + $values[2] + $values[3];
      my $used = $values[1] - $values[0];
      $percent = Round($used*100/$values[1],2);
      Add_Perfdata_AutoScale("Used", $used, "B", $values[1]*$warn/100, $values[1]*$crit/100, 0, $values[1], 1, 2);
      for (my $i=0;$i<=$#values;$i++) { Add_Perfdata_AutoScale($labels[$i], $values[$i], "B", undef, undef, undef, undef, 1, 2); }
   }
   case "huawei"
   {
      my ($keysR, $valuesTR) = LoadKeysValues(".1.3.6.1.4.1.2011.6.3.5.1.1.2", 15);
      my ($keysFR, $valuesFR) = LoadKeysValues(".1.3.6.1.4.1.2011.6.3.5.1.1.3", 15);
      my @keys = @{ $keysR };
      my @totals = @{ $valuesTR };
      my @values = @{ $valuesFR };
      for (my $i=0;$i<=$#totals;$i++)
      {
         $values[$i] = $totals[$i] - $values[$i];
         $percent = $percent +  $values[$i]*100/$totals[$i];
         Add_Perfdata_AutoScale("slot" . $keys[$i] . "-used", $values[$i], "B", $totals[$i]*$warn/100, $totals[$i]*$crit/100, 0, $totals[$i], 0, 2);
         Add_Perfdata_AutoScale("slot" . $keys[$i] . "-total", $totals[$i], "B", undef, undef, undef, undef, 0, 2);
      }
      $percent = Round($percent/($#totals+1),2);
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("mem used: $percent%" );
