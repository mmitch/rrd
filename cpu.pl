#!/usr/bin/perl
# $Id: cpu.pl,v 1.1 2003-07-20 08:39:27 mitch Exp $
#
# RRD script to display cpu usage
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/cpu.rrd";
my $picbase  = "/home/mitch/pub/rrd/cpu-";

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    RRDs::create($datafile,
		 "DS:user:COUNTER:600:0:U",
		 "DS:nice:COUNTER:600:0:U",
		 "DS:system:COUNTER:600:0:U",
		 "DS:idle:COUNTER:600:0:U",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get cpu usage
open PROC, "<", "/proc/stat" or die "can't open /proc/stat: $!\n";
my $cpu;
while ($cpu = <PROC>) {
    last if $cpu =~ /^cpu /;
}
close PROC or die "can't close /proc/meminfo: $!\n";

chomp $cpu;
my (undef, $user, $nice, $system, $idle) = split /\s+/, $cpu;

# update database
RRDs::update($datafile,
	     time() . ":${user}:${nice}:${system}:${idle}"
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
		"--title=${hostname} cpu usage (last $scale)",
		'--base=1024',

		"DEF:user=${datafile}:user:AVERAGE",
		"DEF:nice=${datafile}:nice:AVERAGE",
		"DEF:system=${datafile}:system:AVERAGE",
		"DEF:idle=${datafile}:idle:AVERAGE",

		'AREA:system#E00070:system',
		'STACK:user#F0A000:user',
		'STACK:nice#E0E000:nice',
		'STACK:idle#60D050:idle'
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
