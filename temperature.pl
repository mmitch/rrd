#!/usr/bin/perl
# $Id: temperature.pl,v 1.31 2007-07-13 18:32:28 mitch Exp $
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
my $multiline = 0;
while (my $line = <SENSORS>) {
    chomp $line;
    # celcius sign is garbaged, so pre-treat string 
    $line =~ y/-.:a-zA-Z0-9 / /c;

    if ($multiline and $line !~ /:/) {
	if ($line =~ /^\s+\+?(-?\d+(\.\d+)?) /) {
	    $val{$multiline} = $1;
	}
	$multiline = 0;
    } else {
	if ($line =~ /^([^:]+):(\s+\+?(-?\d+(\.\d+)?) )?/) {
	    if (defined $2) {
		$val{$1} = $3;
	    } else {
		$multiline = $1;
	    }
	}
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
		"DEF:fan1x=${datafile}:fan1:AVERAGE",
		"DEF:fan2x=${datafile}:fan2:AVERAGE",
		"DEF:fan3x=${datafile}:fan3:AVERAGE",
		"DEF:temp0=${datafile}:temp0:AVERAGE",
		"DEF:temp1=${datafile}:temp1:AVERAGE",
		"DEF:temp2=${datafile}:temp2:AVERAGE",
		"DEF:temp3=${datafile}:temp3:AVERAGE",
		"DEF:cpu0=${datafile}:cpu0:AVERAGE",
		"DEF:cpu1=${datafile}:cpu1:AVERAGE",
		"DEF:cpu2=${datafile}:cpu2:AVERAGE",
		"DEF:cpu3=${datafile}:cpu3:AVERAGE",
		"DEF:disk00=${datafile}:disk00:AVERAGE",
		"DEF:disk01=${datafile}:disk01:AVERAGE",
		"DEF:disk02=${datafile}:disk02:AVERAGE",
		"DEF:disk03=${datafile}:disk03:AVERAGE",
		"DEF:disk04=${datafile}:disk04:AVERAGE",
		"DEF:disk05=${datafile}:disk05:AVERAGE",
		"DEF:disk06=${datafile}:disk06:AVERAGE",
		"DEF:disk07=${datafile}:disk07:AVERAGE",

		'CDEF:fan0=fan0x,33,/',
		'CDEF:fan1=fan1x,33,/',
		'CDEF:fan2=fan2x,33,/',
		'CDEF:fan3=fan3x,33,/',

		'CDEF:fan1s=fan0,fan1,-',
		'CDEF:cpu1s=cpu0,cpu1,-',
		'CDEF:temp1s=temp0,temp1,-',

		'AREA:fan0#8888FF00',
		'STACK:fan1s#8888FF:fan [33r/m]',

		'AREA:cpu0#FF888800',
		'STACK:cpu1s#FF8888:cpu core [°C]',

		'AREA:temp0#44444400',
		'STACK:temp1s#444444:board [°C]',

		'COMMENT:\n',
		'LINE2:disk00#0000FF:sda [°C]',
		'LINE2:disk01#FFFF00:sdb [°C]',
		'LINE2:disk02#FF0000:sdc [°C] ',
		'LINE2:disk03#00FF00:sdd [°C]',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
