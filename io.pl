#!/usr/bin/perl
# $Id: io.pl,v 1.1 2003-07-20 09:01:24 mitch Exp $
#
# RRD script to display io stats
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/io.rrd";
my $picbase  = "/home/mitch/pub/rrd/io-";

# watch these paths
my @dev = (
	   "3,1",
	   "3,2",
	   "",
	   "",
	   "",
	   "",
	   "",
	   "",
	   );
my $devs = grep { $_ ne "" } @dev;
my (@read, @write);

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 "DS:io0_read:GAUGE:600:0:U",
		 "DS:io0_write:GAUGE:600:0:U",
		 "DS:io1_read:GAUGE:600:0:U",
		 "DS:io1_write:GAUGE:600:0:U",
		 "DS:io2_read:GAUGE:600:0:U",
		 "DS:io2_write:GAUGE:600:0:U",
		 "DS:io3_read:GAUGE:600:0:U",
		 "DS:io3_write:GAUGE:600:0:U",
		 "DS:io4_read:GAUGE:600:0:U",
		 "DS:io4_write:GAUGE:600:0:U",
		 "DS:io5_read:GAUGE:600:0:U",
		 "DS:io5_write:GAUGE:600:0:U",
		 "DS:io6_read:GAUGE:600:0:U",
		 "DS:io6_write:GAUGE:600:0:U",
		 "DS:io7_read:GAUGE:600:0:U",
		 "DS:io7_write:GAUGE:600:0:U",
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
my %dev;
for my $idx ( 0..7 ) {
    $dev{ $dev[$idx] } = $idx;
    $read[  $idx ] = "U";
    $write[ $idx ] = "U";
}

# get io stats
open PROC, "<", "/proc/stat" or die "can't open /proc/stat: $!\n";
my $io;
while ($io = <PROC>) {
    last if $io =~ /^disk_io:/;
}
close PROC or die "can't close /proc/stat: $!\n";

my @devices = split /\s+/, $io;
shift @devices;

foreach my $device ( @devices ) {
    $device =~ /\((.*)\):\(\d+,\d+,(\d+),\d+,(\d+)\)/;
    if ( exists $dev{ $1 } ) {
	$read[  $dev{$1} ] = $2;
	$write[ $dev{$1} ] = $3;
    }
}

# update database
my $string=time();
for my $idx ( 0..7 ) {
    $string .= ":" . ( $read[$idx] ) . ":" . ( $write[$idx] );
}
RRDs::update($datafile,
	     $string
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

exit 0;

__DATA__

# draw which values?
my (@def, @line, @gprint);
my $draw = 0;
my $PI = 3.14159265356237;
for my $idx ( 0..19 ) {
    if ( $path[$idx] ne "" ) {
	my $color = sprintf '%02X%02X%02X'
	    ,128 + (127 * sin ( 1 + $PI * ( $draw/$paths ) ) )
	    ,128 + (127 * sin (     $PI * ( $draw/$paths ) ) )
	    ,128 - (127 * sin ( 2 + $PI * ( $draw/$paths ) ) );
	push @def, sprintf 'DEF:disk%02d=%s:disk%02d:AVERAGE', $idx, $datafile, $idx;
	push @line, sprintf 'LINE2:disk%02d#%s:%s', $idx, $color, $path[$idx];
	$draw ++;
	push @gprint, sprintf 'GPRINT:disk%02d:AVERAGE:%%3.0lf', $idx;
	push @gprint, sprintf 'GPRINT:disk%02d:MIN:%%3.0lf', $idx;
	push @gprint, sprintf 'GPRINT:disk%02d:MAX:%%3.0lf', $idx;
	push @gprint, sprintf 'COMMENT:%s\n', $path[$idx];
    }
}

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} disk usage (last $scale)",
		'--upper-limit=100',

		@def,

		@line,

		'COMMENT:\n',
		'COMMENT:\n',
		'COMMENT:AVG  MIN  MAX  mount\n',
		@gprint
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

