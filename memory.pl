#!/usr/bin/perl
# $Id: memory.pl,v 1.8 2003-04-17 08:03:03 mitch Exp $
#
# RRD script to display memory usage
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/memory.rrd";
my $picbase  = "/home/mitch/pub/rrd/memory-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max <2GB for each value
    RRDs::create($datafile,
		 "DS:used:GAUGE:600:0:2000000000",
		 "DS:free:GAUGE:600:0:2000000000",
		 "DS:buffer:GAUGE:600:0:2000000000",
		 "DS:cache:GAUGE:600:0:2000000000",
		 "DS:swap_used:GAUGE:600:0:2000000000",
		 "DS:swap_free:GAUGE:600:0:2000000000",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get memory usage
open PROC, "<", "/proc/meminfo" or die "can't open /proc/meminfo: $!\n";
my (undef, $mem, $swap) = (<PROC>, <PROC>, <PROC>);
close PROC or die "can't close /proc/meminfo: $!\n";

chomp $mem;
my (undef, undef, $used, $free, undef, $buffer, $cache) = split /\s+/, $mem;

chomp $swap;
my (undef, undef, $swap_used, $swap_free) = split /\s+/, $swap;

# update database
RRDs::update($datafile,
	     time() . ":${used}:${free}:${buffer}:${cache}:${swap_used}:${swap_free}"
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
