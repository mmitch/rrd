#!/usr/bin/perl -w
#
# RRD script to display unbound statistics
#
# Copyright (C) 2011, 2015-2017  Christian Garbs <mitch@cgarbs.de>
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
my $datafile = "$conf{DBPATH}/unbound.rrd";
my $picbase  = "$conf{OUTPATH}/unbound-";

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
    RRDs::create($datafile,
		 "--step=60",
		 "DS:hit:ABSOLUTE:600:0:150000",
		 "DS:miss:ABSOLUTE:600:0:150000",
		 "DS:time_avg:GAUGE:600:0:30",
		 "DS:time_median:GAUGE:600:0:30",
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797',
		 'RRA:MAX:0.5:1:600',
		 'RRA:MAX:0.5:6:700',
		 'RRA:MAX:0.5:24:775',
		 'RRA:MAX:0.5:288:797'
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
}

# get data
open STATUS, '/usr/sbin/unbound-control stats|' or die "can't open unbound-control: $!";
my %stats = (
    'total.num.cachehits' => 0,
    'total.num.cachemiss' => 0,
    'total.recursion.time.avg' => 0,
    'total.recursion.time.median' => 0,
);
while (my $line = <STATUS>) {
    chomp $line;
    my ($key, $value) = split /=/, $line, 2;
    $stats{$key} = $value;
}
close STATUS or die "can't close unbound-control: $!";

# update database
RRDs::update($datafile,
	     "N:$stats{'total.num.cachehits'}:$stats{'total.num.cachemiss'}:$stats{'total.recursion.time.avg'}:$stats{'total.recursion.time.median'}"
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
		"--title=${hostname} unbound stats (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
#		'--logarithmic',
#		'--units=si',
		
		"DEF:hit=${datafile}:hit:AVERAGE",
		"DEF:miss_o=${datafile}:miss:AVERAGE",
		"DEF:hit_max=${datafile}:hit:MAX",
		"DEF:miss_o_max=${datafile}:miss:MAX",
		'CDEF:miss=0,miss_o,-',
		'CDEF:miss_max=0,miss_o_max,-',

		"DEF:time_avg_o=${datafile}:time_avg:AVERAGE",
		"DEF:time_median=${datafile}:time_median:AVERAGE",
		'CDEF:time_avg=0,time_avg_o,-',
		
		'AREA:hit_max#D0FFD0:max hit',
		'AREA:miss_max#FFD0D0:max miss',
		'AREA:hit#00F000:avg hit',
		'AREA:miss#F00000:avg miss',
		'LINE1:time_median#0000F0:median time [s]',
		'LINE1:time_avg#0000F0:avg time [-s]',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
