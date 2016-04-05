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
use Snmp::rqueizan qw(Instance Add_Arg Connect LoadTableValues LoadValue LoadValues Nagios_Die Nagios_Exit Add_Perfdata AutoScaleNumbers AutoScaleNumbersLower Add_Perfdata_AutoScale Round);

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
my @labels = undef;
my @values = undef;
my $used = undef;
my $percent = undef;
my $warn  = $Snmp::rqueizan::warn;
my $crit  = $Snmp::rqueizan::crit;
my $device = $Snmp::rqueizan::device;
switch ($device) {
   case "linux"
   {
      @labels = ("Free", "Total", "Cached", "Buffers");
      @values = LoadValues(".1.3.6.1.4.1.2021.4.6.0", ".1.3.6.1.4.1.2021.4.5.0", ".1.3.6.1.4.1.2021.4.15.0", ".1.3.6.1.4.1.2021.4.14.0");
      $values[0] = $values[0] + $values[2] + $values[3];
      $used = $values[1] - $values[0];
      $percent = Round($used*100/$values[1],2);
      Add_Perfdata_AutoScale("Used", $used, "B", $values[1]*$warn/100, $values[1]*$crit/100, 0, $values[1], 1, 2);
      for (my $i=0;$i<=$#values;$i++) { Add_Perfdata_AutoScale($labels[$i], $values[$i], "B", undef, undef, undef, undef, 1, 2); }
   }
   case "huawei"
   {
      @labels = ("Used1", "Total1", "Used2", "Total2");
      @values = LoadValues("1.3.6.1.4.1.2011.6.3.5.1.1.2.0.1.0", "1.3.6.1.4.1.2011.6.3.5.1.1.2.0.4.0", "1.3.6.1.4.1.2011.6.3.5.1.1.2.0.2.0", "1.3.6.1.4.1.2011.6.3.5.1.1.2.0.5.0");
      $percent = Round(($values[0]*100/$values[1]+$values[0]*100/$values[1])/2,2);
      Add_Perfdata_AutoScale($labels[0], $values[0], "B", $values[1]*$warn/100, $values[1]*$crit/100, 0, $values[1], 0, 2);
      Add_Perfdata_AutoScale($labels[2], $values[2], "B", $values[3]*$warn/100, $values[3]*$crit/100, 0, $values[3], 0, 2);
      Add_Perfdata_AutoScale($labels[1], $values[1], "B", undef, undef, undef, undef, 0, 2);
      Add_Perfdata_AutoScale($labels[3], $values[3], "B", undef, undef, undef, undef, 0, 2);
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("mem used: $percent%" );
