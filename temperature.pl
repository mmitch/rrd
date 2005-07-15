#!/usr/bin/perl
# $Id: temperature.pl,v 1.21 2005-07-15 12:53:45 mitch Exp $
#
# RRD script to display hardware temperature
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
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

# Configurable stuff here
my $datafile = "/home/mitch/rrd/temperature.rrd";
my $picbase  = "/home/mitch/pub/rrd/temperature-";
my $sensors  = "/usr/bin/sensors";
my $hddtemp  = "/usr/bin/sudo /usr/local/sbin/hddtemp.sh";
my $chip     = "w83697hf-isa-0290";

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
		 "DS:temp0:GAUGE:600:10:100",
		 "DS:temp1:GAUGE:600:10:100",
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

# get cpu data
open SENSORS, "$sensors -A $chip |", or die "can't open $sensors: $!\n";
my ( undef, undef, undef, undef, undef, undef, undef, undef, undef, $fan1, $fan2, $temp1, $temp2 )
    = (<SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>);
close SENSORS, or die "can't close $sensors: $!\n";

$fan1  = 0 + substr $fan1,  10, 4;
#$fan2  = 0 + substr $fan2,  10, 4;
$fan2  = "U";
$temp1 = 0 + substr $temp1, 10, 6;
$temp2 = 0 + substr $temp2, 10, 6;

# get disk data
open HDDTEMP, "$hddtemp |", or die "can't open $hddtemp: $!\n";
my @hd = <HDDTEMP>;
close HDDTEMP, or die "can't close $hddtemp: $!\n";
foreach my $i (0..7) {
    $hd[$i] =~ tr /0-9//cd;
}

# update database
RRDs::update($datafile,
	     time() . ":${fan1}:${fan2}:${temp1}:${temp2}:$hd[0]:$hd[1]:$hd[2]:$hd[3]:$hd[4]:$hd[5]:$hd[6]:$hd[7]"
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
		'LINE2:fan0#8080FF:cpu fan [100r/m]',
		'COMMENT:\n',
		'LINE3:disk00#0000FF:hda [°C]',
		'LINE3:disk01#FFFF00:hdb [°C]',
		'LINE3:disk02#FF0000:hdc [°C] ',
		'LINE2:disk03#00FF00:hdd [°C]',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
