#!/usr/bin/perl -w
#
# SNMP disk check - version 1.0.0
#
# inspired by script written by one inspired from Corey Henderson
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

use strict;
use warnings;
use Switch;
use Snmp::rqueizan qw(Instance Add_Arg Connect LoadTableValues Nagios_Die Nagios_Exit Add_Perfdata_AutoScale Get_Warning Get_Critical Get_Device Get_Arg Get_Args);

my @devices = ("linux");
Instance(
   "Usage: %s -H <host> (-C <community>|-u <user> -a <authPass> -A <authProt> -p <privPass> -P <privProt>) -w <warn> -c <crit> -d <device> -m <mount path> -e <yes|no>",
   "1.0.1",
   "Temp",
   5,
   "this plugin calculates the used disk in linux",
   "Example:\n   check_snmp_disk.pl -H 127.0.0.1 -C public -w 80 -c 90 -d linux -m /boot\n   check_snmp_disk.pl -H 127.0.0.1 -u user -a authPass -A SHA -p privPass -P AES -w 80 -c 90 -d linux -m /var /e yes",
   1,
   \@devices);
Add_Arg("mount|m=s", "select mount path to monitoring", undef, 0);
Add_Arg("exclude|e=s", "exlude mount paths indicates, default no", "no", 0);
Connect();
my $warn  = Get_Warning();
my $crit  = Get_Critical();
my $device = Get_Device();
my @list = Get_Args("mount");
my $exc = Get_Arg("exclude");
switch ($device) {
   case "linux"
   {
      my @names = LoadTableValues(".1.3.6.1.4.1.2021.9.1.2");
      my @totals = LoadTableValues(".1.3.6.1.4.1.2021.9.1.6");
      my @useds = LoadTableValues(".1.3.6.1.4.1.2021.9.1.8");
      for (my $i=0;$i<=$#names;$i++)
      {
         my $esta = 0;
         for my $element (@list) { if ($element eq $names[$i]) {$esta = 1;} }
         if ((($esta != 0) xor ($exc eq "yes")) or ($#list == -1)) { Add_Perfdata_AutoScale($names[$i], $useds[$i], "B", $totals[$i]*$warn/100, $totals[$i]*$crit/100, 0, $totals[$i], 1, 2); }
      }
   }
   else { Nagios_Die("device '$device' not implemented"); }
}
Nagios_Exit("success disk adquired" );
