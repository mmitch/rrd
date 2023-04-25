#!/usr/bin/perl
#
# RRD script to display disk usage
#
# Copyright (C) 2003-2008, 2011, 2015-2017  Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL v3 or later.
#
# This file is part of my rrd scripts (https://github.com/mmitch/rrd).
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

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
my $datafile = "$conf{DBPATH}/diskfree.rrd";
my $picbase  = "$conf{OUTPATH}/diskfree-";

# watch these paths
my @path = @{$conf{'DISKFREE_PATHS'}};
my @size;

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
    # max 100% for each value
    RRDs::create($datafile,
		 'DS:disk00:GAUGE:600:0:100',
		 'DS:disk01:GAUGE:600:0:100',
		 'DS:disk02:GAUGE:600:0:100',
		 'DS:disk03:GAUGE:600:0:100',
		 'DS:disk04:GAUGE:600:0:100',
		 'DS:disk05:GAUGE:600:0:100',
		 'DS:disk06:GAUGE:600:0:100',
		 'DS:disk07:GAUGE:600:0:100',
		 'DS:disk08:GAUGE:600:0:100',
		 'DS:disk09:GAUGE:600:0:100',
		 'DS:disk10:GAUGE:600:0:100',
		 'DS:disk11:GAUGE:600:0:100',
		 'DS:disk12:GAUGE:600:0:100',
		 'DS:disk13:GAUGE:600:0:100',
		 'DS:disk14:GAUGE:600:0:100',
		 'DS:disk15:GAUGE:600:0:100',
		 'DS:disk16:GAUGE:600:0:100',
		 'DS:disk17:GAUGE:600:0:100',
		 'DS:disk18:GAUGE:600:0:100',
		 'DS:disk19:GAUGE:600:0:100',
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797'
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# run df for all paths
for my $idx ( 0..19 ) {
    my $size = 'U';

    my $path = $path[$idx];

    if (defined $path and $path) {

	if ($path =~ /^zpool:(.+)$/) {
	    $path[$idx] = $1;
	    open my $zpool, '-|', "/sbin/zpool list -Hp $1" or die "can't open zpool for `$1': $!";
	    # NAME         SIZE      ALLOC        FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
	    $size = (split /\t/, <$zpool>)[7];
	    close $zpool or die "can't close zpool for `$1': $!";
	}
	else {
	    open my $df, '-|', "df -P \"$path\"" or die "can't open df for `$path': $!";
	    while ( my $line = <$df> ) {
		chomp $line;
		if ($line =~ /\s(\d{1,3})% (\/.*)$/) {
		    $size = $1 if $2 eq $path;
		}
	    }
	    close $df or die "can't close df for `$path': $!";
	}
    }
    $size[ $idx ] = $size;
}

# update database
my $string='N';
for my $idx ( 0..19 ) {
    $string .= ':' . ( $size[$idx] );
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
		00FFFF
	       );

# draw which values?
my (@def, @line, @gprint);
for my $idx ( 0..19 ) {
    if ( $path[$idx] ne '' ) {
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
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} disk usage (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
                '--lower-limit=0',
                '--upper-limit=100',
                '--rigid',

		@def,

		@line,

		'COMMENT:\n',
		'COMMENT: \n',
		'COMMENT:AVG  MIN  MAX  mount\n',
		@gprint,
		'COMMENT: \n',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

