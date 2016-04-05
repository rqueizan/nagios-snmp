#!/usr/bin/perl -w
#
# SNMP load check - version 1.0.3
#
# inspired by script written by one inspired from Corey Henderson
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

use strict;
use warnings;
use Switch;
use Snmp::rqueizan qw(Instance Add_Arg Connect LoadKeysValues LoadTableValues LoadValue LoadValues Nagios_Die Nagios_Exit Add_Perfdata);

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
my @labels = undef;
my @values = undef;
my @warns  = @Snmp::rqueizan::warns;
my @crits  = @Snmp::rqueizan::crits;
my $device = $Snmp::rqueizan::device;
switch ($device) {
   case "linux"
   {
      @labels = LoadTableValues(".1.3.6.1.4.1.2021.10.1.2");
      @values = LoadTableValues(".1.3.6.1.4.1.2021.10.1.3");
      for (my $i=0;$i<3;$i++) { Add_Perfdata($labels[$i], $values[$i], undef, $warns[$i], $crits[$i], 0, $crits[$i]); }
   }
   case "huawei"
   {
      @labels = ("load", "load1", "load5");
      my $oid = ".1.3.6.1.4.1.2011.6.3.4.1";
      my ($keysR, $valuesR) = LoadKeysValues($oid, 14);
      my @keys = @{ $keysR };
      my @values = @{ $valuesR };
      my $cpus = ($#values + 1) / 3;
      for (my $i=0;$i<$cpus;$i++)
      {
         Add_Perfdata("slot" . $keys[$i] . "load", $values[$i], undef, $warns[0], $crits[0], 0, $crits[0]);
         Add_Perfdata("slot" . $keys[$i] . "load1", $values[$i+$cpus], undef, $warns[1], $crits[1], 0, $crits[1]);
         Add_Perfdata("slot" . $keys[$i] . "load5", $values[$i+$cpus*2], undef, $warns[2], $crits[2], 0, $crits[2]);
      }
      @values = LoadValues(".1.3.6.1.4.1.2011.6.3.4.1.2.0.4.0", ".1.3.6.1.4.1.2011.6.3.4.1.3.0.4.0", ".1.3.6.1.4.1.2011.6.3.4.1.4.0.4.0");
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("load average: XXX" ); # $values[0], $values[1], $values[2]
