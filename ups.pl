#!/usr/bin/perl
# $Id: ups.pl,v 1.6 2004-04-01 09:16:58 mitch Exp $
#
# RRD script to display ups values
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
my $datafile = "/home/mitch/rrd/ups.rrd";
my $picbase  = "/home/mitch/pub/rrd/ups-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 "DS:utility:GAUGE:600:0:500",
		 "DS:outvolt:GAUGE:600:0:500",
		 "DS:battpct:GAUGE:600:0:110",
		 "DS:battvolt:GAUGE:600:0:500",
		 "DS:acfreq:GAUGE:600:0:100",
		 "DS:loadpct:GAUGE:600:0:500",
		 "DS:online:GAUGE:600:0:1",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# set empty values
my %status = (
    'battery.charge'  => 0,
    'battery.voltage' => 0,
    'input.frequency' => 0,
    'input.voltage'   => 0,
    'output.voltage'  => 0,
    'ups.load'        => 0,
    'ups.status'      => 0
    );


# get UPS status
open UPS, "upsc mustek\@localhost|" or die "can't read from `upsc mustek\@localhost': $!\n";
while (my $line = <UPS>) {
    chomp $line;
    my ($key, $value) = split /: /, $line, 2;
    $status{$key} = $value;
}
close UPS or die "can't close `upsc mustek\@localhost|': $!\n";

$status{'ups.status'} = ($status{'ups.status'} =~ /^OL/) ? 1 : 0;

# update database
RRDs::update($datafile,
	     time() . ":$status{'input.voltage'}:$status{'output.voltage'}:$status{'battery.charge'}:$status{'battery.voltage'}:$status{'input.frequency'}:$status{'ups.load'}:$status{'ups.status'}"
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
		"--title=${hostname} ups status (last $scale)",
		'--base=1000',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",

		"DEF:volt_i=${datafile}:utility:AVERAGE",
		"DEF:volt_o=${datafile}:outvolt:AVERAGE",
		"DEF:volt_bat=${datafile}:battvolt:AVERAGE",
		"DEF:batt=${datafile}:battpct:AVERAGE",
		"DEF:load=${datafile}:loadpct:AVERAGE",
		"DEF:freq=${datafile}:acfreq:AVERAGE",
		"DEF:status=${datafile}:online:AVERAGE",

		'CDEF:volt_in=volt_i,2,/',
		'CDEF:volt_out=volt_o,2,/',
		'CDEF:online=status,100,*',
		'CDEF:offline=100,online,-',

		'AREA:online#D0FFD0:online [%]',
		'STACK:offline#FFD0D0:offline [%]',
		'AREA:batt#D0D0FF:battery charge [%]\n',
		'LINE2:volt_out#D0D0FF:output [V/2]',
		'LINE1:volt_in#0000A0:input [V/2]',
		'LINE2:volt_bat#00A000:battery [V]',
		'LINE2:freq#F0C840:AC freq [Hz]',
		'LINE2:load#F00000:load [%]',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
