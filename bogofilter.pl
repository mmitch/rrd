#!/usr/bin/perl
# $Id: bogofilter.pl,v 1.1 2007-05-31 20:27:54 mitch Exp $
#
# RRD script to display system load
# 2007 (c) by Christian Garbs <mitch@cgarbs.de>
# Licensed under GNU GPL.
#
# This script should be run every 5 minutes.
#
# *ADDITIONALLY* data aquisition is done externally for every received mail (eg. through procmailrc)
# HAM:
#    rrdtool update $datafile N:1:0:0
# UNSURE:
#    rrdtool update $datafile N:0:1:0
# SPAM:
#    rrdtool update $datafile N:0:0:1
#
use strict;
use warnings;
use RRDs;

# parse configuration file
my %conf;
eval(`cat ~/.rrd-conf.pl`);

# set variables
my $datafile = "$conf{DBPATH}/bogofilter.rrd";
my $picbase  = "$conf{OUTPATH}/bogofilter-";

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
		 "DS:ham:ABSOLUTE:120:0:U",
		 "DS:unsure:ABSOLUTE:120:0:U",
		 "DS:spam:ABSOLUTE:120:0:U",
	         "RRA:AVERAGE:0.5:1:120",
		 "RRA:AVERAGE:0.5:5:600",
		 "RRA:AVERAGE:0.5:30:700",
		 "RRA:AVERAGE:0.5:120:775",
		 "RRA:AVERAGE:0.5:1440:797",
		 );
      $ERR=RRDs::error;
      die "ERROR while creating $datafile: $ERR\n" if $ERR;
      print "created $datafile\n";
  }

# data aquisition is done externally by procmail, see above

# draw pictures
foreach ( [3600, "hour"], [86400, "day"], [604800, "week"], [31536000, "year"] ) {
    my ($time, $scale) = @{$_};
    RRDs::graph($picbase . $scale . ".png",
		"--start=-${time}",
		'--lazy',
		'--imgformat=PNG',
		"--title=${hostname} system load (last $scale)",
		"--width=$conf{GRAPH_WIDTH}",
		"--height=$conf{GRAPH_HEIGHT}",
		'--slope-mode',

		"DEF:ham=${datafile}:ham:AVERAGE",
		"DEF:unsure=${datafile}:unsure:AVERAGE",
		"DEF:spam=${datafile}:spam:AVERAGE",

		'AREA:ham#00F000:ham [messages]',
		'STACK:unsure#F0F000:unsure [messages]',
		'STACK:spam#F00000:spam [messages]',
		'COMMENT:\n',
		);
    $ERR=RRDs::error;
    die "ERROR while drawing $datafile $time: $ERR\n" if $ERR;
}
