#!/usr/bin/perl
# $Id: load.pl,v 1.3 2003-04-05 20:53:15 mitch Exp $
#
# RRD script to display system load
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/load.rrd";
my $picbase  = "/home/mitch/rrd/load-";

# global error variable
my $ERR;

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

# data aquisition is done externally:
# rrdtool update $datafile $( PROCS=`echo /proc/[0-9]*|wc -w|tr -d ' '`; read L1 L2 L3 DUMMY < /proc/loadavg ; echo $( date +\%s ):${L1}:${L2}:${L3}:${PROCS} )

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-$time",
		"--lazy",
		"--title=${hostname} system load (last $scale)",
		"DEF:load1x=${datafile}:load1:AVERAGE",
		"DEF:load2x=${datafile}:load2:AVERAGE",
		"DEF:load3x=${datafile}:load3:AVERAGE",
		"DEF:procs=${datafile}:procs:AVERAGE",
		"DEF:procmin=${datafile}:procs:MIN",
		"DEF:procmax=${datafile}:procs:MAX",
		'CDEF:load1=load1x,100,*',
		'CDEF:load2=load2x,100,*',
		'CDEF:load3=load3x,100,*',
		'CDEF:procrange=procmax,procmin,-',
		'AREA:procmin',
		'STACK:procrange#E0E0E0',
		'AREA:load3#000099:loadavg3 [*100]',
		'LINE2:load2#0000FF:loadavg2 [*100]',
		'LINE1:load1#9999FF:loadavg1 [*100]',
		'LINE1:procs#000000:processes',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
