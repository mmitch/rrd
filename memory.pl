#!/usr/bin/perl
#
# RRD script to display memory usage
# Copyright (C) 2003, 2011, 2015  Christian Garbs <mitch@cgarbs.de>
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
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/memory.rrd";
my $picbase  = "$conf{OUTPATH}/memory-";

# global error variable
my $ERR;

# get graph minimum time ($DETAIL_TIME in rrd_runall.sh)
my $MINTIME = 1;
if (defined $ARGV[0])
{
    $MINTIME = shift @ARGV;
}

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 3G/5G for each value
    RRDs::create($datafile,
		 "DS:used:GAUGE:600:0:3000000000",
		 "DS:free:GAUGE:600:0:3000000000",
		 "DS:buffer:GAUGE:600:0:3000000000",
		 "DS:cache:GAUGE:600:0:3000000000",
		 "DS:swap_used:GAUGE:600:0:8000000000",
		 "DS:swap_free:GAUGE:600:0:8000000000",
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
my $version = <PROC>;
my ($used, $free, $buffer, $cache, $swap_used, $swap_free);
if ($version =~ /^MemTotal/) {
    # 2.6
    $version =~ m/^([^:]+):\s+(\d+) kB$/;
    my $total = $2;
    my $swap_total;
    while (my $line = <PROC>) {
	if ($line =~ /^([^:]+):\s+(\d+) kB$/) {
	    if ($1 eq "MemFree") {
		$free = $2;
	    } elsif ($1 eq "Buffers") {
		$buffer = $2;
	    } elsif ($1 eq "Cached") {
		$cache = $2;
	    } elsif ($1 eq "SwapTotal") {
		$swap_total = $2;
	    } elsif ($1 eq "SwapFree") {
		$swap_free = $2;
	    }
	}
    }
    $total *= 1024;
    $buffer *= 1024;
    $free *= 1024;
    $cache *= 1024;
    $swap_total *= 1024;
    $swap_free *= 1024;
    $used = $total - $free;
    $swap_used = $swap_total - $swap_free;

} else {
    # 2.4
    my ($mem, $swap) = (<PROC>, <PROC>);

    chomp $mem;
    (undef, undef, $used, $free, undef, $buffer, $cache) = split /\s+/, $mem;

    chomp $swap;
    (undef, undef, $swap_used, $swap_free) = split /\s+/, $swap;
}
close PROC or die "can't close /proc/meminfo: $!\n";

# update database
RRDs::update($datafile,
	     "N:${used}:${free}:${buffer}:${cache}:${swap_used}:${swap_free}"
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} memory usage (last $scale)",
		'--base=1024',
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',

		"DEF:used_x=${datafile}:used:AVERAGE",
		"DEF:free=${datafile}:free:AVERAGE",
		"DEF:buffer=${datafile}:buffer:AVERAGE",
		"DEF:cache=${datafile}:cache:AVERAGE",
		"DEF:swap_used=${datafile}:swap_used:AVERAGE",
		"DEF:swap_free=${datafile}:swap_free:AVERAGE",

		'CDEF:used=used_x,buffer,-,cache,-',
		'CDEF:swap_total=0,swap_free,-,swap_used,-',

		'AREA:swap_total',
		'STACK:swap_used#7000E0:swap used',
		'STACK:swap_free#60D050:swap free',
		'STACK:free#90E000:mem free',
		'STACK:cache#E0E000:mem cache',
		'STACK:buffer#F0A000:mem buffer',
		'STACK:used#E00070:mem used',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
