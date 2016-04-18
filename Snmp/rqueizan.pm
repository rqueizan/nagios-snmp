# -*- mode: perl -*-
#
# SNMP Nagios Common - version 1.0.2
#
# 
# Author: Rene Queizan Perez, rqueizan@uci.cu rqueizan@outlook.com
#

package Snmp::rqueizan;
use strict;
use warnings;
use Net::SNMP;
use Nagios::Plugin;
#use Nagios::Plugin::Getopt;
use Math::Round;
use List::Util qw[max min];
use Scalar::Util qw(looks_like_number);
use Switch;

my $nagios_plugin = Nagios::Plugin->new(usage=>"null");
my @authprotocols = ("MD5", "SHA");
my @privprotocols = ("DES", "AES");
my @devices = undef;
my $ver = undef;
my $session = undef;
my $code = 0;
my $countWC = undef;
my @args = ("warning","critical","device");

use Exporter qw(import);

our @EXPORT_OK = qw(Instance Add_Arg Connect LoadTable LoadKeysValues LoadTableValues LoadValue LoadValues Nagios_Die Nagios_Exit CheckNumber CheckNumbers CheckNumberLowerThanOther CheckNumbersLowersThanOthers CheckInList CheckNotNull Add_Perfdata AutoScaleNumber AutoScaleNumbers AutoScaleNumbersLower Round Add_Perfdata_AutoScale Get_Arg Get_Args Get_Warning Get_Critical Get_Device);

#Public Methods
sub Instance # usage version shortname timeout blurb extra count devices
{
   Nagios_Die("Instance: required 'usage version shortname timeout blurb extra count devices'") unless @_ == 8;
   my ($usage, $version, $shortname, $timeout, $blurb, $extra, $count, $devicesR) = @_;
   CheckNumber($count, 1, undef, "Instance: required count of Warnings/Criticals");
   $nagios_plugin = Nagios::Plugin->new(
      usage     => $usage,
      version   => $version,
      shortname => "SNMP " . $shortname,
      timeout   => $timeout,
      blurb     => $blurb,
      extra     => $extra
   );
   $countWC = $count;
   @devices = @{ $devicesR };
   add_Def_Arg();
}
sub Add_Arg # spec help default required
{
   Nagios_Die("Add_Arg: required 'spec help default required'") unless @_ == 4;
   my ($spec, $help, $default, $required) = @_;
   CheckNotNull($spec, "Add_Arg: require valid spec");
   CheckNotNull($help, "Add_Arg: require valid help");
   $nagios_plugin->add_arg(
      spec		=> $spec,
      help		=> $help,
      default  => $default,
      required	=> $required,
   );#mount|
   my @name = split(/\|/ , $spec);
   push(@args,$name[0]);
}
sub Connect
{
   $nagios_plugin->getopts;
   CheckInList($nagios_plugin->opts->device, \@devices, "unknow device '" . $nagios_plugin->opts->device . "', must be (" . join("|", @devices) . ")");
   CheckInList($nagios_plugin->opts->authprotocol, \@authprotocols, "unknow protocol '" . $nagios_plugin->opts->authprotocol . "', must be (" . join("|", @authprotocols) . ")") unless !defined $nagios_plugin->opts->authprotocol;
   CheckInList($nagios_plugin->opts->privprotocol, \@privprotocols, "unknow protocol '" . $nagios_plugin->opts->privprotocol . "', must be (" . join("|", @privprotocols) . ")") unless !defined $nagios_plugin->opts->privprotocol;
   checkSNMP2Or3();
   if ($countWC == 1)
   {
      my $warn = $nagios_plugin->opts->warning;
      my $crit = $nagios_plugin->opts->critical;
      CheckNumber($warn, 0, undef, "warning");
      CheckNumber($crit, 0, undef, "critical");
      CheckNumberLowerThanOther($warn, $crit, "warning", "critical");
   }
   else
   {
      my @warns = split(/,/ , $nagios_plugin->opts->warning);
      my @crits = split(/,/ , $nagios_plugin->opts->critical);
      CheckNumbers(\@warns, $countWC, 0, undef, "warning");
      CheckNumbers(\@crits, $countWC, 0, undef, "critical");
      CheckNumbersLowersThanOthers(\@warns, \@crits, $countWC, "warning", "critical");
   }
   my $error = undef;
   if ($ver == 3)
   {
      ($session, $error) = Net::SNMP->session(
         -hostname     => $nagios_plugin->opts->host,
         -version      => 3,
         -username     => $nagios_plugin->opts->username,
         -authpassword => $nagios_plugin->opts->authpassword,
         -authprotocol => $nagios_plugin->opts->authprotocol,
         -privpassword => $nagios_plugin->opts->privpassword,
         -privprotocol => $nagios_plugin->opts->privprotocol,
         -timeout      => $nagios_plugin->opts->timeout,
      );
   }
   else
   {
      ($session, $error) = Net::SNMP->session(
         -hostname  => $nagios_plugin->opts->host,
         -community => $nagios_plugin->opts->community,
         -version   => 2,
         -timeout   => $nagios_plugin->opts->timeout,
      );
   }
   if (!defined $session) { Nagios_Die($error); }
}
sub LoadTable # oid
{
   Nagios_Die("LoadTable: required 'oid'") unless @_ == 1;
   check_Connect();
   my $oid = shift;
   CheckNotNull($oid, "LoadTable: require valid OID");
   my $table = $session->get_table($oid);
   checkDataResult($table);
   return $table;
}
sub LoadKeysValues # oid index
{
   Nagios_Die("LoadTableValues: required 'oid index'") unless @_ == 2;
   check_Connect();
   my ($oid, $index) = @_;
   my $table = LoadTable($oid);
   my @keys = undef;
   my @values = undef;
   my $i = 0;
   foreach my $key (sort keys %$table)
   {
      if (!defined $index) { $keys[$i] = $key; }
      else
      {
         my @sub = split(/\./ , $key);
         $keys[$i] = $sub[$index];
      }
      $values[$i++] = $$table{$key};
   }
   return (\@keys, \@values);
}
sub LoadTableValues # oid
{
   Nagios_Die("LoadTableValues: required 'oid'") unless @_ == 1;
   check_Connect();
   my $oid = shift;
   my $table = LoadTable($oid);
   my @values = undef;
   my $i = 0;
   foreach my $key (sort keys %$table) { $values[$i++] = $$table{$key}; }
   return @values;
}
sub LoadValue # oid
{
   Nagios_Die("LoadValue: required 'oid'") unless @_ == 1;
   check_Connect();
   my $oid = shift;
   CheckNotNull($oid, "LoadValue: require valid OID");
   my $valueb = $session->get_request(-varbindlist => [$oid],);
   my $value = $valueb->{$oid};
   checkDataResult($value);
   return $value;
}
sub LoadValues # oid
{
   Nagios_Die("LoadValues: required 'oid'") unless @_ >= 1;
   check_Connect();
   my (@oids) = @_;
   my @list = undef;
   my $i = 0;
   foreach my $oid (@oids) { $list[$i++] = LoadValue($oid); }
   return @list;
}
sub Nagios_Die # description
{
   close_snmp();
   Nagios_Die("Nagios_Die: required 'description'") unless @_ == 1;
   my $description = shift;
   $nagios_plugin->nagios_die($description);
}
sub Nagios_Exit # message
{
   close_snmp();
   Nagios_Die("Nagios_Exit: required 'message'") unless @_ == 1;
   my $message = shift;
   $nagios_plugin->nagios_exit( 
      return_code => $code, 
      message     => $message 
   );
}
sub CheckNumber # number min max description
{
   Nagios_Die("CheckNumber: required 'number min max description'") unless @_ == 4;
   my ($number, $min, $max, $description) = @_;
   if (!defined $number) { Nagios_Die("$description, invalid number."); }
   elsif (!looks_like_number($number)) { Nagios_Die("$description, invalid value, $number."); }
   my $low = (defined $min) && ($number < $min);
   my $upp = (defined $max) && ($number > $max);
   if ($low)
   {
      if (defined $max) { Nagios_Die("$description, must be between $min and $max, $number."); }
      else { Nagios_Die("$description, must be greater than $min, $number."); }
   } elsif ($upp)
   {
      if (defined $min) { Nagios_Die("$description, must be between $min and $max, $number."); }
      else { Nagios_Die("$description, invalid must be lower than $max, $number."); }
   }
}
sub CheckNumbers # list count min max element
{
   Nagios_Die("CheckNumbers: required 'list count min max element'") unless @_ == 5;
   my ($listR, $count, $min, $max, $element) = @_;
   my @list = @{ $listR };
   if (!defined $count) { $count = $#list+1; }
   if ($#list+1 != $count) { Nagios_Die("must be $count $element" . "s numbers"); }
   for (my $i=0;$i<$count;$i++) { CheckNumber($list[$i], $min, $max, $element); }
}
sub CheckNumberLowerThanOther # min max namei namem
{
   Nagios_Die("CheckNumberLowerThanOther: required 'min max namei namem'") unless @_ == 4;
   my ($min, $max, $namei, $namem) = @_;
   if ( $min >= $max ) { Nagios_Die( "$namei value '$min' must be lower than $namem value '$max'" ); }
}
sub CheckNumbersLowersThanOthers # min max count namei namem
{
   my ($minR, $maxR, $count, $namei, $namem) = @_;
   my @min = @{ $minR };
   my @max = @{ $maxR };
   if (!defined $count) { $count = $#min+1; }
   for (my $i=0;$i<$count;$i++) { CheckNumberLowerThanOther($min[$i], $max[$i], $namei, $namem); }
}
sub CheckInList # value list description
{
   Nagios_Die("CheckInList: required 'value list description'") unless @_ >= 3;
   my ($value, $listR, $description) = @_;
   my @list = @{ $listR };
   my $found = undef;
   for my $element (@list) { if ($element eq $value) { $found = 1; } }
   if (! defined $found) { Nagios_Die($description); }
}
sub CheckNotNull # value description
{
   Nagios_Die("CheckNotNull: required 'value description'") unless @_ == 2;
   my $value = shift;
   my $description = shift;
   if (!defined $value) { Nagios_Die($description); }
}
sub Add_Perfdata # label value warning critical min max
{
   Nagios_Die("Add_Perfdata: required 'label value, uom warning critical min max'") unless @_ == 7;
   my ($label, $value, $uom, $warning, $critical, $min, $max) = @_;
   $nagios_plugin->add_perfdata(
      label    => $label,
      value    => $value,
      uom      =>	$uom,
      warning  => $warning,
      critical => $critical,
      min      => $min,
      max      => $max
   );
   my $result = $nagios_plugin->check_threshold(check => $value, warning => $warning, critical => $critical, );
   $code = max($code,$result);
}
sub Add_Perfdata_AutoScale # label value uom warning critical min max desp decimals
{
   Nagios_Die("Add_Perfdata_AutoScale: required 'label value uom warning critical min max desp decimals'") unless @_ == 9;
   my ($label, $value, $uom, $warning, $critical, $min, $max, $desp, $decimals) = @_;
   my @perf = ($value, $warning, $critical, $min, $max);
   my ($valsR, $uoma) = AutoScaleNumbersLower(\@perf, $uom, $desp, $decimals);
   @perf = @{ $valsR };
   Add_Perfdata($label, $perf[0], $uoma, $perf[1], $perf[2], $perf[3], $perf[4]);
}
sub AutoScaleNumber # num uom desp decimals
{
   Nagios_Die("AutoScaleNumber: required 'num uom desp decimals'") unless @_ == 4;
   my ($num, $uom, $desp, $decimals) = @_;
   my $n = $num;
   while ($n >= 1024) { $n = $n / 1024; $desp++; }
   if ($n == 0) { $desp = 0; }
   my $u = undef;
   switch ($desp)
   {
      case 1  { $u = "K"; }
      case 2  { $u = "M"; }
      case 3  { $u = "G"; }
      case 4  { $u = "T"; }
      else    { $u = ""; $n = $num; }
   }
   return (Round($n, $decimals), $u . $uom);
}
sub AutoScaleNumbers # nums uom desp decimals
{
   Nagios_Die("AutoScaleNumbers: required 'nums uom desp decimals'") unless @_ == 4;
   my ($numsR, $uom, $desp, $decimals) = @_;
   my @nums = @{ $numsR };
   my @uomas = undef;
   for (my $i=0;$i<=$#nums;$i++)
   {
      my ($n, $uoma) = AutoScaleNumber($nums[$i], $uom, $desp, $decimals);
      $nums[$i] = $n;
      $uomas[$i] = $uoma;
   }
   return (\@nums, \@uomas);
}
sub AutoScaleNumbersLower # nums uom desp decimals
{
   Nagios_Die("AutoScaleNumbers: required 'nums uom desp decimals'") unless @_ == 4;
   my ($numsR, $uom, $desp, $decimals) = @_;
   my @nums = @{ $numsR };
   my $uoma1 = undef;
   my $d = 0;
   my $m = 0;
   for my $element (@nums) { if (defined $element) { $m = max($m,$element); } }
   for my $element (@nums) { if (defined $element && $element != 0) { $m = min($m,$element); } }
   while ($m >= 1024) { $m = $m / 1024; $d++; }
   for (my $i=0;$i<=$#nums;$i++)
   {
      if (defined $nums[$i])
      {
      my ($n, $uoma) = autoScaleNumberLower($nums[$i], $uom, $desp, $d, $decimals);
      $nums[$i] = $n;
      $uoma1 = $uoma;
      }
   }
   return (\@nums, $uoma1);
}
sub Round # num decimals
{
   Nagios_Die("Round: required 'num decimals'") unless @_ == 2;
   my ($num, $decimals) = @_;
   CheckNumber($num, undef, undef, "number to round");
   CheckNumber($decimals, 0, undef, "decimals digits");
   sprintf("%." . $decimals . "f", $num);
}
sub Get_Arg # name
{
   Nagios_Die("Get_Arg: required 'name'") unless @_ == 1;
   my ($name) = @_;
   return $nagios_plugin->opts->$name;
}
sub Get_Args # name
{
   Nagios_Die("Get_Args: required 'name'") unless @_ == 1;
   my ($name) = @_;
   CheckInList($name, \@args, "Invalid argument '$name'");
   return () unless defined $nagios_plugin->opts->$name;
   return split(/,/ , $nagios_plugin->opts->$name);
}
sub Get_Warning
{
   if ($countWC == 1) { return Get_Arg("warning"); }
   else { return Get_Args("warning"); }
}
sub Get_Critical
{
   if ($countWC == 1) { return Get_Arg("critical"); }
   else { return Get_Args("critical"); }
}
sub Get_Device
{
   return Get_Arg("device");
}
#Private Methods
sub add_Def_Arg
{
   $nagios_plugin->add_arg(
      spec		=> "host|H=s",
      help		=> "ip address or hostname of device",
      required	=> 1,
   );
   $nagios_plugin->add_arg(
      spec		=> "community|C=s",
      help		=> "snmp community string, required for snmp v2",
      required	=> 0,
   );
   $nagios_plugin->add_arg(
      spec		=> "username|u=s",
      help		=> "username, required for snmp v3",
      required	=> 0,
   );
   $nagios_plugin->add_arg(
      spec		=> "authpassword|a=s",
      help		=> "authentication password, required for snmp v3",
      required	=> 0,
   );
   $nagios_plugin->add_arg(
      spec		=> "authprotocol|A=s",
      help		=> "MD5|SHA, required for snmp v3",
      required	=> 0,
   );
   $nagios_plugin->add_arg(
      spec		=> "privpassword|p=s",
      help		=> "privacy password, required for snmp v3",
      required	=> 0,
   );
   $nagios_plugin->add_arg(
      spec		=> "privprotocol|P=s",
      help		=> "DES|AES, required for snmp v3",
      required	=> 0,
   );
   if ($countWC == 1)
   {
      $nagios_plugin->add_arg(
         spec		=> "warning|w=i",
         help		=> "warning level",
         required	=> 1,
      );
      $nagios_plugin->add_arg(
         spec		=> "critical|c=i",
         help		=> "critical level",
         required	=> 1,
      );
   } else
   {
      $nagios_plugin->add_arg(
         spec		=> "warning|w=s",
         help		=> "$countWC warning levels separed by comma",
         required	=> 1,
      );
      $nagios_plugin->add_arg(
         spec		=> "critical|c=s",
         help		=> "$countWC critical levels separed by comma",
         required	=> 1,
      );
   }
   $nagios_plugin->add_arg(
      spec		=> "device|d=s",
      help		=> join("|", @devices),
      required	=> 1,
   );
}
sub checkSNMP2Or3
{
   if (defined $nagios_plugin->opts->username || defined $nagios_plugin->opts->authpassword || defined $nagios_plugin->opts->authprotocol || defined $nagios_plugin->opts->privpassword || defined $nagios_plugin->opts->privprotocol)
   {
      if (!defined $nagios_plugin->opts->username || !defined $nagios_plugin->opts->authpassword || !defined $nagios_plugin->opts->authprotocol || !defined $nagios_plugin->opts->privpassword || !defined $nagios_plugin->opts->privprotocol)
      { Nagios_Die("username,authPassword,authProtocol,privPassword,privProtocol, required by snmp v3"); }
      else { $ver = 3; }
   }
   elsif (!defined $nagios_plugin->opts->community) { Nagios_Die("community name required by snmp v2"); }
   else { $ver = 2; }
}
sub close_snmp
{
   if (defined $session) { $session->close(); }
}
sub check_Connect
{
   if (!defined $session) { Nagios_Die("SNMP not connected"); }
}
sub autoScaleNumberLower # num uom desp max decimals
{
   Nagios_Die("autoScaleNumberLower: required 'num uom desp max decimals'") unless @_ == 5;
   my ($num, $uom, $desp, $max, $decimals) = @_;
   my $n = $num;
   for (my $i=0;$i<$max;$i++) { $n = $n / 1024; }
   if ($n == 0) { $max = -$desp; }
   my $u = undef;
   switch ($desp + $max)
   {
      case 1  { $u = "K"; }
      case 2  { $u = "M"; }
      case 3  { $u = "G"; }
      case 4  { $u = "T"; }
      else    { $u = ""; $n = $num; }
   }
   return (Round($n, $decimals), $u . $uom);
}
sub checkDataResult # list
{
   my @list = @_;
   for my $data (@list)
   {
      if ( !defined $data) { Nagios_Die("request data failed"); }
      elsif ( $data eq "noSuchObject" ) { Nagios_Die("request data failed '$data'"); }
      elsif ( $data eq "noSuchInstance" ) { Nagios_Die("request data failed '$data'"); }
   }
}
1;