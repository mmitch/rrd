#!/usr/bin/perl
# $Id: memory.pl,v 1.1 2003-04-05 14:15:10 mitch Exp $
#
# RRD script to display memory usage
# 2003 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
use strict;
use warnings;
use RRDs;

# Configurable stuff here
my $datafile = "/home/mitch/rrd/memory.rrd";
my $picbase  = "/home/mitch/rrd/memory-";

# global error variable
my $ERR;

# generate database if absent
if ( ! -e $datafile ) {
    # max <2GB for each value
    RRDs::create($datafile,
		 "--start=" . time(),
		 "DS:used:GAUGE:600:0:2000000000",
		 "DS:free:GAUGE:600:0:2000000000",
		 "DS:buffer:GAUGE:600:0:2000000000",
		 "DS:cache:GAUGE:600:0:2000000000",
		 "DS:swap_used:GAUGE:600:0:2000000000",
		 "DS:swap_free:GAUGE:600:0:2000000000",
		 "RRA:AVERAGE:0.5:1:600",
		 "RRA:AVERAGE:0.5:6:700",
		 "RRA:AVERAGE:0.5:24:775",
		 "RRA:AVERAGE:0.5:288:797"
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
}

