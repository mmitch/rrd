#!/usr/bin/perl
# $Id: ups.pl,v 1.3 2003-07-18 19:22:19 mitch Exp $
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

# get UPS status
open UPS, "upsc mustek\@localhost|" or die "can't read from `upsc mustek\@localhost': $!\n";
my @data = <UPS>;
close UPS or die "can't close `upsc mustek\@localhost|': $!\n";

chomp @data;

my $utility  =  (split / /, $data[3])[1];
my $outvolt  =  (split / /, $data[4])[1];
my $battpct  =  (split / /, $data[5])[1];
my $battvolt =  (split / /, $data[6])[1];
my $status   = ((split / /, $data[7])[1] eq "OL") ? 1 : 0;
my $acfreq   =  (split / /, $data[8])[1];
my $loadpct  =  (split / /, $data[9])[1];

# update database
RRDs::update($datafile,
	     time() . ":${utility}:${outvolt}:${battpct}:${battvolt}:${status}:${acfreq}:${loadpct}"
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

		"DEF:volt_i=${datafile}:utility:AVERAGE",
		"DEF:volt_o=${datafile}:outvolt:AVERAGE",
		"DEF:volt_bat=${datafile}:battvolt:AVERAGE",
		"DEF:batt=${datafile}:battpct:AVERAGE",
		"DEF:load=${datafile}:loadpct:AVERAGE",

		'CDEF:volt_in=volt_i,2,/',
		'CDEF:volt_out=volt_o,2,/',

		'AREA:batt#D0FFD0:battery charge [%]',
		'LINE2:volt_out#D0D0FF:output [V/2]',
		'LINE1:volt_in#0000A0:input [V/2]',
		'LINE2:volt_bat#00A000:battery [V]',
		'LINE2:load#F0C040:AC freq [Hz]',
		'LINE1:load#F00000:load [%]',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
