#!/usr/bin/perl
# $Id: io.pl,v 1.3 2003-08-02 09:08:51 mitch Exp $
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
	   "3,0",
	   "3,1",
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
		 "DS:io0_read:COUNTER:600:0:100000",
		 "DS:io0_write:COUNTER:600:0:100000",
		 "DS:io1_read:COUNTER:600:0:100000",
		 "DS:io1_write:COUNTER:600:0:100000",
		 "DS:io2_read:COUNTER:600:0:100000",
		 "DS:io2_write:COUNTER:600:0:100000",
		 "DS:io3_read:COUNTER:600:0:100000",
		 "DS:io3_write:COUNTER:600:0:100000",
		 "DS:io4_read:COUNTER:600:0:100000",
		 "DS:io4_write:COUNTER:600:0:100000",
		 "DS:io5_read:COUNTER:600:0:100000",
		 "DS:io5_write:COUNTER:600:0:100000",
		 "DS:io6_read:COUNTER:600:0:100000",
		 "DS:io6_write:COUNTER:600:0:100000",
		 "DS:io7_read:COUNTER:600:0:100000",
		 "DS:io7_write:COUNTER:600:0:100000",
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

# draw which values?
my (@def, @line);
my $draw = 0;
my $PI = 3.14159265356237;
$devs -- if $devs > 1;
for my $idx ( 0..7 ) {
    if ( $dev[$idx] ne "" ) {
	my $color = sprintf '%02X%02X%02X'
	    ,128 + (127 * sin ( 1 + $PI * ( $draw/$devs ) ) )
	    ,128 + (127 * sin (     $PI * ( $draw/$devs ) ) )
	    ,128 - (127 * sin ( 2 + $PI * ( $draw/$devs ) ) );
	push @def, sprintf 'DEF:io%d_read=%s:io%d_read:AVERAGE', $idx, $datafile, $idx;
	push @def, sprintf 'DEF:io%d_writ=%s:io%d_write:AVERAGE', $idx, $datafile, $idx;
	push @def, sprintf 'CDEF:io%d_write=0,io%d_writ,-', $idx, $idx;
	push @line, sprintf 'LINE1:io%d_read#%s:(%s) in', $idx, $color, $dev[$idx];
	push @line, sprintf 'LINE1:io%d_write#%s:(%s) out', $idx, $color, $dev[$idx];
	$draw ++;
    }
}

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} io statistics (last $scale)",

		@def,

		@line
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

