#!/usr/bin/perl
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

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $datafile = "$conf{DBPATH}/io.rrd";
my $picbase  = "$conf{OUTPATH}/io-";

# watch these paths
my @dev = (
	   "sda",
	   "sdb",
	   "sdc",
	   "",
	   "",
	   "",
	   "",
	   "",
	   );
# 2.4: my @dev = (
#	   "8,0",
#	   "",
#	   "",
#	   "",
#	   "",
#	   "",
#	   "",
#	   "",
#	   );
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
		 "DS:io0_read:COUNTER:600:0:250000",
		 "DS:io0_write:COUNTER:600:0:250000",
		 "DS:io1_read:COUNTER:600:0:250000",
		 "DS:io1_write:COUNTER:600:0:250000",
		 "DS:io2_read:COUNTER:600:0:250000",
		 "DS:io2_write:COUNTER:600:0:250000",
		 "DS:io3_read:COUNTER:600:0:250000",
		 "DS:io3_write:COUNTER:600:0:250000",
		 "DS:io4_read:COUNTER:600:0:250000",
		 "DS:io4_write:COUNTER:600:0:250000",
		 "DS:io5_read:COUNTER:600:0:250000",
		 "DS:io5_write:COUNTER:600:0:250000",
		 "DS:io6_read:COUNTER:600:0:250000",
		 "DS:io6_write:COUNTER:600:0:250000",
		 "DS:io7_read:COUNTER:600:0:250000",
		 "DS:io7_write:COUNTER:600:0:250000",
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
open PROC, "<", "/proc/diskstats" or die "can't open /proc/diskstats: $!\n";
while (<PROC>) {
    my @io = split /\s+/;
    if ( exists $dev{ $io[3] } ) {
	$read[  $dev{$io[3] } ] = $io[ 6];
	$write[ $dev{$io[3] } ] = $io[10];
    }
}
close PROC or die "can't close /proc/diskstats: $!\n";

# 2.4: open PROC, "<", "/proc/stat" or die "can't open /proc/stat: $!\n";
#my $io;
#while ($io = <PROC>) {
#    last if $io =~ /^disk_io:/;
#}
#close PROC or die "can't close /proc/stat: $!\n";
#
#my @devices = split /\s+/, $io;
#shift @devices;
#
#foreach my $device ( @devices ) {
#    $device =~ /\((.*)\):\(\d+,\d+,(\d+),\d+,(\d+)\)/;
#    if ( exists $dev{ $1 } ) {
#	$read[  $dev{$1} ] = $2;
#	$write[ $dev{$1} ] = $3;
#    }
#}

# update database
my $string='N';
for my $idx ( 0..7 ) {
    $string .= ':' . ( $read[$idx] ) . ':' . ( $write[$idx] );
}
RRDs::update($datafile,
	     $string
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# set up colorspace
my $drawn = 0;
my @colors = qw(
		00F0B0
		E00070
		40D030
		2020F0
		E0E000
		00FF00
		0000FF
		AAAAAA
		FF00FF
		00FFFF
		000000
		900000
		C0C0C0
		009000
		000090
		909000
		900090
		009090
		FF0000
		FFFF00
	       );


# draw which values?
my (@def, @line);
$devs -- if $devs > 1;
for my $idx ( 0..7 ) {
    if ( $dev[$idx] ne "" ) {
	my $color = $colors[$drawn];
	push @def, sprintf 'DEF:io%d_read=%s:io%d_read:AVERAGE', $idx, $datafile, $idx;
	push @def, sprintf 'DEF:io%d_writ=%s:io%d_write:AVERAGE', $idx, $datafile, $idx;
	push @def, sprintf 'CDEF:io%d_write=0,io%d_writ,-', $idx, $idx;
	push @line, sprintf 'LINE1:io%d_read#%s:%s', $idx, $color, $dev[$idx];
	push @line, sprintf 'LINE1:io%d_write#%s:', $idx, $color;
	$drawn ++;
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
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--slope-mode',

		@def,

		@line,

		'COMMENT:\n',

		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
