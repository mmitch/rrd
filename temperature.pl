#!/usr/bin/perl
# $Id: temperature.pl,v 1.28 2007-07-13 18:14:14 mitch Exp $
#
# RRD script to display hardware temperature
# 2003,2007 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $datafile = "$conf{DBPATH}/temperature.rrd";
my $picbase  = "$conf{OUTPATH}/temperature-";

my $sensors  = $conf{SENSORS_BINARY};
my $hddtemp  = $conf{HDDTEMP_BINARY};
my $cpus     = $conf{SENSOR_MAPPING_CPU};
my $fans     = $conf{SENSOR_MAPPING_FAN};
my $temps    = $conf{SENSOR_MAPPING_TEMP};

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 9000 for fan, 100 for temperature
    RRDs::create($datafile,
		 "DS:fan0:GAUGE:600:0:9000",
		 "DS:fan1:GAUGE:600:0:9000",
		 "DS:fan2:GAUGE:600:0:9000",
		 "DS:fan3:GAUGE:600:0:9000",
		 "DS:temp0:GAUGE:600:10:100",
		 "DS:temp1:GAUGE:600:10:100",
		 "DS:temp2:GAUGE:600:10:100",
		 "DS:temp3:GAUGE:600:10:100",
		 "DS:cpu0:GAUGE:600:10:100",
		 "DS:cpu1:GAUGE:600:10:100",
		 "DS:cpu2:GAUGE:600:10:100",
		 "DS:cpu3:GAUGE:600:10:100",
		 "DS:disk00:GAUGE:600:10:100",
		 "DS:disk01:GAUGE:600:10:100",
		 "DS:disk02:GAUGE:600:10:100",
		 "DS:disk03:GAUGE:600:10:100",
		 "DS:disk04:GAUGE:600:10:100",
		 "DS:disk05:GAUGE:600:10:100",
		 "DS:disk06:GAUGE:600:10:100",
		 "DS:disk07:GAUGE:600:10:100",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get disk data
my %val;
open HDDTEMP, "$hddtemp |", or die "can't open $hddtemp: $!\n";
while (my $hd = <HDDTEMP>) {
    $hd =~ tr /0-9//cd;
    if (length $hd) {
	$val{'HDD_TEMP_' . ($. - 1)} = $hd;
    }
}
close HDDTEMP, or die "can't close $hddtemp: $!\n";

# get cpu data
open SENSORS, "$sensors -A |", or die "can't open $sensors: $!\n";
while (my $line = <SENSORS>) {
    chomp $line;
    # celcius sign is garbaged, so pre-treat string 
    $line =~ y/-.:a-zA-Z0-9 / /c;
    if ($line =~ /^([^:]+):\s+[+-]?(\d+(\.\d+)?) /) {
	$val{$1} = $2;
    }
}
close SENSORS, or die "can't close $sensors: $!\n";


# prepare values
sub getval($)
{
    my $key = shift;
    return 'U' unless defined $key;
    return 'U' unless exists $val{$key};
    return $val{$key};
}

my $rrdstring = 'N';
foreach my $i (0..3) {
    $rrdstring .= ':' . getval($fans->[$i]);
}

foreach my $i (0..3) {
    $rrdstring .= ':' . getval($temps->[$i]);
}

foreach my $i (0..3) {
    $rrdstring .= ':' . getval($cpus->[$i]);
}

foreach my $i (0..7) {
    $rrdstring .= ':' . getval("HDD_TEMP_$i");
}

# update database
print "$rrdstring\n";
RRDs::update($datafile,
	     $rrdstring
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} temperature (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--alt-autoscale',
		'--slope-mode',

		"DEF:fan0x=${datafile}:fan0:AVERAGE",
		"DEF:temp0=${datafile}:temp0:AVERAGE",
		"DEF:temp1=${datafile}:temp1:AVERAGE",
		"DEF:disk00=${datafile}:disk00:AVERAGE",
		"DEF:disk01=${datafile}:disk01:AVERAGE",
		"DEF:disk02=${datafile}:disk02:AVERAGE",
		"DEF:disk03=${datafile}:disk03:AVERAGE",

		'CDEF:fan0=fan0x,100,/',
# platten unter 40°C sind ok
# fürs Board leider keine Werte gefunden...
		'CDEF:temp0_low=temp0,0,40,LIMIT',
		'CDEF:temp0_medium=temp0,40,45,LIMIT',
		'CDEF:temp0_high=temp0,45,999,LIMIT',
# laut http://www.cpu-world.com/info/id/AMD-K7-identification.html
# kann der Athlon XP 1400+ entweder 85°C oder gar 90°C ab
# laut lm_sensors liegt hysteria(?) bei 82°C
		'CDEF:temp1_low=temp1,0,60,LIMIT',
		'CDEF:temp1_medium=temp1,60,70,LIMIT',
		'CDEF:temp1_high=temp1,70,999,LIMIT',

		'AREA:temp1_high#F0A0A0',
		'AREA:temp1_medium#F0C0C0',
		'AREA:temp1_low#E0E0E0:cpu [°C]',
		'AREA:temp0_high#F08888',
		'AREA:temp0_medium#F0A8A8',
		'AREA:temp0_low#C8C8C8:case [°C]',
		'LINE1:temp1#000000',
		'LINE1:temp0#000000',
#		'LINE2:fan0#8080FF:cpu fan [100r/m]',
		'COMMENT:\n',
		'LINE2:disk00#0000FF:sda [°C]',
		'LINE2:disk01#FFFF00:sdb [°C]',
		'LINE2:disk02#FF0000:sdc [°C] ',
		'LINE2:disk03#00FF00:sdd [°C]',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
