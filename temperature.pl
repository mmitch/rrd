#!/usr/bin/perl
# $Id: temperature.pl,v 1.2 2003-04-05 16:26:24 mitch Exp $
#
# RRD script to display hardware temperature
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/temperature.rrd";
my $picbase  = "/home/mitch/rrd/temperature-";
my $sensors  = "/usr/bin/sensors";
my $hddtemp  = "/usr/bin/sudo /usr/local/bin/hddtemp.sh";

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
		 "DS:temp0:GAUGE:600:0:100",
		 "DS:temp1:GAUGE:600:0:100",
		 "DS:disk00:GAUGE:600:0:100",
		 "DS:disk01:GAUGE:600:0:100",
		 "DS:disk02:GAUGE:600:0:100",
		 "DS:disk03:GAUGE:600:0:100",
		 "DS:disk04:GAUGE:600:0:100",
		 "DS:disk05:GAUGE:600:0:100",
		 "DS:disk06:GAUGE:600:0:100",
		 "DS:disk07:GAUGE:600:0:100",
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
open SENSORS, "$sensors -A |", or die "can't open $sensors: $!\n";
my ( undef, undef, undef, undef, undef, undef, undef, undef, undef, $fan1, $fan2, $temp1, $temp2 )
    = (<SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>, <SENSORS>);
close SENSORS, or die "can't close $sensors: $!\n";

$fan1  = 0 + substr $fan1,  10, 4;
$fan2  = 0 + substr $fan2,  10, 4;
$temp1 = 0 + substr $temp1, 10, 6;
$temp2 = 0 + substr $temp2, 10, 6;

# get disk data
open HDDTEMP, "$hddtemp |", or die "can't open $hddtemp: $!\n";
my ($hda, $hdb, $hdc, $hdd, $sda, $sdb, $sdc, $sdd)
    = (<HDDTEMP> + 0, <HDDTEMP> + 0, <HDDTEMP> + 0, <HDDTEMP> + 0, <HDDTEMP> + 0, <HDDTEMP> + 0, <HDDTEMP> + 0, <HDDTEMP> + 0);
close HDDTEMP, or die "can't close $hddtemp: $!\n";

# update database
RRDs::update($datafile,
	     time() . ":${fan1}:${fan2}:${temp1}:${temp2}:${hda}:${hdb}:${hdc}:${hdd}:${sda}:${sdb}:${sdc}:${sdd}"
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-$time",
		"--lazy",
		"--title=${hostname} temperature (last $scale)",
		"DEF:fan0x=${datafile}:fan0:AVERAGE",
		"CDEF:fan0=fan0x,100,/",
		"DEF:temp0=${datafile}:temp0:AVERAGE",
		"DEF:temp1=${datafile}:temp1:AVERAGE",
		"DEF:disk02=${datafile}:disk02:AVERAGE",
		"DEF:disk03=${datafile}:disk03:AVERAGE",
		'AREA:temp1#E0E0E0:cpu [°C]',
		'AREA:temp0#C8C8C8:case [°C]',
		'LINE1:temp1#000000',
		'LINE1:temp0#000000',
		'LINE2:fan0#8080FF:cpu fan [100r/m]',
		'LINE3:disk02#EE00C0:hdc [°C]',
		'LINE2:disk03#00FF00:hdd [°C]',
		'COMMENT:\n',
		'COMMENT:            MIN   MAX  CURR\n',
		'COMMENT:---------------------------\n',
		'GPRINT:fan0x:MIN:cpu  fan\:  %4.0lf',
		'GPRINT:fan0x:MAX:%4.0lf',
		'GPRINT:fan0x:AVERAGE:%4.0lf\n',
		'GPRINT:temp0:MIN:cpu  temp\: %4.0lf',
		'GPRINT:temp0:MAX:%4.0lf',
		'GPRINT:temp0:AVERAGE:%4.0lf\n',
		'GPRINT:temp1:MIN:case temp\: %4.0lf',
		'GPRINT:temp1:MAX:%4.0lf',
		'GPRINT:temp1:AVERAGE:%4.0lf\n',
		'GPRINT:disk02:MIN:hdc  temp\: %4.0lf',
		'GPRINT:disk02:MAX:%4.0lf',
		'GPRINT:disk02:AVERAGE:%4.0lf\n',
		'GPRINT:disk03:MIN:hdd  temp\: %4.0lf',
		'GPRINT:disk03:MAX:%4.0lf',
		'GPRINT:disk03:AVERAGE:%4.0lf'
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
