#!/usr/bin/perl
#
# RRD script to display cpufreq statistics
#
# Copyright (C) 2007, 2008, 2011, 2015, 2017  Christian Garbs <mitch@cgarbs.de>
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
my $datafile = "$conf{DBPATH}/cpufreq.rrd";
my $picbase  = "$conf{OUTPATH}/cpufreq-";
my $stats = '/sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state';
my @colors = qw(
                00F0B0
                E00070
                40D030
                2020F0
                E0E000
                00FF00
                0000FF
                AAAAAA
		);

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
		 '--step=60',
		 'DS:state0:COUNTER:600:0:32000',
		 'DS:state1:COUNTER:600:0:32000',
		 'DS:state2:COUNTER:600:0:32000',
		 'DS:state3:COUNTER:600:0:32000',
		 'DS:state4:COUNTER:600:0:32000',
		 'DS:state5:COUNTER:600:0:32000',
		 'RRA:AVERAGE:0.5:1:600',
		 'RRA:AVERAGE:0.5:6:700',
		 'RRA:AVERAGE:0.5:24:775',
		 'RRA:AVERAGE:0.5:288:797',
		 );
      
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
  }

# get data
open STATS, '<', $stats or die "can't open `$stats': $!";
my @stats = ('U', 'U', 'U', 'U', 'U', 'U');
my @name;
while (my $line = <STATS>) {
    last if $. > 6;
    chomp $line;
    my ($name, $stat) = split /\s+/, $line;
    push @name, $name;
    $stats[$.-1] = $stat;
}
close STATS or die "can't close `$stats': $!";

# update database
RRDs::update($datafile,
	     join ':', ('N', @stats),
	     );

# draw pictures
foreach ( [3600, 'hour'], [86400, 'day'], [604800, 'week'], [31536000, 'year'] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;

    my (@def, @area);

    for my $i (0 .. (scalar @name - 1)) {
	push @def,  "DEF:state${i}=${datafile}:state${i}:AVERAGE";
	push @area, ($i ? 'STACK' : 'AREA') . ":state${i}#${colors[$i]}:${name[$i]}";
    }

    RRDs::graph($picbase . $scale . '.png',
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} cpu frequencies (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--upper-limit=100',
		'--lower-limit=0',
                '--rigid',
		
		@def,
		@area,
		
                'COMMENT:\n',

		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
