#!/usr/bin/perl
# $Id: diskfree.pl,v 1.1 2003-04-05 15:23:30 mitch Exp $
#
# RRD script to display disk usage
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/diskfree.rrd";
my $picbase  = "/home/mitch/rrd/diskfree-";

# watch these paths
my @path = (
	     "/",
	     "/tmp",
	     "/mnt/root",
	     "/mnt/big",
	     "/mnt/home",
	     "/mnt/storage",
	     "/mnt/tomochan",
	     "/mnt/luggage",
	     "/mnt/win",
	     "",
	     "",
	     "",
	     "",
	     "",
	     "",
	     "",
	     "",
	     "",
	     "",
	     ""
	     );

# global error variable
my $ERR;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 "--start=" . time(),
		 "DS:disk00:GAUGE:600:0:100",
		 "DS:disk01:GAUGE:600:0:100",
		 "DS:disk02:GAUGE:600:0:100",
		 "DS:disk03:GAUGE:600:0:100",
		 "DS:disk04:GAUGE:600:0:100",
		 "DS:disk05:GAUGE:600:0:100",
		 "DS:disk06:GAUGE:600:0:100",
		 "DS:disk07:GAUGE:600:0:100",
		 "DS:disk08:GAUGE:600:0:100",
		 "DS:disk09:GAUGE:600:0:100",
		 "DS:disk10:GAUGE:600:0:100",
		 "DS:disk11:GAUGE:600:0:100",
		 "DS:disk12:GAUGE:600:0:100",
		 "DS:disk13:GAUGE:600:0:100",
		 "DS:disk14:GAUGE:600:0:100",
		 "DS:disk15:GAUGE:600:0:100",
		 "DS:disk16:GAUGE:600:0:100",
		 "DS:disk17:GAUGE:600:0:100",
		 "DS:disk18:GAUGE:600:0:100",
		 "DS:disk19:GAUGE:600:0:100",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# build reverse lookup hash and initialize array
my %path;
for my $idx ( 0..19 ) {
    $path{ $path[$idx] } = $idx;
    $path[ $idx ] = 0;
}

# parse df
open DF, "df -P -l|" or die "can't open df: $!";
while ( my $line = <DF> ) {
    chomp $line;
    my $path = substr $line, 60;
    $path[ $path{ $path } ] = 0 + substr $line, 55, 3 if ( exists $path{ $path } );
}
close DF or die "can't close df: $!";

# update database
my $string=time();
for my $idx ( 0..19 ) {
    $string .= ":" . ( $path[$idx] + 0 );
}
RRDs::update($datafile,
	     $string
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-$time",
		"--lazy",
		"--title=Yggdrasil disk usage (last $scale)",
		"--upper-limit=100",
		"DEF:disk00=${datafile}:disk00:AVERAGE",
		"DEF:disk01=${datafile}:disk01:AVERAGE",
		"DEF:disk02=${datafile}:disk02:AVERAGE",
		"DEF:disk03=${datafile}:disk03:AVERAGE",
		"DEF:disk04=${datafile}:disk04:AVERAGE",
		"DEF:disk05=${datafile}:disk05:AVERAGE",
		"DEF:disk06=${datafile}:disk06:AVERAGE",
		"DEF:disk07=${datafile}:disk07:AVERAGE",
		"DEF:disk08=${datafile}:disk08:AVERAGE",
		"CDEF:total=disk00,disk01,disk02,disk03,disk04,disk05,disk06,disk07,disk08,+,+,+,+,+,+,+,+,9,/",
		"AREA:total#EEEEEE:total",
		"LINE2:disk00#EE0000:/",
		"LINE2:disk01#C8FFC8:/tmp",
		"LINE2:disk02#FFFF00:/mnt/root",
		"LINE2:disk03#EE00EE:/mnt/big",
		"LINE2:disk04#0000EE:/mnt/home",
		"LINE2:disk05#00EEEE:/mnt/storage",
		"LINE2:disk06#00C8C8:/mnt/tomochan",
		"LINE2:disk07#990099:/mnt/luggage",
		"LINE2:disk08#FF9900:/mnt/win"
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

