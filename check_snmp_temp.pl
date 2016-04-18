#!/usr/bin/perl -w
#
# SNMP temperature check - version 1.0.1
#
# inspired by script written by one inspired from Corey Henderson
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

use strict;
use warnings;
use Switch;
use Snmp::rqueizan qw(Instance Add_Arg Connect LoadKeysValues Nagios_Die Nagios_Exit Add_Perfdata_AutoScale Get_Arg Get_Warning Get_Critical Get_Device);

my @devices = ("huawei");
Instance(
   "Usage: %s -H <host> (-C <community>|-u <user> -a <authPass> -A <authProt> -p <privPass> -P <privProt>) -w <warn> -c <crit> -d <device>  -s <sensorID> -l <label>",
   "1.0.1",
   "Temp",
   5,
   "this plugin calculates the used memory in huawei",
   "Example:\n   check_snmp_temp.pl -H 127.0.0.1 -C public -w 80 -c 90 -d huawei -s 1231425 -l chasis\n   check_snmp_temp.pl -H 127.0.0.1 -u user -a authPass -A SHA -p privPass -P AES -w 80 -c 90 -d huawei -s 1231425 -l chasis",
   1,
   \@devices);
Add_Arg("sensor|s=s", "id of sensor to monitoring", undef, 1);
Add_Arg("label|l=s", "label of sensor to monitoring", undef, 1);
Connect();
my $warn  = Get_Warning();
my $crit  = Get_Critical();
my $device = Get_Device();
my $sensor = Get_Arg("sensor");
my $label = Get_Arg("label");
switch ($device) {
   case "huawei"
   {
      my ($keysR, $valuesR) = LoadKeysValues("1.3.6.1.4.1.2011.5.25.31.1.1.1.1.11", 15);
      my @keys = @{ $keysR };
      my @values = @{ $valuesR };
      my $count = 0;
      for (my $i=0;$i<=$#values;$i++)
      {
         if ($keys[$i] eq $sensor)
         {
            $count++;
            Add_Perfdata_AutoScale($label, $values[$i], "C", $warn, $crit, 0, $crit, 0, 2);
         }
      }
      if ($count == 0) { Nagios_Die("sensor '$sensor' could not be requested"); }
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("success temp adquired" );
