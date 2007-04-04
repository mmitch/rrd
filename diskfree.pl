#!/usr/bin/perl
# $Id: diskfree.pl,v 1.17 2007-04-04 22:02:20 mitch Exp $
#
# RRD script to display disk usage
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
my $datafile = "$conf{DBPATH}/diskfree.rrd";
my $picbase  = "$conf{OUTPATH}/diskfree-";

# watch these paths
my @path = @{$conf{'DISKFREE_PATHS'}};
my $paths = grep { $_ ne "" } @path;
my @size;

# global error variable
my $ERR;

# whoami?
my $hostname = `/bin/hostname`;
chomp $hostname;

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
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
    $size[ $idx ] = "U";
}

# parse df
open DF, "df -P -l|" or die "can't open df: $!";
while ( my $line = <DF> ) {
    chomp $line;
    if ($line =~ /\s(\d{1,3})% (\/.*)$/) {
	$size[ $path{ $2 } ] = $1 if ( exists $path{ $2 } );
    }
}
close DF or die "can't close df: $!";

# update database
my $string='N';
for my $idx ( 0..19 ) {
    $string .= ":" . ( $size[$idx] );
}
RRDs::update($datafile,
	     $string
	     );
$ERR=RRDs::error;
die "ERROR while updating $datafile: $ERR\n" if $ERR;

# set up colorspace
my $drawn = 0;
my @colors = qw(
		00F0F0
		F0F040
		F000F0
		00F000
		0000F0
		000000
		AAAAAA
		F00000
		F09000
		C0C0C0
		009000
		FF0000
		000090
		900090
		009090
		909000
		E00070
		2020F0
		FF00FF
	       );

# draw which values?
my (@def, @line, @gprint);
for my $idx ( 0..19 ) {
    if ( $path[$idx] ne "" ) {
	my $color = $colors[$drawn];
	push @def, sprintf 'DEF:disk%02d=%s:disk%02d:AVERAGE', $idx, $datafile, $idx;
	push @line, sprintf 'LINE2:disk%02d#%s:%s', $idx, $color, $path[$idx];
	$drawn ++;
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
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
                '--lower-limit=0',
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

