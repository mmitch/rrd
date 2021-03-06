#!/usr/bin/perl
#
# RRD script to display system load
#
# Copyright (C) 2003, 2004, 2006-2008, 2011, 2015-2017  Christian Garbs <mitch@cgarbs.de>
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
# *ADDITIONALLY* data aquisition is done externally every minute:
# rrdtool update $datafile N:$( PROCS=`echo /proc/[0-9]*|wc -w|tr -d ' '`; read L1 L2 L3 DUMMY < /proc/loadavg ; echo ${L1}:${L2}:${L3}:${PROCS} )
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);
die $@ if $@;

# set variables
my $datafile = "$conf{DBPATH}/load.rrd";
my $picbase  = "$conf{OUTPATH}/load-";

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
    # max 70000 for all values
    RRDs::create($datafile,
		 "--step=60",
		 "DS:load1:GAUGE:120:0:70000",
		 "DS:load2:GAUGE:120:0:70000",
		 "DS:load3:GAUGE:120:0:70000",
		 "DS:procs:GAUGE:120:0:70000",
	         "RRA:AVERAGE:0.5:1:120",
		 "RRA:AVERAGE:0.5:5:600",
		 "RRA:AVERAGE:0.5:30:700",
		 "RRA:AVERAGE:0.5:120:775",
		 "RRA:AVERAGE:0.5:1440:797",
		 "RRA:MAX:0.5:1:120",
		 "RRA:MAX:0.5:5:600",
		 "RRA:MAX:0.5:6:700",
		 "RRA:MAX:0.5:120:775",
		 "RRA:MAX:0.5:1440:797",
		 "RRA:MIN:0.5:1:120",
		 "RRA:MIN:0.5:5:600",
		 "RRA:MIN:0.5:6:700",
		 "RRA:MIN:0.5:120:775",
		 "RRA:MIN:0.5:1440:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
  }

# data aquisition is done externally every minute:
# rrdtool update $datafile N:$( PROCS=`echo /proc/[0-9]*|wc -w|tr -d ' '`; read L1 L2 L3 DUMMY < /proc/loadavg ; echo ${L1}:${L2}:${L3}:${PROCS} )

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    next if $time < $MINTIME;
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} system load (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--color=BACK#f3f3f3f3',
		'--color=SHADEA#f3f3f3f3',
		'--color=SHADEB#f3f3f3f3',
		'--slope-mode',
		'--logarithmic',
		'--units=si',


		"DEF:load1=${datafile}:load1:AVERAGE",
		"DEF:load2=${datafile}:load2:AVERAGE",
		"DEF:load3=${datafile}:load3:AVERAGE",
		"DEF:procsx=${datafile}:procs:AVERAGE",
		"DEF:procminx=${datafile}:procs:MIN",
		"DEF:procmaxx=${datafile}:procs:MAX",

		'CDEF:procs=procsx,100,/',
		'CDEF:procmin=procminx,100,/',
		'CDEF:procrange=procmaxx,procminx,-,100,/',

		'AREA:procmin',
		'STACK:procrange#B0F0B0',
		'AREA:load3#000099:loadavg3',
		'LINE2:load2#0000FF:loadavg2',
		'LINE1:load1#9999FF:loadavg1',
		'COMMENT:\n',
		'LINE2:procs#00D000:processes/100',
		'GPRINT:procminx:MIN:[%.0lf',
		'COMMENT:≤',
		'GPRINT:procsx:AVERAGE:%.0lf',
		'COMMENT:≤',
		'GPRINT:procmaxx:MAX:%.0lf]',
		'COMMENT:\n',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
