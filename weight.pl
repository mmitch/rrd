#!/usr/bin/perl
#
# RRD script to display operator weight
#
# Copyright (C) 2007, 2011, 2013, 2015-2017  Christian Garbs <mitch@cgarbs.de>
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
# This is super special and not like the others.
# It's totally nuts and thus not part of runall.sh
#
use strict;
use warnings;
use Time::Local;

use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/weight.rrd";
my $picbase  = "$conf{OUTPATH}/weight-";

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

my $STEP   = 60 * 60 * 12; # half a day's seconds
my $FACTOR = 100000;       # don't let $quot become too small

# generate database if absent
if ( ! -e $datafile ) {
    # max 100% for each value
    RRDs::create($datafile,
		 '-b 1188662000',
		 '-s ' . $STEP,
		 'DS:weight:GAUGE:'.($STEP*2).':80:120',
		 'RRA:AVERAGE:0.5:1:750',   # roughly more than a year on half-a-day-base
		 'RRA:AVERAGE:0.5:2:1500',  # roughly four years on a daily base
		 'RRA:AVERAGE:0.5:14:550',  # roughly ten years on a weekly base
		 'RRA:AVERAGE:0.5:56:1300', # roughly 100 years on a monthly base
		 'RRA:MIN:0.5:1:750',   # roughly more than a year on half-a-day-base
		 'RRA:MIN:0.5:2:1500',  # roughly four years on a daily base
		 'RRA:MIN:0.5:14:550',  # roughly ten years on a weekly base
		 'RRA:MIN:0.5:56:1300', # roughly 100 years on a monthly base
		 'RRA:MAX:0.5:1:750',   # roughly more than a year on half-a-day-base
		 'RRA:MAX:0.5:2:1500',  # roughly four years on a daily base
		 'RRA:MAX:0.5:14:550',  # roughly ten years on a weekly base
		 'RRA:MAX:0.5:56:1300', # roughly 100 years on a monthly base
		 );

      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

sub put($$$)
{
    my ($time, $val, $lastline) = (@_);
    $val /= $FACTOR;
    RRDs::update($datafile, "$time:$val");
    $ERR=RRDs::error;
    die "ERROR while updating `$datafile' with `$time:$val' from `$lastline' in line $.: `$ERR'\n" if $ERR;
    
}

my $lastupdate = RRDs::info($datafile)->{'last_update'};
my $lasttime = undef;
my $lastval = undef;

while (my $line = <>) {
    chomp $line;
    next if $line =~ /^\s*$/;
    my ($date, $val) = split /\s+/, $line;
    $val *= $FACTOR;
    my $time = timelocal(0, 0, 6 + 12 * ((lc substr( $date, 8, 1 )) eq 'b'), substr($date, 6, 2), substr($date, 4, 2)-1, substr($date, 0, 4));
    
    if (defined $lasttime) {

	die "ERROR: duplicate time encountered in `$line' line $.\n" if ($time == $lasttime);
	
	my $quot = ($val - $lastval) / ($time - $lasttime);
	
	my $t = $lasttime + $STEP;
	while ($t <= $time) {
	    my $v = $lastval + $quot * ($t - $lasttime);
	    put($t, $v, $line);
	    $t += $STEP;
	}
	
    } else {
	if ($time <= $lastupdate) {
	    next;
	}
	put($time, $val, $line);
    }
    
    $lasttime = $time;
    $lastval = $val;
    
}

# draw pictures
my $years_back = 5;

my @VLINES;
my $current_year = (localtime(time))[5];
for (my $i = 0; $i < $years_back; $i++) {
    push @VLINES, 'VRULE:' . timelocal(0, 0, 0, 1, 0, $current_year - $i) . '#000000';
}

foreach ( [86400, 'hour', 'day'], [604800, 'day', 'week'], [31536000, 'week', 'year'], [$years_back * 31536000, 'year', $years_back . ' years'] ) {
    my ($time, $filescale, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $filescale . '.png',
		"--start=-$time",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} operator weight (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--alt-autoscale',
		'--slope-mode',
		'--alt-y-grid',
#		'--lower-limit=80',
#               '--upper-limit=120',

		"DEF:weight=$datafile:weight:AVERAGE",
		"DEF:w_min=$datafile:weight:MIN",
		"DEF:w_max=$datafile:weight:MAX",
		"DEF:oldweight=$datafile:weight:AVERAGE:end=now-${time}s:start=end-${time}s",
		"SHIFT:oldweight:$time",
#		'CDEF:smoothed=weight,'.($time/20).',TREND',
		'CDEF:w_stack=w_max,w_min,-',

		'LINE1:oldweight#BBBBBB:mass [kg] previous era',
		'AREA:w_min#00000000',
		'STACK:w_stack#FF88FF',
#		'LINE1:smoothed#008800',
		'LINE1:weight#0000D0:mass [kg]',

		@VLINES,

		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}

