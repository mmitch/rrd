#!/usr/bin/perl
# $Id: ups.pl,v 1.1 2003-07-18 18:37:44 mitch Exp $
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
print $status;

# update database
RRDs::update($datafile,
	     time() . ":${utility}:${outvolt}:${battpct}:${battvolt}:${status}:${acfreq}:${loadpct}"
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

exit 0;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} memory usage (last $scale)",
		'--base=1024',

		"DEF:used_x=${datafile}:used:AVERAGE",
		"DEF:free=${datafile}:free:AVERAGE",
		"DEF:buffer=${datafile}:buffer:AVERAGE",
		"DEF:cache=${datafile}:cache:AVERAGE",
		"DEF:swap_used=${datafile}:swap_used:AVERAGE",
		"DEF:swap_free=${datafile}:swap_free:AVERAGE",

		"CDEF:used=used_x,buffer,-,cache,-",
		"CDEF:swap_total=0,swap_free,-,swap_used,-",

		'AREA:swap_total',
		'STACK:swap_used#7000E0:swap used',
		'STACK:swap_free#60D050:swap free',
		'STACK:free#90E000:mem free',
		'STACK:cache#E0E000:mem cache',
		'STACK:buffer#F0A000:mem buffer',
		'STACK:used#E00070:mem used'
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
